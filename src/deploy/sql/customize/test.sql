-- Test functions for customize.
BEGIN;
DO $$
    DECLARE
        cus CUSTOMIZE;
        opt_key1 UUID;
        opt_key2 UUID;
        opt_key3 UUID;
        payload JSONB;
    BEGIN
        cus = customize_create(
            'cus',
            'new customize.',
            '[
                {
                    "name": "opt1",
                    "price": 100
                },
                {
                    "name": "opt2",
                    "price": 200
                },
                {
                    "name": "opt3",
                    "price": 300
                }
            ]'
        );
        select key into opt_key1 from query_customize_options(cus) where (option).name = 'opt1';
        select key into opt_key2 from query_customize_options(cus) where (option).name = 'opt2';
        select key into opt_key3 from query_customize_options(cus) where (option).name = 'opt3';
        raise info 'initial customize: %', cus;

        payload = jsonb_build_object(
            'name', 'cus2',
            'description', 'test update customize.',
            'delete', jsonb_build_array(opt_key1),
            'create', jsonb_build_array('{ "name": "opt7", "price": 700 }'::JSONB),
            'update', json_build_object(opt_key2, '{ "name": "opt6" }'::JSONB, opt_key3, '{ "name": "opt8", "price": 800 }'::JSONB)
        );
        raise info 'update payload: %', payload;

        cus = customize_update(
            cus,
            payload
        );
        raise info 'updated customize: %', cus;
    END;
$$ LANGUAGE plpgsql;
ROLLBACK;