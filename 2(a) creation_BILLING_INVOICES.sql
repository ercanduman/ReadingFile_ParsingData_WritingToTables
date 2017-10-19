create table EDUMAN.BILLING_INVOICES (
	Invoice_Id   	NUMBER PRIMARY KEY,
	MSISDN       	VARCHAR(13),
	Service_Name 	VARCHAR(50),
	Start_Date   	DATE,
	End_Date     	DATE,
	Product_Name 	VARCHAR(50),
	Fee          	NUMBER,
	Gross_Fee    	NUMBER,
	Processed_Data 	VARCHAR (1000),
	Status       	VARCHAR (1),
	Process_Time 	DATE
);

--table comment retrieved
comment on table EDUMAN.BILLING_INVOICES  is 'Stores all Invoices which are read from file.';

--column comments
comment on column EDUMAN.BILLING_INVOICES.Invoice_Id is 'Invoice_Id attribute defines unique identifier of BILLING_INVOICES.';
comment on column EDUMAN.BILLING_INVOICES.MSISDN is 'MSISDN attribute defines the phone number (MSISDN) that parsed from file data.';
comment on column EDUMAN.BILLING_INVOICES.Service_Name is 'Service_Name attribute defines the of service/product that parsed from file data.';
comment on column EDUMAN.BILLING_INVOICES.Start_Date is 'Start_Date attribute defines the billing start date that parsed from file data.';
comment on column EDUMAN.BILLING_INVOICES.End_Date is 'End_Date attribute defines the billing end date that parsed from file data.';
comment on column EDUMAN.BILLING_INVOICES.Product_Name is 'Product_Name attribute defines the name of product which are stored in eduman.billing_product_types.';
comment on column EDUMAN.BILLING_INVOICES.Fee is 'Fee attribute defines the cost of service that parsed from file data.';
comment on column EDUMAN.BILLING_INVOICES.Gross_Fee is 'Gross_Fee attribute defines the service price with calculation of kdv+oiv taxes.';
comment on column EDUMAN.BILLING_INVOICES.Processed_Data is 'Processed_Data attribute defines the data that retrieved from a row of file.';
comment on column EDUMAN.BILLING_INVOICES.Status is 'Status attribute defines the status of execution which can be S(success), (F)fail.';
comment on column EDUMAN.BILLING_INVOICES.Process_Time is 'Process_Time attribute defines the execution time of invoice.';


--instead of writing Operand_id values one by one, a sequence created
CREATE sequence EDUMAN.seq_BILLING_INVOICES_id start with 1 increment by 1 cache 10 order nocycle;
