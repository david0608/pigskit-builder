-- Option type.
CREATE TYPE OPTION AS (
    name                TEXT_NZ,
    price               INT_NN
);

--Domain OPTION_NN
CREATE DOMAIN OPTION_NN AS OPTION NOT NULL;

-- Customize type.
CREATE TYPE CUSTOMIZE AS (
    name                TEXT_NZ,
    description         TEXT,
    options             HSTORE_NN,
    latest_update       TS_NN
);

-- Domain CUSTOMIZE_NN.
CREATE DOMAIN CUSTOMIZE_NN AS CUSTOMIZE NOT NULL;



-- Create a new option.
CREATE OR REPLACE FUNCTION option_create (
    name TEXT_NZ,
    price INT_NN
) RETURNS OPTION AS $$
    BEGIN
        RETURN (name, price)::OPTION;
    END;
$$ LANGUAGE plpgsql;



-- Update current option.
CREATE OR REPLACE FUNCTION option_update (
    INOUT opt OPTION_NN,
    payload JSONB
) AS $$
    BEGIN
        IF payload IS NOT NULL THEN
            IF payload ? 'name' THEN
                opt.name = payload ->> 'name';
            END IF;
            IF payload ? 'price' THEN
                opt.price = payload ->> 'price';
            END IF;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Query all options of the customize.
CREATE OR REPLACE FUNCTION query_customize_options (
    cus CUSTOMIZE_NN
) RETURNS TABLE (
    key UUID_NN,
    option OPTION
) AS $$
    BEGIN
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::OPTION FROM each(cus.options);
    END;
$$ LANGUAGE plpgsql;



-- Function that create a option for the customize.
CREATE OR REPLACE FUNCTION customize_create_option (
    INOUT cus CUSTOMIZE_NN,
    payload JSONB
) AS $$
    DECLARE
        opt OPTION;
        _k UUID := uuid_generate_v4();
    BEGIN
        opt = option_create(
            payload ->> 'name',
            (payload ->> 'price')::INT_NN
        );
        cus.options = cus.options || hstore(format('%s', _k), format('%s', opt));
    END;
$$ LANGUAGE plpgsql;



-- Read an option of the customize.
CREATE OR REPLACE FUNCTION customize_read_option (
    cus CUSTOMIZE_NN,
    opt_key UUID_NN,
    OUT opt OPTION
) AS $$
    BEGIN
        opt = (cus.options -> format('%s', opt_key))::OPTION;
    END;
$$ LANGUAGE plpgsql;



-- Drop an option of the customize.
CREATE OR REPLACE FUNCTION customize_delete_option (
    INOUT cus CUSTOMIZE_NN,
    opt_key UUID_NN
) AS $$
    BEGIN
        cus.options = cus.options - format('%s', opt_key);
    END;
$$ LANGUAGE plpgsql;



-- Update an option of the customize.
CREATE OR REPLACE FUNCTION customize_update_option (
    INOUT cus CUSTOMIZE_NN,
    opt_key UUID_NN,
    payload jsonb
) AS $$
    DECLARE
        opt OPTION;
    BEGIN
        opt = customize_read_option(cus, opt_key);
        IF opt IS NOT NULL THEN
            opt = option_update(opt, payload);
            cus = customize_delete_option(cus, opt_key);
            cus.options = cus.options || hstore(format('%s', opt_key), format('%s', opt));
            cus.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Create a new customize.
CREATE OR REPLACE FUNCTION customize_create (
    name TEXT_NZ,
    description TEXT,
    options JSONB
) RETURNS CUSTOMIZE AS $$
    DECLARE
        cus CUSTOMIZE;
        option JSONB;
    BEGIN
        cus = (name, description, '', now())::CUSTOMIZE;

        FOR option IN SELECT jsonb_array_elements(options) LOOP
            cus = customize_create_option(cus, option);
        END LOOP;

        RETURN cus;
    END;
$$ LANGUAGE plpgsql;



-- Update current customize.
CREATE OR REPLACE FUNCTION customize_update (
    INOUT cus CUSTOMIZE_NN,
    payload JSONB
) AS $$
    DECLARE
        opt_key UUID;
        opt_payload JSONB;
    BEGIN
        IF payload ? 'name' THEN
            cus.name = payload ->> 'name';
        END IF;

        IF payload ? 'description' THEN
            cus.description = payload ->> 'description';
        END IF;

        FOR opt_key IN SELECT jsonb_array_elements_text(payload -> 'delete') LOOP
            cus = customize_delete_option(cus, opt_key);
        END LOOP;

        FOR opt_payload IN SELECT jsonb_array_elements(payload -> 'create') LOOP
            cus = customize_create_option(cus, opt_payload);
        END LOOP;

        FOR opt_key, opt_payload IN SELECT key, value FROM jsonb_each(payload -> 'update') LOOP
            cus = customize_update_option(cus, opt_key, opt_payload);
        END LOOP;
    END;
$$ LANGUAGE plpgsql;