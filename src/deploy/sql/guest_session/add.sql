-- Guest session table.
CREATE TABLE IF NOT EXISTS guest_session (
    id                      UUID_NN PRIMARY KEY DEFAULT uuid_generate_v4(),
    latest_access           TS_NN DEFAULT now()
);



-- Guest session errors.
INSERT INTO errors (code, name, message) VALUES
    ('C3001', 'guest_session_expired', 'Guest session expired.');



-- Create a new guest session.
CREATE OR REPLACE FUNCTION create_guest_session (
    OUT id UUID
) AS $$
    BEGIN
        INSERT INTO guest_session AS t DEFAULT VALUES RETURNING t.id INTO create_guest_session.id;
    END;
$$ LANGUAGE plpgsql;



-- Is guest session valid.
CREATE OR REPLACE FUNCTION is_guest_session_valid (
    session_id UUID_NN
) RETURNS BOOLEAN AS $$
    <<_>>
    DECLARE
        id UUID;
        ok BOOLEAN := false;
    BEGIN
        UPDATE guest_session AS t SET latest_access = now() WHERE t.id = session_id RETURNING t.id INTO _.id;
        IF _.id IS NOT NULL THEN
            _.ok := true;
        END IF;
        RETURN ok;
    END;
$$ LANGUAGE plpgsql;



-- Check guest session. Will create a new session if the session_id not provided or the session is expired.
CREATE OR REPLACE FUNCTION put_guest_session (
    session_id UUID
) RETURNS UUID AS $$
    <<_>>
    DECLARE
        ok BOOLEAN := false;
        id UUID := session_id;
    BEGIN
        IF session_id IS NOT NULL THEN
            ok := is_guest_session_valid(session_id);
        END IF;

        IF NOT ok THEN
            id := create_guest_session();
        END IF;

        RETURN id;
    END;
$$ LANGUAGE plpgsql;