DROP FUNCTION product_delete_customize;

DROP FUNCTION product_update_customize;

DROP FUNCTION product_read_customize;

DROP FUNCTION product_create_customize;

DROP FUNCTION new_product;

DELETE FROM errors WHERE code LIKE 'C4%';

DROP DOMAIN PRODUCT_NN;
DROP TYPE PRODUCT;