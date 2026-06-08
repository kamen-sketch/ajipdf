const express = require('express');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const pool = require('../database/connection');
const { authenticate, adminOnly } = require('../middleware/auth');

const router = express.Router();

/**
 * POST /api/errors/report — Dari aplikasi Flutter: kirim error report.
 * Autentikasi opsional (user bisa tidak login saat crash).
 * 
 * Body:
 * - errorMessage (required): pesan error
 * - stackTrace: stack trace (opsional)
 * - screen: layar tempat error (mis. 'pdf_viewer', 'split')
 * - action: aksi yang dilakukan saat error (mis. 'save_document', 'compress')
 * - severity: 'low' | 'medium' | 'high' | 'critical'
 * - deviceInfo: { platform, osVersion, appVersion, deviceModel }
 * - reproductionSteps: ["Buka PDF", "Klik split", "Pilih halaman 1-5", "Error"]
 * - context: data tambahan bebas (JSON)
 */
router.post('/report', async (req, res, next) => {
  try {
    const {
      errorMessage,
      stackTrace,
      screen,
      action,
      severity,
      deviceInfo,
      reproductionSteps,
      context,
    } = req.body;

    if (!errorMessage) {
      return res.status(400).json({ success: false, message: 'errorMessage wajib' });
    }

    // Ekstrak user_id dari token jika ada (opsional)
    let userId = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const jwt = require('jsonwebtoken');
        const decoded = jwt.verify(authHeader.split(' ')[1], process.env.JWT_SECRET);
        userId = decoded.userId;
      } catch (_) {}
    }

    // Buat fingerprint: hash dari errorMessage + top stack frame + screen + action
    // Agar error yang sama (pattern) di-group jadi satu.
    const topFrame = (stackTrace || '').split('\n').slice(0, 3).join('|');
    const raw = `${errorMessage}||${topFrame}||${screen || ''}||${action || ''}`;
    const fingerprint = crypto.createHash('sha256').update(raw).digest('hex').slice(0, 64);

    // Cek apakah pattern sudah ada
    const [existing] = await pool.query(
      'SELECT id, occurrence_count, affected_users FROM error_patterns WHERE fingerprint = ?',
      [fingerprint]
    );

    let patternId;

    if (existing.length > 0) {
      // Pattern sudah ada — increment counter
      patternId = existing[0].id;
      const prevCount = existing[0].occurrence_count;
      const prevAffected = existing[0].affected_users;

      // Cek apakah user ini sudah pernah report pattern ini
      let newAffected = prevAffected;
      if (userId) {
        const [prev] = await pool.query(
          'SELECT id FROM error_occurrences WHERE pattern_id = ? AND user_id = ? LIMIT 1',
          [patternId, userId]
        );
        if (prev.length === 0) newAffected++;
      } else {
        newAffected++; // anonymous user counts as new
      }

      await pool.query(
        'UPDATE error_patterns SET occurrence_count = ?, affected_users = ?, last_seen_at = NOW(), severity = GREATEST(severity, ?) WHERE id = ?',
        [prevCount + 1, newAffected, severity || 'medium', patternId]
      );

      // Simpan occurrence detail hanya jika < 5 per pattern (hemat storage)
      const [[{ occCount }]] = await pool.query(
        'SELECT COUNT(*) as occCount FROM error_occurrences WHERE pattern_id = ?',
        [patternId]
      );

      if (occCount < 5) {
        await pool.query(
          'INSERT INTO error_occurrences (id, pattern_id, user_id, device_info, app_version, platform, reproduction_steps, context) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            uuidv4(), patternId, userId,
            JSON.stringify(deviceInfo || {}),
            deviceInfo?.appVersion || null,
            deviceInfo?.platform || null,
            JSON.stringify(reproductionSteps || []),
            JSON.stringify(context || {}),
          ]
        );
      }
    } else {
      // Pattern baru
      patternId = uuidv4();
      await pool.query(
        'INSERT INTO error_patterns (id, fingerprint, error_message, stack_trace, screen, action, severity) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [patternId, fingerprint, errorMessage, stackTrace || null, screen || null, action || null, severity || 'medium']
      );

      // Simpan occurrence pertama
      await pool.query(
        'INSERT INTO error_occurrences (id, pattern_id, user_id, device_info, app_version, platform, reproduction_steps, context) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          uuidv4(), patternId, userId,
          JSON.stringify(deviceInfo || {}),
          deviceInfo?.appVersion || null,
          deviceInfo?.platform || null,
          JSON.stringify(reproductionSteps || []),
          JSON.stringify(context || {}),
        ]
      );
    }

    res.json({ success: true, data: { patternId, fingerprint } });
  } catch (err) {
    next(err);
  }
});

