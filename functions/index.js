const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

exports.approveTeenAccount = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const childUid = String(req.body?.childUid ?? '').trim();
  const parentEmail = String(req.body?.parentEmail ?? '').trim().toLowerCase();

  if (!childUid || !parentEmail) {
    res.status(400).json({ message: 'childUid and parentEmail are required.' });
    return;
  }

  try {
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
      res.status(403).json({ message: 'Parent email does not match.' });
      return;
    }

    await userRef.update({
      approvalStatus: 'approved',
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      parentPayoutApproval: true,
      hasParentMonitoring: true,
    });

    res.json({ message: 'Parent approval granted.' });
  } catch (error) {
    logger.error('approveTeenAccount failed', error);
    res.status(500).json({ message: 'Unable to approve account right now.' });
  }
});
