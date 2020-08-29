DROP FUNCTION create_order;

DROP TABLE orders;

DROP FUNCTION cart_clean_items;
DROP FUNCTION cart_delete_item;
DROP FUNCTION cart_update_item;
DROP FUNCTION cart_create_item;

DROP FUNCTION put_cart;
DROP FUNCTION get_cart;

DROP TABLE cart;

DELETE FROM errors WHERE code LIKE 'C8%';