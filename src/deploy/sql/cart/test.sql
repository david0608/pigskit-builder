-- Test put_cart.
BEGIN;

DO $$
    DECLARE
        shop1_id UUID;
        shop2_id UUID;
        session_id UUID;
    BEGIN
        INSERT INTO shops(name) VALUES ('shop1') RETURNING id INTO shop1_id;
        INSERT INTO shops(name) VALUES ('shop2') RETURNING id INTO shop2_id;

        SELECT id INTO session_id FROM put_cart(session_id, shop1_id) AS id;
        RAISE INFO 'session: %', session_id;

        SELECT id INTO session_id FROM put_cart(session_id, shop2_id) AS id;
        RAISE INFO 'session: %', session_id;
    END;
$$ LANGUAGE plpgsql;

SELECT * FROM guest_session;
SELECT * FROM shops;
SELECT * FROM cart;

ROLLBACK;


-- Test cart_create_item, cart_update_item, cart_delete_item and query_cart_items.
BEGIN;

DO $$
    DECLARE
        shop_id UUID;
        guest_session_id UUID;

        prod1_key UUID;
        prod1 PRODUCT;

        prod2_key UUID;

        cus1_key UUID;
        cus1 CUSTOMIZE;

        sel1_key UUID;
        sel2_key UUID;

        cus2_key UUID;
        cus2 CUSTOMIZE;

        sel3_key UUID;
        sel4_key UUID;

        cus3_key UUID;

        item1_key UUID;
        item2_key UUID;

        cart_r RECORD;
    BEGIN
        INSERT INTO shops(name) VALUES ('shop1') RETURNING id INTO shop_id;
        guest_session_id := put_cart(null, shop_id);

        prod1_key := shop_create_product(
            shop_id,
            jsonb_build_object(
                'name', 'prod1',
                'price', 1000,
                'customizes', jsonb_build_array(
                    jsonb_build_object(
                        'name', 'cus1',
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
                    ),
                    jsonb_build_object(
                        'name', 'cus3'
                    )
                )
            )::TEXT
        );

        prod2_key := shop_create_product(
            shop_id,
            jsonb_build_object(
                'name', 'prod2',
                'price', 2000
            )::TEXT
        );

        prod1 := (SELECT t.product FROM query_shop_products(shop_id) AS t WHERE (t.product).name = 'prod1');

        cus1_key := (SELECT key FROM query_product_customizes(prod1) t WHERE (t.customize).name = 'cus1');
        cus1 := (SELECT t.customize FROM query_product_customizes(prod1) t WHERE t.key = cus1_key);

        sel1_key := (SELECT key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel1');
        sel2_key := (SELECT key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel2');

        cus2_key := (SELECT key FROM query_product_customizes(prod1) t WHERE (t.customize).name = 'cus2');
        cus2 := (SELECT t.customize FROM query_product_customizes(prod1) t WHERE t.key = cus2_key);

        sel3_key := (SELECT key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel3');
        sel4_key := (SELECT key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel4');

        cus3_key := (SELECT key FROM query_product_customizes(prod1) t WHERE (t.customize).name = 'cus3');

        item1_key := cart_create_item(
            guest_session_id,
            shop_id,
            jsonb_build_object(
                'product_key', prod1_key,
                'customizes', jsonb_build_object(
                    cus1_key, sel1_key,
                    cus2_key, sel3_key
                ),
                'count', 2,
                'remark', 'test cart item'
            )::TEXT
        );

        PERFORM cart_delete_item(
            guest_session_id,
            shop_id,
            item1_key
        );

        item2_key := cart_create_item(
            guest_session_id,
            shop_id,
            jsonb_build_object(
                'product_key', prod1_key,
                'customizes', jsonb_build_object(
                    cus1_key, sel2_key,
                    cus2_key, sel4_key
                ),
                'count', 2,
                'remark', 'test cart item'
            )::TEXT
        );

        PERFORM cart_update_item(
            guest_session_id,
            shop_id,
            item2_key,
            jsonb_build_object(
                'count', 3,
                'remark', 'edited item remark.'
            )::TEXT
        );

        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            jsonb_build_object(
                'product_key', prod1_key,
                'customizes', jsonb_build_object(
                    cus1_key, sel2_key,
                    cus2_key, sel4_key,
                    cus3_key, null
                ),
                'count', 2,
                'remark', 'test cart item'
            )::TEXT
        );

        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            jsonb_build_object(
                'product_key', prod2_key,
                'count', 1
            )::TEXT
        );

        FOR cart_r IN
            with items as (
                select
                    key,
                    item
                from
                    query_cart_items(guest_session_id, shop_id)
            ), customizes as (
                select
                    key item_key,
                    unnest((item).customizes) customize
                from items
            )
            select
                key,
                (item).name,
                (item).price,
                (item).count,
                (item).remark,
                (customize).name cus_name,
                (customize).choice cus_choice,
                (customize).price cus_price
            from
                items left join customizes on items.key = customizes.item_key
        LOOP
            raise info 'key: %, price: %, count: %, remark: %, cus_name: %, cus_choice: %, cus_price: %',
                cart_r.key, cart_r.price, cart_r.count, cart_r.remark, cart_r.cus_name, cart_r.cus_choice, cart_r.cus_price;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;

ROLLBACK;