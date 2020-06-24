-- Sessions table.
CREATE TABLE sessions (
    id                  UUID_NN PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID_NN REFERENCES users(id),
    latest_access       TS_NN DEFAULT NOW()
);



-- Sessions errors.
INSERT INTO errors (code, name, message) VALUES
    ('C2002', 'session_expired', 'Session expired.');



-- Signin user.
CREATE OR REPLACE FUNCTION signin_user (
    username TEXT_NZ,
    password TEXT_NZ,
    OUT session_id UUID
) AS $$
    DECLARE
        user_id UUID;
    BEGIN
        SELECT id INTO user_id FROM users AS t
            WHERE t.username = signin_user.username AND t.password = signin_user.password;

        IF user_id IS NOT NULL THEN
            INSERT INTO sessions (user_id) VALUES (user_id) RETURNING id INTO session_id;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Signout user.
CREATE OR REPLACE FUNCTION signout_user (
    session_id UUID_NN
) RETURNS VOID AS $$
    BEGIN
        DELETE FROM sessions WHERE id = session_id;
    END;
$$ LANGUAGE plpgsql;



-- Get user_id from session_id.
CREATE OR REPLACE FUNCTION get_session_user (
    session_id UUID_NN,
    OUT user_id UUID
) AS $$
    BEGIN
        UPDATE sessions AS t SET latest_access = NOW() WHERE id = session_id RETURNING t.user_id INTO get_session_user.user_id;
        IF user_id IS NULL THEN
            PERFORM raise_error('session_expired');
        END IF;
    END;
$$ LANGUAGE plpgsql;