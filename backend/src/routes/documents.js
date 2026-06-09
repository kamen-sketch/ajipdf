const express = require('express');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pool = require('../database/connection');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// Multer config
const uploadDir = path.join(__dirname, '..', '..', process.env.UPLOAD_DIR || 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const userDir = path.join(uploadDir, req.user.id);
    if (!fs.existsSync(userDir)) fs.mkdirSync(userDir, { recursive: true });
    cb(null, userDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE) || 50) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
    } else {
      cb(new Error('Hanya file PDF yang diizinkan'));
    }
  },
});

// GET /api/documents — list user's documents
router.get('/', authenticate, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = (page - 1) * limit;

    const [rows] = await pool.query(
      'SELECT id, name, file_size, page_count, created_at, updated_at FROM documents WHERE user_id = ? AND is_deleted = FALSE ORDER BY updated_at DESC LIMIT ? OFFSET ?',
      [req.user.id, limit, offset]
    );

    const [[{ total }]] = await pool.query(
      'SELECT COUNT(*) as total FROM documents WHERE user_id = ? AND is_deleted = FALSE',
      [req.user.id]
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

// POST /api/documents/upload — upload a PDF
router.post('/upload', authenticate, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'File PDF diperlukan' });
    }

    const id = uuidv4();
    const filePath = path.relative(uploadDir, req.file.path).replace(/\\/g, '/');

    await pool.query(
      'INSERT INTO documents (id, user_id, name, file_path, file_size, page_count) VALUES (?, ?, ?, ?, ?, ?)',
      [id, req.user.id, req.file.originalname, filePath, req.file.size, req.body.pageCount || 0]
    );

    res.status(201).json({
      success: true,
      data: {
        id,
        name: req.file.originalname,
        fileSize: req.file.size,
        filePath,
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/documents/:id/download — secure download (owner only)
router.get('/:id/download', authenticate, async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT name, file_path FROM documents WHERE id = ? AND user_id = ? AND is_deleted = FALSE',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0 || !rows[0].file_path) {
      return res.status(404).json({ success: false, message: 'Dokumen tidak ditemukan' });
    }

    // Cegah path traversal: pastikan file ada di dalam uploadDir
    const resolved = path.resolve(uploadDir, rows[0].file_path);
    if (!resolved.startsWith(path.resolve(uploadDir))) {
      return res.status(403).json({ success: false, message: 'Akses ditolak' });
    }
    if (!fs.existsSync(resolved)) {
      return res.status(404).json({ success: false, message: 'File tidak ada di server' });
    }

    res.download(resolved, rows[0].name);
  } catch (err) {
    next(err);
  }
});

// GET /api/documents/:id — get document detail
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM documents WHERE id = ? AND user_id = ? AND is_deleted = FALSE',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Dokumen tidak ditemukan' });
    }
    res.json({ success: true, data: rows[0] });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/documents/:id — soft delete
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const [result] = await pool.query(
      'UPDATE documents SET is_deleted = TRUE WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Dokumen tidak ditemukan' });
    }
    res.json({ success: true, message: 'Dokumen dihapus' });
  } catch (err) {
    next(err);
  }
});

// POST /api/documents/log-operation — log an operation
router.post('/log-operation', authenticate, async (req, res, next) => {
  try {
    let { type, documentId, inputSize, outputSize, metadata } = req.body;

    // Whitelist tipe operasi yang valid (sesuai ENUM di DB).
    const validTypes = ['split', 'merge', 'compress', 'encrypt', 'watermark',
      'sign', 'ocr', 'scan', 'rotate', 'annotate'];
    // Map legacy 'split_merge' → 'split'
    if (type === 'split_merge') type = 'split';
    if (!validTypes.includes(type)) {
      return res.status(400).json({ success: false, message: 'Tipe operasi tidak valid' });
    }

    // Validasi ukuran (cegah angka negatif/aneh)
    inputSize = Math.max(0, parseInt(inputSize) || 0);
    outputSize = Math.max(0, parseInt(outputSize) || 0);

    // Jika documentId diberikan, pastikan milik user ini (cegah IDOR).
    if (documentId) {
      const [doc] = await pool.query(
        'SELECT id FROM documents WHERE id = ? AND user_id = ?',
        [documentId, req.user.id]
      );
      if (doc.length === 0) documentId = null;
    }

    const id = uuidv4();
    await pool.query(
      'INSERT INTO operations (id, user_id, document_id, type, input_size, output_size, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, req.user.id, documentId || null, type, inputSize, outputSize, JSON.stringify(metadata || {})]
    );

    // Update usage tracking
    const monthYear = new Date().toISOString().slice(0, 7);
    await pool.query(`
      INSERT INTO usage_tracking (id, user_id, month_year, total_operations, split_merge_count, compress_count, ocr_count)
      VALUES (?, ?, ?, 1, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        total_operations = total_operations + 1,
        split_merge_count = split_merge_count + VALUES(split_merge_count),
        compress_count = compress_count + VALUES(compress_count),
        ocr_count = ocr_count + VALUES(ocr_count)
    `, [
      uuidv4(), req.user.id, monthYear,
      ['split', 'merge'].includes(type) ? 1 : 0,
      type === 'compress' ? 1 : 0,
      type === 'ocr' ? 1 : 0,
    ]);

    res.json({ success: true, data: { id } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
