const express = require('express');
const { v4: uuidv4 } = require('uuid');
const pool = require('../database/connection');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/subscriptions — current user's subscription
router.get('/', authenticate, async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );
    const sub = rows[0] || { plan: 'free', status: 'active' };
    res.json({ success: true, data: sub });
  } catch (err) {
    next(err);
  }
});

// POST /api/subscriptions/upgrade — upgrade to pro (simulated)
router.post('/upgrade', authenticate, async (req, res, next) => {
  try {
    const { plan } = req.body;
    if (!['pro', 'enterprise'].includes(plan)) {
      return res.status(400).json({ success: false, message: 'Plan tidak valid' });
    }

    // Deactivate existing
    await pool.query(
      'UPDATE subscriptions SET status = "cancelled" WHERE user_id = ? AND status = "active"',
      [req.user.id]
    );

    // Create new subscription (30 days for pro, 365 for enterprise)
    const days = plan === 'pro' ? 30 : 365;
    const id = uuidv4();
    await pool.query(
      'INSERT INTO subscriptions (id, user_id, plan, status, expires_at) VALUES (?, ?, ?, "active", DATE_ADD(NOW(), INTERVAL ? DAY))',
      [id, req.user.id, plan, days]
    );

    res.json({ success: true, data: { id, plan, status: 'active', days } });
  } catch (err) {
    next(err);
  }
});

// POST /api/subscriptions/cancel
router.post('/cancel', authenticate, async (req, res, next) => {
  try {
    await pool.query(
      'UPDATE subscriptions SET status = "cancelled" WHERE user_id = ? AND status = "active"',
      [req.user.id]
    );
    res.json({ success: true, message: 'Subscription dibatalkan' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
