DROP FUNCTION test_get_session_user;
DROP FUNCTION get_session_user;

DROP FUNCTION signout_user;

DROP FUNCTION test_signin_user;
DROP FUNCTION signin_user;

DELETE FROM errors WHERE code LIKE 'C2%';

DROP TABLE sessions;