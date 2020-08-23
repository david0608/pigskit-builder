DROP FUNCTION put_guest_session;
DROP FUNCTION is_guest_session_valid;
DROP FUNCTION create_guest_session;

DELETE FROM errors WHERE code LIKE 'C3%';

DROP TABLE guest_session;