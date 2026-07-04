require('dotenv').config();

const express = require('express');
const cors = require('cors');
const Stripe = require('stripe');
const {
  gigs,
  escrows,
  users,
  providerAccounts,
  paymentRecords,
  paymentCustomers,
  initializeStore,
  persistStore,
} = require('./data/store');

const app = express();
const port = process.env.PORT || 4000;
const stripeSecretKey = process.env.STRIPE_SECRET_KEY || '';
const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET || '';
const appBaseUrl = process.env.APP_BASE_URL || 'http://localhost:3000';
const stripe = stripeSecretKey ? new Stripe(stripeSecretKey) : null;
const platformCommissionRate = 0.20;
const allowedCorsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedCorsOrigins.length === 0) {
        callback(null, true);
        return;
      }

      if (allowedCorsOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error('Origin not allowed by Giggo CORS policy.'));
    },
  }),
);

function upsertEscrowFromPaymentRecord(record) {
  const existing = escrows.find((item) =>
    item.processorPaymentId
      ? item.processorPaymentId === record.id
      : item.bookingId === record.bookingId,
  );

  if (existing) {
    existing.status = record.status;
    existing.processorMode = record.mode;
    existing.processorPaymentId = record.id;
    persistStore();
    return existing;
  }

  const escrow = {
    id: `escrow_${record.bookingId}`,
    gigId: record.serviceTitle || record.bookingId,
    bookingId: record.bookingId,
    amount: record.amount,
    serviceTitle: record.serviceTitle || '',
    clientUid: record.clientUid,
    providerUid: record.providerUid,
    status: record.status,
    processorMode: record.mode,
    processorPaymentId: record.id,
  };
  escrows.unshift(escrow);
  persistStore();
  return escrow;
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

function updatePaymentStatus(paymentIntentId, status) {
  const record = paymentRecords.find((item) => item.id === paymentIntentId);
  if (!record) {
    return;
  }

  record.status = status;
  upsertEscrowFromPaymentRecord(record);
  persistStore();
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
  paymentCustomers[userUid] = {
    ...(paymentCustomers[userUid] || {}),
    userUid,
    customerId,
    defaultPaymentMethodId: paymentMethodId,
    cardBrand: card.brand || paymentCustomers[userUid]?.cardBrand || null,
    cardLast4: card.last4 || paymentCustomers[userUid]?.cardLast4 || null,
    mode,
    updatedAt: new Date().toISOString(),
  };
  persistStore();

  return paymentCustomers[userUid];
}

app.post(
  '/api/payments/webhook',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    if (!stripe || !stripeWebhookSecret) {
      return res.status(503).json({
        message:
          'Stripe webhook is not configured. Set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET.',
      });
    }

    const signature = req.headers['stripe-signature'];
    if (!signature) {
      return res.status(400).json({ message: 'Missing Stripe signature.' });
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        signature,
        stripeWebhookSecret,
      );
    } catch (error) {
      return res.status(400).json({ message: `Webhook Error: ${error.message}` });
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
        case 'payment_intent.succeeded': {
          const paymentIntent = event.data.object;
          updatePaymentStatus(paymentIntent.id, 'funded');
          break;
        }
        case 'payment_intent.payment_failed': {
          const paymentIntent = event.data.object;
          updatePaymentStatus(paymentIntent.id, 'failed');
          break;
        }
        case 'payment_intent.canceled': {
          const paymentIntent = event.data.object;
          updatePaymentStatus(paymentIntent.id, 'canceled');
          break;
        }
        case 'charge.dispute.created': {
          const charge = event.data.object;
          const paymentIntentId = charge.payment_intent;
          if (typeof paymentIntentId === 'string' && paymentIntentId) {
            updatePaymentStatus(paymentIntentId, 'disputed');
          }
          break;
        }
        case 'account.updated': {
          const account = event.data.object;
          const provider = Object.values(providerAccounts).find(
            (item) => item.accountId === account.id,
          );

          if (provider) {
            provider.payoutsEnabled = Boolean(account.payouts_enabled);
            provider.chargesEnabled = Boolean(account.charges_enabled);
            persistStore();
          }
          break;
        }
        default:
          break;
      }
    } catch (error) {
      return res.status(500).json({ message: error.message });
    }

    return res.json({ received: true });
  },
);

