-- Testing function create_store and error handling.
CREATE OR REPLACE FUNCTION test_create_store (
    user_id UUID,
    shop_id UUID,
    store_name TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM create_store(user_id, shop_id, store_name);

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
        shop_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function create_store and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');

        PERFORM test_create_store(user_id, shop_id, 'store1', '');
        PERFORM test_create_store(user_id, shop_id, 'store1', 'stores_shop_id_name_upper_key');
        PERFORM test_create_store(invalid_id, shop_id, 'store2', 'permission_denied');
        PERFORM test_create_store(null, shop_id, 'store2', 'uuid_not_null');
        PERFORM test_create_store(user_id, null, 'store2', 'uuid_not_null');
        PERFORM test_create_store(user_id, shop_id, '', 'text_not_null');
        PERFORM test_create_store(user_id, shop_id, null, 'text_not_null');

        DELETE FROM store_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM stores AS s WHERE s.shop_id = _.shop_id;
        DELETE FROM shop_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM shops WHERE name = 'davidshop';
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

DROP FUNCTION test_create_store;



-- Testing function check_store_user_authority and error handling.
CREATE OR REPLACE FUNCTION test_check_store_user_authority (
    store_id UUID,
    user_id UUID,
    auth_name TEXT,
    auth_perm PERMISSION,
    result BOOLEAN,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        IF check_store_user_authority(store_id, user_id, auth_name, auth_perm) != result THEN
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
        shop_id UUID;
        store_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function check_store_user_authority and error handling...';

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        PERFORM create_store(user_id, shop_id, 'davidstore');
        store_id = (SELECT id FROM stores WHERE name = 'davidstore');

        PERFORM test_check_store_user_authority(store_id, user_id, 'team_authority', 'all', true, '');
        PERFORM test_check_store_user_authority(store_id, user_id, 'team_authority', 'none', true, 'test_failed');
        PERFORM test_check_store_user_authority(store_id, user_id, 'team_authority', 'none', false, '');
        PERFORM test_check_store_user_authority(invalid_id, user_id, 'team_authority', 'none', false, '');
        PERFORM test_check_store_user_authority(store_id, invalid_id, 'team_authority', 'none', false, '');
        PERFORM test_check_store_user_authority(null, user_id, 'team_authority', 'none', false, 'uuid_not_null');
        PERFORM test_check_store_user_authority(store_id, null, 'team_authority', 'none', false, 'uuid_not_null');

        DELETE FROM store_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM stores WHERE name = 'davidstore';
        DELETE FROM shop_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM shops WHERE name = 'davidshop';
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

DROP FUNCTION test_check_store_user_authority;



-- Testing function add_store_member and error handling.
CREATE OR REPLACE FUNCTION test_add_store_member (
    user_id UUID,
    store_id UUID,
    member_id UUID,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM add_store_member(user_id, store_id, member_id);

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
        member_id UUID;
        shop_id UUID;
        store_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function add_store_member and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('alice123', '123123', 'alice', 'alice123@mail.com', '0932132132')
            RETURNING id INTO member_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        PERFORM create_store(user_id, shop_id, 'davidstore');
        store_id = (SELECT id FROM stores WHERE name = 'davidstore');

        PERFORM test_add_store_member(member_id, store_id, user_id, 'permission_denied');
        PERFORM test_add_store_member(user_id, store_id, member_id, '');
        PERFORM test_add_store_member(user_id, store_id, user_id, 'store_user_store_id_user_id_key');
        PERFORM test_add_store_member(user_id, store_id, invalid_id, 'store_user_user_id_fkey');

        DELETE FROM store_user AS s WHERE s.store_id = _.store_id;
        DELETE FROM stores AS s WHERE name = 'davidstore';
        DELETE FROM shop_user AS s WHERE s.shop_id = _.shop_id;
        DELETE FROM shops WHERE name = 'davidshop';
        DELETE FROM users WHERE id = member_id;
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

DROP FUNCTION test_add_store_member;