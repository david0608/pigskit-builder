DROP FUNCTION shop_update_series;
DROP FUNCTION shop_delete_series;
DROP FUNCTION shop_create_series;
DROP FUNCTION query_shop_serieses;

DROP FUNCTION shop_update_product;
DROP FUNCTION shop_delete_product;
DROP FUNCTION shop_read_product;
DROP FUNCTION shop_create_product;
DROP FUNCTION query_shop_products;

DROP FUNCTION create_shop;
DROP FUNCTION shop_name_to_id;

DELETE FROM errors WHERE code LIKE 'C5%';

DROP TRIGGER name_auto_upper ON shops;
DROP FUNCTION shop_name_auto_upper;

DROP TABLE shops;