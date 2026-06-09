require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const documentRoutes = require('./routes/documents');
const subscriptionRoutes = require('./routes/subscriptions');
const adminRoutes = require('./routes/admin');
const errorRoutes = require('./routes/errors');
const configRoutes = require('./routes/config');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Security headers ──
app.use(helmet({
  contentSecurityPolicy: false, // admin dashboard inline JS perlu ini off
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));

// ── CORS whitelist ──
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:8080')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    // Izinkan request tanpa origin (mobile app, curl, server-to-server)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origin tidak diizinkan oleh CORS'));
  },
  credentials: true,
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// ── Rate limiters ──
// Global limiter
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 menit
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Terlalu banyak request, coba lagi nanti.' },
});
app.use('/api', globalLimiter);

// Auth limiter ketat — cegah brute force login
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // 20 percobaan login/register per 15 menit per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Terlalu banyak percobaan login. Tunggu 15 menit.' },
});

// Error report limiter — cegah spam DB
const errorLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 menit
  max: 30,
  message: { success: false, message: 'Terlalu banyak error report.' },
});

// Admin dashboard (static HTML)
app.use('/admin', express.static(path.join(__dirname, '..', 'public', 'admin')));

// Routes (dengan limiter spesifik)
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/errors', errorLimiter, errorRoutes);
app.use('/api/config', configRoutes);

// Secure file download — hanya pemilik atau admin (lihat documents route)
// File TIDAK lagi di-serve statis tanpa auth.

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('[Error]', err.message);
  // Jangan bocorkan stack trace ke client
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

app.listen(PORT, () => {
  console.log(`🚀 AjiPDF Backend running on http://localhost:${PORT}`);
  console.log(`📊 Admin dashboard: http://localhost:${PORT}/admin/`);
  console.log(`🔒 Allowed origins: ${allowedOrigins.join(', ')}`);
});
