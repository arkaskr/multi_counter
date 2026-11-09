const express = require('express');
const cors = require('cors');
const config = require('./config');
const { connectDB, mongoose } = require('./db');
const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');
const groupRoutes = require('./routes/groups');

const app = express();

// Middlewares
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Vercel serverless rewrite handler:
// When Vercel rewrites requests to /api/index.js or /src/index.js,
// 'x-matched-path' holds the original URL requested by the client (e.g. /api/health)
app.use((req, res, next) => {
  const original = req.headers['x-matched-path'] || req.headers['x-invoke-path'] || req.headers['x-forwarded-uri'];
  if (original && (req.url.startsWith('/src/index') || req.url.startsWith('/api/index'))) {
    req.url = original;
  }
  next();
});

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
  console.log(`[HTTP] ${req.method} ${req.originalUrl || req.url}`);
  next();
});

// Root welcome & status
app.get('/', (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  res.json({
    status: 'ok',
    message: 'Daily Counter API is live!',
    database: isDbConnected ? 'connected' : 'disconnected',
    endpoints: {
      health: '/api/health',
      auth: {
        sendOtp: 'POST /api/auth/send-otp',
        verifyOtp: 'POST /api/auth/verify-otp',
      },
      sync: {
        pushPull: 'POST /api/sync',
        fetch: 'GET /api/sync',
      },
    },
  });
});

// Health check handler
const healthHandler = (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: isDbConnected ? 'connected' : 'disconnected',
    mongodbState: mongoose.connection.readyState,
  });
};

app.get('/api/health', healthHandler);
app.get('/health', healthHandler);

// Mount Auth routes (supports /api/auth, /auth, and rewrite fallbacks)
app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);
app.use('/api/api/auth', authRoutes);

// Mount Sync routes (supports /api/sync, /sync, and rewrite fallbacks)
app.use('/api/sync', syncRoutes);
app.use('/sync', syncRoutes);
app.use('/api/api/sync', syncRoutes);

// Mount Group & Expense routes (supports /api/groups, /groups, and rewrite fallbacks)
app.use('/api/groups', groupRoutes);
app.use('/groups', groupRoutes);
app.use('/api/api/groups', groupRoutes);

// Catch-all route for any direct rewrite path hits
app.all(['/src/index.js', '/api/index.js', '/src/index', '/api/index'], (req, res, next) => {
  const original = req.headers['x-matched-path'] || req.headers['x-invoke-path'] || '/';
  if (original !== req.url && original !== '/src/index.js' && original !== '/api/index.js') {
    req.url = original;
    return app.handle(req, res, next);
  }
  healthHandler(req, res);
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
