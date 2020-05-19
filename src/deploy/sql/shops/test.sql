BEGIN;
DO $$
    DECLARE
        shop_id UUID;
        prod_key UUID;
        prod PRODUCT;
        cus_key UUID;
        cus CUSTOMIZE;
        opt_key UUID;
        opt OPTION;
        payload TEXT_NN;
    BEGIN
        INSERT INTO shops(name) VALUES ('testshop') RETURNING id INTO shop_id;

        payload = jsonb_build_object(
            'name', 'prod1',
            'description', 'product 1.',
            'price', 1000,
            'series_id', uuid_generate_v4(),
            'customizes', jsonb_build_array(
                jsonb_build_object(
                    'name', 'cus1',
                    'description', 'customize 1.',
                    'options', jsonb_build_array(
                        jsonb_build_object(
                            'name', 'opt1',
                            'price', 100
                        )
                    )
                )
            )
        );
        perform shop_create_product(shop_id, payload);

        select key into prod_key from query_shop_products(shop_id) where (product).name = 'prod1';
        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

        select key into cus_key from query_product_customizes(prod) where (customize).name = 'cus1';
        cus = product_read_customize(prod, cus_key);
        raise info '%', cus;

        select key into opt_key from query_customize_options(cus) where (option).name = 'opt1';
        opt = customize_read_option(cus, opt_key);
        raise info '%', opt;

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
                            'name', 'opt_c',
                            'price', 200
                        )
                    ),
                    'update', jsonb_build_object(
                        opt_key, jsonb_build_object(
                            'name', 'opt_u',
                            'price', 1000
                        )
                    )
                )
            )
        );
        perform shop_update_product(shop_id, prod_key, payload);

        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

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

        prod = shop_read_product(shop_id, prod_key);
        raise info '%', prod;

        select key into cus_key from query_product_customizes(prod) where (customize).name = 'cus3';
        cus = product_read_customize(prod, cus_key);
        raise info '%', cus;

        payload = jsonb_build_object(
            'delete', jsonb_build_array(cus_key)
        );
        perform shop_update_product(shop_id, prod_key, payload);

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
        INSERT INTO shops(name) VALUES ('testshop') RETURNING id INTO shop_id;
        PERFORM shop_create_series(shop_id, 'series1');
    END;
$$ LANGUAGE plpgsql;

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
        PERFORM shop_update_series(shop_id, series_key, 'new_series');
    END;
$$ LANGUAGE plpgsql;

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
        PERFORM shop_delete_series(shop_id, series_key);
    END;
$$ LANGUAGE plpgsql;

with select_shop as (
    select id from shops where name = 'testshop'
)
,query_serieses as (
    select query_shop_serieses(id) as serieses from select_shop
)
select (serieses).* from query_serieses;

ROLLBACK;