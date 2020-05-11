-- Product type.
CREATE TYPE PRODUCT AS (
    id                  UUID_NN,
    name                TEXT_NN,
    price               INT_NN,
    customizes          HSTORE_NN,
    latest_update       TS_NN
);

-- Domain PRODUCT_NN.
CREATE DOMAIN PRODUCT_NN AS PRODUCT
    CONSTRAINT product_not_null CHECK (
        VALUE IS NOT NULL
    );



-- Product errors.
INSERT INTO errors (code, name, message) VALUES
    ('C4001', 'product_duplicated_customize', 'Customize already existed for the product.'),
    ('C4002', 'product_customize_not_found', 'Customize for the product not found.'),
    ('C4003', 'product_customize_mismatch', 'Customize for the product mismatch.');



-- New product.
CREATE OR REPLACE FUNCTION new_product (
    name TEXT_NN,
    price INT_NN
) RETURNS PRODUCT AS $$
    BEGIN
        RETURN (uuid_generate_v4(), name, price, '', now())::PRODUCT;
    END;
$$ LANGUAGE plpgsql;



-- Create customize for the product.
CREATE OR REPLACE FUNCTION product_create_customize (
    INOUT product PRODUCT_NN,
    customize CUSTOMIZE_NN
) AS $$
    BEGIN
        IF (product.customizes ? upper(customize.name)) THEN
            PERFORM raise_error('product_duplicated_customize');
        END IF;
        product.customizes = product.customizes || hstore(upper(customize.name), format('%s', customize));
        product.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Read customize of the product.
CREATE OR REPLACE FUNCTION product_read_customize (
    product PRODUCT_NN,
    customize_name TEXT_NN,
    OUT customize CUSTOMIZE
) AS $$
    BEGIN
        customize = (product.customizes -> upper(customize_name))::CUSTOMIZE;
        IF customize IS NULL THEN
            PERFORM raise_error('product_customize_not_found');
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Update customize of the product.
CREATE OR REPLACE FUNCTION product_update_customize (
    INOUT product PRODUCT_NN,
    customize CUSTOMIZE_NN,
    new_name TEXT
) AS $$
    DECLARE
        old_customize CUSTOMIZE;
    BEGIN
        old_customize = product_read_customize(product, customize.name);
        
        IF customize.id != old_customize.id THEN
            PERFORM raise_error('product_customize_mismatch');
        END IF;

        IF new_name IS NOT NULL AND new_name != '' THEN
            IF product.customizes ? upper(new_name) THEN
                PERFORM raise_error('product_duplicated_customize');
            ELSE
                product.customizes = product.customizes - upper(customize.name);
                customize.name = new_name;
            END IF;
        ELSE
            product.customizes = product.customizes - upper(customize.name);
        END IF;

        product.customizes = product.customizes || hstore(upper(customize.name), format('%s', customize));
        product.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Delete customize of a product.
CREATE OR REPLACE FUNCTION product_delete_customize (
    INOUT product PRODUCT_NN,
    name TEXT_NN,
    id UUID_NN
) AS $$
    DECLARE
        customize CUSTOMIZE;
    BEGIN
        customize = (product.customizes -> upper(name))::CUSTOMIZE;

        IF customize IS NULL THEN
            PERFORM raise_error('product_customize_not_found');
        ELSIF customize.id != id THEN
            PERFORM raise_error('product_customize_mismatch');
        ELSE
            product.customizes = product.customizes - upper(name);
            product.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;