// ============ ADMIN ENDPOINTS ============

// GET /api/errors/patterns — Semua error patterns (admin)
router.get('/patterns', authenticate, adminOnly, async (req, res, next) => {
  try {
    const status = req.query.status;
    const severity = req.query.severity;
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const offset = (page - 1) * limit;

    let where = [];
    let params = [];
    if (status) { where.push('status = ?'); params.push(status); }
    if (severity) { where.push('severity = ?'); params.push(severity); }

    const whereClause = where.length > 0 ? 'WHERE ' + where.join(' AND ') : '';

    const [rows] = await pool.query(
      `SELECT * FROM error_patterns ${whereClause} ORDER BY 
        CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
        last_seen_at DESC 
       LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );

    const [[{ total }]] = await pool.query(
      `SELECT COUNT(*) as total FROM error_patterns ${whereClause}`, params
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

// GET /api/errors/patterns/:id — Detail pattern + occurrences (admin)
router.get('/patterns/:id', authenticate, adminOnly, async (req, res, next) => {
  try {
    const [patterns] = await pool.query('SELECT * FROM error_patterns WHERE id = ?', [req.params.id]);
    if (patterns.length === 0) {
      return res.status(404).json({ success: false, message: 'Pattern tidak ditemukan' });
    }

    const [occurrences] = await pool.query(
      `SELECT eo.*, u.email, u.display_name 
       FROM error_occurrences eo 
       LEFT JOIN users u ON eo.user_id = u.id 
       WHERE eo.pattern_id = ? 
       ORDER BY eo.created_at DESC`,
      [req.params.id]
    );

    res.json({
      success: true,
      data: {
        pattern: patterns[0],
        occurrences: occurrences.map(o => ({
          ...o,
          device_info: typeof o.device_info === 'string' ? JSON.parse(o.device_info) : o.device_info,
          reproduction_steps: typeof o.reproduction_steps === 'string' ? JSON.parse(o.reproduction_steps) : o.reproduction_steps,
          context: typeof o.context === 'string' ? JSON.parse(o.context) : o.context,
        })),
      },
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/errors/patterns/:id — Update status/notes (admin)
router.put('/patterns/:id', authenticate, adminOnly, async (req, res, next) => {
  try {
    const { status, severity, notes } = req.body;
    const updates = [];
    const params = [];

    if (status) { updates.push('status = ?'); params.push(status); }
    if (severity) { updates.push('severity = ?'); params.push(severity); }
    if (notes !== undefined) { updates.push('notes = ?'); params.push(notes); }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Tidak ada field untuk diupdate' });
    }

    params.push(req.params.id);
    await pool.query(`UPDATE error_patterns SET ${updates.join(', ')} WHERE id = ?`, params);
    res.json({ success: true, message: 'Pattern diupdate' });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/errors/patterns/:id — Hapus pattern (admin)
router.delete('/patterns/:id', authenticate, adminOnly, async (req, res, next) => {
  try {
    await pool.query('DELETE FROM error_patterns WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Pattern dihapus' });
  } catch (err) {
    next(err);
  }
});

// GET /api/errors/stats — Ringkasan error (admin)
router.get('/stats', authenticate, adminOnly, async (req, res, next) => {
  try {
    const [[{ total }]] = await pool.query('SELECT COUNT(*) as total FROM error_patterns');
    const [[{ newCount }]] = await pool.query("SELECT COUNT(*) as newCount FROM error_patterns WHERE status = 'new'");
    const [[{ criticalCount }]] = await pool.query("SELECT COUNT(*) as criticalCount FROM error_patterns WHERE severity = 'critical' AND status != 'fixed'");
    const [[{ todayCount }]] = await pool.query("SELECT COUNT(*) as todayCount FROM error_patterns WHERE DATE(last_seen_at) = CURDATE()");

    const [byScreen] = await pool.query(
      "SELECT screen, COUNT(*) as count, SUM(occurrence_count) as total_occurrences FROM error_patterns WHERE screen IS NOT NULL GROUP BY screen ORDER BY total_occurrences DESC LIMIT 10"
    );

    const [topErrors] = await pool.query(
      "SELECT id, error_message, screen, action, severity, occurrence_count, affected_users, last_seen_at FROM error_patterns WHERE status != 'fixed' ORDER BY occurrence_count DESC LIMIT 10"
    );

    res.json({
      success: true,
      data: { total, newCount, criticalCount, todayCount, byScreen, topErrors },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
