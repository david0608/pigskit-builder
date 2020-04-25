DROP FUNCTION test_shop_product_delete_customize;
DROP FUNCTION shop_product_delete_customize;

DROP FUNCTION test_shop_product_create_customize;
DROP FUNCTION shop_product_create_customize;

DROP FUNCTION shop_delete_product;
DROP FUNCTION shop_update_product;
DROP FUNCTION shop_read_product;
DROP FUNCTION shop_create_product;

DROP FUNCTION check_shop_products_write_authority;

DROP FUNCTION test_set_shop_member_authority;
DROP FUNCTION set_shop_member_authority;

DROP FUNCTION test_add_shop_member;
DROP FUNCTION add_shop_member;

DROP FUNCTION test_create_shop;
DROP FUNCTION create_shop;

DROP FUNCTION shop_name_to_id;

DELETE FROM errors WHERE code LIKE 'C5%';

DROP TABLE shop_user;

DROP TRIGGER name_auto_upper ON shops;
DROP FUNCTION shop_name_auto_upper;

DROP TABLE shops;