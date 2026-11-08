const express = require('express');
const cors = require('cors');
const config = require('./config');
const { connectDB, mongoose } = require('./db');
const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Serverless DB connection middleware (ensures connection in warm or cold serverless functions)
app.use(async (req, res, next) => {
  if (mongoose.connection.readyState !== 1) {
    try {
      await connectDB();
    } catch (_) {}
  }
  next();
});

// Request logging in development
app.use((req, res, next) => {
  console.log(`[HTTP] ${req.method} ${req.originalUrl}`);
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sync', syncRoutes);

// Health check
app.get('/api/health', (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: isDbConnected ? 'connected' : 'disconnected',
    mongodbState: mongoose.connection.readyState,
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]', err);
  res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
});

// Start standalone server locally; Vercel imports `app` directly as serverless function
if (!process.env.VERCEL) {
  connectDB().then(() => {
    app.listen(config.port, () => {
      console.log(`====================================================`);
      console.log(` Daily Counter Backend Server running on port ${config.port}`);
      console.log(` Health check: http://localhost:${config.port}/api/health`);
      console.log(` Auth endpoints: /api/auth/send-otp , /api/auth/verify-otp`);
      console.log(` Sync endpoint:  /api/sync`);
      console.log(`====================================================`);
    });
  });
}

module.exports = app;

