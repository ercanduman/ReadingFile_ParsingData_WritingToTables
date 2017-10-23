INSERT INTO eduman.billing_global_config (file_separator, directory_name, file_prefix, wa_name, stringcolumncount, isvalid) VALUES 	('|', 'USER_DIR', 'invoice_', 'BILLINGSYSTEM', 6, 'Y');
COMMIT;

-- CONSTRAINT -- insertion of only one column with (Y) : limit/restrict to only one row with Y
ALTER TABLE EDUMAN.BILLING_GLOBAL_CONFIG ADD CONSTRAINT CK_BILLING_GLOBAL_CONF_ISVALID CHECK ( isValid NOT IN ('Y'))  ENABLE NOVALIDATE;

-- drop constraint
-- alter table eduman.billing_global_config drop constraint ck_billing_global_conf_isvalid;
