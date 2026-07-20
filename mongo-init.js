db = db.getSiblingDB('namegen');

db.createUser({
  user: 'genuser',
  pwd: 'password',
  roles: [
    {
      role: 'readWrite',
      db: 'namegen'
    }
  ]
});