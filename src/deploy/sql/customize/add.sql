-- Option type.
CREATE TYPE OPTION AS (
    name                TEXT_NN,
    price               INT_NN
);



-- New option.
CREATE OR REPLACE FUNCTION new_option (
    name TEXT_NN,
    price INT_NN
) RETURNS OPTION AS $$
    BEGIN
        RETURN (name, price)::OPTION;
    END;
$$ LANGUAGE plpgsql;



-- Customize type.
CREATE TYPE CUSTOMIZE AS (
    name                TEXT_NN,
    options             HSTORE_NN,
    latest_update       TS_NN
);



-- Customize errors.
INSERT INTO errors (code, name, message) VALUES
    ('C3001', 'customize_duplicated_option', 'Option already existed for the customize.'),
    ('C3002', 'customize_option_not_found', 'Option not found for the customize.');



-- New customize.
CREATE OR REPLACE FUNCTION new_customize (
    name TEXT_NN
) RETURNS CUSTOMIZE AS $$
    BEGIN
        RETURN (name, '', now())::CUSTOMIZE;
    END;
$$ LANGUAGE plpgsql;



-- Create a option for the customize.
CREATE OR REPLACE FUNCTION customize_create_option (
    INOUT customize CUSTOMIZE,
    option OPTION
) AS $$
    BEGIN
        IF (customize.options ? upper(option.name)) THEN
            PERFORM raise_error('customize_duplicated_option');
        END IF;
        customize.options = customize.options || hstore(upper(option.name), format('%s', option));
        customize.latest_update = now();
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_customize_create_option (
    INOUT customize CUSTOMIZE,
    option OPTION
) AS $$
    BEGIN
        customize = customize_create_option(customize, option);
        RAISE INFO 'Successfully inserted option.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;



-- Read option of the customize.
CREATE OR REPLACE FUNCTION customize_read_option (
    customize CUSTOMIZE,
    option_name TEXT_NN
) RETURNS OPTION AS $$
    BEGIN
        RETURN (customize.options -> upper(option_name))::OPTION;
    END;
$$ LANGUAGE plpgsql;



-- Update option of a customize.
CREATE OR REPLACE FUNCTION customize_update_option (
    INOUT customize CUSTOMIZE,
    option OPTION,
    new_name TEXT
) AS $$
    BEGIN
        IF new_name IS NOT NULL AND new_name != '' AND (customize.options ? upper(new_name)) THEN
            PERFORM raise_error('customize_duplicated_option');
        END IF;

        customize.options = customize.options - upper(option.name);

        IF new_name IS NOT NULL AND new_name != '' THEN
            option.name = new_name;
        END IF;

        customize.options = customize.options || hstore(upper(option.name), format('%s', option));
        customize.latest_update = now();
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_customize_update_option (
    INOUT customize CUSTOMIZE,
    option OPTION,
    new_name TEXT
) AS $$
    BEGIN
        customize = customize_update_option(customize, option, new_name);
        RAISE INFO 'Succeddfully updated option.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;



-- Drop option of a customize.
CREATE OR REPLACE FUNCTION customize_delete_option (
    INOUT customize CUSTOMIZE,
    name TEXT
) AS $$
    BEGIN
        customize.options = customize.options - upper(name);
        customize.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Test customize functions and error handling.
DO $$
    DECLARE
        cus CUSTOMIZE;
    BEGIN
        RAISE INFO 'Testing customize functions and error handling.';

        cus = new_customize('customize_1');
        
        -- Successfully insert.
        cus = test_customize_create_option(
            cus,
            new_option('option_1', '100')
        );

        -- Fail. Duplicated option name.
        cus = test_customize_create_option(
            cus,
            new_option('OPTION_1', '200')
        );
        
        -- Successfully update.
        cus = test_customize_update_option(
            cus,
            new_option('option_1', '200'),
            'option_2'
        );

        -- Successfully delete.
        cus = customize_delete_option(
            cus,
            'option_1'
        );

        -- Fail. Duplicated option.
        cus = test_customize_update_option(
            cus,
            new_option('option_1', '300'),
            'option_2'
        );

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;