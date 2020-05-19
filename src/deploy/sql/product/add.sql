-- Product type.
CREATE TYPE PRODUCT AS (
    name                TEXT_NZ,
    description         TEXT,
    price               INT_NN,
    series_id           UUID,
    customizes          HSTORE_NN,
    latest_update       TS_NN
);

-- Domain PRODUCT_NN.
CREATE DOMAIN PRODUCT_NN AS PRODUCT NOT NULL;



-- Query all customizes of the product.
CREATE OR REPLACE FUNCTION query_product_customizes (
    prod PRODUCT_NN
) RETURNS TABLE (
    key UUID_NN,
    customize CUSTOMIZE
) AS $$
    BEGIN
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::CUSTOMIZE FROM each(prod.customizes);
    END;
$$ LANGUAGE plpgsql;



-- Create a customize for the product.
CREATE OR REPLACE FUNCTION product_create_customize (
    INOUT prod PRODUCT_NN,
    payload JSONB
) AS $$
    DECLARE
        cus CUSTOMIZE;
        key UUID := uuid_generate_v4();
    BEGIN
        cus = customize_create(
            payload ->> 'name',
            payload ->> 'description',
            payload -> 'options'
        );
        prod.customizes = prod.customizes || hstore(format('%s', key), format('%s', cus));
    END;
$$ LANGUAGE plpgsql;



-- Read a customize of the product.
CREATE OR REPLACE FUNCTION product_read_customize (
    prod PRODUCT_NN,
    key UUID_NN,
    OUT cus CUSTOMIZE
) AS $$
    BEGIN
        cus = (prod.customizes -> format('%s', key))::CUSTOMIZE;
    END;
$$ LANGUAGE plpgsql;



-- Delete a customize of the product.
CREATE OR REPLACE FUNCTION product_delete_customize (
    INOUT prod PRODUCT_NN,
    key UUID_NN
) AS $$
    BEGIN
        prod.customizes = prod.customizes - format('%s', key);
    END;
$$ LANGUAGE plpgsql;



-- Update a customize of the product.
CREATE OR REPLACE FUNCTION product_update_customize (
    INOUT prod PRODUCT_NN,
    key UUID_NN,
    payload JSONB
) AS $$
    DECLARE
        cus CUSTOMIZE;
    BEGIN
        cus = product_read_customize(prod, key);
        IF cus IS NOT NULL THEN
            cus = customize_update(cus, payload);
            prod = product_delete_customize(prod, key);
            prod.customizes = prod.customizes || hstore(format('%s', key), format('%s', cus));
            prod.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Create a new product.
CREATE OR REPLACE FUNCTION product_create (
    name TEXT_NZ,
    description TEXT,
    price INT_NN,
    series_id UUID,
    customizes JSONB
) RETURNS PRODUCT AS $$
    DECLARE
        prod PRODUCT;
        customize JSONB;
    BEGIN
        prod = (name, description, price, series_id, '', now())::PRODUCT;
        
        FOR customize IN SELECT jsonb_array_elements(customizes) LOOP
            prod = product_create_customize(prod, customize);
        END LOOP;

        RETURN prod;
    END;
$$ LANGUAGE plpgsql;



-- Update current product.
CREATE OR REPLACE FUNCTION product_update (
    INOUT prod PRODUCT_NN,
    payload JSONB
) AS $$
    DECLARE
        cus_key UUID;
        cus_payload JSONB;
    BEGIN
        IF payload ? 'name' THEN
            prod.name = payload ->> 'name';
        END IF;

        IF payload ? 'description' THEN
            prod.description = payload ->> 'description';
        END IF;
        
        IF payload ? 'price' THEN
            prod.price = payload ->> 'price';
        END IF;

        IF payload ? 'series_id' THEN
            prod.series_id = payload ->> 'series_id';
        END IF;

        FOR cus_key IN SELECT jsonb_array_elements_text(payload -> 'delete') LOOP
            prod = product_delete_customize(prod, cus_key);
        END LOOP;

        FOR cus_payload IN SELECT jsonb_array_elements(payload -> 'create') LOOP
            prod = product_create_customize(prod, cus_payload);
        END LOOP;

        FOR cus_key, cus_payload IN SELECT key, value FROM jsonb_each(payload -> 'update') LOOP
            prod = product_update_customize(prod, cus_key, cus_payload);
        END LOOP;
    END;
$$ LANGUAGE plpgsql;