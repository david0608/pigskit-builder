-- Product type.
CREATE TYPE PRODUCT AS (
    name                TEXT_NN,
    price               INT_NN,
    customizes          HSTORE_NN,
    latest_update       TIMESTAMPTZ
);



-- Product errors.
INSERT INTO errors (code, name, message) VALUES
    ('C4001', 'product_duplicated_customize', 'Customize already existed for the product.'),
    ('C4002', 'product_customize_not_found', 'Customize not found for the product.');



-- New product.
CREATE OR REPLACE FUNCTION new_product (
    name TEXT_NN,
    price INT_NN
) RETURNS PRODUCT AS $$
    BEGIN
        RETURN (name, price, '', now())::PRODUCT;
    END;
$$ LANGUAGE plpgsql;



-- Create customize for the product.
CREATE OR REPLACE FUNCTION product_create_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE
) AS $$
    BEGIN
        IF (product.customizes ? upper(customize.name)) THEN
            PERFORM raise_error('product_duplicated_customize');
        END IF;
        product.customizes = product.customizes || hstore(upper(customize.name), format('%s', customize));
        product.latest_update = now();
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_product_create_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE
) AS $$
    BEGIN
        product = product_create_customize(product, customize);
        RAISE INFO 'Successfully created customize.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;



-- Read customize of the product.
CREATE OR REPLACE FUNCTION product_read_customize (
    product PRODUCT,
    customize_name TEXT_NN
) RETURNS CUSTOMIZE AS $$
    BEGIN
        RETURN (product.customizes -> upper(customize_name))::CUSTOMIZE;
    END;
$$ LANGUAGE plpgsql;


-- Update customize of the product.
CREATE OR REPLACE FUNCTION product_update_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE,
    new_name TEXT
) AS $$
    BEGIN
        IF new_name IS NOT NULL AND new_name != '' AND (product.customizes ? upper(new_name)) THEN
            PERFORM raise_error('product_duplicated_customize');
        END IF;

        product.customizes = product.customizes - upper(customize.name);

        IF new_name IS NOT NULL AND new_name != '' THEN
            customize.name = new_name;
        END IF;

        product.customizes = product.customizes || hstore(upper(customize.name), format('%s', customize));
        product.latest_update = now();
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_product_update_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE,
    new_name TEXT
) AS $$
    BEGIN
        product = product_update_customize(product, customize, new_name);
        RAISE INFO 'Successfully updated customize.';
    EXCEPTION WHEN OTHERS THEN
        RAISE INFO 'error_code:%, message:%', SQLSTATE, SQLERRM;
    END;
$$ LANGUAGE plpgsql;



-- Delete customize of a product.
CREATE OR REPLACE FUNCTION product_delete_customize (
    INOUT product PRODUCT,
    name TEXT
) AS $$
    BEGIN
        product.customizes = product.customizes - upper(name);
        product.latest_update = now();
    END;
$$ LANGUAGE plpgsql;



-- Test product functions and error handling.
DO $$
    DECLARE
        product PRODUCT;
    BEGIN
        RAISE INFO 'Testing product functions and error handling.';

        product = new_product('product_1', 100);

        -- Successfully insert.
        product = test_product_create_customize(
            product,
            new_customize('customize_1')
        );

        -- Fail. Duplicated customize name.
        product = test_product_create_customize(
            product,
            new_customize('customize_1')
        );

        -- Successfully updated.
        product = test_product_update_customize (
            product,
            new_customize('customize_1'),
            'customize_2'
        );

        -- Successfully deleted.
        product = product_delete_customize(
            product,
            'customize_1'
        );

        -- Fail. Duplicated customize.
        product = test_product_update_customize(
            product,
            new_customize('customize_1'),
            'customize_2'
        );

        RAISE INFO 'Done!';
    END;
$$ LANGUAGE plpgsql;