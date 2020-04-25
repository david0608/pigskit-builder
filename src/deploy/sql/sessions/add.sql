-- Sessions table.
CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID REFERENCES users(id) NOT NULL,
    latest_access       TIMESTAMPTZ DEFAULT NOW()
);



-- Sessions errors.
INSERT INTO errors (code, name, message) VALUES
    ('C2001', 'invalid_username_password', 'Invalid username or password.'),
    ('C2002', 'session_expired', 'Session expired.');



-- Signin user.
CREATE OR REPLACE FUNCTION signin_user (
    username TEXT_NN,
    password TEXT_NN,
    OUT session_id UUID
) AS $$
    DECLARE
        user_id UUID;
    BEGIN
        SELECT id INTO user_id FROM users AS t
            WHERE t.username = signin_user.username AND t.password = signin_user.password;

        IF user_id IS NULL THEN
            PERFORM raise_error('invalid_username_password');
        END IF;

        INSERT INTO sessions (user_id) VALUES (user_id) RETURNING id INTO session_id;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_signin_user (
    username TEXT,
    password TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM signin_user(username, password);
        RAISE INFO 'Successfully signed in.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    BEGIN
        RAISE INFO 'Testing function signin_user and error handling.';
        
        -- Success.
        PERFORM test_signin_user('david0608', '123123');
        -- Success.
        PERFORM test_signin_user('alice0710', '123123');
        -- Fail. Invalid username.
        PERFORM test_signin_user('someone12', '123123');
        -- Fail. Invalid password.
        PERFORM test_signin_user('someone123', '12312');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Signout user.
CREATE OR REPLACE FUNCTION signout_user (
    session_id UUID
) RETURNS VOID AS $$
    BEGIN
        DELETE FROM sessions WHERE id = session_id;
    END;
$$ LANGUAGE plpgsql;



-- Get user_id from session_id.
CREATE OR REPLACE FUNCTION get_session_user (
    session_id UUID,
    OUT user_id UUID
) AS $$
    BEGIN
        UPDATE sessions AS t SET latest_access = NOW() WHERE id = session_id RETURNING t.user_id INTO get_session_user.user_id;
        IF user_id IS NULL THEN
            PERFORM raise_error('session_expired');
        END IF;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_get_session_user (
    session_id UUID
) RETURNS VOID AS $$
    BEGIN
        PERFORM get_session_user(session_id);
        RAISE INFO 'Successfully get user_id.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        session_id UUID;
    BEGIN
        RAISE INFO 'Testing function get_session_user and error handling.';

        SELECT signin_user('david0608', '123123') INTO session_id;
        -- Success.
        PERFORM test_get_session_user(session_id);

        PERFORM signout_user(session_id);
        -- Fail. Session expired.
        PERFORM test_get_session_user(session_id);

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;