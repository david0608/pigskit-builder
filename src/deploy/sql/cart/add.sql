-- Cart table.
CREATE TABLE cart (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    guest_session_id    UUID_NN REFERENCES guest_session(id),
    shop_id             UUID_NN REFERENCES shops(id),
    items               HSTORE_NN DEFAULT '',
    UNIQUE(guest_session_id, shop_id)
);



-- Item errors.
INSERT INTO errors (code, name, message) VALUES
    ('C8001', 'cart_not_found', 'Cart not found.'),
    ('C8002', 'item_not_found', 'Item not found.'),
    ('C8010', 'item_prod_key_not_provided', 'prod_key not provided in the item payload.'),
    ('C8011', 'item_count_not_provided', 'count not provided in the item payload.'),
    ('C8020', 'item_cus_sel_not_provided', 'Item customize selection not provided.'),
    ('C8023', 'item_selection_not_found', 'Item customize selection not found for the product.');



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



-- Cart item customize type.
CREATE TYPE ITEM_CUSTOMIZE AS (
    name                TEXT_NZ,
    choice              TEXT,
    price               INTEGER
);



-- Create an item customize.
CREATE OR REPLACE FUNCTION item_customize_create (
    customize CUSTOMIZE_NN,
    selection_key UUID
) RETURNS ITEM_CUSTOMIZE AS $$
    DECLARE
        selection SELECTION;
    BEGIN
        IF selection_key IS NULL THEN
            IF customize.selections = '' THEN
                RETURN (
                    customize.name,
                    NULL,
                    NULL
                )::ITEM_CUSTOMIZE;
            ELSE
                PERFORM raise_error('item_cus_sel_not_provided');
            END IF;
        ELSE
            selection := customize_read_selection(customize, selection_key);

            IF selection IS NULL THEN
                PERFORM raise_error('item_selection_not_found');
            END IF;

            RETURN (
                customize.name,
                selection.name,
                selection.price
            )::ITEM_CUSTOMIZE;
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Cart item type.
CREATE TYPE ITEM AS (
    name                TEXT_NZ,
    price               INT_NN,
    customizes          ITEM_CUSTOMIZE[],
    count               INT_NN,
    remark              TEXT
);



-- Create an item.
CREATE OR REPLACE FUNCTION item_create (
    shop_id UUID_NN,
    payload JSONB
) RETURNS ITEM AS $$
    <<_>>
    DECLARE
        product_key UUID := payload ->> 'product_key';
        count INTEGER := payload ->> 'count';
        remark TEXT := payload ->> 'remark';
        customizes JSONB := payload -> 'customizes';
        product PRODUCT;
        cus RECORD;
        item_customizes ITEM_CUSTOMIZE[] := '{}';
    BEGIN
        IF product_key IS NULL THEN
            PERFORM raise_error('item_prod_key_not_provided');
        END IF;
        
        IF count IS NULL THEN
            PERFORM raise_error('item_count_not_provided');
        END IF;

        product := shop_read_product(shop_id, product_key);
        
        IF product IS NULL THEN
            PERFORM raise_error('shop_product_not_found');
        END IF;

        FOR cus IN SELECT (each(product.customizes)).* LOOP
            item_customizes := array_append(
                item_customizes,
                item_customize_create(
                    (cus.value)::CUSTOMIZE,
                    (customizes ->> cus.key)::UUID
                )
            );
        END LOOP;

        RETURN (
            product.name,
            product.price,
            item_customizes,
            count,
            remark
        )::ITEM;
    END;
$$ LANGUAGE plpgsql;



-- Update current item.
CREATE OR REPLACE FUNCTION item_update (
    INOUT item ITEM,
    payload JSONB
) AS $$
    DECLARE

    BEGIN
        IF payload ? 'count' THEN
            item.count = payload ->> 'count';
        END IF;

        IF payload ? 'remark' THEN
            item.remark = payload ->> 'remark';
        END IF;
    END;
$$ LANGUAGE plpgsql;



-- Query all items of the cart.
CREATE OR REPLACE FUNCTION query_cart_items (
    guest_session_id UUID_NN,
    shop_id UUID_NN
) RETURNS TABLE (
    key UUID_NN,
    item ITEM
) AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        items hstore;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);

        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = cart_id;

        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::ITEM FROM each(items);
    END;
$$ LANGUAGE plpgsql;



-- Create an item for the cart.
CREATE OR REPLACE FUNCTION cart_create_item (
    guest_session_id UUID_NN,
    shop_id UUID_NN,
    payload TEXT_NN,
    OUT item_key UUID
) AS $$
    <<_>>
    DECLARE
        cart_id UUID;
        items hstore;
        payload JSONB;
        item ITEM;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);

        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = cart_id;

        _.payload := cart_create_item.payload::JSONB;

        item := item_create(shop_id, payload);
        item_key := uuid_generate_v4();

        items := items || hstore(format('%s', item_key), format('%s', item));
        
        UPDATE cart SET items = _.items WHERE id = cart_id;
    END;
$$ LANGUAGE plpgsql;



-- Update an item for the cart.
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
        item ITEM;
        payload JSONB;
    BEGIN
        cart_id := get_cart(guest_session_id, shop_id);

        IF cart_id IS NULL THEN
            PERFORM raise_error('cart_not_found');
        END IF;

        SELECT t.items INTO _.items FROM cart AS t WHERE t.id = cart_id;
        item := (items -> format('%s', item_key))::ITEM;
        IF item IS NULL THEN
            PERFORM raise_error('item_not_found');
        END IF;

        _.payload := cart_update_item.payload::JSONB;
        item := item_update(item, _.payload);

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
        items hstore;
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