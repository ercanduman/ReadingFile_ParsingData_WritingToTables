SELECT * FROM eduman.billing_invoices;
SELECT * FROM eduman.billing_product_types;
SELECT * FROM eduman.billing_global_config WHERE wa_name = 'BILLINGSYSTEM';

SELECT *
	FROM eduman.billing_invoices bi, eduman.billing_product_types bp
 WHERE bi.product_name = bp.product_name;

-- value changes for tests
SELECT ROWID, a.* FROM eduman.billing_global_config a;

---
SELECT DISTINCT kdv_tax_rate, oiv_tax_rate
	FROM eduman.billing_invoices bi, eduman.billing_product_types bp
 WHERE bi.product_name = bp.product_name
	 AND msisdn = '5552550000';
