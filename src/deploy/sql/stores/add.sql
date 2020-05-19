-- Stores table.
CREATE TABLE stores (
    id                              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                            TEXT_NZ,
    name_upper                      TEXT,
    shop_id                         UUID_NN REFERENCES shops(id),
    latest_update                   TS_NN DEFAULT NOW(),
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
    store_id        UUID_NN REFERENCES stores(id),
    user_id         UUID_NN REFERENCES users(id),
    team_authority  PERMISSION_NN DEFAULT 'none',
    UNIQUE(store_id, user_id)
);



-- Stores errors.
INSERT INTO errors (code, name, message) VALUES
    ('C7005', 'store_user_update_authority_failed', 'Failed to update store_user authority.');



-- Create store by user session and specific shop_name and store_name.
CREATE OR REPLACE FUNCTION create_store (
    user_id UUID_NN,
    shop_id UUID_NN,
    store_name TEXT_NZ
) RETURNS void AS $$
    DECLARE
        store_id UUID;
    BEGIN
        IF NOT check_shop_user_authority(shop_id, user_id, 'store_authority', 'all') THEN
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
    END;
$$ LANGUAGE plpgsql;



-- Check store user authority.
CREATE OR REPLACE FUNCTION check_store_user_authority (
    store_id UUID_NN,
    user_id UUID_NN,
    auth_name TEXT_NZ,
    auth_perm PERMISSION_NN,
    OUT ok BOOLEAN
) AS $$
    DECLARE
        auth PERMISSION;
    BEGIN
        EXECUTE 'SELECT t.' || auth_name || ' FROM store_user AS t WHERE t.store_id = $1 AND t.user_id = $2'
            INTO auth
            USING store_id, user_id;
        IF auth = auth_perm::PERMISSION THEN
            ok := true;
        ELSE
            ok := false;
        END IF;        
    END;
$$ LANGUAGE plpgsql;



-- Add store member.
CREATE OR REPLACE FUNCTION add_store_member (
    user_id UUID_NN,
    store_id UUID_NN,
    member_id UUID_NN
) RETURNS VOID AS $$
    BEGIN
        IF NOT check_store_user_authority(store_id, user_id, 'team_authority', 'all') THEN
            PERFORM raise_error('permission_denied');
        END IF;
        INSERT INTO store_user (store_id, user_id) VALUES (store_id, member_id);
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
            PERFORM raise_error('store_user_update_authority_failed');
        END IF;
    END;
$$ LANGUAGE plpgsql;