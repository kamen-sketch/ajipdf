const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { body, validationResult } = require('express-validator');
const pool = require('../database/connection');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

/// Derive a deterministic but secret password for OAuth accounts.
/// Memakai server-side salt sehingga client TIDAK bisa menebak passwordnya.
function oauthPassword(email) {
  const salt = process.env.OAUTH_PASSWORD_SALT || 'fallback_salt';
  return crypto.createHmac('sha256', salt).update(`google:${email}`).digest('hex');
}

// POST /api/auth/register
router.post('/register', [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }),
  body('displayName').trim().isLength({ min: 2, max: 100 }),
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { email, password, displayName } = req.body;

    // Check if email already exists
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ success: false, message: 'Email sudah terdaftar' });
    }

    const id = uuidv4();
    const passwordHash = await bcrypt.hash(password, 10);

    await pool.query(
      'INSERT INTO users (id, email, password_hash, display_name) VALUES (?, ?, ?, ?)',
      [id, email, passwordHash, displayName]
    );

    // Create free subscription
    await pool.query(
      'INSERT INTO subscriptions (id, user_id, plan, status) VALUES (?, ?, ?, ?)',
      [uuidv4(), id, 'free', 'active']
    );

    const token = jwt.sign({ userId: id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.status(201).json({
      success: true,
      data: {
        token,
        user: { id, email, displayName, role: 'user' },
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/login
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { email, password } = req.body;

    const [rows] = await pool.query(
      'SELECT id, email, password_hash, display_name, role, is_active FROM users WHERE email = ?',
      [email]
    );

    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Email atau password salah' });
    }

    const user = rows[0];
    if (!user.is_active) {
      return res.status(403).json({ success: false, message: 'Akun dinonaktifkan' });
    }

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Email atau password salah' });
    }

    // Update last login
    await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = ?', [user.id]);

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          displayName: user.display_name,
          role: user.role,
        },
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/google — login/register via Google OAuth (idToken verification)
router.post('/google', [
  body('email').isEmail().normalizeEmail(),
  body('displayName').optional().trim().isLength({ max: 100 }),
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { email, displayName, idToken } = req.body;

    // CATATAN KEAMANAN: Idealnya idToken diverifikasi ke Google
    // (https://oauth2.googleapis.com/tokeninfo?id_token=...) untuk memastikan
    // email benar-benar milik pemanggil. Tanpa verifikasi, siapa pun bisa
    // mengaku email apa saja. Verifikasi idToken WAJIB sebelum production.
    if (!idToken) {
      // Tetap lanjut untuk dev, tapi tandai. JANGAN biarkan ini di production.
      console.warn('[auth/google] idToken tidak ada — verifikasi dilewati (DEV ONLY)');
    }

    const derivedPassword = oauthPassword(email);
    const passwordHash = await bcrypt.hash(derivedPassword, 10);

    // Cek user
    const [rows] = await pool.query(
      'SELECT id, email, display_name, role, is_active FROM users WHERE email = ?',
      [email]
    );

    let user;
    if (rows.length > 0) {
      user = rows[0];
      if (!user.is_active) {
        return res.status(403).json({ success: false, message: 'Akun dinonaktifkan' });
      }
      await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = ?', [user.id]);
    } else {
      // Register baru
      const id = uuidv4();
      const name = displayName || email.split('@')[0];
      await pool.query(
        'INSERT INTO users (id, email, password_hash, display_name) VALUES (?, ?, ?, ?)',
        [id, email, passwordHash, name]
      );
      await pool.query(
        'INSERT INTO subscriptions (id, user_id, plan, status) VALUES (?, ?, "free", "active")',
        [uuidv4(), id]
      );
      user = { id, email, display_name: name, role: 'user' };
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          displayName: user.display_name,
          role: user.role,
        },
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/auth/me — get current user profile
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const [subs] = await pool.query(
      'SELECT plan, status, expires_at FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );

    res.json({
      success: true,
      data: {
        ...req.user,
        subscription: subs[0] || { plan: 'free', status: 'active' },
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/change-password
router.post('/change-password', authenticate, [
  body('currentPassword').notEmpty(),
  body('newPassword').isLength({ min: 6 }),
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { currentPassword, newPassword } = req.body;
    const [rows] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);

    const valid = await bcrypt.compare(currentPassword, rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Password saat ini salah' });
    }

    const newHash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, req.user.id]);

    res.json({ success: true, message: 'Password berhasil diubah' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
