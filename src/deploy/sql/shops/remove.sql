DROP FUNCTION test_set_shop_member_authority;
DROP FUNCTION set_shop_member_authority;

DROP FUNCTION test_add_shop_member;
DROP FUNCTION add_shop_member;

DROP FUNCTION test_create_shop;
DROP FUNCTION create_shop;

DROP FUNCTION shop_name_to_id;

DELETE FROM errors WHERE code LIKE 'C3%';

DROP TABLE shop_user;

DROP TRIGGER name_auto_upper ON shops;
DROP FUNCTION shop_name_auto_upper;

DROP TABLE shops;