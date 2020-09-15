-- Errors.
INSERT INTO errors (code, name, message) VALUES
    ('C4101', 'sel_not_found', 'Selection not found.'),
    ('C4301', 'cus_item_sel_not_provided', 'Selection for the customize item not provided.');





-- Selection type.
CREATE TYPE SELECTION AS (
    name                TEXT_NZ,
    price               INT_NN
);

--Domain SELECTION_NN
CREATE DOMAIN SELECTION_NN AS SELECTION NOT NULL;

-- Create a new selection.
CREATE OR REPLACE FUNCTION selection_create (
    name TEXT_NZ,
    price INT_NN
) RETURNS SELECTION AS $$
    BEGIN
        RETURN (name, price)::SELECTION;
    END;
$$ LANGUAGE plpgsql;

-- Update current selection.
CREATE OR REPLACE FUNCTION selection_update (
    INOUT sel SELECTION_NN,
    payload JSONB
) AS $$
    BEGIN
        IF payload IS NOT NULL THEN
            IF payload ? 'name' THEN
                sel.name = payload ->> 'name';
            END IF;
            IF payload ? 'price' THEN
                sel.price = payload ->> 'price';
            END IF;
        END IF;
    END;
$$ LANGUAGE plpgsql;





-- Customize type.
CREATE TYPE CUSTOMIZE AS (
    name                TEXT_NZ,
    description         TEXT,
    selections          HSTORE_NN,
    latest_update       TS_NN
);

-- Domain CUSTOMIZE_NN.
CREATE DOMAIN CUSTOMIZE_NN AS CUSTOMIZE NOT NULL;

-- Query all selections of the customize.
CREATE OR REPLACE FUNCTION query_customize_selections (
    cus CUSTOMIZE_NN
) RETURNS TABLE (
    key UUID_NN,
    selection SELECTION
) AS $$
    BEGIN
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::SELECTION FROM each(cus.selections);
    END;
$$ LANGUAGE plpgsql;

-- Function that create a selection for the customize.
CREATE OR REPLACE FUNCTION customize_create_selection (
    INOUT cus CUSTOMIZE_NN,
    payload JSONB
) AS $$
    DECLARE
        sel SELECTION;
        _k UUID := uuid_generate_v4();
    BEGIN
        sel = selection_create(
            payload ->> 'name',
            (payload ->> 'price')::INT_NN
        );
        cus.selections = cus.selections || hstore(format('%s', _k), format('%s', sel));
    END;
$$ LANGUAGE plpgsql;

-- Read a selection of the customize.
CREATE OR REPLACE FUNCTION customize_read_selection (
    cus CUSTOMIZE_NN,
    sel_key UUID_NN,
    OUT sel SELECTION
) AS $$
    BEGIN
        sel = (cus.selections -> format('%s', sel_key))::SELECTION;
    END;
$$ LANGUAGE plpgsql;

-- Drop a selection of the customize.
CREATE OR REPLACE FUNCTION customize_delete_selection (
    INOUT cus CUSTOMIZE_NN,
    sel_key UUID_NN
) AS $$
    BEGIN
        cus.selections = cus.selections - format('%s', sel_key);
    END;
$$ LANGUAGE plpgsql;

-- Update a selection of the customize.
CREATE OR REPLACE FUNCTION customize_update_selection (
    INOUT cus CUSTOMIZE_NN,
    sel_key UUID_NN,
    payload jsonb
) AS $$
    DECLARE
        sel SELECTION;
    BEGIN
        sel = customize_read_selection(cus, sel_key);
        IF sel IS NOT NULL THEN
            sel = selection_update(sel, payload);
            cus = customize_delete_selection(cus, sel_key);
            cus.selections = cus.selections || hstore(format('%s', sel_key), format('%s', sel));
            cus.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;

-- Create a new customize.
CREATE OR REPLACE FUNCTION customize_create (
    name TEXT_NZ,
    description TEXT,
    selections JSONB
) RETURNS CUSTOMIZE AS $$
    DECLARE
        cus CUSTOMIZE;
        selection JSONB;
    BEGIN
        cus = (name, description, '', now())::CUSTOMIZE;

        FOR selection IN SELECT jsonb_array_elements(selections) LOOP
            cus = customize_create_selection(cus, selection);
        END LOOP;

        RETURN cus;
    END;
$$ LANGUAGE plpgsql;

