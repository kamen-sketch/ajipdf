require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

async function seed() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'ajipdf',
  });

  console.log('Seeding database...');

  // Create admin user
  const adminId = uuidv4();
  const adminPassword = await bcrypt.hash('admin123', 10);
  await conn.query(`
    INSERT IGNORE INTO users (id, email, password_hash, display_name, role)
    VALUES (?, ?, ?, ?, 'admin')
  `, [adminId, 'admin@ajipdf.com', adminPassword, 'Admin']);

  // Create demo user
  const userId = uuidv4();
  const userPassword = await bcrypt.hash('user123', 10);
  await conn.query(`
    INSERT IGNORE INTO users (id, email, password_hash, display_name, role)
    VALUES (?, ?, ?, ?, 'user')
  `, [userId, 'demo@ajipdf.com', userPassword, 'Demo User']);

  // Create subscription for demo user
  await conn.query(`
    INSERT IGNORE INTO subscriptions (id, user_id, plan, status, expires_at)
    VALUES (?, ?, 'pro', 'active', DATE_ADD(NOW(), INTERVAL 30 DAY))
  `, [uuidv4(), userId]);

  console.log('✅ Seed completed!');
  console.log('');
  console.log('Admin account:');
  console.log('  Email: admin@ajipdf.com');
  console.log('  Password: admin123');
  console.log('');
  console.log('Demo account:');
  console.log('  Email: demo@ajipdf.com');
  console.log('  Password: user123');

  await conn.end();
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err.message);
  process.exit(1);
});
