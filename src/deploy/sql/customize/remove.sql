DROP FUNCTION customize_delete_option;

DROP FUNCTION customize_update_option;

DROP FUNCTION customize_read_option;

DROP FUNCTION customize_create_option;

DROP FUNCTION new_customize;

DELETE FROM errors WHERE code LIKE 'C3%';

DROP DOMAIN CUSTOMIZE_NN;
DROP TYPE CUSTOMIZE;

DROP FUNCTION new_option;

DROP DOMAIN OPTION_NN;
DROP TYPE OPTION;