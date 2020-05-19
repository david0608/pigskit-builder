DROP FUNCTION set_store_member_authority;

DROP FUNCTION add_store_member;

DROP FUNCTION check_store_user_authority;

DROP FUNCTION create_store;

DELETE FROM errors WHERE code LIKE 'C7%';

DROP TABLE store_user;

DROP TRIGGER name_auto_upper ON stores;
DROP FUNCTION stores_name_auto_upper;
DROP TABLE stores;