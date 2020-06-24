-- Users table.
CREATE TABLE users (
    id              UUID_NN PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        TEXT_NZ UNIQUE,
    password        TEXT_NZ,
    email           TEXT_NZ UNIQUE,
    phone           TEXT_NZ UNIQUE,
    nickname        TEXT
);



-- User register session table.
CREATE TABLE user_register_session (
    id              UUID_NN PRIMARY KEY,
    username        TEXT,
    password        TEXT,
    email           TEXT,
    phone           TEXT,
    generate_at     TIMESTAMPTZ DEFAULT now()
);



-- Users errors.
INSERT INTO errors (code, name, message) VALUES
    ('C1001', 'user_not_found', 'User not found.');



-- Get user_id from specific username.
CREATE OR REPLACE FUNCTION username_to_id (
    username TEXT_NZ,
    OUT id UUID
) AS $$
    BEGIN
        SELECT t.id INTO STRICT username_to_id.id FROM users AS t WHERE t.username = username_to_id.username;
    EXCEPTION WHEN OTHERS THEN
        PERFORM raise_error('user_not_found');
    END;
$$ LANGUAGE plpgsql;



-- Register an user.
CREATE OR REPLACE FUNCTION register_user (
    regssid UUID,
    OUT ok BOOLEAN
) AS $$
    DECLARE
        inserted UUID;
    BEGIN
        INSERT INTO users (username, password, email, phone)
            SELECT username, password, email, phone FROM user_register_session WHERE id = regssid
            RETURNING id INTO inserted;

        DELETE FROM user_register_session WHERE id = regssid;

        ok := inserted IS NOT NULL;
    EXCEPTION WHEN OTHERS THEN
        DELETE FROM user_register_session WHERE id = regssid;
        ok := false;
    END;
$$ LANGUAGE plpgsql;