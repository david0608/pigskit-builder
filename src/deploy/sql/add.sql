CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- CREATE DOMAIN UUID_NN AS UUID NOT NULL;
-- CREATE DOMAIN TEXT_NN AS TEXT NOT NULL;

-- CREATE TYPE message AS (
--     user_id     UUID_NN,
--     content     TEXT_NN
-- );

CREATE TABLE account (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- id          SERIAL PRIMARY KEY,
    username    TEXT UNIQUE NOT NULL,
    password    TEXT NOT NULL,
    nick_name   TEXT NOT NULL
);

INSERT INTO account (username, password, nick_name) VALUES
    ('david0608', '123123', 'David'),
    ('alice0710', '123123', 'Alice');

CREATE TABLE session (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v1(),
    account_id  UUID REFERENCES account (id) NOT NULL
);

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