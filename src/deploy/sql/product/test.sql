-- Testing function new_product and error handling.
CREATE OR REPLACE FUNCTION test_new_product (
    name TEXT,
    price INTEGER,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM new_product(name, price);

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    BEGIN
        RAISE INFO 'Testing function new_product and error handling...';

        PERFORM test_new_product('prod1', 100, '');
        PERFORM test_new_product('', 100, 'text_not_null');
        PERFORM test_new_product(null, 100, 'text_not_null');
        PERFORM test_new_product('prod1', null, 'integer_not_null');

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_new_product;



-- Testing function product_create_customize and error handling.
CREATE OR REPLACE FUNCTION test_product_create_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE,
    error TEXT
) AS $$
    BEGIN
        product = product_create_customize(product, customize);

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        product PRODUCT;
    BEGIN
        RAISE INFO 'Testing function product_create_customize and error handling...';

        product = new_product('prod1', 100);

        product = test_product_create_customize(product, new_customize('c1'), '');
        PERFORM test_product_create_customize(product, new_customize('c1'), 'product_duplicated_customize');
        PERFORM test_product_create_customize(null, new_customize('c2'), 'product_not_null');
        PERFORM test_product_create_customize(product, null, 'customize_not_null');
        product = test_product_create_customize(product, new_customize('c2'), '');

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_product_create_customize;



-- Testing function product_read_customize and error handling.
CREATE OR REPLACE FUNCTION test_product_read_customize (
    product PRODUCT,
    name TEXT,
    customize CUSTOMIZE_NN,
    error TEXT
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        customize CUSTOMIZE;
    BEGIN
        _.customize = product_read_customize(product, name);

        IF _.customize != test_product_read_customize.customize THEN
            PERFORM raise_error('test_failed');
        END IF;

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        prod PRODUCT;
        cus CUSTOMIZE;
    BEGIN
        RAISE INFO 'Testing function product_read_customize and error handling...';

        prod = new_product('p1', 100);
        cus = new_customize('c1');
        prod = product_create_customize(prod, cus);

        PERFORM test_product_read_customize(prod, 'c1', cus, '');
        PERFORM test_product_read_customize(prod, 'c1', new_customize('c1'), 'test_failed');
        PERFORM test_product_read_customize(prod, 'c2', cus, 'product_customize_not_found');
        PERFORM test_product_read_customize(null, 'c1', cus, 'product_not_null');
        PERFORM test_product_read_customize(prod, '', cus, 'text_not_null');
        PERFORM test_product_read_customize(prod, null, cus, 'text_not_null');

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_product_read_customize;



-- Testing function product_update_customize and error handling.
CREATE OR REPLACE FUNCTION test_product_update_customize (
    INOUT product PRODUCT,
    customize CUSTOMIZE,
    new_name TEXT,
    error TEXT
) AS $$
    BEGIN
        product = product_update_customize(product, customize, new_name);

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        prod PRODUCT;
        cus CUSTOMIZE;
        opt OPTION;
    BEGIN
        RAISE INFO 'Testing function product_update_customize and error handling...';

        prod = new_product('p1', 100);
        cus = new_customize('c1');
        opt = new_option('o1', 100);
        cus = customize_create_option(cus, opt);
        prod = product_create_customize(prod, cus);

        opt.price = 200;
        cus = customize_update_option(cus, opt, '');
        prod = test_product_update_customize(prod, cus, '', '');
        prod = test_product_update_customize(prod, cus, 'c2', '');
        PERFORM test_product_update_customize(prod, cus, 'c3', 'product_customize_not_found');
        PERFORM test_product_update_customize(prod, new_customize('c2'), 'c3', 'product_customize_mismatch');
        prod = product_create_customize(prod, new_customize('c3'));
        cus.name = 'c2';
        PERFORM test_product_update_customize(prod, cus, 'c3', 'product_duplicated_customize');
        PERFORM test_product_update_customize(null, cus, 'c4', 'product_not_null');
        PERFORM test_product_update_customize(prod, null, 'c4', 'customize_not_null');
        prod = test_product_update_customize(prod, cus, 'c4', '');

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_product_update_customize;



-- Testing function product_delete_customize and error handling.
CREATE OR REPLACE FUNCTION test_product_delete_customize (
    INOUT product PRODUCT,
    name TEXT,
    id UUID,
    error TEXT
) AS $$
    BEGIN
        product = product_delete_customize(product, name, id);

        IF error IS NOT NULL AND error != '' THEN
            PERFORM raise_error('test_failed');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            IF error IS NULL OR error = '' OR c_name != error THEN
                RAISE EXCEPTION USING ERRCODE = SQLSTATE, MESSAGE = SQLERRM, CONSTRAINT = c_name;
            END IF;
        END;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        prod PRODUCT;
        cus1 CUSTOMIZE;
        cus2 CUSTOMIZE;
    BEGIN
        RAISE INFO 'Testing function product_delete_customize and error handling...';
        
        prod = new_product('p1', 100);
        cus1 = new_customize('c1');
        cus2 = new_customize('c2');
        prod = product_create_customize(prod, cus1);
        prod = product_create_customize(prod, cus2);

        PERFORM test_product_delete_customize(prod, cus1.name, cus2.id, 'product_customize_mismatch');
        prod = test_product_delete_customize(prod, cus1.name, cus1.id, '');
        PERFORM test_product_delete_customize(prod, cus1.name, cus1.id, 'product_customize_not_found');
        PERFORM test_product_delete_customize(null, cus2.name, cus2.id, 'product_not_null');
        PERFORM test_product_delete_customize(prod, null, cus2.id, 'text_not_null');
        PERFORM test_product_delete_customize(prod, cus2.name, null, 'uuid_not_null');
        prod = test_product_delete_customize(prod, cus2.name, cus2.id, '');

        RAISE INFO 'Done!';
    EXCEPTION WHEN OTHERS THEN
        DECLARE
            c_name TEXT;
        BEGIN
            GET STACKED DIAGNOSTICS c_name = CONSTRAINT_NAME;
            RAISE INFO 'Error code:%, name:%, msg:%', SQLSTATE, c_name, SQLERRM;
        END;
    END;
$$ LANGUAGE plpgsql;

DROP FUNCTION test_product_delete_customize;