app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    paymentsMode: stripe ? 'stripe' : 'mock',
    webhookConfigured: Boolean(stripeWebhookSecret),
  });
});

app.post('/api/providers/connect-account', async (req, res) => {
  const {
    providerUid,
    email,
    country = 'US',
    accountId: providedAccountId,
  } = req.body;

  if (!providerUid || !email) {
    return res
      .status(400)
      .json({ message: 'providerUid and email are required.' });
  }

  if (!stripe) {
    const accountId = `mock_acct_${providerUid}`;
    providerAccounts[providerUid] = {
      accountId,
      providerUid,
      email,
      payoutsEnabled: true,
      chargesEnabled: true,
      mode: 'mock',
    };
    persistStore();

    return res.status(201).json({
      accountId,
      onboardingUrl: `${appBaseUrl}/provider/onboarding/mock/${providerUid}`,
      mode: 'mock',
    });
  }

  try {
    const existing = providerAccounts[providerUid];
    if (existing?.accountId) {
      return res.json({
        accountId: existing.accountId,
        mode: 'stripe',
      });
    }

    if (providedAccountId && String(providedAccountId).trim().isNotEmpty) {
      const hydratedAccountId = String(providedAccountId).trim();
      const account = await stripe.accounts.retrieve(hydratedAccountId);

      providerAccounts[providerUid] = {
        accountId: account.id,
        providerUid,
        email,
        payoutsEnabled: Boolean(account.payouts_enabled),
        chargesEnabled: Boolean(account.charges_enabled),
        mode: 'stripe',
      };
      persistStore();

      return res.json({ accountId: account.id, mode: 'stripe' });
    }

    const account = await stripe.accounts.create({
      type: 'express',
      email: String(email).trim().toLowerCase(),
      country,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    });

    providerAccounts[providerUid] = {
      accountId: account.id,
      providerUid,
      email,
      payoutsEnabled: Boolean(account.payouts_enabled),
      chargesEnabled: Boolean(account.charges_enabled),
      mode: 'stripe',
    };
    persistStore();

    return res.status(201).json({ accountId: account.id, mode: 'stripe' });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/providers/:providerUid/onboarding-link', async (req, res) => {
  const { providerUid } = req.params;
  const provider = providerAccounts[providerUid];
  const requestedAccountId = req.body?.accountId;
  const accountId =
    provider?.accountId ||
    (typeof requestedAccountId === 'string' && requestedAccountId.trim()
      ? requestedAccountId.trim()
      : null);

  if (!accountId) {
    return res
      .status(404)
      .json({ message: 'Provider payment account not found.' });
  }

  if (!provider) {
    providerAccounts[providerUid] = {
      accountId,
      providerUid,
      email: null,
      payoutsEnabled: false,
      chargesEnabled: false,
      mode: stripe ? 'stripe' : 'mock',
    };
    persistStore();
  }

  if (!stripe) {
    return res.json({
      url: `${appBaseUrl}/provider/onboarding/mock/${providerUid}`,
      mode: 'mock',
    });
  }

  try {
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${appBaseUrl}/provider/onboarding/refresh`,
      return_url: `${appBaseUrl}/provider/onboarding/complete`,
      type: 'account_onboarding',
    });

    return res.json({ url: accountLink.url, mode: 'stripe' });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/payments/setup-card-session', async (req, res) => {
  const {
    userUid,
    email,
    name,
    returnUrl = `${appBaseUrl}/payment-method/complete`,
    cancelUrl = `${appBaseUrl}/payment-method/cancel`,
  } = req.body;

  if (!userUid || !email) {
    return res
      .status(400)
      .json({ message: 'userUid and email are required.' });
  }

  if (!stripe) {
    const customerId = `mock_cus_${userUid}`;
    paymentCustomers[userUid] = {
      userUid,
      email,
      name: name || '',
      customerId,
      defaultPaymentMethodId: `mock_pm_${Date.now()}`,
      cardBrand: 'visa',
      cardLast4: '4242',
      mode: 'mock',
      updatedAt: new Date().toISOString(),
    };
    persistStore();

    return res.status(201).json({
      url: `${appBaseUrl}/payment-method/mock/${userUid}`,
      mode: 'mock',
      customerId,
      cardBrand: 'visa',
      cardLast4: '4242',
    });
  }

  try {
    let customerId = paymentCustomers[userUid]?.customerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: String(email).trim().toLowerCase(),
        name: name ? String(name).trim() : undefined,
        metadata: { userUid },
      });
      customerId = customer.id;
      paymentCustomers[userUid] = {
        userUid,
        email,
        name: name || '',
        customerId,
        mode: 'stripe',
        updatedAt: new Date().toISOString(),
      };
      persistStore();
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

    return res.status(201).json({
      url: session.url,
      mode: 'stripe',
      customerId,
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/payments/setup-card-status/:userUid', (req, res) => {
  const customer = paymentCustomers[req.params.userUid];
  if (!customer) {
    return res.json({
      hasPaymentMethod: false,
      mode: stripe ? 'stripe' : 'mock',
    });
  }

  return res.json({
    hasPaymentMethod: Boolean(customer.defaultPaymentMethodId),
    customerId: customer.customerId,
    paymentMethodId: customer.defaultPaymentMethodId,
    cardBrand: customer.cardBrand,
    cardLast4: customer.cardLast4,
    mode: customer.mode,
    updatedAt: customer.updatedAt,
  });
});

app.post('/api/payments/escrow-authorize', async (req, res) => {
  const {
    amount,
    currency = 'usd',
    bookingId,
    serviceTitle,
    clientUid,
    providerUid,
    providerAccountId,
    providerSubscriptionActive = false,
  } = req.body;

  const parsedAmount = Number(amount);
  if (
    Number.isNaN(parsedAmount) ||
    parsedAmount <= 0 ||
    !bookingId ||
    !serviceTitle ||
    !clientUid ||
    !providerUid
  ) {
    return res.status(400).json({
      message:
        'amount, bookingId, serviceTitle, clientUid, and providerUid are required.',
    });
  }

  const commissionRate = providerSubscriptionActive ? 0 : platformCommissionRate;

  if (!stripe) {
    const paymentIntentId = `mock_pi_${Date.now()}`;
    const platformFee = Number((parsedAmount * commissionRate).toFixed(2));
    const providerPayout = Number((parsedAmount - platformFee).toFixed(2));
    paymentRecords.unshift({
      id: paymentIntentId,
      bookingId,
      serviceTitle,
      amount: parsedAmount,
      platformFee,
      providerPayout,
      currency,
      clientUid,
      providerUid,
      providerAccountId: providerAccountId || providerAccounts[providerUid]?.accountId || null,
      providerSubscriptionActive: Boolean(providerSubscriptionActive),
      status: 'funded',
      mode: 'mock',
      createdAt: new Date().toISOString(),
    });
    persistStore();

    upsertEscrowFromPaymentRecord(paymentRecords[0]);

    return res.status(201).json({
      paymentIntentId,
      status: 'succeeded',
      mode: 'mock',
    });
  }

  try {
    const customer = paymentCustomers[clientUid];
    if (!customer?.customerId || !customer?.defaultPaymentMethodId) {
      return res.status(409).json({
        message: 'Client must add a secure payment method before booking.',
      });
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

    paymentRecords.unshift({
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
      createdAt: new Date().toISOString(),
    });
    persistStore();

    upsertEscrowFromPaymentRecord(paymentRecords[0]);

    return res.status(201).json({
      paymentIntentId: paymentIntent.id,
      status: mapStripeStatusToEscrowStatus(paymentIntent.status),
      mode: 'stripe',
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.post('/api/payments/escrow-release', async (req, res) => {
  const { paymentIntentId } = req.body;
  if (!paymentIntentId) {
    return res.status(400).json({ message: 'paymentIntentId is required.' });
  }

  if (!stripe) {
    const record = paymentRecords.find((item) => item.id === paymentIntentId);
    if (!record) {
      return res.status(404).json({ message: 'Payment record not found.' });
    }

    record.status = 'released';
    persistStore();
    return res.json({ status: 'released', mode: 'mock' });
  }

  try {
    const intent = await stripe.paymentIntents.retrieve(paymentIntentId);
    return res.json({ status: intent.status, mode: 'stripe' });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
});

app.get('/api/gigs', (_req, res) => {
  res.json(gigs);
});

app.post('/api/gigs', (req, res) => {
  const { title, description, category, price, providerName, location } = req.body;

  if (!title || !description || !category || !providerName || !location || !price) {
    return res.status(400).json({ message: 'Missing required fields.' });
  }

  const parsedPrice = Number(price);
  if (Number.isNaN(parsedPrice) || parsedPrice <= 0) {
    return res.status(400).json({ message: 'Price must be a valid positive number.' });
  }

  const gig = {
    id: `g${Date.now()}`,
    title: String(title).trim(),
    description: String(description).trim(),
    category: String(category).trim(),
    price: parsedPrice,
    providerName: String(providerName).trim(),
    location: String(location).trim()
  };

  gigs.unshift(gig);
  persistStore();
  return res.status(201).json(gig);
});

app.get('/api/escrows', (_req, res) => {
  res.json(escrows);
});

app.get('/api/payments/records', (_req, res) => {
  res.json(paymentRecords);
});

function ageFromDateOfBirth(dateOfBirth) {
  const dob = new Date(dateOfBirth);
  if (Number.isNaN(dob.getTime())) {
    return null;
  }

  const now = new Date();
  let age = now.getFullYear() - dob.getFullYear();
  const monthDelta = now.getMonth() - dob.getMonth();
  if (monthDelta < 0 || (monthDelta === 0 && now.getDate() < dob.getDate())) {
    age -= 1;
  }

  return age;
}

app.post('/api/auth/signup', (req, res) => {
  const { name, email, password, dateOfBirth, parentEmail } = req.body;

  if (!name || !email || !password || !dateOfBirth) {
    return res.status(400).json({ message: 'Missing required fields.' });
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const parsedAge = ageFromDateOfBirth(dateOfBirth);

  if (!normalizedEmail.includes('@')) {
    return res.status(400).json({ message: 'Please provide a valid email.' });
  }

  if (password.length < 6) {
    return res.status(400).json({ message: 'Password must be at least 6 characters.' });
  }

  if (Number.isNaN(parsedAge) || parsedAge < 13) {
    return res.status(400).json({ message: 'Minimum age to create an account is 13.' });
  }

  const isTeen = parsedAge >= 13 && parsedAge <= 17;
  const normalizedParentEmail = parentEmail
    ? String(parentEmail).trim().toLowerCase()
    : '';

  if (isTeen && !normalizedParentEmail.includes('@')) {
    return res.status(400).json({
      message: 'Parent email is required for ages 13–17.',
    });
  }

  if (normalizedParentEmail && normalizedParentEmail === normalizedEmail) {
    return res.status(400).json({
      message: 'Parent email must be different from account email.',
    });
  }

  const existingUser = users.find((item) => item.email === normalizedEmail);
  if (existingUser) {
    return res.status(409).json({ message: 'An account already exists for this email.' });
  }

  const user = {
    id: `u${Date.now()}`,
    name: String(name).trim(),
    email: normalizedEmail,
    password: String(password),
    age: parsedAge,
    dateOfBirth: String(dateOfBirth),
    parentEmail: normalizedParentEmail || null,
    parentApprovalStatus: isTeen ? 'pending' : 'approved',
  };

  users.unshift(user);
  persistStore();

  if (isTeen) {
    return res.status(202).json({
      message: 'Parent approval required.',
      parentEmail: user.parentEmail,
    });
  }

  return res.status(201).json({
    id: user.id,
    name: user.name,
    email: user.email,
    age: user.age,
  });
});

app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required.' });
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const user = users.find((item) => item.email === normalizedEmail);

  if (!user || user.password !== String(password)) {
    return res.status(401).json({ message: 'Invalid email or password.' });
  }

  if (user.parentApprovalStatus === 'pending') {
    return res.status(403).json({
      message: 'Parent approval is still pending. Please check parent email.',
    });
  }

  return res.json({
    id: user.id,
    name: user.name,
    email: user.email,
    age: user.age,
  });
});

app.post('/api/auth/approve-parent', (req, res) => {
  const { childEmail, parentEmail } = req.body;

  if (!childEmail || !parentEmail) {
    return res.status(400).json({ message: 'childEmail and parentEmail are required.' });
  }

  const normalizedChildEmail = String(childEmail).trim().toLowerCase();
  const normalizedParentEmail = String(parentEmail).trim().toLowerCase();
  const user = users.find((item) => item.email === normalizedChildEmail);

  if (!user) {
    return res.status(404).json({ message: 'Child account not found.' });
  }

  if (user.parentEmail !== normalizedParentEmail) {
    return res.status(403).json({ message: 'Parent email does not match.' });
  }

  user.parentApprovalStatus = 'approved';
  persistStore();
  return res.json({ message: 'Parent approval granted.' });
});

app.post('/api/escrows', (req, res) => {
  const { gigId, amount } = req.body;
  if (!gigId || !amount) {
    return res.status(400).json({ message: 'gigId and amount are required.' });
  }

  const parsedAmount = Number(amount);
  if (Number.isNaN(parsedAmount) || parsedAmount <= 0) {
    return res.status(400).json({ message: 'Amount must be a valid positive number.' });
  }

  const escrow = {
    id: `e${Date.now()}`,
    gigId: String(gigId),
    amount: parsedAmount,
    status: 'pendingFunding'
  };

  escrows.unshift(escrow);
  persistStore();
  return res.status(201).json(escrow);
});

app.patch('/api/escrows/:id/fund', (req, res) => {
  const escrow = escrows.find((item) => item.id === req.params.id);
  if (!escrow) {
    return res.status(404).json({ message: 'Escrow not found.' });
  }

  if (escrow.status !== 'pendingFunding') {
    return res.status(409).json({ message: 'Escrow can only be funded from pendingFunding.' });
  }

  escrow.status = 'funded';
  persistStore();
  return res.json(escrow);
});

app.patch('/api/escrows/:id/release', (req, res) => {
  const escrow = escrows.find((item) => item.id === req.params.id);
  if (!escrow) {
    return res.status(404).json({ message: 'Escrow not found.' });
  }

  if (escrow.status !== 'funded') {
    return res.status(409).json({ message: 'Escrow can only be released from funded.' });
  }

  escrow.status = 'released';
  persistStore();
  return res.json(escrow);
});

app.patch('/api/escrows/:id/dispute', (req, res) => {
  const escrow = escrows.find((item) => item.id === req.params.id);
  if (!escrow) {
    return res.status(404).json({ message: 'Escrow not found.' });
  }

  if (escrow.status === 'released') {
    return res.status(409).json({ message: 'Released escrow cannot be disputed.' });
  }

  escrow.status = 'disputed';
  persistStore();
  return res.json(escrow);
});

async function startServer() {
  await initializeStore();

  app.listen(port, () => {
    console.log(`Giggo API listening on port ${port}`);
    console.log(
      `[payments] mode=${stripe ? 'stripe' : 'mock'} webhook=${stripeWebhookSecret ? 'configured' : 'missing'} commission=${Math.round(platformCommissionRate * 100)}%`,
    );
  });
}

startServer().catch((error) => {
  console.error(`Giggo API failed to start: ${error.message}`);
  process.exit(1);
});
