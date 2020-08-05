BEGIN;
DO $$
    DECLARE
        shop_id UUID;
        prod_key UUID;
        prod PRODUCT;
        cus_key UUID;
        cus CUSTOMIZE;
        sel_key UUID;
        sel SELECTION;
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
                        )
                    )
                )
            )
        );
        select product_key into prod_key from shop_create_product(shop_id, payload);

        -- Read the product just created.
        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

        -- Get customize key.
        select key into cus_key from query_product_customizes(prod) where (customize).name = 'cus1';
        -- Read the customize just created.
        cus = product_read_customize(prod, cus_key);
        raise info '%', cus;

        -- Get selection key.
        select key into sel_key from query_customize_selections(cus) where (selection).name = 'sel1';
        -- Read the selection just created.
        sel = customize_read_selection(cus, sel_key);
        raise info '%', sel;

        -- Update the product just created.
        payload = jsonb_build_object(
            'name', 'prod_u',
            'description', 'product updated.',
            'price', 2000,
            'series_id', uuid_generate_v4(),
            'update', jsonb_build_object(
                cus_key, jsonb_build_object(
                    'name', 'cus_u',
                    'description', 'customize updated.',
                    'create', jsonb_build_array(
                        jsonb_build_object(
                            'name', 'sel_c',
                            'price', 200
                        )
                    ),
                    'update', jsonb_build_object(
                        sel_key, jsonb_build_object(
                            'name', 'sel_u',
                            'price', 1000
                        )
                    )
                )
            )
        );
        perform shop_update_product(shop_id, prod_key, payload);

        -- Read the product just updated.
        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

        -- Delete a old customize and create a new customize through update product.
        payload = jsonb_build_object(
            'delete', jsonb_build_array(cus_key),
            'create', jsonb_build_array(
                jsonb_build_object(
                    'name', 'cus3',
                    'description', 'customize 3.'
                )
            )
        );
        perform shop_update_product(shop_id, prod_key, payload);

        -- Get the product just updated.
        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

        -- Get the customize just created.
        select key into cus_key from query_product_customizes(prod) where (customize).name = 'cus3';
        cus = product_read_customize(prod, cus_key);
        raise info '%', cus;

        -- Delete the customize through update product.
        payload = jsonb_build_object(
            'delete', jsonb_build_array(cus_key)
        );
        perform shop_update_product(shop_id, prod_key, payload);

        -- Get the product just updated.
        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;
    END;
$$ LANGUAGE plpgsql;
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