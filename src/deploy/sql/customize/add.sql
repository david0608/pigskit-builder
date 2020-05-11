-- Option type.
CREATE TYPE OPTION AS (
    id                  UUID_NN,
    name                TEXT_NN,
    price               INT_NN
);

--Domain OPTION_NN
CREATE DOMAIN OPTION_NN AS OPTION
    CONSTRAINT option_not_null CHECK (
        VALUE IS NOT NULL
    );



-- New option.
CREATE OR REPLACE FUNCTION new_option (
    name TEXT_NN,
    price INT_NN
) RETURNS OPTION AS $$
    BEGIN
        RETURN (uuid_generate_v4(), name, price)::OPTION;
    END;
$$ LANGUAGE plpgsql;



-- Customize type.
CREATE TYPE CUSTOMIZE AS (
    id                  UUID_NN,
    name                TEXT_NN,
    options             HSTORE_NN,
    latest_update       TS_NN
);

-- Domain CUSTOMIZE_NN.
CREATE DOMAIN CUSTOMIZE_NN AS CUSTOMIZE
    CONSTRAINT customize_not_null CHECK (
        VALUE IS NOT NULL
    );



-- Customize errors.
INSERT INTO errors (code, name, message) VALUES
    ('C3001', 'customize_duplicated_option', 'Option already existed for the customize.'),
    ('C3002', 'customize_option_not_found', 'Option for the customize not found.'),
    ('C3003', 'customize_option_mismatch', 'Option for the customize mismatch.');



-- New customize.
CREATE OR REPLACE FUNCTION new_customize (
    name TEXT_NN
) RETURNS CUSTOMIZE AS $$
    BEGIN
        RETURN (uuid_generate_v4(), name, '', now())::CUSTOMIZE;
    END;
$$ LANGUAGE plpgsql;



-- Create a option for the customize.
CREATE OR REPLACE FUNCTION customize_create_option (
    INOUT customize CUSTOMIZE_NN,
    option OPTION_NN
) AS $$
    BEGIN
        IF (customize.options ? upper(option.name)) THEN
            PERFORM raise_error('customize_duplicated_option');
        END IF;
        customize.options = customize.options || hstore(upper(option.name), format('%s', option));
        customize.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Read option of the customize.
CREATE OR REPLACE FUNCTION customize_read_option (
    customize CUSTOMIZE_NN,
    option_name TEXT_NN,
    OUT option OPTION
) AS $$
    BEGIN
        option = (customize.options -> upper(option_name))::OPTION;
        IF option IS NULL THEN
            PERFORM raise_error('customize_option_not_found');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Update option of a customize.
CREATE OR REPLACE FUNCTION customize_update_option (
    INOUT customize CUSTOMIZE_NN,
    option OPTION_NN,
    new_name TEXT
) AS $$
    DECLARE
        old_option OPTION;
    BEGIN
        old_option = customize_read_option(customize, option.name);
        IF option.id != old_option.id THEN
            PERFORM raise_error('customize_option_mismatch');
        END IF;

        IF new_name IS NOT NULL AND new_name != '' THEN
            IF customize.options ? upper(new_name) THEN
                PERFORM raise_error('customize_duplicated_option');
            ELSE
                customize.options = customize.options - upper(option.name);
                option.name = new_name;
            END IF;
        ELSE
            customize.options = customize.options - upper(option.name);
        END IF;

        customize.options = customize.options || hstore(upper(option.name), format('%s', option));
        customize.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Drop option of a customize.
CREATE OR REPLACE FUNCTION customize_delete_option (
    INOUT customize CUSTOMIZE_NN,
    name TEXT_NN,
    id UUID_NN
) AS $$
    DECLARE
        option OPTION;
    BEGIN
        option = (customize.options -> upper(name))::OPTION;

        IF option IS NULL THEN
            PERFORM raise_error('customize_option_not_found');
        ELSIF option.id != id THEN
            PERFORM raise_error('customize_option_mismatch');
        ELSE
            customize.options = customize.options - upper(name);
            customize.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;