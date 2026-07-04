const fs = require('fs');
const path = require('path');

const runtimeStorePath = path.join(__dirname, 'runtime-store.json');
const storeDriver = process.env.GIGGO_STORE_DRIVER || 'file';
const firestoreCollection =
  process.env.GIGGO_STORE_COLLECTION || '_serverState';
const firestoreDocument = process.env.GIGGO_STORE_DOCUMENT || 'runtime';
let firestoreDb = null;

const defaultGigs = [
  {
    id: 'g1',
    title: 'Dog Walking (30 mins)',
    description: 'Friendly neighborhood dog walking service.',
    category: 'Pet Care',
    price: 15,
    providerName: 'Mia R.',
    location: 'Downtown'
  },
  {
    id: 'g2',
    title: 'Lawn Mowing + Edge Trim',
    description: 'Clean landscaping for front and back yard.',
    category: 'Landscaping',
    price: 45,
    providerName: 'Jordan T.',
    location: 'North Side'
  },
  {
    id: 'g3',
    title: 'Basic Car Detailing',
    description: 'Exterior wash and interior vacuum package.',
    category: 'Car Care',
    price: 60,
    providerName: 'Chris A.',
    location: 'West End'
  }
];

const defaultUsers = [
  {
    id: 'u1',
    name: 'Avery Jordan',
    email: 'avery@giggo.dev',
    password: 'password123',
    age: 16,
  },
];

function readRuntimeStore() {
  if (!fs.existsSync(runtimeStorePath)) {
    return {};
  }

  try {
    return JSON.parse(fs.readFileSync(runtimeStorePath, 'utf8'));
  } catch (error) {
    console.warn(
      `[store] Unable to read runtime store. Starting with defaults. ${error.message}`,
    );
    return {};
  }
}

function serializeStore() {
  return {
    gigs,
    escrows,
    users,
    providerAccounts,
    paymentRecords,
    paymentCustomers,
    updatedAt: new Date().toISOString(),
  };
}

function applyRuntimeStore(store) {
  if (!store || typeof store !== 'object') {
    return;
  }

  if (Array.isArray(store.gigs)) {
    gigs.splice(0, gigs.length, ...store.gigs);
  }
  if (Array.isArray(store.escrows)) {
    escrows.splice(0, escrows.length, ...store.escrows);
  }
  if (Array.isArray(store.users)) {
    users.splice(0, users.length, ...store.users);
  }
  if (store.providerAccounts && typeof store.providerAccounts === 'object') {
    Object.keys(providerAccounts).forEach((key) => delete providerAccounts[key]);
    Object.assign(providerAccounts, store.providerAccounts);
  }
  if (Array.isArray(store.paymentRecords)) {
    paymentRecords.splice(0, paymentRecords.length, ...store.paymentRecords);
  }
  if (store.paymentCustomers && typeof store.paymentCustomers === 'object') {
    Object.keys(paymentCustomers).forEach((key) => delete paymentCustomers[key]);
    Object.assign(paymentCustomers, store.paymentCustomers);
  }
}

async function initializeFirestoreStore() {
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (error) {
    throw new Error(
      `firebase-admin is required when GIGGO_STORE_DRIVER=firestore. ${error.message}`,
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp();
  }
  firestoreDb = admin.firestore();

  const snapshot = await firestoreDb
    .collection(firestoreCollection)
    .doc(firestoreDocument)
    .get();

  if (snapshot.exists) {
    applyRuntimeStore(snapshot.data());
    return;
  }

  await firestoreDb
    .collection(firestoreCollection)
    .doc(firestoreDocument)
    .set(serializeStore());
}

const runtimeStore = readRuntimeStore();

const gigs = Array.isArray(runtimeStore.gigs) ? runtimeStore.gigs : defaultGigs;
const escrows = Array.isArray(runtimeStore.escrows)
  ? runtimeStore.escrows
  : [];
const users = Array.isArray(runtimeStore.users) ? runtimeStore.users : defaultUsers;
const providerAccounts =
  runtimeStore.providerAccounts &&
  typeof runtimeStore.providerAccounts === 'object'
    ? runtimeStore.providerAccounts
    : {};
const paymentRecords = Array.isArray(runtimeStore.paymentRecords)
  ? runtimeStore.paymentRecords
  : [];
const paymentCustomers =
  runtimeStore.paymentCustomers &&
  typeof runtimeStore.paymentCustomers === 'object'
    ? runtimeStore.paymentCustomers
    : {};

function persistStore() {
  const payload = serializeStore();

  if (storeDriver === 'firestore') {
    if (!firestoreDb) {
      console.warn('[store] Firestore store is not initialized yet.');
      return;
    }

    firestoreDb
      .collection(firestoreCollection)
      .doc(firestoreDocument)
      .set(payload)
      .catch((error) => {
        console.error(`[store] Unable to persist to Firestore. ${error.message}`);
      });
    return;
  }

  fs.writeFileSync(runtimeStorePath, `${JSON.stringify(payload, null, 2)}\n`);
}

async function initializeStore() {
  if (storeDriver === 'firestore') {
    await initializeFirestoreStore();
  }
}

module.exports = {
  gigs,
  escrows,
  users,
  providerAccounts,
  paymentRecords,
  paymentCustomers,
  initializeStore,
  persistStore,
};
