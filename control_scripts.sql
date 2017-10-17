SELECT * FROM eduman.billing_invoices;
SELECT * FROM eduman.billing_product_types;
SELECT * FROM eduman.billing_global_config;

SELECT *
	FROM eduman.billing_invoices bi, eduman.billing_product_types bp
 WHERE bi.product_name = bp.product_name;

-- calue changes for tests
SELECT rowid, a.* FROM eduman.billing_global_config a;
