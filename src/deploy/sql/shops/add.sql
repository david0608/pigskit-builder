-- Shops table.
CREATE TABLE shops (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                    TEXT_NN,
    name_upper              TEXT UNIQUE,
    products                HSTORE_NN DEFAULT '',
    latest_update           TS_NN DEFAULT NOW()
);

-- Trigger function which automatically add column name_upper from column name.
CREATE OR REPLACE FUNCTION shop_name_auto_upper ()
RETURNS trigger
AS $$
    BEGIN
        NEW.name_upper = upper(NEW.name);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER name_auto_upper
BEFORE INSERT ON shops FOR EACH ROW
EXECUTE PROCEDURE shop_name_auto_upper();



-- Shop_user table.
CREATE TABLE shop_user (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id                 UUID REFERENCES shops(id) NOT NULL,
    user_id                 UUID REFERENCES users(id) NOT NULL,
    team_authority          PERMISSION NOT NULL DEFAULT 'none',
    store_authority         PERMISSION NOT NULL DEFAULT 'read-only',
    product_authority       PERMISSION NOT NULL DEFAULT 'read-only',
    UNIQUE(shop_id, user_id)
);



-- Shops errors.
INSERT INTO errors (code, name, message) VALUES
    ('C5002', 'shops_name_upper_key', 'Shop name already been used.'),
    ('C5003', 'shop_not_found', 'Shop not found.'),
    ('C5004', 'shop_user_shop_id_user_id_key', 'Pair of shop_id and user_id already existed.'),
    ('C5005', 'shop_user_user_id_fkey', 'user_id not existed.'),
    ('C5006', 'shop_user_shop_id_fkey', 'shop_id not existed.'),
    ('C5007', 'shop_user_update_authority_failed', 'Failed to update shop_user authority.'),
    ('C5008', 'shop_duplicated_product', 'Product already existed for the shop.'),
    ('C5009', 'shop_product_not_found', 'Product not found for the shop.');



-- Get shop_id from specific shop_name.
CREATE OR REPLACE FUNCTION shop_name_to_id (
    shop_name TEXT_NN,
    OUT shop_id UUID
) AS $$
    BEGIN
        SELECT id INTO STRICT shop_id FROM shops WHERE name_upper = upper(shop_name);
    EXCEPTION WHEN OTHERS THEN
        PERFORM raise_error('shop_not_found');
    END;
$$ LANGUAGE plpgsql;



-- Create shop.
CREATE OR REPLACE FUNCTION create_shop (
    user_id UUID,
    shop_name TEXT_NN
) RETURNS VOID AS $$
    DECLARE
        shop_id UUID;
    BEGIN
        INSERT INTO shops(name) VALUES (shop_name) RETURNING id INTO shop_id;
        INSERT INTO shop_user (
            shop_id,
            user_id,
            team_authority,
            store_authority,
            product_authority
        ) VALUES (
            shop_id,
            user_id,
            'all',
            'all',
            'all'
        );
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            PERFORM raise_error(c_name);
        END;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_create_shop (
    user_id UUID,
    shop_name TEXT_NN
) RETURNS VOID AS $$
    BEGIN
        PERFORM create_shop(user_id, shop_name);
        RAISE INFO 'Successfully created shop.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function create_shop and error handling.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        -- Success.
        PERFORM test_create_shop(user_id, 'DavidShop');
        -- Fail. Duplicated shop name.
        PERFORM test_create_shop(user_id, 'DavidShop');
        -- Success.
        PERFORM test_create_shop(user_id, 'DavidShop2');
        -- Fail. Invalid user_id.
        PERFORM test_create_shop(invalid_id, 'TestShop');

        SELECT id INTO user_id FROM users WHERE username = 'alice0710';
        -- Success.
        PERFORM test_create_shop(user_id, 'AliceShop');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Add shop member by user session and specific shop_name and member username.
