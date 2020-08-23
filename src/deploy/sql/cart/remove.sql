DROP FUNCTION cart_delete_item;
DROP FUNCTION cart_update_item;
DROP FUNCTION cart_create_item;
DROP FUNCTION query_cart_items;

DROP FUNCTION item_update;
DROP FUNCTION item_create;

DROP TYPE ITEM;

DROP FUNCTION item_customize_create;

DROP TYPE ITEM_CUSTOMIZE;

DROP FUNCTION put_cart;
DROP FUNCTION get_cart;

DELETE FROM errors WHERE code LIKE 'C8%';

DROP TABLE cart;