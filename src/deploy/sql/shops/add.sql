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
    shop_id                 UUID_NN REFERENCES shops(id),
    user_id                 UUID_NN REFERENCES users(id),
    team_authority          PERMISSION_NN DEFAULT 'none',
    store_authority         PERMISSION_NN DEFAULT 'read-only',
    product_authority       PERMISSION_NN DEFAULT 'read-only',
    UNIQUE(shop_id, user_id)
);



-- Shops errors.
INSERT INTO errors (code, name, message) VALUES
    ('C5003', 'shop_not_found', 'Shop not found.'),
    ('C5007', 'shop_user_update_authority_failed', 'Failed to update shop_user authority.'),
    ('C5008', 'shop_duplicated_product', 'Product already existed for the shop.'),
    ('C5009', 'shop_product_not_found', 'Product not found for the shop.'),
    ('C5010', 'shop_product_mismatch', 'Product for the shop mismatch.');



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
    user_id UUID_NN,
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
    END;
$$ LANGUAGE plpgsql;



-- Chech shop user authority.
CREATE OR REPLACE FUNCTION check_shop_user_authority (
    shop_id UUID_NN,
    user_id UUID_NN,
    auth_name TEXT_NN,
    auth_perm PERMISSION_NN,
    OUT ok BOOLEAN
) AS $$
    DECLARE
        auth PERMISSION;
    BEGIN
        EXECUTE 'SELECT t.' || auth_name || ' FROM shop_user AS t WHERE t.shop_id = $1 AND t.user_id = $2'
            INTO auth
            USING shop_id, user_id;
        IF auth = auth_perm::PERMISSION THEN
            ok := true;
        ELSE
            ok := false;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Add shop member by user session and specific shop_name and member username.
CREATE OR REPLACE FUNCTION add_shop_member (
    user_id UUID_NN,
    shop_id UUID_NN,
    member_id UUID_NN
) RETURNS VOID AS $$
    BEGIN
        IF NOT check_shop_user_authority(shop_id, user_id, 'team_authority', 'all') THEN
            PERFORM raise_error('permission_denied');
        END IF;
        INSERT INTO shop_user (shop_id, user_id) VALUES (shop_id, member_id);
    END;
$$ LANGUAGE plpgsql;



-- Set shop member authority.
CREATE OR REPLACE FUNCTION set_shop_member_authority (
    user_id UUID_NN,
    shop_id UUID_NN,
    member_id UUID_NN,
    auth_name TEXT_NN,
    auth_perm PERMISSION_NN
) RETURNS VOID AS $$
    DECLARE
        updated UUID;
    BEGIN
        IF user_id = member_id AND auth_name = 'team_authority' THEN
            PERFORM raise_error('invalid_operation');
        END IF;

        IF NOT check_shop_user_authority(shop_id, user_id, 'team_authority', 'all') THEN
            PERFORM raise_error('permission_denied');
        END IF;
        
        EXECUTE 'UPDATE shop_user SET ' || auth_name || ' = $1 WHERE shop_id = $2 AND user_id = $3 RETURNING id'
            INTO updated
            USING auth_perm, shop_id, member_id;
        
        IF updated IS NULL THEN
            PERFORM raise_error('shop_user_update_authority_failed');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Create a product for the shop.
CREATE OR REPLACE FUNCTION shop_create_product (
    shop_id UUID_NN,
    product PRODUCT_NN
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;

        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        ELSIF (products ? upper(product.name)) THEN
            PERFORM raise_error('shop_duplicated_product');
        END IF;

        products = products || hstore(upper(product.name), format('%s', product));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Read a product from the shop.
CREATE OR REPLACE FUNCTION shop_read_product (
    shop_id UUID_NN,
    product_name TEXT_NN
) RETURNS PRODUCT AS $$
    DECLARE
        products hstore;
        product PRODUCT;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        product = (products -> upper(product_name))::PRODUCT;
        IF product IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;
        RETURN product;
    END;
$$ LANGUAGE plpgsql;



-- Delete a product of the shop.
CREATE OR REPLACE FUNCTION shop_delete_product (
    shop_id UUID_NN,
    name TEXT_NN,
    id UUID_NN
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
        product PRODUCT;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;

        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        ELSE
            product = (products -> upper(name))::PRODUCT;
            IF product IS NULL THEN
                PERFORM raise_error('shop_product_not_found');
            ELSIF product.id != id THEN
                PERFORM raise_error('shop_product_mismatch');
            END IF;
        END IF;

        products = products - upper(name);
        UPDATE shops AS s SET products = _.products WHERE s.id = shop_delete_product.shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Update a product of the shop.
CREATE OR REPLACE FUNCTION shop_update_product (
    shop_id UUID_NN,
    product PRODUCT_NN,
    new_name TEXT
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        products hstore;
        product PRODUCT;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        ELSE
            _.product = (products -> upper(shop_update_product.product.name))::PRODUCT;
            IF _.product IS NULL THEN
                PERFORM raise_error('shop_product_not_found');
            ELSIF _.product.id != shop_update_product.product.id THEN
                PERFORM raise_error('shop_product_mismatch');
            END IF;
        END IF;

        IF new_name IS NOT NULL AND new_name != '' THEN
            IF products ? upper(new_name) THEN
                PERFORM raise_error('shop_duplicated_product');
            ELSE
                products = products - upper(shop_update_product.product.name);
                shop_update_product.product.name = new_name;
            END IF;
        ELSE
            products = products - upper(shop_update_product.product.name);
        END IF;

        products = products || hstore(upper(shop_update_product.product.name), format('%s', shop_update_product.product));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;