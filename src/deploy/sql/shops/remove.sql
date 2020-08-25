DROP FUNCTION shop_next_order_number;

DROP TABLE shop_order_number_sequence;

DROP FUNCTION shop_user_update_authority;
DROP FUNCTION shop_user_create;
DROP FUNCTION check_shop_user_authority;

DROP TABLE shop_user;

DROP FUNCTION shop_update_series;
DROP FUNCTION shop_delete_series;
DROP FUNCTION shop_create_series;
DROP FUNCTION query_shop_serieses;

DROP FUNCTION shop_set_product_has_picture;
DROP FUNCTION shop_update_product;
DROP FUNCTION shop_delete_product;
DROP FUNCTION shop_read_product;
DROP FUNCTION shop_create_product;
DROP FUNCTION query_shop_products;

DROP FUNCTION create_shop;
DROP FUNCTION shop_name_to_id;

DROP TRIGGER name_auto_upper ON shops;
DROP FUNCTION shop_name_auto_upper;

DROP TABLE shops;

DELETE FROM errors WHERE code LIKE 'C6%';