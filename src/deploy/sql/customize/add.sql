-- Selection type.
CREATE TYPE SELECTION AS (
    name                TEXT_NZ,
    price               INT_NN
);

--Domain SELECTION_NN
CREATE DOMAIN SELECTION_NN AS SELECTION NOT NULL;

-- Customize type.
CREATE TYPE CUSTOMIZE AS (
    name                TEXT_NZ,
    description         TEXT,
    selections          HSTORE_NN,
    latest_update       TS_NN
);

-- Domain CUSTOMIZE_NN.
CREATE DOMAIN CUSTOMIZE_NN AS CUSTOMIZE NOT NULL;



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