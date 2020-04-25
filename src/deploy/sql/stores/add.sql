-- Stores table.
CREATE TABLE stores (
    id                              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                            TEXT,
    name_upper                      TEXT,
    shop_id                         UUID REFERENCES shops(id) NOT NULL,
    latest_update                   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shop_id, name_upper),
    CONSTRAINT stores_name_notnull CHECK (
        name_upper IS NOT NULL AND LENGTH(name_upper) > 0
    )
);

-- Trigger function which automatically add column name_upper from column name;
CREATE OR REPLACE FUNCTION stores_name_auto_upper ()
RETURNS trigger
AS $$
    BEGIN
        NEW.name_upper = upper(NEW.name);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER name_auto_upper
BEFORE INSERT ON stores FOR EACH ROW
EXECUTE PROCEDURE stores_name_auto_upper();



-- Store_user table.
CREATE TABLE store_user (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id        UUID REFERENCES stores(id) NOT NULL,
    user_id         UUID REFERENCES users(id) NOT NULL,
    team_authority  PERMISSION NOT NULL DEFAULT 'none',
    UNIQUE(store_id, user_id)
);



-- Stores errors.
INSERT INTO errors (code, name, message) VALUES
    ('C6001', 'stores_shop_id_name_upper_key', 'Store name already been used.'),
    ('C6002', 'stores_name_notnull', 'Invalid store name.'),
    ('C6003', 'store_user_store_id_user_id_key', 'Pair of store_id and user_id already existed.'),
    ('C6004', 'store_user_user_id_fkey', 'user_id not existed.'),
    ('C6005', 'store_user_update_authority_failed', 'Failed to update store_user authority.');



