const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const sgMail = require('@sendgrid/mail');
const Stripe = require('stripe');

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

const apiApp = express();
const platformCommissionRate = 0.20;

apiApp.use(cors({ origin: true }));

function stripeClient() {
  const stripeSecretKey = process.env.STRIPE_SECRET_KEY || '';
  return stripeSecretKey ? new Stripe(stripeSecretKey) : null;
}

function appBaseUrl(req) {
  const configured = process.env.APP_BASE_URL || process.env.PARENT_APPROVAL_BASE_URL;
  const origin = req.get('origin');
  return (configured || origin || 'https://giggo-8a302.web.app').replace(/\/$/, '');
}

function providerAccountRef(providerUid) {
  return admin.firestore().collection('_providerAccounts').doc(providerUid);
}

function paymentCustomerRef(userUid) {
  return admin.firestore().collection('_paymentCustomers').doc(userUid);
}

function paymentRecordRef(paymentIntentId) {
  return admin.firestore().collection('_paymentRecords').doc(paymentIntentId);
}

async function upsertEscrowFromPaymentRecord(record) {
  if (!record || !record.bookingId) {
    return;
  }

  await admin
    .firestore()
    .collection('escrows')
    .doc(`escrow_${record.bookingId}`)
    .set(
      {
        gigId: record.serviceTitle || record.bookingId,
        bookingId: record.bookingId,
        amount: record.amount,
        serviceTitle: record.serviceTitle || '',
        clientUid: record.clientUid,
        providerUid: record.providerUid,
        status: record.status,
        processorMode: record.mode,
        processorPaymentId: record.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

function mapStripeStatusToEscrowStatus(status) {
  switch (status) {
    case 'succeeded':
      return 'funded';
    case 'requires_payment_method':
    case 'requires_confirmation':
    case 'requires_action':
    case 'processing':
      return 'pendingFunding';
    case 'canceled':
      return 'disputed';
    default:
      return 'pendingFunding';
  }
}

async function saveCustomerPaymentMethod({
  userUid,
  customerId,
  paymentMethodId,
  mode = 'stripe',
}) {
  if (!userUid || !customerId || !paymentMethodId) {
    return null;
  }

  const stripe = stripeClient();
  let paymentMethod = null;
  if (stripe && mode === 'stripe') {
    paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);
    await stripe.customers.update(customerId, {
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
    });
  }

  const card = paymentMethod?.card || {};
  const payload = {
    userUid,
    customerId,
    defaultPaymentMethodId: paymentMethodId,
    cardBrand: card.brand || null,
    cardLast4: card.last4 || null,
    mode,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await paymentCustomerRef(userUid).set(payload, { merge: true });
  return payload;
}

async function updatePaymentStatus(paymentIntentId, status) {
  const snapshot = await paymentRecordRef(paymentIntentId).get();
  if (!snapshot.exists) {
    return;
  }

  const record = {
    ...snapshot.data(),
    id: paymentIntentId,
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await paymentRecordRef(paymentIntentId).set(record, { merge: true });
  await upsertEscrowFromPaymentRecord(record);
}

apiApp.post(
  '/api/payments/webhook',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const stripe = stripeClient();
    const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET || '';
    if (!stripe || !stripeWebhookSecret) {
      res.status(503).json({
        message:
          'Stripe webhook is not configured. Set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET.',
      });
      return;
    }

    const signature = req.headers['stripe-signature'];
    if (!signature) {
      res.status(400).json({ message: 'Missing Stripe signature.' });
      return;
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        signature,
        stripeWebhookSecret,
      );
    } catch (error) {
      res.status(400).json({ message: `Webhook Error: ${error.message}` });
      return;
    }

    try {
      switch (event.type) {
        case 'checkout.session.completed': {
          const session = event.data.object;
          if (session.mode === 'setup' && session.setup_intent) {
            const setupIntent = await stripe.setupIntents.retrieve(
              session.setup_intent,
            );
            const userUid =
              session.metadata?.userUid || setupIntent.metadata?.userUid;
            const paymentMethodId =
              typeof setupIntent.payment_method === 'string'
                ? setupIntent.payment_method
                : setupIntent.payment_method?.id;
            const customerId =
              typeof session.customer === 'string'
                ? session.customer
                : session.customer?.id;

            await saveCustomerPaymentMethod({
              userUid,
              customerId,
              paymentMethodId,
            });
          }
          break;
        }
        case 'setup_intent.succeeded': {
          const setupIntent = event.data.object;
          const userUid = setupIntent.metadata?.userUid;
          const paymentMethodId =
            typeof setupIntent.payment_method === 'string'
              ? setupIntent.payment_method
              : setupIntent.payment_method?.id;
          const customerId =
            typeof setupIntent.customer === 'string'
              ? setupIntent.customer
              : setupIntent.customer?.id;

          await saveCustomerPaymentMethod({
            userUid,
            customerId,
            paymentMethodId,
          });
          break;
        }
        case 'payment_intent.succeeded':
          await updatePaymentStatus(event.data.object.id, 'funded');
          break;
        case 'payment_intent.payment_failed':
          await updatePaymentStatus(event.data.object.id, 'failed');
          break;
        case 'payment_intent.canceled':
          await updatePaymentStatus(event.data.object.id, 'canceled');
          break;
        case 'charge.dispute.created': {
          const paymentIntentId = event.data.object.payment_intent;
          if (typeof paymentIntentId === 'string' && paymentIntentId) {
            await updatePaymentStatus(paymentIntentId, 'disputed');
          }
          break;
        }
        case 'account.updated': {
          const account = event.data.object;
          const snapshot = await admin
            .firestore()
            .collection('_providerAccounts')
            .where('accountId', '==', account.id)
            .limit(1)
            .get();

          if (!snapshot.empty) {
            await snapshot.docs[0].ref.set(
              {
                payoutsEnabled: Boolean(account.payouts_enabled),
                chargesEnabled: Boolean(account.charges_enabled),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true },
            );
          }
          break;
        }
        default:
          break;
      }
    } catch (error) {
      logger.error('Stripe webhook handling failed', error);
      res.status(500).json({ message: error.message });
      return;
    }

    res.json({ received: true });
  },
);

apiApp.use(express.json());

apiApp.get('/api/health', (_req, res) => {
  res.json({
    status: 'ok',
    paymentsMode: stripeClient() ? 'stripe' : 'mock',
    webhookConfigured: Boolean(process.env.STRIPE_WEBHOOK_SECRET),
  });
});

apiApp.post('/api/providers/connect-account', async (req, res) => {
  const {
    providerUid,
    email,
    country = 'US',
    accountId: providedAccountId,
  } = req.body || {};

  if (!providerUid || !email) {
    res.status(400).json({ message: 'providerUid and email are required.' });
    return;
  }

  const stripe = stripeClient();
  const providerRef = providerAccountRef(providerUid);

  if (!stripe) {
    const accountId = `mock_acct_${providerUid}`;
    await providerRef.set(
      {
        accountId,
        providerUid,
        email,
        payoutsEnabled: true,
        chargesEnabled: true,
        mode: 'mock',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    res.status(201).json({
      accountId,
      onboardingUrl: `${appBaseUrl(req)}/provider/onboarding/mock/${providerUid}`,
      mode: 'mock',
    });
    return;
  }

  try {
    const existingSnapshot = await providerRef.get();
    const existing = existingSnapshot.data();
    if (existing?.accountId) {
      res.json({ accountId: existing.accountId, mode: 'stripe' });
      return;
    }

    let account;
    if (providedAccountId && String(providedAccountId).trim()) {
      account = await stripe.accounts.retrieve(String(providedAccountId).trim());
    } else {
      account = await stripe.accounts.create({
        type: 'express',
        email: String(email).trim().toLowerCase(),
        country,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
      });
    }

    await providerRef.set(
      {
        accountId: account.id,
        providerUid,
        email,
        payoutsEnabled: Boolean(account.payouts_enabled),
        chargesEnabled: Boolean(account.charges_enabled),
        mode: 'stripe',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await admin.firestore().collection('users').doc(providerUid).set(
      {
        stripeAccountId: account.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    res.status(providedAccountId ? 200 : 201).json({
      accountId: account.id,
      mode: 'stripe',
    });
  } catch (error) {
    logger.error('connect-account failed', error);
    res.status(500).json({ message: error.message });
  }
});

apiApp.post('/api/providers/:providerUid/onboarding-link', async (req, res) => {
  const providerUid = String(req.params.providerUid || '').trim();
  const requestedAccountId = req.body?.accountId;
  const providerSnapshot = await providerAccountRef(providerUid).get();
  const provider = providerSnapshot.data();
  const accountId =
    provider?.accountId ||
    (typeof requestedAccountId === 'string' && requestedAccountId.trim()
      ? requestedAccountId.trim()
      : null);

  if (!providerUid || !accountId) {
    res.status(404).json({ message: 'Provider payment account not found.' });
    return;
  }

  const stripe = stripeClient();
  if (!stripe) {
    res.json({
      url: `${appBaseUrl(req)}/provider/onboarding/mock/${providerUid}`,
      mode: 'mock',
    });
    return;
  }

  try {
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${appBaseUrl(req)}/provider/onboarding/refresh`,
      return_url: `${appBaseUrl(req)}/provider/onboarding/complete`,
      type: 'account_onboarding',
    });

    res.json({ url: accountLink.url, mode: 'stripe' });
  } catch (error) {
    logger.error('onboarding-link failed', error);
    res.status(500).json({ message: error.message });
  }
});

apiApp.post('/api/payments/setup-card-session', async (req, res) => {
  const {
    userUid,
    email,
    name,
    returnUrl = `${appBaseUrl(req)}/payment-method/complete`,
    cancelUrl = `${appBaseUrl(req)}/payment-method/cancel`,
  } = req.body || {};

  if (!userUid || !email) {
    res.status(400).json({ message: 'userUid and email are required.' });
    return;
  }

  const stripe = stripeClient();
  if (!stripe) {
    await paymentCustomerRef(userUid).set(
      {
        userUid,
        email,
        name: name || '',
        customerId: `mock_cus_${userUid}`,
        defaultPaymentMethodId: `mock_pm_${Date.now()}`,
        cardBrand: 'visa',
        cardLast4: '4242',
        mode: 'mock',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    res.status(201).json({
      url: `${appBaseUrl(req)}/payment-method/mock/${userUid}`,
      mode: 'mock',
      cardBrand: 'visa',
      cardLast4: '4242',
    });
    return;
  }

  try {
    const customerSnapshot = await paymentCustomerRef(userUid).get();
    let customerId = customerSnapshot.data()?.customerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: String(email).trim().toLowerCase(),
        name: name ? String(name).trim() : undefined,
        metadata: { userUid },
      });
      customerId = customer.id;
      await paymentCustomerRef(userUid).set(
        {
          userUid,
          email,
          name: name || '',
          customerId,
          mode: 'stripe',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'setup',
      customer: customerId,
      success_url: returnUrl,
      cancel_url: cancelUrl,
      metadata: { userUid },
      setup_intent_data: {
        metadata: { userUid },
      },
    });

    res.status(201).json({
      url: session.url,
      mode: 'stripe',
      customerId,
    });
  } catch (error) {
    logger.error('setup-card-session failed', error);
    res.status(500).json({ message: error.message });
  }
});

apiApp.get('/api/payments/setup-card-status/:userUid', async (req, res) => {
  const snapshot = await paymentCustomerRef(req.params.userUid).get();
  const customer = snapshot.data();
  if (!customer) {
    res.json({
      hasPaymentMethod: false,
      mode: stripeClient() ? 'stripe' : 'mock',
    });
    return;
  }

  res.json({
    hasPaymentMethod: Boolean(customer.defaultPaymentMethodId),
    customerId: customer.customerId,
    paymentMethodId: customer.defaultPaymentMethodId,
    cardBrand: customer.cardBrand,
    cardLast4: customer.cardLast4,
    mode: customer.mode,
  });
});

apiApp.post('/api/payments/escrow-authorize', async (req, res) => {
  const {
    amount,
    currency = 'usd',
    bookingId,
    serviceTitle,
    clientUid,
    providerUid,
    providerAccountId,
    providerSubscriptionActive = false,
  } = req.body || {};

  const parsedAmount = Number(amount);
  if (
    Number.isNaN(parsedAmount) ||
    parsedAmount <= 0 ||
    !bookingId ||
    !serviceTitle ||
    !clientUid ||
    !providerUid
  ) {
    res.status(400).json({
      message:
        'amount, bookingId, serviceTitle, clientUid, and providerUid are required.',
    });
    return;
  }

  const commissionRate = providerSubscriptionActive ? 0 : platformCommissionRate;
  const stripe = stripeClient();

  if (!stripe) {
    const paymentIntentId = `mock_pi_${Date.now()}`;
    const platformFee = Number((parsedAmount * commissionRate).toFixed(2));
    const providerPayout = Number((parsedAmount - platformFee).toFixed(2));
    const record = {
      id: paymentIntentId,
      bookingId,
      serviceTitle,
      amount: parsedAmount,
      platformFee,
      providerPayout,
      currency,
      clientUid,
      providerUid,
      providerAccountId: providerAccountId || null,
      providerSubscriptionActive: Boolean(providerSubscriptionActive),
      status: 'funded',
      mode: 'mock',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await paymentRecordRef(paymentIntentId).set(record);
    await upsertEscrowFromPaymentRecord(record);
    res.status(201).json({
      paymentIntentId,
      status: 'succeeded',
      mode: 'mock',
    });
    return;
  }

  try {
    const customerSnapshot = await paymentCustomerRef(clientUid).get();
    const customer = customerSnapshot.data();
    if (!customer?.customerId || !customer?.defaultPaymentMethodId) {
      res.status(409).json({
        message: 'Client must add a secure payment method before booking.',
      });
      return;
    }

    const amountInCents = Math.round(parsedAmount * 100);
    const platformFeeCents = Math.round(amountInCents * commissionRate);
    const providerPayoutCents = amountInCents - platformFeeCents;
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency,
      customer: customer.customerId,
      payment_method: customer.defaultPaymentMethodId,
      confirm: true,
      off_session: true,
      application_fee_amount:
        providerAccountId && platformFeeCents > 0 ? platformFeeCents : undefined,
      transfer_data: providerAccountId
        ? {
            destination: providerAccountId,
          }
        : undefined,
      metadata: {
        bookingId,
        serviceTitle,
        clientUid,
        providerUid,
      },
    });

    const record = {
      id: paymentIntent.id,
      bookingId,
      serviceTitle,
      amount: parsedAmount,
      platformFee: Number((platformFeeCents / 100).toFixed(2)),
      providerPayout: Number((providerPayoutCents / 100).toFixed(2)),
      currency,
      clientUid,
      providerUid,
      providerAccountId: providerAccountId || null,
      providerSubscriptionActive: Boolean(providerSubscriptionActive),
      status: mapStripeStatusToEscrowStatus(paymentIntent.status),
      mode: 'stripe',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await paymentRecordRef(paymentIntent.id).set(record);
    await upsertEscrowFromPaymentRecord(record);
    res.status(201).json({
      paymentIntentId: paymentIntent.id,
      status: mapStripeStatusToEscrowStatus(paymentIntent.status),
      mode: 'stripe',
    });
  } catch (error) {
    logger.error('escrow-authorize failed', error);
    res.status(500).json({ message: error.message });
  }
});

apiApp.post('/api/payments/escrow-release', async (req, res) => {
  const { paymentIntentId } = req.body || {};
  if (!paymentIntentId) {
    res.status(400).json({ message: 'paymentIntentId is required.' });
    return;
  }

  const stripe = stripeClient();
  if (!stripe) {
    await paymentRecordRef(paymentIntentId).set(
      {
        status: 'released',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    res.json({ status: 'released', mode: 'mock' });
    return;
  }

  try {
    const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
    res.json({ status: intent.status, mode: 'stripe' });
  } catch (error) {
    logger.error('escrow-release failed', error);
    res.status(500).json({ message: error.message });
  }
});

exports.api = onRequest(
  {
    cors: true,
    region: 'us-central1',
    secrets: ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET'],
  },
  apiApp,
);
