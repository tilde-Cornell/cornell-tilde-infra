CREATE TABLE IF NOT EXISTS directory_modified (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    modified INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO directory_modified (id, modified)
VALUES (1, 0);

CREATE TRIGGER IF NOT EXISTS trg_directory_modified_user_insert
AFTER INSERT ON users
BEGIN
    UPDATE directory_modified
    SET modified = 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = 1;
END;

CREATE TRIGGER IF NOT EXISTS trg_directory_modified_user_profile_update
AFTER UPDATE OF name, username, college, grad_year, bio, public ON users
WHEN
    OLD.name IS NOT NEW.name OR
    OLD.username IS NOT NEW.username OR
    OLD.college IS NOT NEW.college OR
    OLD.grad_year IS NOT NEW.grad_year OR
    OLD.bio IS NOT NEW.bio OR
    OLD.public IS NOT NEW.public
BEGIN
    UPDATE directory_modified
    SET modified = 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = 1;
END;

CREATE TRIGGER IF NOT EXISTS trg_directory_modified_user_delete
AFTER DELETE ON users
BEGIN
    UPDATE directory_modified
    SET modified = 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = 1;
END;