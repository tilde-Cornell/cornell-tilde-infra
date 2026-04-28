CREATE TABLE IF NOT EXISTS users (
    username TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    college TEXT,
    grad_year TEXT,
    bio TEXT,
    public INTEGER NOT NULL DEFAULT 1,
    is_admin INTEGER NOT NULL DEFAULT 0,
    permissions_json TEXT NOT NULL DEFAULT '{}',
    tilde_compute_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_public
ON users(public);

CREATE INDEX IF NOT EXISTS idx_users_username_nocase
ON users(username COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS applications (
    application_id TEXT PRIMARY KEY,
    submitted_at TEXT,
    email TEXT,
    name TEXT,
    preferred_username TEXT,
    final_username TEXT,
    college TEXT,
    graduation_year TEXT,
    additional_info TEXT,
    ssh_key TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_applications_status
ON applications(status);

CREATE INDEX IF NOT EXISTS idx_applications_email
ON applications(email);

CREATE INDEX IF NOT EXISTS idx_applications_preferred_username
ON applications(preferred_username);
