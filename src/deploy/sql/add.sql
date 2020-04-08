

CREATE TYPE PERMISSION AS ENUM (
    'none',
    'read-only',
    'all'
);





CREATE TABLE users(
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username    TEXT UNIQUE NOT NULL,
    password    TEXT NOT NULL,
    name        TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL,
    phone       TEXT UNIQUE NOT NULL
);

-- register_user(username, password, name, email, phone)
CREATE OR REPLACE FUNCTION register_user(TEXT, TEXT, TEXT, TEXT, TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
    DECLARE
        errors INTEGER := 0;
        username_reged CONSTANT INTEGER := 1;
        email_reged CONSTANT INTEGER := 2;
        phone_reged CONSTANT INTEGER := 4;
    BEGIN
        IF EXISTS(SELECT 1 FROM users WHERE username = $1) THEN
            errors = errors | username_reged;
        END IF;

        IF EXISTS(SELECT 1 FROM users WHERE email = $4) THEN
            errors = errors | email_reged;
        END IF;

        IF EXISTS(SELECT 1 FROM users WHERE phone = $5) THEN
            errors = errors | phone_reged;
        END IF;

        IF errors = 0 THEN
            INSERT INTO users(username, password, name, email, phone) VALUES ($1, $2, $3, $4, $5);
        ELSE
            RAISE EXCEPTION 'Failed to register user, error_code: %', errors;
        END IF;

        RETURN errors;
    END;
$$;

SELECT register_user('david0608', '123132', 'David', 'david0608@gmail.com', '0912047175');
SELECT register_user('alice0710', '123123', 'Alice', 'alice0710@gmail.com', '0912345678');



CREATE TABLE sessions(
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID REFERENCES users(id) NOT NULL
);

-- signin_user(username, password)
CREATE OR REPLACE FUNCTION signin_user(TEXT, TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
    BEGIN
        WITH user_d AS (
            SELECT (id, password) FROM users WHERE username = $1
        )
        IF $2 = user_d.password THEN
            RETURN INSERT INTO sessions(user_id) VALUES (user_d.id) RETURNING id;
        ELSE
            RAISE EXCEPTION 'Invalid username or password.';
        END IF;
    END;
$$;








CREATE TABLE shops(
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                TEXT UNIQUE NOT NULL,
    latest_update       TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO shops(name) VALUES
    ('GoodShop'),
    ('MyShop');





CREATE TABLE shop_user(
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shop_id             UUID REFERENCES shops(id) NOT NULL,
    user_id             UUID REFERENCES users(id) NOT NULL,
    team_authority      PERMISSION NOT NULL,
    product_authority   PERMISSION NOT NULL,
    UNIQUE(shop_id, user_id)
);

CREATE OR REPLACE PROCEDURE insert_shop_user(
    user_name TEXT,
    shop_name TEXT,
    p1 PERMISSION,
    p2 PERMISSION
)
AS $$
    DECLARE
        user_id UUID;
        shop_id UUID;
    BEGIN
        SELECT id INTO user_id FROM users WHERE users.name = user_name;
        SELECT id INTO shop_id FROM shops WHERE shops.name = shop_name;
        INSERT INTO shop_user(shop_id, user_id, team_authority, product_authority)
        VALUES (shop_id, user_id, p1, p2);
    END;
$$ LANGUAGE plpgsql;

CALL insert_shop_user('David', 'GoodShop', 'all', 'all');
CALL insert_shop_user('Alice', 'MyShop', 'none', 'read-only');








CREATE TABLE stores(
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                TEXT UNIQUE NOT NULL,
    shop_id             UUID REFERENCES shops(id) NOT NULL
);

CREATE OR REPLACE PROCEDURE insert_stores(
    name TEXT,
    shop_name TEXT
)
AS $$
    DECLARE
        shop_id UUID;
    BEGIN
        SELECT id INTO shop_id FROM shops WHERE shops.name = shop_name;
        INSERT INTO stores(name, shop_id)
        VALUES (name, shop_id);
    END;
$$ LANGUAGE plpgsql;

CALL insert_stores('GoodStore1', 'GoodShop');
CALL insert_stores('GoodStore2', 'GoodShop');
CALL insert_stores('MyStore1', 'MyShop');





CREATE TABLE series(
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                TEXT NOT NULL,
    shop_id             UUID REFERENCES shops(id) NOT NULL,
    latest_update       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(name, shop_id)
);

CREATE OR REPLACE PROCEDURE insert_series(
    name TEXT,
    shop_name TEXT
)
AS $$
    DECLARE
        shop_id UUID;
    BEGIN
        SELECT id INTO shop_id FROM shops WHERE shops.name = shop_name;
        INSERT INTO series(name, shop_id)
        VALUES (name, shop_id);
    END;
$$ LANGUAGE plpgsql;

CALL insert_series('GoodSeries1', 'GoodShop');
CALL insert_series('GoodSeries2', 'GoodShop');
CALL insert_series('MySeries1', 'MyShop');




-- CREATE TABLE account (
--     id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     -- id          SERIAL PRIMARY KEY,
--     username    TEXT UNIQUE NOT NULL,
--     password    TEXT NOT NULL,
--     nick_name   TEXT NOT NULL
-- );

-- INSERT INTO account (username, password, nick_name) VALUES
--     ('david0608', '123123', 'David'),
--     ('alice0710', '123123', 'Alice');

-- CREATE TABLE session (
--     id          UUID PRIMARY KEY DEFAULT uuid_generate_v1(),
--     account_id  UUID REFERENCES account (id) NOT NULL
-- );

-- CREATE TABLE groups (
--     id         SERIAL PRIMARY KEY,
--     messages    message[]
-- );

-- INSERT INTO groups (messages) VALUES
--     ('{}'),
--     ('{}');

-- CREATE TABLE group_user (
--     id         SERIAL PRIMARY KEY,
--     group_id    SERIAL NOT NULL,
--     user_id     UUID REFERENCES users (id) NOT NULL,
-- UNIQUE (group_id, user_id)
-- );

-- CREATE TABLE invites (
--     id         SERIAL PRIMARY KEY,
--     master_id   UUID REFERENCES users (id) NOT NULL,
--     guest_id    UUID REFERENCES users (id) NOT NULL,
--     group_id    SERIAL REFERENCES groups (id) NOT NULL,
-- UNIQUE (master_id, guest_id, group_id)
-- );