-- Update current customize.
CREATE OR REPLACE FUNCTION customize_update (
    INOUT cus CUSTOMIZE_NN,
    payload JSONB
) AS $$
    DECLARE
        sel_key UUID;
        sel_payload JSONB;
    BEGIN
        IF payload ? 'name' THEN
            cus.name = payload ->> 'name';
        END IF;

        IF payload ? 'description' THEN
            cus.description = payload ->> 'description';
        END IF;

        FOR sel_key IN SELECT jsonb_array_elements_text(payload -> 'delete') LOOP
            cus = customize_delete_selection(cus, sel_key);
        END LOOP;

        FOR sel_payload IN SELECT jsonb_array_elements(payload -> 'create') LOOP
            cus = customize_create_selection(cus, sel_payload);
        END LOOP;

        FOR sel_key, sel_payload IN SELECT key, value FROM jsonb_each(payload -> 'update') LOOP
            cus = customize_update_selection(cus, sel_key, sel_payload);
        END LOOP;
    END;
$$ LANGUAGE plpgsql;





-- Customize item type.
CREATE TYPE CUSTOMIZE_ITEM AS (
    name                TEXT_NZ,
    selection           TEXT,
    selection_key       UUID,
    price               INTEGER,
    order_at            TS_NN
);

-- Create a new customize item.
CREATE OR REPLACE FUNCTION customize_item_create (
    cus CUSTOMIZE_NN,
    sel_key UUID
) RETURNS CUSTOMIZE_ITEM AS $$
    DECLARE
        sel SELECTION;
    BEGIN
        IF sel_key IS NULL THEN
            IF cus.selections = '' THEN
                RETURN (
                    cus.name,
                    NULL,
                    NULL,
                    NULL,
                    now()
                )::CUSTOMIZE_ITEM;
            ELSE
                PERFORM raise_error('cus_item_sel_not_provided');
            END IF;
        ELSE
            sel := customize_read_selection(cus, sel_key);

            IF sel IS NULL THEN
                PERFORM raise_error('sel_not_found');
            END IF;

            RETURN (
                cus.name,
                sel.name,
                sel_key,
                sel.price,
                now()
            )::CUSTOMIZE_ITEM;
        END IF;
    END;
$$ LANGUAGE plpgsql;





-- Product type.
CREATE TYPE PRODUCT AS (
    name                TEXT_NZ,
    description         TEXT,
    price               INT_NN,
    series_id           UUID,
    has_picture         BOOLEAN,
    customizes          HSTORE_NN,
    latest_update       TS_NN
);

-- Domain PRODUCT_NN.
CREATE DOMAIN PRODUCT_NN AS PRODUCT NOT NULL;

-- Query all customizes of the product.
CREATE OR REPLACE FUNCTION query_product_customizes (
    prod PRODUCT_NN
) RETURNS TABLE (
    key UUID_NN,
    customize CUSTOMIZE
) AS $$
    BEGIN
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::CUSTOMIZE FROM each(prod.customizes);
    END;
$$ LANGUAGE plpgsql;

-- Create a customize for the product.
CREATE OR REPLACE FUNCTION product_create_customize (
    INOUT prod PRODUCT_NN,
    payload JSONB
) AS $$
    DECLARE
        cus CUSTOMIZE;
        key UUID := uuid_generate_v4();
    BEGIN
        cus = customize_create(
            payload ->> 'name',
            payload ->> 'description',
            payload -> 'selections'
        );
        prod.customizes = prod.customizes || hstore(format('%s', key), format('%s', cus));
    END;
$$ LANGUAGE plpgsql;

-- Read a customize of the product.
CREATE OR REPLACE FUNCTION product_read_customize (
    prod PRODUCT_NN,
    key UUID_NN,
    OUT cus CUSTOMIZE
) AS $$
    BEGIN
        cus = (prod.customizes -> format('%s', key))::CUSTOMIZE;
    END;
$$ LANGUAGE plpgsql;

-- Delete a customize of the product.
CREATE OR REPLACE FUNCTION product_delete_customize (
    INOUT prod PRODUCT_NN,
    key UUID_NN
) AS $$
    BEGIN
        prod.customizes = prod.customizes - format('%s', key);
    END;
$$ LANGUAGE plpgsql;

-- Update a customize of the product.
CREATE OR REPLACE FUNCTION product_update_customize (
    INOUT prod PRODUCT_NN,
    key UUID_NN,
    payload JSONB
) AS $$
    DECLARE
        cus CUSTOMIZE;
    BEGIN
        cus = product_read_customize(prod, key);
        IF cus IS NOT NULL THEN
            cus = customize_update(cus, payload);
            prod = product_delete_customize(prod, key);
            prod.customizes = prod.customizes || hstore(format('%s', key), format('%s', cus));
            prod.latest_update = now();
        END IF;
    END;
