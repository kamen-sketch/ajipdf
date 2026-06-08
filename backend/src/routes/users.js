const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../database/connection');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/users/profile
router.get('/profile', authenticate, async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, email, display_name, avatar_url, role, created_at, last_login_at FROM users WHERE id = ?',
      [req.user.id]
    );
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    next(err);
  }
});

// PUT /api/users/profile
router.put('/profile', authenticate, [
  body('displayName').optional().trim().isLength({ min: 2, max: 100 }),
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { displayName } = req.body;
    if (displayName) {
      await pool.query('UPDATE users SET display_name = ? WHERE id = ?', [displayName, req.user.id]);
    }

    const [rows] = await pool.query(
      'SELECT id, email, display_name, avatar_url, role FROM users WHERE id = ?',
      [req.user.id]
    );
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    next(err);
  }
});

// GET /api/users/usage — get current month usage stats
router.get('/usage', authenticate, async (req, res, next) => {
  try {
    const monthYear = new Date().toISOString().slice(0, 7); // "2024-01"
    const [rows] = await pool.query(
      'SELECT * FROM usage_tracking WHERE user_id = ? AND month_year = ?',
      [req.user.id, monthYear]
    );

    const usage = rows[0] || {
      split_merge_count: 0,
      compress_count: 0,
      ocr_count: 0,
      total_operations: 0,
    };

    res.json({ success: true, data: usage });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
