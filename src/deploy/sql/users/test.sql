-- Test funstion username_to_id and error handling.
CREATE OR REPLACE FUNCTION test_username_to_id (
    username TEXT,
    id UUID_NN,
    error TEXT
) RETURNS VOID AS $$
    DECLARE
        user_id UUID;
    BEGIN
        user_id = username_to_id(username);
        IF user_id != id THEN
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
    BEGIN
        RAISE INFO 'Testing function username_to_id and error handling...';

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        PERFORM test_username_to_id('david123', user_id, '');
        PERFORM test_username_to_id('david1234', user_id, 'user_not_found');
        PERFORM test_username_to_id('', user_id, 'text_not_null');
        PERFORM test_username_to_id(null, user_id, 'text_not_null');

        DELETE FROM users WHERE id = user_id;

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_username_to_id;



-- Test function register_user and error handling.
CREATE OR REPLACE FUNCTION test_register_user (
    username TEXT,
    password TEXT,
    name TEXT,
    email TEXT,
    phone TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM register_user(username, password, name, email, phone);
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
    BEGIN
        RAISE INFO 'Testing function register_user and error handling...';

        PERFORM test_register_user('david0608', '123123', 'David', 'david0608@gmail.com', '0912047175', '');
        PERFORM test_register_user('alice0710', '123123', 'Alice', 'alice0710@gmail.com', '0912345678', '');
        PERFORM test_register_user('someone123', '123123', 'Someone', 'someone@mail.com', '0911111111', '');

        PERFORM test_register_user('someone123', '123123', 'Someone', 'someone@mail.com', '0911111111', 'users_username_key');
        PERFORM test_register_user('other123', '123123', 'Someone', 'someone@mail.com', '0911111111', 'users_email_key');
        PERFORM test_register_user('other123', '123123', 'Someone', 'other@mail.com', '0911111111', 'users_phone_key');
        PERFORM test_register_user(null, '123123', 'Any', 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('', '123123', 'Any', 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', null, 'Any', 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '', 'Any', 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '123123', null, 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '123123', '', 'any@mail.com', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '123123', 'Any', null, '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '123123', 'Any', '', '0922222222', 'text_not_null');
        PERFORM test_register_user('any123', '123123', 'Any', 'any@mail.com', null, 'text_not_null');
        PERFORM test_register_user('any123', '123123', 'Any', 'any@mail.com', '', 'text_not_null');

        DELETE FROM users WHERE username = 'david0608' OR username = 'alice0710' OR username = 'someone123';

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

DROP FUNCTION test_register_user;

DO $$
    BEGIN
        PERFORM register_user('david0608', '123123', 'david', 'david0608@mail.com', '0912312312');
        PERFORM register_user('alice0710', '123123', 'alice', 'alice0710@mail.com', '0932132132');
    END;
$$ LANGUAGE plpgsql;