$$ LANGUAGE plpgsql;

-- Create a new product.
CREATE OR REPLACE FUNCTION product_create (
    name TEXT_NZ,
    description TEXT,
    price INT_NN,
    series_id UUID,
    customizes JSONB
) RETURNS PRODUCT AS $$
    DECLARE
        prod PRODUCT;
        customize JSONB;
    BEGIN
        prod = (
            name,
            description,
            price,
            series_id,
            false,
            '',
            now()
        )::PRODUCT;
        
        FOR customize IN SELECT jsonb_array_elements(customizes) LOOP
            prod = product_create_customize(prod, customize);
        END LOOP;

        RETURN prod;
    END;
$$ LANGUAGE plpgsql;

-- Update current product.
CREATE OR REPLACE FUNCTION product_update (
    INOUT prod PRODUCT_NN,
    payload JSONB
) AS $$
    DECLARE
        cus_key UUID;
        cus_payload JSONB;
    BEGIN
        IF payload ? 'name' THEN
            prod.name = payload ->> 'name';
        END IF;

        IF payload ? 'description' THEN
            prod.description = payload ->> 'description';
        END IF;
        
        IF payload ? 'price' THEN
            prod.price = payload ->> 'price';
        END IF;

        IF payload ? 'series_id' THEN
            prod.series_id = payload ->> 'series_id';
        END IF;

        IF payload ? 'has_picture' THEN
            prod.has_picture = payload ->> 'has_picture';
        END IF;

        FOR cus_key IN SELECT jsonb_array_elements_text(payload -> 'delete') LOOP
            prod = product_delete_customize(prod, cus_key);
        END LOOP;

        FOR cus_payload IN SELECT jsonb_array_elements(payload -> 'create') LOOP
            prod = product_create_customize(prod, cus_payload);
        END LOOP;

        FOR cus_key, cus_payload IN SELECT key, value FROM jsonb_each(payload -> 'update') LOOP
            prod = product_update_customize(prod, cus_key, cus_payload);
        END LOOP;

        prod.latest_update = now();
    END;
$$ LANGUAGE plpgsql;





-- Product item type.
CREATE TYPE PRODUCT_ITEM AS (
    product_key             UUID_NN,
    name                    TEXT_NN,
    price                   INT_NN,
    customizes              HSTORE_NN,
    count                   INT_NN,
    remark                  TEXT,
    order_at                TS_NN
);

-- Domain PRODUCT_ITEM_NN.
CREATE DOMAIN PRODUCT_ITEM_NN AS PRODUCT_ITEM NOT NULL;

-- Query all customize item of the product item.
CREATE OR REPLACE FUNCTION query_product_item_customize_items (
    prod_item PRODUCT_ITEM_NN
) RETURNS TABLE (
    key UUID_NN,
    customize CUSTOMIZE_ITEM
) AS $$
    BEGIN
        RETURN QUERY SELECT ((each).key)::UUID_NN, ((each).value)::CUSTOMIZE_ITEM FROM each(prod_item.customizes);
    END;
$$ LANGUAGE plpgsql;

-- Create a new product item.
CREATE OR REPLACE FUNCTION product_item_create (
    prod_key UUID_NN,
    prod PRODUCT_NN,
    count INT_NN,
    remark TEXT,
    cus_sel JSONB
) RETURNS PRODUCT_ITEM AS $$
    DECLARE
        cus RECORD;
        customize_items HSTORE := '';
    BEGIN
        FOR cus IN SELECT (each(prod.customizes)).* LOOP
            customize_items :=  customize_items || hstore(
                format('%s', cus.key),
                format(
                    '%s',
                    customize_item_create(
                        (cus.value)::CUSTOMIZE,
                        (cus_sel ->> cus.key)::UUID
                    )
                )
            );
        END LOOP;

        RETURN (
            prod_key,
            prod.name,
            prod.price,
            customize_items,
            count,
            remark,
            now()
        )::PRODUCT_ITEM;
    END;
$$ LANGUAGE plpgsql;

-- Update current product item.
CREATE OR REPLACE FUNCTION product_item_update (
    INOUT item PRODUCT_ITEM,
    payload JSONB
) AS $$
    BEGIN
        IF payload ? 'count' THEN
            item.count := payload ->> 'count';
        END IF;

        IF payload ? 'remark' THEN
            item.remark := payload ->> 'remark';
        END IF;
    END;
$$ LANGUAGE plpgsql;