CREATE OR REPLACE FUNCTION add_shop_member (
    user_id UUID,
    shop_id UUID,
    member_id UUID
) RETURNS VOID AS $$
    DECLARE
        auth PERMISSION;
    BEGIN
        SELECT t.team_authority INTO auth FROM shop_user AS t WHERE t.shop_id = add_shop_member.shop_id AND t.user_id = add_shop_member.user_id;
        IF auth IS NULL OR auth != 'all' THEN
            PERFORM raise_error('permission_denied');
        END IF;
        INSERT INTO shop_user (shop_id, user_id) VALUES (shop_id, member_id);
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            PERFORM raise_error(c_name);
        END;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_add_shop_member (
    user_id UUID,
    shop_id UUID,
    member_id UUID
) RETURNS VOID AS $$
    BEGIN
        PERFORM add_shop_member(user_id, shop_id, member_id);
        RAISE INFO 'Successfully added shop member.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        shop_id UUID;
        member_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function add_shop_member and error handling.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP';
        SELECT id INTO member_id FROM users WHERE username = 'alice0710';
        -- Fail. Invalid user_id.
        PERFORM test_add_shop_member(invalid_id, shop_id, member_id);
        -- Fail. Invalid shop_id.
        PERFORM test_add_shop_member(user_id, invalid_id, member_id);
        -- Fail. Invalid member_id.
        PERFORM test_add_shop_member(user_id, shop_id, invalid_id);
        -- Success.
        PERFORM test_add_shop_member(user_id, shop_id, member_id);
        -- Fail. Duplicated shop_id member_id pair.
        PERFORM test_add_shop_member(user_id, shop_id, member_id);

        SELECT id INTO shop_id FROM shops WHERE name_upper = 'ALICESHOP';
        -- Fail. Permission denied.
        PERFORM test_add_shop_member(user_id, shop_id, member_id);

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Set shop member authority.
CREATE OR REPLACE FUNCTION set_shop_member_authority (
    user_id UUID,
    shop_id UUID,
    member_id UUID,
    auth_name TEXT_NN,
    auth_perm PERMISSION
) RETURNS VOID AS $$
    DECLARE
        auth PERMISSION;
        updated UUID;
    BEGIN
        SELECT t.team_authority INTO auth FROM shop_user AS t
            WHERE t.shop_id = set_shop_member_authority.shop_id AND t.user_id = set_shop_member_authority.user_id;

        IF
            auth IS NULL
            OR auth != 'all'
            OR (user_id = member_id AND auth_name = 'team_authority')
        THEN
            PERFORM raise_error('permission_denied');
        END IF;
        
        EXECUTE 'UPDATE shop_user SET ' || auth_name || ' = $1 WHERE shop_id = $2 AND user_id = $3 RETURNING id'
            INTO updated
            USING auth_perm, shop_id, member_id;
        
        IF updated IS NULL THEN
            RAISE EXCEPTION USING CONSTRAINT = 'shop_user_update_authority_failed';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            PERFORM raise_error(c_name);
        END;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_set_shop_member_authority (
    user_id UUID,
    shop_id UUID,
    member_id UUID,
    auth_name TEXT_NN,
    auth_perm PERMISSION
) RETURNS VOID AS $$
    BEGIN
        PERFORM set_shop_member_authority(user_id, shop_id, member_id, auth_name, auth_perm);
        RAISE INFO 'Successfully set shop member authority.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        shop_id UUID;
        member_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function set_shop_member_authority and error handling.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP';
        SELECT id INTO member_id FROM users WHERE username = 'alice0710';

        -- Fail. Invalid user_id.
        PERFORM test_set_shop_member_authority(invalid_id, shop_id, member_id, 'team_authority', 'all');
        -- Fail. Invalid shop_id.
        PERFORM test_set_shop_member_authority(user_id, invalid_id, member_id, 'team_authority', 'all');
        -- Fail. Invalid member_id.
        PERFORM test_set_shop_member_authority(user_id, shop_id, invalid_id, 'team_authority', 'all');
        -- Success.
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, 'team_authority', 'all');
        -- Fail. Set self team_authority.
        PERFORM test_set_shop_member_authority(user_id, shop_id, user_id, 'team_authority', 'all');
        -- Fail. Invalid column.
        PERFORM test_set_shop_member_authority(user_id, shop_id, member_id, 'invalid_column', 'all');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Check user write authority to shop products.
CREATE OR REPLACE FUNCTION check_shop_products_write_authority (
    user_id UUID,
    shop_id UUID
) RETURNS VOID AS $$
    DECLARE
        authority PERMISSION;
    BEGIN
        SELECT t.product_authority INTO authority FROM shop_user AS t
            WHERE t.shop_id = check_shop_products_write_authority.shop_id AND t.user_id = check_shop_products_write_authority.user_id;
        IF authority IS NULL OR authority != 'all' THEN
            PERFORM raise_error('permission_denied');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Create a product for the shop.
