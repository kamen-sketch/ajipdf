require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
const mysql = require('mysql2/promise');

async function migrate() {
  // Koneksi tanpa database dulu untuk CREATE DATABASE
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
  });

  const dbName = process.env.DB_NAME || 'ajipdf';

  console.log(`Creating database "${dbName}" if not exists...`);
  await conn.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  await conn.query(`USE \`${dbName}\``);

  console.log('Creating tables...');

  // Users table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS users (
      id VARCHAR(36) PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      display_name VARCHAR(100) NOT NULL,
      avatar_url VARCHAR(500) NULL,
      role ENUM('user', 'admin') DEFAULT 'user',
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      last_login_at TIMESTAMP NULL,
      INDEX idx_email (email),
      INDEX idx_role (role)
    )
  `);

  // Subscriptions table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS subscriptions (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      plan ENUM('free', 'pro', 'enterprise') DEFAULT 'free',
      status ENUM('active', 'expired', 'cancelled') DEFAULT 'active',
      started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMP NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user (user_id),
      INDEX idx_status (status)
    )
  `);

  // Documents table
  await conn.query(`
    CREATE TABLE IF NOT EXISTS documents (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      name VARCHAR(255) NOT NULL,
      file_path VARCHAR(500) NULL,
      file_size BIGINT DEFAULT 0,
      page_count INT DEFAULT 0,
      mime_type VARCHAR(100) DEFAULT 'application/pdf',
      is_deleted BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user (user_id),
      INDEX idx_deleted (is_deleted)
    )
  `);

  // Operations log (split, merge, compress, etc.)
  await conn.query(`
    CREATE TABLE IF NOT EXISTS operations (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      document_id VARCHAR(36) NULL,
      type ENUM('split', 'merge', 'compress', 'encrypt', 'watermark', 'sign', 'ocr', 'scan', 'rotate', 'annotate') NOT NULL,
      status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'completed',
      input_size BIGINT DEFAULT 0,
      output_size BIGINT DEFAULT 0,
      metadata JSON NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      INDEX idx_user (user_id),
      INDEX idx_type (type),
      INDEX idx_created (created_at)
    )
  `);

  // Usage tracking (for free tier limits)
  await conn.query(`
    CREATE TABLE IF NOT EXISTS usage_tracking (
      id VARCHAR(36) PRIMARY KEY,
      user_id VARCHAR(36) NOT NULL,
      month_year VARCHAR(7) NOT NULL,
      split_merge_count INT DEFAULT 0,
      compress_count INT DEFAULT 0,
      ocr_count INT DEFAULT 0,
      total_operations INT DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY uk_user_month (user_id, month_year),
      INDEX idx_user (user_id)
    )
  `);

  // Error reports — grouped by pattern (fingerprint)
  // Fingerprint = hash dari error message + stack trace top frame
  // Agar error yang sama dari banyak user hanya disimpan 1 pattern.
  await conn.query(`
    CREATE TABLE IF NOT EXISTS error_patterns (
      id VARCHAR(36) PRIMARY KEY,
      fingerprint VARCHAR(64) NOT NULL UNIQUE,
      error_message TEXT NOT NULL,
      stack_trace TEXT NULL,
      screen VARCHAR(100) NULL,
      action VARCHAR(100) NULL,
      severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
      status ENUM('new', 'investigating', 'fixed', 'wontfix') DEFAULT 'new',
      first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      occurrence_count INT DEFAULT 1,
      affected_users INT DEFAULT 1,
      notes TEXT NULL,
      INDEX idx_fingerprint (fingerprint),
      INDEX idx_status (status),
      INDEX idx_severity (severity),
      INDEX idx_last_seen (last_seen_at)
    )
  `);

  // Error occurrences — setiap kali error terjadi (detail per-kejadian).
  // Dibatasi max ~5 per pattern agar tidak meledak.
  await conn.query(`
    CREATE TABLE IF NOT EXISTS error_occurrences (
      id VARCHAR(36) PRIMARY KEY,
      pattern_id VARCHAR(36) NOT NULL,
      user_id VARCHAR(36) NULL,
      device_info JSON NULL,
      app_version VARCHAR(20) NULL,
      platform VARCHAR(20) NULL,
      reproduction_steps JSON NULL,
      context JSON NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (pattern_id) REFERENCES error_patterns(id) ON DELETE CASCADE,
      INDEX idx_pattern (pattern_id),
      INDEX idx_created (created_at)
    )
  `);

  console.log('✅ Migration completed successfully!');
  await conn.end();
}

migrate().catch((err) => {
  console.error('❌ Migration failed:', err.message);
  process.exit(1);
});
