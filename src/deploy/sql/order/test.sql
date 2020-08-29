-- Test put_cart.
BEGIN;
DO $$
    DECLARE
        shop1_id UUID;
        shop2_id UUID;
        session_id UUID;
    BEGIN
        INSERT INTO shops(name) VALUES ('shop test 1') RETURNING id INTO shop1_id;
        INSERT INTO shops(name) VALUES ('shop test 2') RETURNING id INTO shop2_id;

        SELECT id INTO session_id FROM put_cart(session_id, shop1_id) AS id;
        RAISE INFO 'session_id: %', session_id;

        SELECT id INTO session_id FROM put_cart(session_id, shop2_id) AS id;
        RAISE INFO 'session_id: %', session_id;
    END;
$$ LANGUAGE plpgsql;

SELECT * FROM guest_session;
SELECT * FROM shops;
SELECT * from cart;
ROLLBACK;



-- Test cart_create_item, cart_update_item and cart_delete_item.
BEGIN;
DO $$
    <<_>>
    DECLARE
        shop_id UUID;
        guest_session_id UUID;

        prod1_key UUID;
        prod2_key UUID;

        prod1 PRODUCT;

        cus1_key UUID;
        cus2_key UUID;
        cus3_key UUID;

        cus1 CUSTOMIZE;
        cus2 CUSTOMIZE;

        sel1_key UUID;
        sel2_key UUID;
        sel3_key UUID;
        sel4_key UUID;

        item1_key UUID;
        item2_key UUID;

        cart_r RECORD;
    BEGIN
        INSERT INTO shops(name) VALUES ('shop test') RETURNING id INTO shop_id;
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
        cus2_key := (SELECT key FROM query_product_customizes(prod1) t WHERE (t.customize).name = 'cus2');
        cus3_key := (SELECT key FROM query_product_customizes(prod1) t WHERE (t.customize).name = 'cus3');

        cus1 := (SELECT t.customize FROM query_product_customizes(prod1) t WHERE t.key = cus1_key);
        cus2 := (SELECT t.customize FROM query_product_customizes(prod1) t WHERE t.key = cus2_key);

        sel1_key := (SELECT key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel1');
        sel2_key := (SELECT key FROM query_customize_selections(cus1) WHERE (selection).name = 'sel2');
        sel3_key := (SELECT key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel3');
        sel4_key := (SELECT key FROM query_customize_selections(cus2) WHERE (selection).name = 'sel4');

        item1_key := cart_create_item(
            guest_session_id,
            shop_id,
            prod1_key,
            'test cart item1',
            2,
            jsonb_build_object(
                cus1_key, sel1_key,
                cus2_key, sel3_key
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
            prod1_key,
            'test cart item2',
            2,
            jsonb_build_object(
                cus1_key, sel2_key,
                cus2_key, sel4_key
            )::TEXT
        );

        PERFORM cart_update_item(
            guest_session_id,
            shop_id,
            item2_key,
            jsonb_build_object(
                'count', 3,
                'remark', 'edit item remark.'
            )::TEXT
        );

        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod1_key,
            'test cart item3',
            1,
            jsonb_build_object(
                cus1_key, sel2_key,
                cus2_key, sel4_key,
                cus3_key, null
            )::TEXT
        );

        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod2_key,
            null,
            1,
            null
        );

        FOR cart_r IN
            WITH
                query_carts AS (
                    SELECT * FROM cart t WHERE t.shop_id = _.shop_id AND t.guest_session_id = _.guest_session_id
                ),
                query_items AS (
                    SELECT id cart_id, (each(items)).* FROM query_carts
                ),
                query_customizes AS (
                    SELECT key item_key, (query_product_item_customize_items(value::PRODUCT_ITEM)).* FROM query_items
                )
            SELECT
                item_key,
                (item).name,
                (item).price,
                (item).count,
                (item).remark,
                customize_key cus_key,
                (customize).name cus_name,
                (customize).selection,
                (customize).price sel_price
            FROM
                query_carts
            LEFT JOIN
                (
                    SELECT
                        cart_id,
                        query_items.key::UUID item_key,
                        query_items.value::PRODUCT_ITEM item,
                        query_customizes.key::UUID customize_key,
                        customize
                    FROM
                        query_items
                    LEFT JOIN
                        query_customizes
                    ON
                        query_items.key = query_customizes.item_key
                ) item_join_cus
            ON
                query_carts.id = item_join_cus.cart_id
        LOOP
            RAISE INFO '%, %, %, %, %, %, %, %, %',
                cart_r.item_key, cart_r.name, cart_r.price, cart_r.count, cart_r.remark, cart_r.cus_key, cart_r.cus_name, cart_r.selection, cart_r.sel_price;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;
ROLLBACK;



-- Test create_order.
BEGIN;
DO $$
    <<_>>
    DECLARE
        user_id UUID;
        shop_id UUID;
        guest_session_id UUID;

        prod1_key UUID;
        prod2_key UUID;

        order_r RECORD;
    BEGIN
        -- insert a user for the test.
        INSERT INTO users(username, password, email, phone) VALUES ('user1', 'user', 'user', '123') RETURNING id INTO user_id;

        -- create a shop for the test.
        PERFORM create_shop(user_id, 'user_shop');
        -- get id of the shop just created.
        SELECT id INTO shop_id FROM shops WHERE name = 'user_shop';

        -- create a cart for the test.
        guest_session_id := put_cart(null, shop_id);

        -- create products for the test.
        prod1_key := shop_create_product(
            shop_id,
            jsonb_build_object(
                'name', 'prod1',
                'price', 1000
            )::TEXT
        );
        prod2_key := shop_create_product(
            shop_id,
            jsonb_build_object(
                'name', 'prod2',
                'price', 2000
            )::TEXT
        );

        -- add items into the cart.
        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod1_key,
            'test item1',
            1,
            null
        );
        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod1_key,
            'test item2',
            2,
            null
        );

        -- create an order. this will clear the cart.
        PERFORM create_order(
            guest_session_id,
            shop_id
        );

        -- add items into the cart.
        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod1_key,
            'test item3',
            10,
            null
        );
        PERFORM cart_create_item(
            guest_session_id,
            shop_id,
            prod2_key,
            'test item4',
            5,
            null
        );

        -- create another order.
        PERFORM create_order(
            guest_session_id,
            shop_id
        );

        FOR order_r IN
            WITH
                shop_orders AS ( SELECT * FROM orders t WHERE t.shop_id = _.shop_id ),
                order_items AS ( SELECT id order_id, (each(items)).* FROM shop_orders )
            SELECT
                shop_orders.id,
                order_number,
                order_at,
                order_items.key item_key,
                ((order_items.value)::PRODUCT_ITEM).product_key prod_key,
                ((order_items.value)::PRODUCT_ITEM).name prod_name,
                ((order_items.value)::PRODUCT_ITEM).price prod_price,
                ((order_items.value)::PRODUCT_ITEM).count count
            FROM
                shop_orders LEFT JOIN order_items
            ON
                shop_orders.id = order_items.order_id
        LOOP
            RAISE INFO '%, %, %, %, %',
                order_r.id, order_r.order_number, order_r.prod_name, order_r.prod_price, order_r.count;
        END LOOP;
    END;
$$ LANGUAGE plpgsql;
ROLLBACK;