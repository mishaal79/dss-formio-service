// MongoDB Initialization Script for Form.io Community
// This script runs once when MongoDB container is first created

// Switch to the formio database
db = db.getSiblingDB('formio');

// Create a user for the formio database with read/write permissions
db.createUser({
  user: 'formio',
  pwd: 'formio123',
  roles: [
    {
      role: 'readWrite',
      db: 'formio'
    }
  ]
});

// Create initial collections if needed
db.createCollection('forms');
db.createCollection('submissions');
db.createCollection('actions');
db.createCollection('roles');

// Add indexes for better performance
db.forms.createIndex({ "path": 1 });
db.forms.createIndex({ "name": 1 });
db.submissions.createIndex({ "form": 1 });
db.submissions.createIndex({ "created": 1 });

print('MongoDB initialization completed for Form.io Community');