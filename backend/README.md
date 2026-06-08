# AjiPDF Backend

Node.js + Express + MySQL backend for PDF Enterprise Suite.

## Setup

```bash
# Install dependencies
npm install

# Setup database (XAMPP MySQL harus running di localhost:3306)
npm run migrate
npm run seed
```

## Run

```bash
npm start        # production
npm run dev      # development (auto-reload)
```

Server berjalan di `http://localhost:3000`

## Default Accounts

| Role  | Email              | Password |
|-------|--------------------|----------|
| Admin | admin@ajipdf.com   | admin123 |
| User  | demo@ajipdf.com    | user123  |

## API Endpoints

### Auth
- `POST /api/auth/register` — Register baru
- `POST /api/auth/login` — Login, returns JWT token
- `GET /api/auth/me` — Profile + subscription (auth required)
- `POST /api/auth/change-password` — Ubah password

### Users
- `GET /api/users/profile` — Get profile
- `PUT /api/users/profile` — Update display name
- `GET /api/users/usage` — Usage stats bulan ini

### Documents
- `GET /api/documents` — List documents (paginated)
- `POST /api/documents/upload` — Upload PDF (multipart)
- `GET /api/documents/:id` — Detail document
- `DELETE /api/documents/:id` — Soft delete
- `POST /api/documents/log-operation` — Log operasi (split/merge/etc)

### Subscriptions
- `GET /api/subscriptions` — Current subscription
- `POST /api/subscriptions/upgrade` — Upgrade plan
- `POST /api/subscriptions/cancel` — Cancel

### Admin (requires admin role)
- `GET /api/admin/stats` — Dashboard statistics
- `GET /api/admin/users` — List all users (search, paginated)
- `GET /api/admin/users/:id` — User detail + stats
- `POST /api/admin/users` — Create user
- `PUT /api/admin/users/:id` — Update user (role, active, name)
- `DELETE /api/admin/users/:id` — Delete user
- `PUT /api/admin/users/:id/subscription` — Set subscription
- `GET /api/admin/operations` — All operations log
- `GET /api/admin/documents` — All documents

## Tech Stack
- **Runtime**: Node.js 20
- **Framework**: Express 4
- **Database**: MySQL 8 (via XAMPP)
- **Auth**: JWT (jsonwebtoken + bcryptjs)
- **Validation**: express-validator
- **Upload**: multer
