-- Domain TEXT_NN.
CREATE DOMAIN TEXT_NN AS TEXT
    CONSTRAINT text_not_null CHECK (
        LENGTH(VALUE) > 0
    );

-- Domain TEXT_NZ.
CREATE DOMAIN TEXT_NZ AS TEXT
    CONSTRAINT text_not_zero CHECK (
        VALUE IS NOT NULL AND LENGTH(VALUE) > 0
    );

-- Domain INT_NN.
CREATE DOMAIN INT_NN AS INTEGER
    CONSTRAINT integer_not_null CHECK (
        VALUE IS NOT NULL
    );

-- Domain TS_NN
CREATE DOMAIN TS_NN AS TIMESTAMPTZ
    CONSTRAINT timestamptz_not_null CHECK (
        VALUE IS NOT NULL
    );

-- Domain HSTORE_NN.
CREATE DOMAIN HSTORE_NN AS hstore
    CONSTRAINT hstore_not_null CHECK (
        VALUE IS NOT NULL
    );

-- Domain UUID_NN.
CREATE DOMAIN UUID_NN AS UUID
    CONSTRAINT uuid_not_null CHECK (
        VALUE IS NOT NULL
    );

-- Authority enum type.
CREATE TYPE AUTHORITY AS ENUM (
    'member_authority',
    'order_authority',
    'product_authority'
);

-- Domain AUTHORITY_NN.
CREATE DOMAIN AUTHORITY_NN AS AUTHORITY
    CONSTRAINT authority_not_null CHECK (
        VALUE IS NOT NULL
    );

-- Permission enum type.
CREATE TYPE PERMISSION AS ENUM (
    'none',
    'read-only',
    'all'
);

-- Domain PERMISSION_NN.
CREATE DOMAIN PERMISSION_NN AS PERMISSION
    CONSTRAINT permission_not_null CHECK (
        VALUE IS NOT NULL
    );