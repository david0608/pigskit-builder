-- Errors table.
CREATE TABLE errors (
    code            TEXT PRIMARY KEY CHECK (LENGTH(code) = 5 AND code LIKE 'C%'),
    name            TEXT UNIQUE,
    message         TEXT,
    CONSTRAINT errors_columns_notnull CHECK (
        name IS NOT NULL
        AND message IS NOT NULL
    )
);

-- Trigger function which automatically convert code column of errors table to uppercase.
CREATE OR REPLACE FUNCTION errors_code_auto_upper ()
RETURNS trigger
AS $$
    BEGIN
        NEW.code = upper(NEW.code);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER code_auto_upper
BEFORE INSERT ON errors FOR EACH ROW
EXECUTE PROCEDURE errors_code_auto_upper();



-- Default errors.
INSERT INTO errors (code, name, message) VALUES
    ('C0000', 'unknown', 'Unknown error occurred.'),
    ('C0001', 'permission_denied', 'Permission denied.'),
    ('C0002', 'not_found', 'Not found.'),
    ('C0003', 'text_not_null', 'value for domain text_nn violates check constraint "text_not_null"');



-- Raise an exception with corresponding code and message from error name.
CREATE OR REPLACE FUNCTION raise_error (
    name TEXT
) RETURNS VOID AS $$
    DECLARE
        code TEXT;
        message TEXT;
    BEGIN
        SELECT e.code, e.name, e.message INTO code, name, message FROM errors AS e WHERE e.name = raise_error.name;
        IF code IS NULL THEN
            SELECT e.code, e.name, e.message INTO code, name, message FROM errors AS e WHERE e.name = 'unknown';
        END IF;
        RAISE EXCEPTION USING ERRCODE = code, MESSAGE = message, CONSTRAINT = name;
    END;
$$ LANGUAGE plpgsql;