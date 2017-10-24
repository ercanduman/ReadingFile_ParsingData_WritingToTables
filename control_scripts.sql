SELECT * FROM eduman.billing_global_config WHERE wa_name = 'BILLINGSYSTEM';
SELECT * FROM eduman.billing_product_types;

SELECT * FROM eduman.billing_invoices ORDER BY invoice_id DESC;
SELECT * FROM eduman.billing_inv_wa_log ORDER BY inv_log_id DESC;
