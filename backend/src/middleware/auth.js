const jwt = require('jsonwebtoken');
const pool = require('../database/connection');

/**
 * Middleware: verifikasi JWT token
 */
async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Token tidak ditemukan' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const [rows] = await pool.query('SELECT id, email, display_name, role, is_active FROM users WHERE id = ?', [decoded.userId]);
    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'User tidak ditemukan' });
    }
    if (!rows[0].is_active) {
      return res.status(403).json({ success: false, message: 'Akun dinonaktifkan' });
    }

    req.user = rows[0];
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token tidak valid atau expired' });
    }
    next(err);
  }
}

/**
 * Middleware: hanya admin
 */
function adminOnly(req, res, next) {
  if (req.user && req.user.role === 'admin') {
    return next();
  }
  return res.status(403).json({ success: false, message: 'Akses ditolak — hanya admin' });
}

module.exports = { authenticate, adminOnly };
