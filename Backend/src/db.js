const mongoose = require('mongoose');
const config = require('./config');

async function connectDB() {
  if (mongoose.connection.readyState === 1) {
    return;
  }

  try {
    await mongoose.connect(config.mongodbUri, {
      serverSelectionTimeoutMS: 8000,
    });
    console.log('[MongoDB] Connected successfully to MongoDB Atlas');
  } catch (err) {
    console.error('[MongoDB] Connection error:', err.message);
  }

  mongoose.connection.on('disconnected', () => {
    console.warn('[MongoDB] Disconnected from MongoDB Atlas');
  });

  mongoose.connection.on('reconnected', () => {
    console.log('[MongoDB] Reconnected to MongoDB Atlas');
  });
}

module.exports = { connectDB, mongoose };

