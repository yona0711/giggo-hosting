const express = require('express');
const cors = require('cors');
const { gigs, escrows, users } = require('./data/store');

const app = express();
const port = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
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
  return res.status(201).json(gig);
});

app.get('/api/escrows', (_req, res) => {
  res.json(escrows);
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
  return res.json(escrow);
});

app.listen(port, () => {
  console.log(`Giggo API listening on port ${port}`);
});
