-- Testing function shop_name_to_id and error handling.
CREATE OR REPLACE FUNCTION test_shop_name_to_id (
    shop_name TEXT,
    OUT shop_id UUID,
    error TEXT
) AS $$
    BEGIN
        shop_id = shop_name_to_id(shop_name);

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
        RAISE INFO 'Testing function shop_name_to_id and error handling...';

        INSERT INTO shops (name) VALUES ('s1');

        PERFORM test_shop_name_to_id('s1', '');
        PERFORM test_shop_name_to_id('s2', 'shop_not_found');
        PERFORM test_shop_name_to_id('', 'text_not_null');
        PERFORM test_shop_name_to_id(null, 'text_not_null');

        DELETE FROM shops WHERE name = 's1';

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

DROP FUNCTION test_shop_name_to_id;



-- Testing function create_shop and error handling.
CREATE OR REPLACE FUNCTION test_create_shop (
    user_id UUID,
    shop_name TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM create_shop(user_id, shop_name);

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
        invalid_user UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function create_shop and error handling...';

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        PERFORM test_create_shop(user_id, 's1', '');
        PERFORM test_create_shop(user_id, 's1', 'shops_name_upper_key');
        PERFORM test_create_shop(invalid_user, 's2', 'shop_user_user_id_fkey');
        PERFORM test_create_shop(null, 's2', 'uuid_not_null');
        PERFORM test_create_shop(user_id, '', 'text_not_null');
        PERFORM test_create_shop(user_id, null, 'text_not_null');
        
        DELETE FROM shop_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM shops WHERE name = 's1';
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

DROP FUNCTION test_create_shop;



-- Testing function shop_name_to_id and error handling.
CREATE OR REPLACE FUNCTION test_add_shop_member (
    user_id UUID,
    shop_id UUID,
    member_id UUID,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM add_shop_member(user_id, shop_id, member_id);

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
        invalid_id UUID := uuid_generate_v4();
        shop_id UUID;
    BEGIN
        RAISE INFO 'Testing function add_shop_member and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('alice123', '123123', 'alice', 'alice123@mail.com', '0922312312')
            RETURNING id INTO member_id;

        PERFORM create_shop(user_id, 'davidshop');

        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');

        PERFORM test_add_shop_member(user_id, shop_id, member_id, '');
        PERFORM test_add_shop_member(user_id, shop_id, member_id, 'shop_user_shop_id_user_id_key');
        PERFORM test_add_shop_member(member_id, shop_id, user_id, 'permission_denied');
        PERFORM test_add_shop_member(member_id, invalid_id, user_id, 'permission_denied');
        PERFORM test_add_shop_member(null, shop_id, member_id, 'uuid_not_null');
        PERFORM test_add_shop_member(user_id, null, member_id, 'uuid_not_null');
        PERFORM test_add_shop_member(user_id, shop_id, null, 'uuid_not_null');

        DELETE FROM shop_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM shop_user AS s WHERE s.user_id = _.member_id;
        DELETE FROM shops WHERE name = 'davidshop';

        DELETE FROM users WHERE id = user_id;
        DELETE FROM users WHERE id = member_id;

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

DROP FUNCTION test_add_shop_member;



-- Testing function set_shop_member_authority and error handling.
CREATE OR REPLACE FUNCTION test_set_shop_member_authority (
    user_id UUID,
    shop_id UUID,
    member_id UUID,
    auth_name TEXT,
    auth_permission PERMISSION,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM set_shop_member_authority(user_id, shop_id, member_id, auth_name, auth_permission);

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
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function set_shop_member_authority and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('alice123', '123123', 'alice', 'alice123@mail.com', '0922312312')
            RETURNING id INTO member_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        PERFORM add_shop_member(user_id, shop_id, member_id);

        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, 'product_authority', 'all', '');
        PERFORM test_set_shop_member_authority(member_id, shop_id, user_id, 'store_authority', 'none', 'permission_denied');
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, 'team_authority', 'all', '');
        PERFORM test_set_shop_member_authority(member_id, shop_id, user_id, 'store_authority', 'none', '');
        PERFORM test_set_shop_member_authority(user_id, shop_id, user_id, 'team_authority', 'read-only' ,'invalid_operation');
        PERFORM test_set_shop_member_authority(user_id, shop_id, invalid_id, 'product_authority', 'read-only' ,'shop_user_update_authority_failed');
        PERFORM test_set_shop_member_authority(null, shop_id, member_id, 'product_authority', 'read-only' ,'uuid_not_null');
        PERFORM test_set_shop_member_authority(user_id, null, member_id, 'product_authority', 'read-only' ,'uuid_not_null');
        PERFORM test_set_shop_member_authority(user_id, shop_id, null, 'product_authority', 'read-only' ,'uuid_not_null');
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, '', 'read-only', 'text_not_null');
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, null, 'read-only', 'text_not_null');
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, 'product_authority', null, 'permission_not_null');

        DELETE FROM shop_user AS s WHERE s.user_id = _.user_id;
        DELETE FROM shop_user AS s WHERE s.user_id = _.member_id;
        DELETE FROM shops WHERE name = 'davidshop';

        DELETE FROM users WHERE id = user_id;
        DELETE FROM users WHERE id = member_id;

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

DROP FUNCTION test_set_shop_member_authority;



