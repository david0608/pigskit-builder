DROP FUNCTION test_set_store_member_authority;
DROP FUNCTION set_store_member_authority;

DROP FUNCTION test_add_store_member;
DROP FUNCTION add_store_member;

DROP FUNCTION test_create_store;
DROP FUNCTION create_store;

DELETE FROM errors WHERE code LIKE 'C4%';

DROP TABLE store_user;

DROP TRIGGER name_auto_upper ON stores;
DROP FUNCTION stores_name_auto_upper;
DROP TABLE stores;