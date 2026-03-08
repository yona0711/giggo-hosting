const gigs = [
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

const escrows = [];

const users = [
  {
    id: 'u1',
    name: 'Avery Jordan',
    email: 'avery@giggo.dev',
    password: 'password123',
    age: 16,
  },
];

module.exports = {
  gigs,
  escrows,
  users,
};
