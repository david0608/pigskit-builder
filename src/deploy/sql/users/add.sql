-- Users table.
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        TEXT UNIQUE,
    password        TEXT,
    name            TEXT,
    email           TEXT UNIQUE,
    phone           TEXT UNIQUE,
    CONSTRAINT users_columns_notnull CHECK (
        username IS NOT NULL AND LENGTH(username) > 0
        AND password IS NOT NULL AND LENGTH(password) > 0
        AND name IS NOT NULL AND LENGTH(name) > 0
        AND email IS NOT NULL AND LENGTH(email) > 0
        AND phone IS NOT NULL AND LENGTH(phone) > 0
    )
);



-- Users errors.
INSERT INTO errors (code, name, message) VALUES
    ('C1001', 'users_username_key', 'Username has been registered.'),
    ('C1002', 'users_email_key', 'Email has been registered.'),
    ('C1003', 'users_phone_key', 'Phone number has been registered.'),
    ('C1004', 'users_columns_notnull', 'Received null on columns which cannot be null.');



-- Get user_id from specific username.
CREATE OR REPLACE FUNCTION username_to_id (
    username TEXT,
    OUT id UUID
) AS $$
    BEGIN
        SELECT t.id INTO STRICT username_to_id.id FROM users AS t WHERE t.username = username_to_id.username;
    EXCEPTION WHEN OTHERS THEN
        PERFORM raise_error('not_found');
    END;
$$ LANGUAGE plpgsql;



-- Register and user.
CREATE OR REPLACE FUNCTION register_user (
    username TEXT,
    password TEXT,
    name TEXT,
    email TEXT,
    phone TEXT
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

CREATE OR REPLACE FUNCTION test_register_user (
    username TEXT,
    password TEXT,
    name TEXT,
    email TEXT,
    phone TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM register_user(username, password, name, email, phone);
        RAISE INFO 'Successfully registered user.';
    EXCEPTION WHEN OTHERS THEN
        BEGIN
            RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    BEGIN
        RAISE INFO 'Testing function register_user and error handling.';

        -- Success.
        PERFORM test_register_user('david0608', '123123', 'David', 'david0608@gmail.com', '0912047175');
        -- Success.
        PERFORM test_register_user('alice0710', '123123', 'Alice', 'alice0710@gmail.com', '0912345678');
        -- Success.
        PERFORM test_register_user('someone123', '123123', 'Someone', 'someone@mail.com', '0911111111');
        -- Fail. Duplicated username.
        PERFORM test_register_user('someone123', '123456', 'Anotherone', 'anotherone@mail.com', '0922222222');
        -- Fail. Duplicated email.
        PERFORM test_register_user('anotherone123', '123456', 'Anotherone', 'someone@mail.com', '0922222222');
        -- Fail. Duplicated phone.
        PERFORM test_register_user('anotherone123', '123456', 'Anotherone', 'anotherone@mail.com', '0911111111');
        -- Fail. Null values.
        PERFORM test_register_user(NULL, '123456', 'Anotherone', 'anotherone@mail.com', '0922222222');
        -- Fail. Null values.
        PERFORM test_register_user('', '123456', 'Anotherone', 'anotherone@mail.com', '0922222222');
        -- Fail. Null values.
        PERFORM test_register_user('anotherone123', '', 'Anotherone', 'anotherone@mail.com', '0922222222');
        -- Fail. Null values.
        PERFORM test_register_user('anotherone123', '123456', 'Anotherone', 'anotherone@mail.com', NULL);

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;