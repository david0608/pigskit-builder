-- Errors.
INSERT INTO errors(code, name, message) VALUES
    ('C8001', 'cart_not_found', 'Cart not found.'),
    ('C8002', 'cart_item_not_found', 'Cart item not found.'),
    ('C8101', 'order_cart_empty', 'Cart is empty on create order.'),
    ('C8102', 'order_product_not_found', 'Product not found on create order.'),
    ('C8103', 'order_item_expired', 'Cart item is expired on create order.');





-- Cart table.
CREATE TABLE IF NOT EXISTS cart (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_session_id    UUID_NN REFERENCES guest_session(id),
    shop_id             UUID_NN REFERENCES shops(id),
    items               HSTORE_NN DEFAULT '',
    UNIQUE(guest_session_id, shop_id)
);

-- Get cart by guest_session_id and shop_id.
CREATE OR REPLACE FUNCTION get_cart (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    OUT cart_id UUID
) AS $$
    BEGIN
        IF NOT is_guest_session_valid(guest_session_id) THEN
            PERFORM raise_error('guest_session_expired');
        END IF;

        SELECT t.id INTO cart_id FROM cart AS t
        WHERE t.guest_session_id = get_cart.guest_session_id
            AND t.shop_id = get_cart.shop_id;
    END;
$$ LANGUAGE plpgsql;

-- Put cart. Create a new cart if not existed.
CREATE OR REPLACE FUNCTION put_cart (
    guest_session_id UUID,
    shop_id UUID_NN
) RETURNS UUID AS $$
    <<_>>
    DECLARE
        guest_session_id UUID;
        cart_id UUID;
    BEGIN
        -- Create a new session if session not provided or expired.
        _.guest_session_id := put_guest_session(put_cart.guest_session_id);

        _.cart_id := get_cart(_.guest_session_id, put_cart.shop_id);
        -- Create a new cart if not existed.
        IF cart_id IS NULL THEN
            INSERT INTO cart(guest_session_id, shop_id) VALUES (_.guest_session_id, shop_id) RETURNING id INTO cart_id;
        END IF;

        RETURN guest_session_id;
    END;
$$ LANGUAGE plpgsql;

-- Create an item for the cart.
CREATE OR REPLACE FUNCTION cart_create_item (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    product_key UUID_NN,
    remark TEXT,
    count INT_NN,
    cus_sel TEXT_NN,
    OUT item_key UUID
) AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        product PRODUCT;
        cus_sel JSONB;
        item PRODUCT_ITEM;
        items HSTORE;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);

        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        product := shop_read_product(shop_id, product_key);
        IF product IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;

        _.cus_sel := cart_create_item.cus_sel::JSONB;

        item := product_item_create(
            product_key,
            product,
            count,
            remark,
            _.cus_sel
        );
        item_key := uuid_generate_v4();

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = cart_id;
        items := items || hstore(format('%s', item_key), format('%s', item));
        UPDATE cart SET items = _.items WHERE id = cart_id;
    END;
$$ LANGUAGE plpgsql;

-- Update an item of the cart.
CREATE OR REPLACE FUNCTION cart_update_item (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    item_key UUID_NN,
    payload TEXT_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        items hstore;
        item PRODUCT_ITEM;
        payload JSONB;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);

        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = cart_id;
        item := (items -> format('%s', item_key))::PRODUCT_ITEM;
        IF item IS NULL THEN
            PERFORM raise_error('cart_item_not_found');
        END IF;

        _.payload := cart_update_item.payload::JSONB;
        item := product_item_update(item, _.payload);

        items := items - format('%s', item_key);
        items := items || hstore(format('%s', item_key), format('%s', item));
        UPDATE cart SET items = _.items WHERE id = cart_id;
    END;
$$ LANGUAGE plpgsql;

-- Delete an item of the cart.
CREATE OR REPLACE FUNCTION cart_delete_item (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    item_key UUID_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        items HSTORE;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);
        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = _.cart_id;
        items := items - format('%s', item_key);
        UPDATE cart SET items = _.items WHERE id = cart_id;
    END;
$$ LANGUAGE plpgsql;

-- Clean the cart.
CREATE OR REPLACE FUNCTION cart_clean_items (
    guest_session_id UUID_NN,
    shop_id UUID_NN
) RETURNS void AS $$
    <<_>>
    DECLARE
        cart_id UUID;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);
        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        UPDATE cart SET items = '' WHERE id = cart_id;
    END;
$$ LANGUAGE plpgsql;





-- Orders table.
CREATE TABLE IF NOT EXISTS orders (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_session_id        UUID_NN REFERENCES guest_session(id),
    shop_id                 UUID_NN REFERENCES shops(id),
    items                   HSTORE_NN,
    order_number            INT_NN,
    order_at                TS_NN DEFAULT now()
);

-- Create a new order.
CREATE OR REPLACE FUNCTION create_order (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    OUT order_id UUID
) AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        items HSTORE;
        item RECORD;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);
        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart t WHERE id = cart_id;
        IF items = '' THEN
            PERFORM raise_error('order_cart_empty');
        END IF;

        FOR item IN SELECT * FROM each(items) LOOP
            DECLARE
                prod_item PRODUCT_ITEM := (item.value)::PRODUCT_ITEM;
                prod PRODUCT;
            BEGIN
                prod := shop_read_product(shop_id, prod_item.product_key);
                IF prod IS NULL OR prod.latest_update > prod_item.order_at THEN
                    PERFORM raise_error('order_item_expired');
                END IF;
            END;
        END LOOP;

        INSERT INTO orders (guest_session_id, shop_id, items, order_number)
            VALUES (guest_session_id, shop_id, items, shop_next_order_number(shop_id))
            RETURNING id INTO order_id;

        PERFORM cart_clean_items(guest_session_id, shop_id);
    END;
$$ LANGUAGE plpgsql;