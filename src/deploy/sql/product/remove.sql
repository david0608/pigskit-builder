DROP FUNCTION product_item_update;
DROP FUNCTION product_item_create;
DROP FUNCTION query_product_item_customize_items;

DROP DOMAIN PRODUCT_ITEM_NN;
DROP TYPE PRODUCT_ITEM;

DROP FUNCTION product_update;
DROP FUNCTION product_create;
DROP FUNCTION product_update_customize;
DROP FUNCTION product_delete_customize;
DROP FUNCTION product_read_customize;
DROP FUNCTION product_create_customize;
DROP FUNCTION query_product_customizes;

DROP DOMAIN PRODUCT_NN;
DROP TYPE PRODUCT;

DROP FUNCTION customize_item_create;

DROP TYPE CUSTOMIZE_ITEM;

DROP FUNCTION customize_update;
DROP FUNCTION customize_create;
DROP FUNCTION customize_update_selection;
DROP FUNCTION customize_delete_selection;
DROP FUNCTION customize_read_selection;
DROP FUNCTION customize_create_selection;
DROP FUNCTION query_customize_selections;

DROP DOMAIN CUSTOMIZE_NN;
DROP TYPE CUSTOMIZE;

DROP FUNCTION selection_update;
DROP FUNCTION selection_create;

DROP DOMAIN SELECTION_NN;
DROP TYPE SELECTION;

DELETE FROM errors WHERE code LIKE 'C4%';