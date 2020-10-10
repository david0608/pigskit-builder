-- Shops errors.
INSERT INTO errors (code, name, message) VALUES
    ('C6001', 'shop_name_used', 'Shop name has been used.'),
    ('C6003', 'shop_not_found', 'Shop not found.'),
    ('C6009', 'shop_product_not_found', 'Product not found for the shop.'),
    ('C6101', 'shop_user_update_authority_failed', 'Failed to update shop_user authority.');



-- Shops table.
CREATE TABLE IF NOT EXISTS shops (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                    TEXT_NZ,
    name_upper              TEXT UNIQUE,
    products                HSTORE_NN DEFAULT '',
    serieses                HSTORE_NN DEFAULT '',
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



-- Get shop_id from specific shop_name.
CREATE OR REPLACE FUNCTION shop_name_to_id (
    shop_name TEXT_NZ,
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
    shop_name TEXT_NZ
) RETURNS VOID AS $$
    DECLARE
        shop_id UUID;
    BEGIN
        IF (SELECT name FROM shops WHERE name_upper = upper(shop_name)) IS NOT NULL THEN
            PERFORM raise_error('shop_name_used');
        END IF;

        INSERT INTO shops(name) VALUES (shop_name) RETURNING id INTO shop_id;

        INSERT INTO shop_order_number_sequence(shop_id) VALUES (shop_id);

        INSERT INTO shop_user (
            shop_id,
            user_id,
            member_authority,
            order_authority,
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



-- Query all products of the shop.
CREATE OR REPLACE FUNCTION query_shop_products (
    shop_id UUID_NN
) RETURNS TABLE (
    key UUID_NN,
    product PRODUCT
) AS $$
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE id = shop_id;
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::PRODUCT FROM each(products);
    END;
$$ LANGUAGE plpgsql;



-- Create a product for the shop.
CREATE OR REPLACE FUNCTION shop_create_product (
    shop_id UUID_NN,
    payload TEXT_NN,
    OUT product_key UUID
) AS $$
    <<_>>
    DECLARE
        products hstore;
        payload JSONB;
        prod PRODUCT;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;

        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        _.payload := shop_create_product.payload::JSONB;

        prod := product_create(
            _.payload ->> 'name',
            _.payload ->> 'description',
            (_.payload ->> 'price')::INTEGER,
            (_.payload ->> 'series_id')::UUID,
            _.payload -> 'customizes'
        );
        product_key := uuid_generate_v4();

        products := products || hstore(format('%s', product_key), format('%s', prod));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Read a product from the shop.
CREATE OR REPLACE FUNCTION shop_read_product (
    shop_id UUID_NN,
    prod_key UUID_NN
) RETURNS PRODUCT AS $$
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;

        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        RETURN (products -> format('%s', prod_key))::PRODUCT;
    END;
$$ LANGUAGE plpgsql;



-- Delete a product of the shop.
CREATE OR REPLACE FUNCTION shop_delete_product (
    shop_id UUID_NN,
    prod_key UUID_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        products hstore;
    BEGIN
        SELECT t.products INTO _.products FROM shops AS t WHERE t.id = shop_id;

        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        products = products - format('%s', prod_key);
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Update a product of the shop.
CREATE OR REPLACE FUNCTION shop_update_product (
    shop_id UUID_NN,
    prod_key UUID_NN,
    payload TEXT_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        products hstore;
        payload JSONB;
        prod PRODUCT;
    BEGIN
        SELECT t.products INTO products FROM shops AS t WHERE t.id = shop_id;
        IF products IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        prod = (products -> format('%s', prod_key))::PRODUCT;
        IF prod IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;

        _.payload = shop_update_product.payload::JSONB;
        prod = product_update(prod, _.payload);

        products = products - format('%s', prod_key);
        products = products || hstore(format('%s', prod_key), format('%s', prod));
        UPDATE shops SET products = _.products WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Set has_picture of a product of the shop.
CREATE OR REPLACE FUNCTION shop_set_product_has_picture (
    shop_id UUID_NN,
    prod_key UUID_NN,
    has_picture BOOLEAN
) RETURNS void AS $$
    BEGIN
        PERFORM shop_update_product(
            shop_id,
            prod_key,
            (json_build_object('has_picture', has_picture))::TEXT
        );
    END;
$$ LANGUAGE plpgsql;



-- Qeury all serieses of the shop;
CREATE OR REPLACE FUNCTION query_shop_serieses (
    shop_id UUID_NN
) RETURNS TABLE (
    key UUID_NN,
    name TEXT
) AS $$
    DECLARE
        serieses hstore;
    BEGIN
        SELECT t.serieses INTO serieses FROM shops AS t WHERE id = shop_id;
        IF serieses IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::TEXT FROM each(serieses);
    END;
$$ LANGUAGE plpgsql;



-- Create a series for the shop.
CREATE OR REPLACE FUNCTION shop_create_series (
    shop_id UUID_NN,
    name TEXT_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        serieses hstore;
    BEGIN
        SELECT t.serieses INTO serieses FROM shops AS t WHERE t.id = shop_id;
        IF serieses IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        serieses = serieses || hstore(format('%s', uuid_generate_v4()), name);
        UPDATE shops SET serieses = _.serieses, latest_update = now() WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Delete a series of the shop.
CREATE OR REPLACE FUNCTION shop_delete_series (
    shop_id UUID_NN,
    key UUID_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        serieses hstore;
    BEGIN
        SELECT t.serieses INTO serieses FROM shops AS t WHERE t.id = shop_id;
        IF serieses IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        serieses = serieses - format('%s', key);
        UPDATE shops SET serieses = _.serieses, latest_update = now() WHERE id = shop_id;
    END;
$$ LANGUAGE plpgsql;



-- Update a series of the shop.
CREATE OR REPLACE FUNCTION shop_update_series (
    shop_id UUID_NN,
    key UUID_NN,
    name TEXT_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        serieses hstore;
    BEGIN
        SELECT t.serieses INTO serieses FROM shops AS t WHERE t.id = shop_id;
        IF serieses IS NULL THEN
            PERFORM raise_error('shop_not_found');
        END IF;

        IF serieses ? format('%s', key) THEN
            serieses = serieses - format('%s', key);
            serieses = serieses || hstore(format('%s', key), name);
            UPDATE shops SET serieses = _.serieses, latest_update = now() WHERE id = shop_id;
        ELSE
            PERFORM raise_error('shop_series_not_found');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Shop_user table.
CREATE TABLE IF NOT EXISTS shop_user (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id                 UUID_NN REFERENCES shops(id),
    user_id                 UUID_NN REFERENCES users(id),
    member_authority        PERMISSION_NN DEFAULT 'none',
    order_authority         PERMISSION_NN DEFAULT 'read-only',
    product_authority       PERMISSION_NN DEFAULT 'read-only',
    UNIQUE(shop_id, user_id)
);



-- Chech shop user authority.
CREATE OR REPLACE FUNCTION check_shop_user_authority (
    shop_id UUID_NN,
    user_id UUID_NN,
    auth AUTHORITY_NN,
    perm PERMISSION_NN,
    OUT ok BOOLEAN
) AS $$
    DECLARE
        _perm PERMISSION;
    BEGIN
        EXECUTE 'SELECT t.' || auth || ' FROM shop_user AS t WHERE t.shop_id = $1 AND t.user_id = $2'
            INTO _perm
            USING shop_id, user_id;
        
        IF _perm = perm::PERMISSION THEN
            ok := true;
        ELSE
            ok := false;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Add a new shop_user by shop member.
CREATE OR REPLACE FUNCTION shop_user_create (
    user_id UUID_NN,
    shop_id UUID_NN,
    member_id UUID_NN
) RETURNS void AS $$
    BEGIN
        IF NOT check_shop_user_authority(shop_id, user_id, 'member_authority', 'all') THEN
            PERFORM raise_error('permission_denied');
        END IF;
        INSERT INTO shop_user (shop_id, user_id) VALUES (shop_id, member_id);
    END;
$$ LANGUAGE plpgsql;



-- Update authority of a shop user.
CREATE OR REPLACE FUNCTION shop_user_update_authority (
    user_id UUID_NN,
    shop_id UUID_NN,
    member_id UUID_NN,
    auth AUTHORITY_NN,
    perm PERMISSION_NN
) RETURNS void AS $$
    DECLARE
        updated UUID;
    BEGIN
        IF NOT check_shop_user_authority(shop_id, user_id, 'member_authority', 'all') THEN
            PERFORM raise_error('permission_denied');
        END IF;

        EXECUTE 'UPDATE shop_user SET ' || auth || ' = $1 WHERE shop_id = $2 AND user_id = $3 RETURNING id'
            INTO updated
            USING perm, shop_id, member_id;

        IF updated IS NULL THEN
            PERFORM raise_error('shop_user_update_authority_failed');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Shop order number sequence table.
CREATE TABLE IF NOT EXISTS shop_order_number_sequence (
    shop_id             UUID UNIQUE REFERENCES shops(id) NOT NULL,
    current_number      INTEGER DEFAULT 0
);



-- Get next order number of the shop.
CREATE OR REPLACE FUNCTION shop_next_order_number (
    shop_id UUID_NN,
    OUT next_number INTEGER
) AS $$
    BEGIN
        UPDATE shop_order_number_sequence AS t
        SET current_number = current_number + 1
        WHERE t.shop_id = shop_next_order_number.shop_id
        RETURNING current_number INTO next_number;
    END;
$$ LANGUAGE plpgsql;