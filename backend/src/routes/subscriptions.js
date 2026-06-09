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

// POST /api/subscriptions/upgrade
// PENTING: Endpoint ini TIDAK boleh langsung mengaktifkan Pro tanpa verifikasi
// pembayaran. Upgrade hanya boleh dilakukan setelah webhook payment gateway
// (mis. RevenueCat/Stripe) memverifikasi transaksi, atau secara manual oleh admin.
// Untuk saat ini endpoint dinonaktifkan agar user tidak bisa self-upgrade gratis.
router.post('/upgrade', authenticate, async (req, res) => {
  return res.status(402).json({
    success: false,
    message:
        'Upgrade harus melalui pembayaran. Hubungi admin atau gunakan in-app purchase.',
  });
});

// POST /api/subscriptions/verify-purchase — verifikasi pembelian dari payment gateway.
// Body: { provider: 'revenuecat'|'stripe', receipt: '...', plan: 'pro' }
// NOTE: Implementasi verifikasi receipt yang sebenarnya perlu ditambahkan
// sesuai payment provider. Saat ini hanya placeholder yang memvalidasi struktur.
router.post('/verify-purchase', authenticate, async (req, res, next) => {
  try {
    const { provider, receipt, plan } = req.body;
    if (!provider || !receipt || !['pro', 'enterprise'].includes(plan)) {
      return res.status(400).json({
        success: false,
        message: 'provider, receipt, dan plan valid wajib diisi',
      });
    }

    // TODO: Verifikasi receipt ke payment provider (RevenueCat/Stripe/Google Play).
    // JANGAN aktifkan subscription sebelum receipt benar-benar terverifikasi.
    return res.status(501).json({
      success: false,
      message:
          'Verifikasi pembayaran belum dikonfigurasi. Hubungi admin untuk aktivasi manual.',
    });
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
