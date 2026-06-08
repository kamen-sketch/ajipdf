const express = require('express');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');
const pool = require('../database/connection');
const { authenticate, adminOnly } = require('../middleware/auth');

const router = express.Router();

// Semua route admin butuh autentikasi + role admin
router.use(authenticate, adminOnly);

// ============ DASHBOARD STATS ============

// GET /api/admin/stats
router.get('/stats', async (req, res, next) => {
  try {
    const [[{ totalUsers }]] = await pool.query('SELECT COUNT(*) as totalUsers FROM users');
    const [[{ activeUsers }]] = await pool.query('SELECT COUNT(*) as activeUsers FROM users WHERE is_active = TRUE');
    const [[{ proUsers }]] = await pool.query(
      'SELECT COUNT(DISTINCT user_id) as proUsers FROM subscriptions WHERE plan = "pro" AND status = "active"'
    );
    const [[{ totalDocuments }]] = await pool.query('SELECT COUNT(*) as totalDocuments FROM documents WHERE is_deleted = FALSE');
    const [[{ totalOperations }]] = await pool.query('SELECT COUNT(*) as totalOperations FROM operations');
    const [[{ todayOperations }]] = await pool.query(
      'SELECT COUNT(*) as todayOperations FROM operations WHERE DATE(created_at) = CURDATE()'
    );

    // Operations by type (last 30 days)
    const [opsByType] = await pool.query(
      'SELECT type, COUNT(*) as count FROM operations WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY type ORDER BY count DESC'
    );

    // Recent signups
    const [recentUsers] = await pool.query(
      'SELECT id, email, display_name, role, created_at FROM users ORDER BY created_at DESC LIMIT 10'
    );

    res.json({
      success: true,
      data: {
        overview: { totalUsers, activeUsers, proUsers, totalDocuments, totalOperations, todayOperations },
        operationsByType: opsByType,
        recentUsers,
      },
    });
  } catch (err) {
    next(err);
  }
});

// ============ USER MANAGEMENT ============

