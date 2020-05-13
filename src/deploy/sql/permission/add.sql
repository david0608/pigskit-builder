-- Authority enum type.
CREATE TYPE AUTHORITY AS ENUM (
    'team_authority',
    'store_authority',
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