DROP FUNCTION shop_user_update_authority;
DROP FUNCTION shop_user_create;
DROP FUNCTION check_shop_user_authority;

DELETE FROM errors WHERE code LIKE 'C6%';

DROP TABLE shop_user;