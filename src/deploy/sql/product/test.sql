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



-- Test functinos for product.
BEGIN;
DO $$
    DECLARE
        prod PRODUCT;
        cus_key1 UUID;
        cus_key2 UUID;
        cus2 CUSTOMIZE;
        sel_key1 UUID;
        sel_key2 UUID;
        payload JSONB;
    BEGIN
        prod = product_create(
            'prod',
            'new product',
            1000,
            null,
            '[
                {
                    "name": "cus1",
                    "description": "customize 1.",
                    "selections": [
                        {
                            "name": "sel1",
                            "price": 100
                        },
                        {
                            "name": "sel2",
                            "price": 200
                        }
                    ]
                },
                {
                    "name": "cus2",
                    "description": "customize 2.",
                    "selections": [
                        {
                            "name": "sel3",
                            "price": 300
                        },
                        {
                            "name": "sel4",
                            "price": 400
                        }
                    ]
                }
            ]'
        );
        select key into cus_key1 from query_product_customizes(prod) where (customize).name = 'cus1';
        select key into cus_key2 from query_product_customizes(prod) where (customize).name = 'cus2';

        cus2 = product_read_customize(prod, cus_key2);
        select key into sel_key1 from query_customize_selections(cus2) where (selection).name = 'sel3';
        select key into sel_key2 from query_customize_selections(cus2) where (selection).name = 'sel4';

        raise info '%', prod;

        payload = jsonb_build_object(
            'name', 'test',
            'description', 'test product.',
            'price', 2000,
            'series_id', uuid_generate_v4(),
            'has_picture', true,
            'delete', jsonb_build_array(cus_key1),
            'create', jsonb_build_array('{
                "name": "cus3",
                "description": "csutomize 3.",
                "selections": [
                    {
                        "name": "sel5",
                        "price": 500
                    }
                ]
            }'::JSONB),
            'update', jsonb_build_object(
                cus_key2, jsonb_build_object(
                    'name', 'cus_test',
                    'description', 'customize test',
                    'delete', jsonb_build_array(sel_key1),
                    'create', jsonb_build_array('{ "name": "sel5", "price": 500 }'::JSONB),
                    'update', jsonb_build_object(
                        sel_key2, '{ "price": 700 }'::JSONB
                    )
                )
            )
        );

        prod = product_update(prod, payload);

        raise info '%', prod;
    END;
$$ LANGUAGE plpgsql;
ROLLBACK;



-- BEGIN;
-- with create_product as (
--     select product_create(
--         'prod',
--         'test product.',
--         1000,
--         null,
--         '[
--             {
--                 "name": "cus1",
--                 "description": "csutomize 1.",
--                 "selections": [
--                     {
--                         "name": "sel1",
--                         "price": 100
--                     },
--                     {
--                         "name": "sel2",
--                         "price": 200
--                     }
--                 ]
--             },
--             {
--                 "name": "cus2",
--                 "description": "csutomize 2.",
--                 "selections": [
--                     {
--                         "name": "sel3",
--                         "price": 100
--                     },
--                     {
--                         "name": "sel4",
--                         "price": 200
--                     }
--                 ]
--             }
--         ]'
--     ) AS prod
-- )
-- , query_customize as (
--     select query_product_customizes(prod) AS cus from create_product
-- )
-- select (cus).key, (cus).customize.* from query_customize;
-- ROLLBACK;