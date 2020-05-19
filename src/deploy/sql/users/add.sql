-- Users table.
CREATE TABLE users (
    id              UUID_NN PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        TEXT_NZ UNIQUE,
    password        TEXT_NZ,
    name            TEXT_NZ,
    email           TEXT_NZ UNIQUE,
    phone           TEXT_NZ UNIQUE
);



-- Users errors.
INSERT INTO errors (code, name, message) VALUES
    ('C1001', 'users_username_key', 'Username has been registered.'),
    ('C1002', 'users_email_key', 'Email has been registered.'),
    ('C1003', 'users_phone_key', 'Phone number has been registered.'),
    ('C1004', 'user_not_found', 'User not found.');



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



-- Register and user.
CREATE OR REPLACE FUNCTION register_user (
    username TEXT_NZ,
    password TEXT_NZ,
    name TEXT_NZ,
    email TEXT_NZ,
    phone TEXT_NZ
) RETURNS VOID AS $$
    BEGIN
        INSERT INTO users(username, password, name, email, phone)
            VALUES (username, password, name, email, phone);
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            PERFORM raise_error(c_name);
        END;
    END;
$$ LANGUAGE plpgsql;