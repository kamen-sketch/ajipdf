const express = require('express');
const pool = require('../database/connection');
const { authenticate, adminOnly } = require('../middleware/auth');

const router = express.Router();

// ============ PUBLIC CONFIG (untuk app client) ============

// GET /api/config/public — config yang boleh dibaca client (pricing, promo, limits)
router.get('/public', async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      "SELECT config_key, config_value FROM app_config WHERE config_key IN ('pricing', 'promo', 'free_limits', 'pro_features', 'revenuecat')"
    );

    const config = {};
    for (const row of rows) {
      config[row.config_key] = typeof row.config_value === 'string'
        ? JSON.parse(row.config_value)
        : row.config_value;
    }

    // Jangan kirim secret revenuecat ke client — hanya api_key dan product IDs
    if (config.revenuecat) {
      config.revenuecat = {
        api_key: config.revenuecat.api_key,
        entitlement_id: config.revenuecat.entitlement_id,
        product_monthly: config.revenuecat.product_monthly,
        product_yearly: config.revenuecat.product_yearly,
      };
    }

    res.json({ success: true, data: config });
  } catch (err) {
    next(err);
  }
});

// ============ ADMIN CONFIG CRUD ============

// GET /api/config — all configs (admin only)
router.get('/', authenticate, adminOnly, async (req, res, next) => {
  try {
    const [rows] = await pool.query('SELECT * FROM app_config ORDER BY config_key');
    const configs = rows.map(r => ({
      ...r,
      config_value: typeof r.config_value === 'string' ? JSON.parse(r.config_value) : r.config_value,
    }));
    res.json({ success: true, data: configs });
  } catch (err) {
    next(err);
  }
});

// PUT /api/config/:key — update config (admin only)
router.put('/:key', authenticate, adminOnly, async (req, res, next) => {
  try {
    const { value, description } = req.body;
    if (value === undefined) {
      return res.status(400).json({ success: false, message: 'value wajib' });
    }

    const jsonValue = JSON.stringify(value);
    const updates = ['config_value = ?'];
    const params = [jsonValue];

    if (description !== undefined) {
      updates.push('description = ?');
      params.push(description);
    }

    params.push(req.params.key);
    const [result] = await pool.query(
      `UPDATE app_config SET ${updates.join(', ')} WHERE config_key = ?`,
      params
    );

    if (result.affectedRows === 0) {
      // Key baru — insert
      await pool.query(
        'INSERT INTO app_config (config_key, config_value, description) VALUES (?, ?, ?)',
        [req.params.key, jsonValue, description || null]
      );
    }

    res.json({ success: true, message: `Config "${req.params.key}" updated` });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
