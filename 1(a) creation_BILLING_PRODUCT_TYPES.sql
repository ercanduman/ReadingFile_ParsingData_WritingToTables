create table EDUMAN.BILLING_PRODUCT_TYPES (
	Product_Id     NUMBER primary key,
	Product_Name   VARCHAR2(20) NOT NULL,
	kdv_tax_rate   NUMBER,
	oiv_tax_rate   NUMBER
);

--table comment
comment on table EDUMAN.BILLING_PRODUCT_TYPES  is 'Stores all products types such as SES, DATA, SMS, etc for billing system.';

--column comments
comment on column EDUMAN.BILLING_PRODUCT_TYPES.Product_Id is 'Product_Id attribute defines unique identifier of products types.';
comment on column EDUMAN.BILLING_PRODUCT_TYPES.Product_Name is 'Product_Name attribute defines name of products such as DATA, SES, SMS, etc.';
comment on column EDUMAN.BILLING_PRODUCT_TYPES.kdv_tax_rate is 'kdv_tax_rate attribute defines the tax rate value of products types for KDV (Katma Deger Vergisi)';
comment on column EDUMAN.BILLING_PRODUCT_TYPES.oiv_tax_rate is 'oiv_tax_rate attribute defines the tax rate value of products types for OIV (Ozel Iletisim Vergisi)';

--instead of writing Product_Id values one by one, a sequence created
CREATE sequence EDUMAN.seq_Product_Id start with 1 increment by 1 cache 10 order nocycle;
