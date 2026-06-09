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

// POST /api/subscriptions/upgrade — ditolak (harus via payment)
router.post('/upgrade', authenticate, async (req, res) => {
  return res.status(402).json({
    success: false,
    message: 'Upgrade harus melalui pembayaran (in-app purchase).',
  });
});

// POST /api/subscriptions/verify-revenuecat — verifikasi dari client setelah purchase
// Client mengirim customerInfo setelah sukses purchase via RevenueCat SDK.
// Backend memvalidasi dan mengaktifkan subscription.
router.post('/verify-revenuecat', authenticate, async (req, res, next) => {
  try {
    const { customerId, entitlementId, productId, expiresAt } = req.body;

    if (!customerId || !entitlementId) {
      return res.status(400).json({
        success: false,
        message: 'customerId dan entitlementId wajib',
      });
    }

    // Verifikasi: entitlement harus "pro" (sesuai config)
    const [configRows] = await pool.query(
      "SELECT config_value FROM app_config WHERE config_key = 'revenuecat'"
    );
    const rcConfig = configRows.length > 0
      ? (typeof configRows[0].config_value === 'string'
        ? JSON.parse(configRows[0].config_value)
        : configRows[0].config_value)
      : { entitlement_id: 'pro' };

    if (entitlementId !== rcConfig.entitlement_id) {
      return res.status(400).json({
        success: false,
        message: 'Entitlement tidak valid',
      });
    }

    // Determine plan dari productId
    const plan = (productId || '').includes('yearly') ? 'pro' : 'pro';
    const days = (productId || '').includes('yearly') ? 365 : 30;

    // Cancel existing active
    await pool.query(
      'UPDATE subscriptions SET status = "cancelled" WHERE user_id = ? AND status = "active"',
      [req.user.id]
    );

    // Create new subscription
    const id = uuidv4();
    const expires = expiresAt
      ? new Date(expiresAt)
      : new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    await pool.query(
      'INSERT INTO subscriptions (id, user_id, plan, status, expires_at) VALUES (?, ?, ?, "active", ?)',
      [id, req.user.id, plan, expires]
    );

    res.json({
      success: true,
      data: { id, plan, status: 'active', expiresAt: expires.toISOString() },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/subscriptions/webhook — RevenueCat server-to-server webhook
// RevenueCat kirim event saat subscription dibuat/renew/cancel/expire.
// Setup di RevenueCat dashboard: webhook URL = https://yourdomain.com/api/subscriptions/webhook
router.post('/webhook', async (req, res, next) => {
  try {
    const event = req.body;
    // RevenueCat webhook format: { event: { type, app_user_id, ... } }
    const ev = event.event || event;
    const type = ev.type; // INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION
    const appUserId = ev.app_user_id;

    if (!type || !appUserId) {
      return res.status(400).json({ success: false, message: 'Invalid webhook' });
    }

    console.log(`[RevenueCat Webhook] ${type} for user ${appUserId}`);

    // Cari user by ID (appUserId = user.id di kita)
    const [users] = await pool.query('SELECT id FROM users WHERE id = ?', [appUserId]);
    if (users.length === 0) {
      // User tidak ditemukan di DB kita — mungkin anonymous RC user, skip
      return res.json({ success: true, message: 'User not found, skipped' });
    }

    const userId = users[0].id;

    switch (type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'NON_RENEWING_PURCHASE': {
        // Aktifkan Pro
        await pool.query(
          'UPDATE subscriptions SET status = "cancelled" WHERE user_id = ? AND status = "active"',
          [userId]
        );
        const expiresMs = ev.expiration_at_ms || (Date.now() + 30 * 24 * 60 * 60 * 1000);
        await pool.query(
          'INSERT INTO subscriptions (id, user_id, plan, status, expires_at) VALUES (?, ?, "pro", "active", ?)',
          [uuidv4(), userId, new Date(expiresMs)]
        );
        break;
      }
      case 'CANCELLATION':
      case 'EXPIRATION': {
        // Downgrade ke Free
        await pool.query(
          'UPDATE subscriptions SET status = "expired" WHERE user_id = ? AND status = "active"',
          [userId]
        );
        await pool.query(
          'INSERT INTO subscriptions (id, user_id, plan, status) VALUES (?, ?, "free", "active")',
          [uuidv4(), userId]
        );
        break;
      }
    }

    res.json({ success: true });
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