-- Testing function check_shop_user_authority and error handling.
CREATE OR REPLACE FUNCTION test_check_shop_user_authority (
    shop_id UUID,
    user_id UUID,
    auth_name TEXT,
    auth_perm PERMISSION,
    result BOOLEAN,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        IF check_shop_user_authority(shop_id, user_id, auth_name, auth_perm) != result THEN
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
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function check_shop_products_all_authority and error handling...';

        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;

        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');

        PERFORM test_check_shop_user_authority(shop_id, user_id, 'team_authority', 'all', true, '');
        PERFORM test_check_shop_user_authority(shop_id, user_id, 'team_authority', 'none', true, 'test_failed');
        PERFORM test_check_shop_user_authority(shop_id, user_id, 'team_authority', 'none', false, '');
        PERFORM test_check_shop_user_authority(invalid_id, user_id, 'product_authority', 'none', false, '');
        PERFORM test_check_shop_user_authority(shop_id, invalid_id, 'store_authority', 'none', false, '');
        PERFORM test_check_shop_user_authority(null, user_id, 'store_authority', 'none', false, 'uuid_not_null');
        PERFORM test_check_shop_user_authority(shop_id, null, 'store_authority', 'none', false, 'uuid_not_null');

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

DROP FUNCTION test_check_shop_user_authority;



-- Testing function shop_create_product and error handling.
CREATE OR REPLACE FUNCTION test_shop_create_product (
    shop_id UUID,
    product PRODUCT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_create_product(shop_id, product);

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
        product PRODUCT;
    BEGIN
        RAISE INFO 'Testing function shop_create_product and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        product = new_product('p1', 100);

        PERFORM test_shop_create_product(shop_id, product, '');
        PERFORM test_shop_create_product(shop_id, product, 'shop_duplicated_product');
        product = new_product('p2', 200);
        PERFORM test_shop_create_product(null, product, 'uuid_not_null');
        PERFORM test_shop_create_product(invalid_id, product, 'shop_not_found');

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

DROP FUNCTION test_shop_create_product;



-- Testing function shop_read_product and error handling.
CREATE OR REPLACE FUNCTION test_shop_read_product (
    shop_id UUID,
    product_name TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_read_product(shop_id, product_name);

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
        RAISE INFO 'Testing function shop_read_product and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        PERFORM shop_create_product(shop_id, new_product('p1', 100));

        PERFORM test_shop_read_product(shop_id, 'p1', '');
        PERFORM test_shop_read_product(shop_id, 'p2', 'shop_product_not_found');
        PERFORM test_shop_read_product(invalid_id, 'p1', 'shop_product_not_found');
        PERFORM test_shop_read_product(null, 'p1', 'uuid_not_null');
        PERFORM test_shop_read_product(shop_id, '', 'text_not_null');
        PERFORM test_shop_read_product(shop_id, null, 'text_not_null');

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

DROP FUNCTION test_shop_read_product;



-- Testing function shop_delete_product and error handling.
CREATE OR REPLACE FUNCTION test_shop_delete_product (
    shop_id UUID,
    name TEXT,
    id UUID,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_delete_product(shop_id, name, id);

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
        product PRODUCT;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function shop_delete_product and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        product = new_product('p1', 100);
        PERFORM shop_create_product(shop_id, product);

        PERFORM test_shop_delete_product(invalid_id, product.name, product.id, 'shop_not_found');
        PERFORM test_shop_delete_product(shop_id, product.name, invalid_id, 'shop_product_mismatch');
        PERFORM test_shop_delete_product(shop_id, product.name, product.id, '');
        PERFORM test_shop_delete_product(shop_id, product.name, product.id, 'shop_product_not_found');
        PERFORM test_shop_delete_product(null, product.name, product.id, 'uuid_not_null');
        PERFORM test_shop_delete_product(shop_id, '', product.id, 'text_not_null');
        PERFORM test_shop_delete_product(shop_id, null, product.id, 'text_not_null');
        PERFORM test_shop_delete_product(shop_id, product.name, null, 'uuid_not_null');

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

DROP FUNCTION test_shop_delete_product;



-- Testing function shop_update_product and error handling.
CREATE OR REPLACE FUNCTION test_shop_update_product (
    shop_id UUID,
    product PRODUCT,
    new_name TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_update_product(shop_id, product, new_name);

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
        product PRODUCT;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function shop_update_product and error handling...';
        
        INSERT INTO users (username, password, name, email, phone)
            VALUES ('david123', '123123', 'david', 'david123@mail.com', '0912312312')
            RETURNING id INTO user_id;
        
        PERFORM create_shop(user_id, 'davidshop');
        shop_id = (SELECT id FROM shops WHERE name = 'davidshop');
        product = new_product('p1', 100);
        PERFORM shop_create_product(shop_id, product);

        PERFORM test_shop_update_product(shop_id, product, 'p2', '');
        product.price = 200;
        PERFORM test_shop_update_product(shop_id, product, '', 'shop_product_not_found');
        product.name = 'p2';
        PERFORM test_shop_update_product(shop_id, product, '', '');
        PERFORM test_shop_update_product(shop_id, new_product('p2', 300), '', 'shop_product_mismatch');
        PERFORM test_shop_update_product(invalid_id, product, '', 'shop_not_found');
        PERFORM test_shop_update_product(shop_id, product, 'p2', 'shop_duplicated_product');
        PERFORM test_shop_update_product(null, product, 'p3', 'uuid_not_null');
        PERFORM test_shop_update_product(shop_id, null, 'p3', 'product_not_null');
        PERFORM test_shop_update_product(shop_id, product, 'p3', '');

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

DROP FUNCTION test_shop_update_product;