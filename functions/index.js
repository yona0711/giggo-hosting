const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
const CREATE_TOKEN_MAX_ATTEMPTS = 10;
const APPROVE_MAX_ATTEMPTS = 10;

function sha256(input) {
  return crypto.createHash('sha256').update(input, 'utf8').digest('hex');
}

function extractBearerToken(req) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

function getRequestIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').trim();
  if (forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return String(req.ip || req.connection?.remoteAddress || 'unknown').trim();
}

async function enforceRateLimit({ req, endpoint, maxAttempts }) {
  const ip = getRequestIp(req);
  const key = sha256(`${endpoint}:${ip}`);
  const ref = admin.firestore().collection('_rateLimits').doc(key);
  const nowMillis = Date.now();
  let blocked = false;
  let retryAfterSeconds = 0;

  await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    if (!snapshot.exists) {
      transaction.set(ref, {
        endpoint,
        ip,
        count: 1,
        resetAt: admin.firestore.Timestamp.fromMillis(
          nowMillis + RATE_LIMIT_WINDOW_MS,
        ),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const data = snapshot.data() || {};
    const count = Number(data.count || 0);
    const resetAt = data.resetAt;
    const resetAtMillis =
      resetAt && typeof resetAt.toMillis === 'function'
        ? resetAt.toMillis()
        : nowMillis + RATE_LIMIT_WINDOW_MS;

    if (resetAtMillis <= nowMillis) {
      transaction.set(
        ref,
        {
          endpoint,
          ip,
          count: 1,
          resetAt: admin.firestore.Timestamp.fromMillis(
            nowMillis + RATE_LIMIT_WINDOW_MS,
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    if (count >= maxAttempts) {
      blocked = true;
      retryAfterSeconds = Math.max(1, Math.ceil((resetAtMillis - nowMillis) / 1000));
      return;
    }

    transaction.set(
      ref,
      {
        endpoint,
        ip,
        count: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return { blocked, retryAfterSeconds };
}

async function sendParentApprovalEmail({ parentEmail, approvalToken }) {
  const sendgridApiKey = process.env.SENDGRID_API_KEY;
  const fromEmail = process.env.PARENT_APPROVAL_FROM_EMAIL;
  const appBaseUrl =
    process.env.PARENT_APPROVAL_BASE_URL || 'https://giggo-8a302.web.app';

  const approvalLink = `${appBaseUrl.replace(/\/$/, '')}/?token=${encodeURIComponent(approvalToken)}&email=${encodeURIComponent(parentEmail)}`;

  if (!sendgridApiKey || !fromEmail) {
    logger.warn('SendGrid env vars not set. Returning approval link without sending email.', {
      approvalLink,
      parentEmail,
    });
    return {
      sent: false,
      approvalLink,
    };
  }

  sgMail.setApiKey(sendgridApiKey);
  await sgMail.send({
    to: parentEmail,
    from: fromEmail,
    subject: 'Giggo parent approval request',
    text: `A teen account needs your approval. Open this link to approve: ${approvalLink}`,
    html: `<p>A teen account needs your approval.</p><p><a href="${approvalLink}">Approve teen account</a></p><p>If the button doesn't work, use this link: ${approvalLink}</p>`,
  });

  return {
    sent: true,
    approvalLink,
  };
}

exports.createTeenApprovalToken = onRequest(
  {
    cors: true,
    secrets: ['SENDGRID_API_KEY', 'PARENT_APPROVAL_FROM_EMAIL'],
  },
  async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const rateLimit = await enforceRateLimit({
    req,
    endpoint: 'createTeenApprovalToken',
    maxAttempts: CREATE_TOKEN_MAX_ATTEMPTS,
  });
  if (rateLimit.blocked) {
    res.status(429).json({
      message: 'Too many attempts. Please try again later.',
      retryAfterSeconds: rateLimit.retryAfterSeconds,
    });
    return;
  }

  const idToken = extractBearerToken(req);
  if (!idToken) {
    res.status(401).json({ message: 'Authorization token is required.' });
    return;
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const authUid = String(decoded.uid || '').trim();
    const childUid = String(req.body?.childUid ?? '').trim();
    const parentEmail = String(req.body?.parentEmail ?? '').trim().toLowerCase();

    if (!authUid || !childUid || !parentEmail) {
      res.status(400).json({ message: 'childUid and parentEmail are required.' });
      return;
    }

    if (authUid !== childUid) {
      res.status(403).json({ message: 'Token does not match child account.' });
      return;
    }

    const userRef = admin.firestore().collection('users').doc(childUid);
    const snapshot = await userRef.get();

    if (!snapshot.exists) {
      res.status(404).json({ message: 'Child account not found.' });
      return;
    }

    const profile = snapshot.data() || {};
    const profileParentEmail = String(profile.parentEmail || '').trim().toLowerCase();
    const approvalStatus = String(profile.approvalStatus || 'pending');

    if (approvalStatus !== 'pending') {
      res.status(409).json({ message: 'Account is not pending approval.' });
      return;
    }

    if (!profileParentEmail || profileParentEmail !== parentEmail) {
      res.status(403).json({ message: 'Parent email does not match registration.' });
      return;
    }

    const approvalToken = crypto.randomBytes(24).toString('hex');
    const approvalTokenHash = sha256(approvalToken);
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await userRef.update({
      approvalTokenHash,
      approvalTokenExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      approvalTokenIssuedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const mailResult = await sendParentApprovalEmail({
      parentEmail,
      approvalToken,
    });

    res.json({
      approvalToken,
      expiresAt: expiresAt.toISOString(),
      emailSent: mailResult.sent,
      approvalLink: mailResult.approvalLink,
    });
  } catch (error) {
    logger.error('createTeenApprovalToken failed', error);
    res.status(500).json({ message: 'Unable to initialize parent approval token.' });
  }
  },
);

exports.approveTeenAccount = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const approvalToken = String(req.body?.approvalToken ?? '').trim();
  const parentEmail = String(req.body?.parentEmail ?? '').trim().toLowerCase();

  if (!approvalToken || !parentEmail) {
    res.status(400).json({ message: 'approvalToken and parentEmail are required.' });
    return;
  }

  const rateLimit = await enforceRateLimit({
    req,
    endpoint: 'approveTeenAccount',
    maxAttempts: APPROVE_MAX_ATTEMPTS,
  });
  if (rateLimit.blocked) {
    res.status(429).json({
      message: 'Too many attempts. Please try again later.',
      retryAfterSeconds: rateLimit.retryAfterSeconds,
    });
    return;
  }

  try {
    const approvalTokenHash = sha256(approvalToken);
    const query = await admin
      .firestore()
      .collection('users')
      .where('approvalTokenHash', '==', approvalTokenHash)
      .limit(1)
      .get();

    if (query.empty) {
      res.status(404).json({ message: 'Invalid or expired approval token.' });
      return;
    }

    const userDoc = query.docs[0];
    const userRef = userDoc.ref;
    const profile = userDoc.data() || {};
    const profileParentEmail = String(profile.parentEmail || '').trim().toLowerCase();
    const approvalStatus = String(profile.approvalStatus || 'pending');
    const expiresAt = profile.approvalTokenExpiresAt;

    if (!expiresAt || typeof expiresAt.toDate !== 'function') {
      res.status(410).json({ message: 'Approval token has expired.' });
      return;
    }

    if (expiresAt.toDate().getTime() <= Date.now()) {
      res.status(410).json({ message: 'Approval token has expired.' });
      return;
    }

    if (approvalStatus !== 'pending') {
      res.status(409).json({ message: 'Account is not pending approval.' });
      return;
    }

    if (!profileParentEmail || profileParentEmail !== parentEmail) {
      res.status(403).json({ message: 'Parent email does not match.' });
      return;
    }

    await userRef.update({
      approvalStatus: 'approved',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      parentPayoutApproval: true,
      hasParentMonitoring: true,
      approvalTokenHash: admin.firestore.FieldValue.delete(),
      approvalTokenExpiresAt: admin.firestore.FieldValue.delete(),
      approvalTokenIssuedAt: admin.firestore.FieldValue.delete(),
    });

    res.json({ message: 'Parent approval granted.' });
  } catch (error) {
    logger.error('approveTeenAccount failed', error);
    res.status(500).json({ message: 'Unable to approve account right now.' });
  }
});
