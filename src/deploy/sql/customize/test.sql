-- Test functions for customize.
BEGIN;
DO $$
    DECLARE
        cus CUSTOMIZE;
        sel_key1 UUID;
        sel_key2 UUID;
        sel_key3 UUID;
        payload JSONB;
    BEGIN
        cus = customize_create(
            'cus',
            'new customize.',
            '[
                {
                    "name": "sel1",
                    "price": 100
                },
                {
                    "name": "sel2",
                    "price": 200
                },
                {
                    "name": "sel3",
                    "price": 300
                }
            ]'
        );
        select key into sel_key1 from query_customize_selections(cus) where (selection).name = 'sel1';
        select key into sel_key2 from query_customize_selections(cus) where (selection).name = 'sel2';
        select key into sel_key3 from query_customize_selections(cus) where (selection).name = 'sel3';
        raise info 'initial customize: %', cus;

        payload = jsonb_build_object(
            'name', 'cus2',
            'description', 'test update customize.',
            'delete', jsonb_build_array(sel_key1),
            'create', jsonb_build_array('{ "name": "sel7", "price": 700 }'::JSONB),
            'update', json_build_object(sel_key2, '{ "name": "sel6" }'::JSONB, sel_key3, '{ "name": "sel8", "price": 800 }'::JSONB)
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