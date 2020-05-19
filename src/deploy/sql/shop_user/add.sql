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



-- Shop_User errors.
INSERT INTO errors (code, name, message) VALUES
    ('C6001', 'shop_user_update_authority_failed', 'Failed to update shop_user authority.');



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
        IF NOT check_shop_user_authority(shop_id, user_id, 'team_authority', 'all') THEN
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
        IF NOT check_shop_user_authority(shop_id, user_id, 'team_authority', 'all') THEN
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