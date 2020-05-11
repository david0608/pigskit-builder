-- Testing function singin_user and error handling.
CREATE OR REPLACE FUNCTION test_signin_user (
    username TEXT,
    password TEXT,
    user_id UUID_NN,
    error TEXT
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        session_id UUID;
        user_id UUID;
    BEGIN
        session_id = signin_user(username, password);
        _.user_id = (SELECT s.user_id FROM sessions AS s WHERE s.id = _.session_id);

        IF _.user_id != test_signin_user.user_id THEN
            PERFORM raise_error('test_failed');
        END IF;

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    <<_>>
    DECLARE
        user_id UUID;
    BEGIN
        RAISE INFO 'Testing function signin_user and error handling...';

        INSERT INTO users(username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        PERFORM test_signin_user('david123', '123123', user_id, '');
        PERFORM test_signin_user('david123', '123123', user_id, '');
        PERFORM test_signin_user('david1234', '123123', user_id, 'invalid_username_password');
        PERFORM test_signin_user('david123', '1231234', user_id, 'invalid_username_password');
        PERFORM test_signin_user('', '123123', user_id, 'text_not_null');
        PERFORM test_signin_user(null, '123123', user_id, 'text_not_null');
        PERFORM test_signin_user('david123', '', user_id, 'text_not_null');
        PERFORM test_signin_user('david123', null, user_id, 'text_not_null');

        DELETE FROM sessions AS s WHERE s.user_id = _.user_id;
        DELETE FROM users WHERE id = user_id;

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_signin_user;



-- Testing function signout_user and error handling.
CREATE OR REPLACE FUNCTION test_signout_user (
    session_id UUID,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM signout_user(session_id);
        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        session_id UUID;
    BEGIN
        RAISE INFO 'Testing function signout_user and error handling...';

        INSERT INTO users(username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        INSERT INTO sessions(user_id) VALUES (user_id) RETURNING id INTO session_id;

        PERFORM test_signout_user(null, 'uuid_not_null');
        PERFORM test_signout_user(session_id, '');
        PERFORM test_signout_user(session_id, '');

        DELETE FROM sessions WHERE id = session_id;
        DELETE FROM users WHERE id = user_id;

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_signout_user;



-- Testing function get_session_user and error handling.
CREATE OR REPLACE FUNCTION test_get_session_user (
    session_id UUID,
    user_id UUID_NN,
    error TEXT
) RETURNS VOID AS $$
    DECLARE
        sess UUID;
    BEGIN
        sess = get_session_user(session_id);

        IF sess != user_id THEN
            PERFORM raise_error('test_failed');
        END IF;

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        session_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function get_session_user and error handling...';

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        INSERT INTO sessions (user_id) VALUES (user_id) RETURNING id INTO session_id;

        PERFORM test_get_session_user(session_id, user_id, '');
        PERFORM test_get_session_user(invalid_id, user_id, 'session_expired');
        PERFORM test_get_session_user(null, user_id, 'uuid_not_null');


        DELETE FROM sessions WHERE id = session_id;
        DELETE FROM users WHERE id = user_id;

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_get_session_user;