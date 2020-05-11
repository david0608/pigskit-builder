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