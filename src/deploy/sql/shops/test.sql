BEGIN;

-- Define a function that query shop products in details for testing.
CREATE FUNCTION query_test_shop_product (
    shop_name TEXT
) RETURNS TABLE (
    prod_key UUID_NN,
    prod_name TEXT_NZ,
    prod_desc TEXT,
    prod_price INT_NN,
    cus_key UUID_NN,
    cus_name TEXT_NZ,
    cus_desc TEXT,
    sel_key UUID_NN,
    sel_name TEXT_NZ,
    sel_price INT_NN
) AS $$
    BEGIN
        RETURN QUERY
        WITH
            products AS ( SELECT (query_shop_products(id)).* FROM shops WHERE name = shop_name ),
            customizes AS ( SELECT key prod_key, (query_product_customizes(product)).* FROM products ),
            selections AS ( SELECT key cus_key, (query_customize_selections(customize)).* FROM customizes )
        SELECT
            products.key prod_key,
            (product).name prod_name,
            (product).description prod_desc,
            (product).price prod_price,
            cus_join_sel.cus_key,
            (cus_join_sel.customize).name cus_name,
            (cus_join_sel.customize).description cus_desc,
            cus_join_sel.sel_key,
            (cus_join_sel.selection).name sel_name,
            (cus_join_sel.selection).price sel_price
        FROM
            products
        LEFT JOIN
            (
                SELECT
                    customizes.prod_key,
                    customizes.key cus_key,
                    customize,
                    selections.key sel_key,
                    selection
                FROM
                    customizes
                LEFT JOIN
                    selections
                ON
                    customizes.key = selections.cus_key
            ) cus_join_sel
        ON
            products.key = cus_join_sel.prod_key;
    END;
$$ LANGUAGE plpgsql;

DO $$
    DECLARE
        shop_id UUID;
        payload TEXT_NN;
    BEGIN
        -- Create a shop for the test.
        INSERT INTO shops(name) VALUES ('testshop') RETURNING id INTO shop_id;

        -- Create a product.
        payload = jsonb_build_object(
            'name', 'prod1',
            'description', 'product 1.',
            'price', 1000,
            'series_id', uuid_generate_v4(),
            'customizes', jsonb_build_array(
                jsonb_build_object(
                    'name', 'cus1',
                    'description', 'customize 1.',
                    'selections', jsonb_build_array(
                        jsonb_build_object(
                            'name', 'sel1',
                            'price', 100
                        ),
                        jsonb_build_object(
                            'name', 'sel2',
                            'price', 200
                        )
                    )
                ),
                jsonb_build_object(
                    'name', 'cus2',
                    'description', 'customize 2.',
                    'selections', jsonb_build_array(
                        jsonb_build_object(
                            'name', 'sel3',
                            'price', 300
                        ),
                        jsonb_build_object(
                            'name', 'sel4',
                            'price', 400
                        )
                    )
                )
            )
        );
        PERFORM shop_create_product(shop_id, payload);
    END;
$$ LANGUAGE plpgsql;

-- Show the product just created.
select * from query_test_shop_product('testshop');

DO $$
    DECLARE
        shop_id UUID;

        prod_key UUID;
        prod PRODUCT;

        cus1_key UUID;
        cus2_key UUID;
        cus1 CUSTOMIZE;
        cus2 CUSTOMIZE;

        sel1_key UUID;
        sel2_key UUID;
        sel3_key UUID;
        sel4_key UUID;

        payload TEXT_NN;
    BEGIN
        SELECT id INTO shop_id FROM shops WHERE name = 'testshop';

        SELECT key INTO prod_key FROM query_shop_products(shop_id) WHERE (product).name = 'prod1';
        prod = shop_read_product(shop_id, prod_key);

        SELECT key INTO cus1_key FROM query_product_customizes(prod) WHERE (customize).name = 'cus1';
        SELECT key INTO cus2_key FROM query_product_customizes(prod) WHERE (customize).name = 'cus2';
        cus1 = product_read_customize(prod, cus1_key);
        cus2 = product_read_customize(prod, cus2_key);

        SELECT key INTO sel1_key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel1';
        SELECT key INTO sel2_key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel2';
        SELECT key INTO sel3_key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel3';
        SELECT key INTO sel4_key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel4';

        -- Update the product just created.
        payload = jsonb_build_object(
            'name', 'prod2',
            'description', 'product 2',
            'price', 2000,
            'customizes', jsonb_build_object(
                'update', jsonb_build_object(
                    cus1_key, jsonb_build_object(
                        'name', 'cus11',
                        'description', 'customize 11.',
                        'selections', jsonb_build_object(
                            'update', jsonb_build_object(
                                sel1_key, jsonb_build_object(
                                    'name', 'sel11'
                                )
                            ),
                            'delete', jsonb_build_array(
                                sel2_key
                            ),
                            'create', jsonb_build_array(
                                jsonb_build_object(
                                    'name', 'sel3',
                                    'price', 30
                                )
                            )
                        )
                    )
                ),
                'delete', jsonb_build_array(
                    cus2_key
                ),
                'create', jsonb_build_array(
                    jsonb_build_object(
                        'name', 'cus3',
                        'selections', jsonb_build_array(
                            jsonb_build_object(
                                'name', 'sel33',
                                'price', 33
                            )
                        )
                    )
                )
            )
        );
        PERFORM shop_update_product(shop_id, prod_key, payload);
    END;
$$ LANGUAGE plpgsql;

-- Show the product just updates.
select * from query_test_shop_product('testshop');

ROLLBACK;



BEGIN;
DO $$
    DECLARE
        shop_id UUID;
    BEGIN
        -- Create a shop for the test.
        INSERT INTO shops(name) VALUES ('testshop') RETURNING id INTO shop_id;
        -- Create a new series for the shops.
        PERFORM shop_create_series(shop_id, 'series1');
    END;
$$ LANGUAGE plpgsql;

-- Query serieses of the shop.
with shop_id as (
    select id from shops where name = 'testshop'
)
, query_serieses as (
    select query_shop_serieses(id) as serieses from shop_id
)
select (serieses).* from query_serieses;

DO $$
    DECLARE
        shop_id UUID;
        series_key UUID;
    BEGIN
        SELECT id INTO shop_id FROM shops WHERE name = 'testshop';
        SELECT key INTO series_key FROM query_shop_serieses(shop_id) WHERE name = 'series1';
        -- Update the series just created.
        PERFORM shop_update_series(shop_id, series_key, 'new_series');
    END;
$$ LANGUAGE plpgsql;

-- Query serieses of the shop.
with select_shop as (
    select id from shops where name = 'testshop'
)
, query_serieses as (
    select query_shop_serieses(id) as serieses from select_shop
)
select (serieses).* from query_serieses;

DO $$
    DECLARE
        shop_id UUID;
        series_key UUID;
    BEGIN
        SELECT id INTO shop_id FROM shops WHERE name = 'testshop';
        SELECT key INTO series_key FROM query_shop_serieses(shop_id) WHERE name = 'new_series';
        -- Delete the series.        
        PERFORM shop_delete_series(shop_id, series_key);
    END;
$$ LANGUAGE plpgsql;

-- Query serieses of the shop.
with select_shop as (
    select id from shops where name = 'testshop'
)
,query_serieses as (
    select query_shop_serieses(id) as serieses from select_shop
)
select (serieses).* from query_serieses;

ROLLBACK;