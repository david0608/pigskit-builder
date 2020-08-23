-- Test put_guest_session.
BEGIN;

DO $$
    DECLARE
        gssid UUID;
    BEGIN
        SELECT id INTO gssid FROM put_guest_session(null) AS id;
        RAISE INFO 'id: %', gssid;

        SELECT id INTO gssid FROM put_guest_session(gssid) AS id;
        RAISE INFO 'id: %', gssid;

        DELETE FROM guest_session WHERE id = gssid;

        SELECT id INTO gssid FROM put_guest_session(gssid) AS id;
        RAISE INFO 'id: %', gssid;
    END;
$$ LANGUAGE plpgsql;

SELECT * FROM guest_session;

ROLLBACK;