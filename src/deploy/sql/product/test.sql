-- Test functinos for product.
BEGIN;
DO $$
    DECLARE
        prod PRODUCT;
        cus_key1 UUID;
        cus_key2 UUID;
        cus2 CUSTOMIZE;
        opt_key1 UUID;
        opt_key2 UUID;
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
                    "options": [
                        {
                            "name": "opt1",
                            "price": 100
                        },
                        {
                            "name": "opt2",
                            "price": 200
                        }
                    ]
                },
                {
                    "name": "cus2",
                    "description": "customize 2.",
                    "options": [
                        {
                            "name": "opt3",
                            "price": 300
                        },
                        {
                            "name": "opt4",
                            "price": 400
                        }
                    ]
                }
            ]'
        );
        select key into cus_key1 from query_product_customizes(prod) where (customize).name = 'cus1';
        select key into cus_key2 from query_product_customizes(prod) where (customize).name = 'cus2';

        cus2 = product_read_customize(prod, cus_key2);
        select key into opt_key1 from query_customize_options(cus2) where (option).name = 'opt3';
        select key into opt_key2 from query_customize_options(cus2) where (option).name = 'opt4';

        raise info '%', prod;

        payload = jsonb_build_object(
            'name', 'test',
            'description', 'test product.',
            'price', 2000,
            'series_id', uuid_generate_v4(),
            'delete', jsonb_build_array(cus_key1),
            'create', jsonb_build_array('{
                "name": "cus3",
                "description": "csutomize 3.",
                "options": [
                    {
                        "name": "opt5",
                        "price": 500
                    }
                ]
            }'::JSONB),
            'update', jsonb_build_object(
                cus_key2, jsonb_build_object(
                    'name', 'cus_test',
                    'description', 'customize test',
                    'delete', jsonb_build_array(opt_key1),
                    'create', jsonb_build_array('{ "name": "opt5", "price": 500 }'::JSONB),
                    'update', jsonb_build_object(
                        opt_key2, '{ "price": 700 }'::JSONB
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
--                 "options": [
--                     {
--                         "name": "opt1",
--                         "price": 100
--                     },
--                     {
--                         "name": "opt2",
--                         "price": 200
--                     }
--                 ]
--             },
--             {
--                 "name": "cus2",
--                 "description": "csutomize 2.",
--                 "options": [
--                     {
--                         "name": "opt3",
--                         "price": 100
--                     },
--                     {
--                         "name": "opt4",
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