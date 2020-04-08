DROP FUNCTION test_register_user;
DROP FUNCTION register_user;

DROP FUNCTION username_to_id;

DELETE FROM errors WHERE code LIKE 'C1%';

DROP TABLE users;