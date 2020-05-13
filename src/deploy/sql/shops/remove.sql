DROP FUNCTION shop_update_product;
DROP FUNCTION shop_delete_product;
DROP FUNCTION shop_read_product;
DROP FUNCTION shop_create_product;

DROP FUNCTION shop_set_authority;
DROP FUNCTION shop_add_member;

DROP FUNCTION check_shop_user_authority;

DROP FUNCTION create_shop;

DROP FUNCTION shop_name_to_id;

DELETE FROM errors WHERE code LIKE 'C5%';

DROP TABLE shop_user;

DROP TRIGGER name_auto_upper ON shops;
DROP FUNCTION shop_name_auto_upper;

DROP TABLE shops;