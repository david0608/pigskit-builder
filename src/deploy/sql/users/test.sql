DO $$
    DECLARE
        regssid UUID;
    BEGIN
        INSERT INTO user_register_session (id, username, password, email, phone)
            VALUES (uuid_generate_v4(), 'david0608', '123123', 'david@mail.com', '0912312312')
            RETURNING id INTO regssid;
        PERFORM register_user(regssid);

        INSERT INTO user_register_session (id, username, password, email, phone)
            VALUES (uuid_generate_v4(), 'alice0710', '123123', 'alice@mail.com', '0932132132')
            RETURNING id INTO regssid;
        PERFORM register_user(regssid);
    END;
$$ LANGUAGE plpgsql;