-- Create store by user session and specific shop_name and store_name.
CREATE OR REPLACE FUNCTION create_store (
    user_id UUID,
    shop_id UUID,
    store_name TEXT
) RETURNS void AS $$
    DECLARE
        auth PERMISSION;
        store_id UUID;
    BEGIN
        SELECT t.store_authority INTO auth FROM shop_user AS t
            WHERE t.shop_id = create_store.shop_id AND t.user_id = create_store.user_id;

        IF auth IS NULL OR auth != 'all' THEN
            PERFORM raise_error('permission_denied');
        END IF;

        INSERT INTO stores (name, shop_id) VALUES (store_name, shop_id) RETURNING id INTO store_id;
        INSERT INTO store_user (
            store_id,
            user_id,
            team_authority
        ) VALUES (
            store_id,
            user_id,
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

CREATE OR REPLACE FUNCTION test_create_store (
    user_id UUID,
    shop_id UUID,
    store_name TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM create_store(user_id, shop_id, store_name);
        RAISE INFO 'Successfully created store.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        user_id UUID;
        shop_id UUID;
    BEGIN
        RAISE INFO 'Testing function create_store and error handling.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP';

        --Success.
        PERFORM test_create_store(user_id, shop_id, 'store1');
        -- Fail. Duplocated store name.
        PERFORM test_create_store(user_id, shop_id, 'store1');
        -- Fail. Invalid store name.
        PERFORM test_create_store(user_id, shop_id, '');
        -- Fail. Invalid store name.
        PERFORM test_create_store(user_id, shop_id, null);
        
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP2';
        -- Success.
        PERFORM test_create_store(user_id, shop_id, 'store1');

        SELECT id INTO shop_id FROM shops WHERE name_upper = 'ALICESHOP';
        -- Fail. Permission denied.
        PERFORM test_create_store(user_id, shop_id, 'store1');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Add store member.
CREATE OR REPLACE FUNCTION add_store_member (
    user_id UUID,
    store_id UUID,
    member_id UUID
) RETURNS VOID AS $$
    DECLARE
        auth PERMISSION;
    BEGIN
        SELECT t.team_authority INTO auth FROM store_user AS t
            WHERE t.store_id = add_store_member.store_id AND t.user_id = add_store_member.user_id;

        IF auth IS NULL OR auth != 'all' THEN
            PERFORM raise_error('permission_denied');
        END IF;

        INSERT INTO store_user (store_id, user_id) VALUES (store_id, member_id);
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            PERFORM raise_error(c_name);
        END;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_add_store_member (
    user_id UUID,
    store_id UUID,
    member_id UUID
) RETURNS VOID AS $$
    BEGIN
        PERFORM add_store_member(user_id, store_id, member_id);
        RAISE INFO 'Successfully added store member.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    <<_>>
    DECLARE
        user_id UUID;
        shop_id UUID;
        store_id UUID;
        member_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function add_store_member and error handling.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP';
        SELECT t.id INTO _.store_id FROM stores AS t WHERE t.shop_id = _.shop_id AND t.name_upper = 'STORE1';
        SELECT id INTO member_id FROM users WHERE username = 'alice0710';

        -- Fail. Invalid user_id.
        PERFORM test_add_store_member(invalid_id, store_id, member_id);
        -- Fail. Invalid store_id.
        PERFORM test_add_store_member(user_id, invalid_id, member_id);
        -- Fail. Invalid member_id.
        PERFORM test_add_store_member(user_id, store_id, invalid_id);
        -- Success.
        PERFORM test_add_store_member(user_id, store_id, member_id);
        -- Fail. Duplicated store_id user_id pair.
        PERFORM test_add_store_member(user_id, store_id, member_id);

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;



-- Set store member authority.
CREATE OR REPLACE FUNCTION set_store_member_authority (
    user_id UUID,
    store_id UUID,
    member_id UUID,
    auth_name TEXT,
    auth_perm PERMISSION
) RETURNS VOID AS $$
    DECLARE
        auth PERMISSION;
        updated UUID;
    BEGIN
        SELECT t.team_authority INTO auth FROM store_user AS t
            WHERE t.store_id = set_store_member_authority.store_id AND t.user_id = set_store_member_authority.user_id;

        IF
            auth IS NULL
            OR auth != 'all'
            OR (user_id = member_id AND auth_name = 'team_authority')
        THEN
            PERFORM raise_error('permission_denied');
        END IF;

        EXECUTE 'UPDATE store_user SET ' || auth_name || ' = $1 WHERE store_id = $2 AND user_id = $3 RETURNING id'
            INTO updated
            USING auth_perm, store_id, member_id;

        IF updated IS NULL THEN
            RAISE EXCEPTION USING CONSTRAINT = 'store_user_update_authority_failed';
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

CREATE OR REPLACE FUNCTION test_set_store_member_authority (
    user_id UUID,
    store_id UUID,
    member_id UUID,
    auth_name TEXT,
    auth_perm PERMISSION
) RETURNS VOID AS $$
    BEGIN
        PERFORM set_store_member_authority(user_id, store_id, member_id, auth_name, auth_perm);
        RAISE INFO 'Successfully set store member authority.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;

DO $$
    <<_>>
    DECLARE
        user_id UUID;
        shop_id UUID;
        store_id UUID;
        member_id UUID;
        invalid_id UUID := uuid_generate_v4();
    BEGIN
        RAISE INFO 'Testing function set_store_member_authority.';

        SELECT id INTO user_id FROM users WHERE username = 'david0608';
        SELECT id INTO shop_id FROM shops WHERE name_upper = 'DAVIDSHOP';
        SELECT t.id INTO store_id FROM stores AS t WHERE t.shop_id = _.shop_id AND t.name_upper = 'STORE1';
        SELECT id INTO member_id FROM users WHERE username = 'alice0710';

        -- Fail. Invalid user_id.
        PERFORM test_set_store_member_authority(invalid_id, store_id, member_id, 'team_authority', 'all');
        -- Fail. Invalid store_id.
        PERFORM test_set_store_member_authority(user_id, invalid_id, member_id, 'team_authority', 'all');
        -- Fail. Invalid member_id.
        PERFORM test_set_store_member_authority(user_id, store_id, invalid_id, 'team_authority', 'all');
        -- Success.
        PERFORM test_set_store_member_authority(user_id, store_id, member_id, 'team_authority', 'all');
        -- Fail. Set self team_authority.
        PERFORM test_set_store_member_authority(user_id, store_id, user_id, 'team_authority', 'all');
        -- Fail. Invalid column.
        PERFORM test_set_store_member_authority(user_id, store_id, member_id, 'invalid_column', 'all');

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;