CREATE OR REPLACE FUNCTION shop_create_product (
    shop_id UUID,
    product_name TEXT_NN,
    price INT_NN
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        IF (products ? upper(product_name)) THEN
            PERFORM raise_error('shop_duplicated_product');
        END IF;

        products = products || hstore(upper(product_name), format('%s', new_product(product_name, price)));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;

-- Read a product from the shop.
CREATE OR REPLACE FUNCTION shop_read_product (
    shop_id UUID,
    product_name TEXT_NN
) RETURNS PRODUCT AS $$
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        RETURN (products -> upper(product_name))::PRODUCT;
    END;
$$ LANGUAGE plpgsql;

-- Update a product of the shop.
CREATE OR REPLACE FUNCTION shop_update_product (
    shop_id UUID,
    product PRODUCT,
    new_name TEXT
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;

        products = products - upper(product.name);

        IF new_name IS NOT NULL AND new_name != '' THEN
            IF (products ? upper(new_name)) THEN
                PERFORM raise_error('shop_duplicated_product');
            ELSE
                product.name = new_name;
            END IF;
        END IF;

        product.latest_update = now();
        products = products || hstore(upper(product.name), format('%s', product));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;

-- Delete a product of the shop.
CREATE OR REPLACE FUNCTION shop_delete_product (
    shop_id UUID,
    product_name TEXT_NN
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        IF (products ? upper(product_name)) THEN
            products = products - upper(product_name);
            UPDATE shops SET products = _.products WHERE id = shop_id;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- TODO: Impl this in rust.
-- Create a customize for the product of the shop.
CREATE OR REPLACE FUNCTION shop_product_create_customize (
    shop_id UUID,
    product_name TEXT_NN,
    customize_name TEXT_NN
) RETURNS VOID AS $$
    DECLARE
        product PRODUCT;
    BEGIN
        product = (shop_read_product(shop_id, product_name));
        IF product IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;

        product = product_create_customize(product, new_customize(customize_name));
        product.latest_update = now();
        PERFORM shop_update_product(shop_id, product, '');
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_shop_product_create_customize (
    shop_id UUID,
    product_name TEXT_NN,
    customize_name TEXT_NN
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_product_create_customize(shop_id, product_name, customize_name);
        RAISE INFO 'Successfully create product customize.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        shop_id UUID;
    BEGIN
        RAISE INFO 'Testing function shop_product_create_customize and error handling.';

        shop_id = (SELECT id FROM shops WHERE name_upper = 'DAVIDSHOP');
        PERFORM shop_create_product(shop_id, 'product_1', 100);
        -- Success.
        PERFORM test_shop_product_create_customize(shop_id, 'product_1', 'customize_1');
        -- Fail. Product not found.
        PERFORM test_shop_product_create_customize(shop_id, 'product_2', 'customize_1');
        -- Fail. Duplicated customize name.
        PERFORM test_shop_product_create_customize(shop_id, 'product_1', 'customize_1');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- TODO: Impl this in rust.
-- Delete a customize for the product of the shop.
CREATE OR REPLACE FUNCTION shop_product_delete_customize (
    shop_id UUID,
    product_name TEXT_NN,
    customize_name TEXT_NN
) RETURNS VOID AS $$
    DECLARE
        product PRODUCT;
    BEGIN
        product = (shop_read_product(shop_id, product_name));
        IF product IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;

        product = product_delete_customize(product, customize_name);
        product.latest_update = now();
        PERFORM shop_update_product(shop_id, product, '');
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_shop_product_delete_customize (
    shop_id UUID,
    product_name TEXT_NN,
    customize_name TEXT_NN
) RETURNS VOID AS $$
    BEGIN
        PERFORM shop_product_delete_customize(shop_id, product_name, customize_name);
        RAISE INFO 'Succefully deleted product customize';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        shop_id UUID;
    BEGIN
        RAISE INFO 'Testing function shop_product_delete_customize.';

        shop_id = (SELECT id FROM shops WHERE name_upper = 'DAVIDSHOP');
        PERFORM shop_product_create_customize(shop_id, 'product_1', 'test');
        -- Success.
        PERFORM test_shop_product_delete_customize(shop_id, 'product_1', 'test');
        -- Fail. Product not found.
        PERFORM test_shop_product_delete_customize(shop_id, 'product_2', 'test');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;