// GET /api/admin/users — list all users with pagination
router.get('/users', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = (page - 1) * limit;
    const search = req.query.search || '';

    let whereClause = '';
    let params = [];
    if (search) {
      whereClause = 'WHERE email LIKE ? OR display_name LIKE ?';
      params = [`%${search}%`, `%${search}%`];
    }

    const [rows] = await pool.query(
      `SELECT u.id, u.email, u.display_name, u.role, u.is_active, u.created_at, u.last_login_at,
        (SELECT plan FROM subscriptions WHERE user_id = u.id AND status = 'active' ORDER BY created_at DESC LIMIT 1) as current_plan
       FROM users u ${whereClause} ORDER BY u.created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM users ${whereClause}`, params
    );

    res.json({
      success: true,
      data: rows,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/admin/users/:id — get user detail
router.get('/users/:id', async (req, res, next) => {
  try {
    const [users] = await pool.query(
      'SELECT id, email, display_name, role, is_active, created_at, last_login_at FROM users WHERE id = ?',
      [req.params.id]
    );
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }

    const [subs] = await pool.query(
      'SELECT * FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 5',
      [req.params.id]
    );

    const [docs] = await pool.query(
      'SELECT COUNT(*) as count, SUM(file_size) as totalSize FROM documents WHERE user_id = ? AND is_deleted = FALSE',
      [req.params.id]
    );

    const [ops] = await pool.query(
      'SELECT type, COUNT(*) as count FROM operations WHERE user_id = ? GROUP BY type',
      [req.params.id]
    );

    res.json({
      success: true,
      data: {
        user: users[0],
        subscriptions: subs,
        documents: docs[0],
        operations: ops,
      },
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/admin/users/:id — update user
router.put('/users/:id', async (req, res, next) => {
  try {
    const { displayName, role, isActive } = req.body;
    const updates = [];
    const params = [];

    if (displayName !== undefined) { updates.push('display_name = ?'); params.push(displayName); }
    if (role !== undefined) { updates.push('role = ?'); params.push(role); }
    if (isActive !== undefined) { updates.push('is_active = ?'); params.push(isActive); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Tidak ada field untuk diupdate' });
    }

    params.push(req.params.id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);

    res.json({ success: true, message: 'User berhasil diupdate' });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/admin/users/:id — delete user (hard delete)
router.delete('/users/:id', async (req, res, next) => {
  try {
    // Prevent deleting yourself
    if (req.params.id === req.user.id) {
      return res.status(400).json({ success: false, message: 'Tidak bisa menghapus diri sendiri' });
    }

    const [result] = await pool.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'User tidak ditemukan' });
    }
    res.json({ success: true, message: 'User berhasil dihapus' });
  } catch (err) {
    next(err);
  }
});

// POST /api/admin/users — create user (by admin)
router.post('/users', async (req, res, next) => {
  try {
    const { email, password, displayName, role } = req.body;
    if (!email || !password || !displayName) {
      return res.status(400).json({ success: false, message: 'email, password, displayName wajib' });
    }

    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ success: false, message: 'Email sudah terdaftar' });
    }

    const id = uuidv4();
    const hash = await bcrypt.hash(password, 10);
    await pool.query(
      'INSERT INTO users (id, email, password_hash, display_name, role) VALUES (?, ?, ?, ?, ?)',
      [id, email, hash, displayName, role || 'user']
    );

    // Create free subscription
    await pool.query(
      'INSERT INTO subscriptions (id, user_id, plan, status) VALUES (?, ?, "free", "active")',
      [uuidv4(), id]
    );

    res.status(201).json({ success: true, data: { id, email, displayName, role: role || 'user' } });
  } catch (err) {
    next(err);
  }
});

// ============ SUBSCRIPTION MANAGEMENT ============

// PUT /api/admin/users/:id/subscription — set subscription
router.put('/users/:id/subscription', async (req, res, next) => {
  try {
    const { plan, days } = req.body;
    if (!['free', 'pro', 'enterprise'].includes(plan)) {
      return res.status(400).json({ success: false, message: 'Plan tidak valid' });
    }

    // Cancel existing
    await pool.query(
      'UPDATE subscriptions SET status = "cancelled" WHERE user_id = ? AND status = "active"',
      [req.params.id]
    );

    if (plan !== 'free') {
      const d = days || (plan === 'pro' ? 30 : 365);
      await pool.query(
        'INSERT INTO subscriptions (id, user_id, plan, status, expires_at) VALUES (?, ?, ?, "active", DATE_ADD(NOW(), INTERVAL ? DAY))',
        [uuidv4(), req.params.id, plan, d]
      );
    } else {
      await pool.query(
        'INSERT INTO subscriptions (id, user_id, plan, status) VALUES (?, ?, "free", "active")',
        [uuidv4(), req.params.id]
      );
    }

    res.json({ success: true, message: `Subscription diubah ke ${plan}` });
  } catch (err) {
    next(err);
  }
});

// ============ OPERATIONS LOG ============

// GET /api/admin/operations — list all operations
router.get('/operations', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const offset = (page - 1) * limit;
    const type = req.query.type;

    let whereClause = '';
    let params = [];
    if (type) {
      whereClause = 'WHERE o.type = ?';
      params = [type];
    }

    const [rows] = await pool.query(
      `SELECT o.*, u.email, u.display_name FROM operations o
       JOIN users u ON o.user_id = u.id
       ${whereClause} ORDER BY o.created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM operations o ${whereClause}`, params
    );

    res.json({
      success: true,
      data: rows,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

// ============ DOCUMENTS ============

// GET /api/admin/documents — list all documents
router.get('/documents', async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = (page - 1) * limit;

    const [rows] = await pool.query(
      `SELECT d.*, u.email, u.display_name FROM documents d
       JOIN users u ON d.user_id = u.id
       WHERE d.is_deleted = FALSE ORDER BY d.created_at DESC LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) as total FROM documents WHERE is_deleted = FALSE'
    );

    res.json({
      success: true,
      data: rows,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
