-- Testing function new_option and error handling.
CREATE OR REPLACE FUNCTION test_new_option (
    name TEXT,
    price INT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM new_option(name, price);

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
        RAISE INFO 'Testing function new_option and error handling...';

        PERFORM test_new_option('opt1', 123, '');
        PERFORM test_new_option('', 123, 'text_not_null');
        PERFORM test_new_option(null, 123, 'text_not_null');
        PERFORM test_new_option('opt1', null, 'integer_not_null');

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

DROP FUNCTION test_new_option;



-- Testing function new_customize and error handling.
CREATE OR REPLACE FUNCTION test_new_customize (
    name TEXT,
    error TEXT
) RETURNS VOID AS $$
    BEGIN
        PERFORM new_customize(name);

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
        RAISE INFO 'Testing function new_customize and error handling...';

        PERFORM test_new_customize('c1', '');
        PERFORM test_new_customize('', 'text_not_null');
        PERFORM test_new_customize(null, 'text_not_null');

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

DROP FUNCTION test_new_customize;



-- Test function customize_create_option and error handling.
CREATE OR REPLACE FUNCTION test_customize_create_option (
    INOUT customize CUSTOMIZE,
    option OPTION,
    error TEXT
) AS $$
    BEGIN
        customize = customize_create_option(customize, option);

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
        cus CUSTOMIZE;
    BEGIN
        RAISE INFO 'Testing function customize_create_option and error handling...';

        cus = new_customize('c1');

        cus = test_customize_create_option(cus, new_option('opt1', 100), '');
        PERFORM test_customize_create_option(cus, new_option('opt1', 100), 'customize_duplicated_option');
        PERFORM test_customize_create_option(null, new_option('opt2' ,100), 'customize_not_null');
        PERFORM test_customize_create_option(cus, null, 'option_not_null');
        cus = test_customize_create_option(cus, new_option('opt2', 100), '');

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

DROP FUNCTION test_customize_create_option;



-- Test function customize_read_option and error handling.
CREATE OR REPLACE FUNCTION test_customize_read_option (
    customize CUSTOMIZE,
    option_name TEXT,
    option OPTION_NN,
    error TEXT
) RETURNS VOID AS $$
    <<_>>
    DECLARE
        option OPTION;
    BEGIN
        _.option = customize_read_option(customize, option_name);

        IF _.option != test_customize_read_option.option THEN
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
        cus CUSTOMIZE;
        opt OPTION;
    BEGIN
        RAISE INFO 'Testing function customize_read_option and error handling...';

        cus = new_customize('c1');
        opt = new_option('opt1', 100);
        cus = customize_create_option(cus, opt);
        
        PERFORM test_customize_read_option(cus, 'opt1', opt, '');
        PERFORM test_customize_read_option(cus, 'opt1', new_option('opt2', 100), 'test_failed');
        PERFORM test_customize_read_option(cus, 'opt2', opt, 'customize_option_not_found');
        PERFORM test_customize_read_option(null, 'opt1', opt, 'customize_not_null');
        PERFORM test_customize_read_option(cus, '', opt, 'text_not_null');
        PERFORM test_customize_read_option(cus, null, opt, 'text_not_null');

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

DROP FUNCTION test_customize_read_option;



-- Test function customize_update_option and error handling.
CREATE OR REPLACE FUNCTION test_customize_update_option (
    INOUT customize CUSTOMIZE,
    option OPTION,
    new_name TEXT,
    error TEXT
) AS $$
    BEGIN
        customize = customize_update_option(customize, option, new_name);

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
        cus CUSTOMIZE;
        opt OPTION;
    BEGIN
        RAISE INFO 'Testing function customize_update_option and error handling...';

        cus = new_customize('c1');
        opt = new_option('opt1', 100);
        cus = customize_create_option(cus, opt);

        opt.price = 200;
        cus = test_customize_update_option(cus, opt, '', '');
        PERFORM test_customize_update_option(cus, new_option('opt1', 200), '', 'customize_option_mismatch');
        cus = test_customize_update_option(cus, opt, 'opt2', '');
        PERFORM test_customize_update_option(cus, opt, 'opt3', 'customize_option_not_found');
        opt.name = 'opt2';
        cus = test_customize_update_option(cus, opt, 'opt3', '');
        opt.name = 'opt3';
        cus = customize_create_option(cus, new_option('opt4', 400));
        PERFORM test_customize_update_option(cus, opt, 'opt4', 'customize_duplicated_option');
        PERFORM test_customize_update_option(cus, opt, 'opt3', 'customize_duplicated_option');
        PERFORM test_customize_update_option(null, opt, '', 'customize_not_null');
        PERFORM test_customize_update_option(cus, null, '', 'option_not_null');

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

DROP FUNCTION test_customize_update_option;



-- Test function customize_delete_option and error handling.
CREATE OR REPLACE FUNCTION test_customize_delete_option (
    INOUT customize CUSTOMIZE,
    name TEXT,
    id UUID,
    error TEXT
) AS $$
    BEGIN
        customize = customize_delete_option(customize, name, id);

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
        cus CUSTOMIZE;
        opt1 OPTION;
        opt2 OPTION;
    BEGIN
        RAISE INFO 'Testing function customize_delete_option and error handling...';

        cus = new_customize('c1');
        opt1 = new_option('opt1', 100);
        opt2 = new_option('opt2', 200);
        cus = customize_create_option(cus, opt1);
        cus = customize_create_option(cus, opt2);

        PERFORM test_customize_delete_option(cus, opt1.name, opt2.id, 'customize_option_mismatch');
        cus = test_customize_delete_option(cus, opt1.name, opt1.id, '');
        PERFORM test_customize_delete_option(cus, opt1.name, opt1.id, 'customize_option_not_found');
        PERFORM test_customize_delete_option(null, opt2.name, opt2.id, 'customize_not_null');
        PERFORM test_customize_delete_option(cus, null, opt2.id, 'text_not_null');
        PERFORM test_customize_delete_option(cus, opt2.name, null, 'uuid_not_null');
        cus = test_customize_delete_option(cus, opt2.name, opt2.id, '');


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

DROP FUNCTION test_customize_delete_option;