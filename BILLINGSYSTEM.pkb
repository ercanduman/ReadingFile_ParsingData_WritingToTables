CREATE OR REPLACE PACKAGE BODY EDUMAN.BILLINGSYSTEM
/**************************************************************************************
  * Purpose    :  A simple billing system that reads data from file and parse&writes this data into database tables.
  * Notes      : 
  * -------------------------------------------------------------------------------------
  * History    :        
   | Author         | Date                 | Purpose
   |-------         |-----------           |-----------------------------------
   | Ercan DUMAN    | 17.10.2017           | Package creation.
  **************************************************************************************/
 IS

	-- Private constant declarations
	gs_OutDirectoryName VARCHAR2(100);
	gs_OutFileName      VARCHAR2(50);

	PROCEDURE i_BillingInvoices(vs_AllFileData IN OUT VARCHAR2) IS
		vs_Msisdn      VARCHAR(20);
		vs_Service     VARCHAR(200);
		vd_StartDate   DATE;
		vd_EndDate     DATE;
		vs_ProductName VARCHAR(20);
		vn_Fee         NUMBER;
		vn_GrossFee    NUMBER;
	
	BEGIN
	
		vs_msisdn      := regexp_substr(vs_AllFileData, '[^|]+', 1, 1);
		vs_Service     := regexp_substr(vs_AllFileData, '[^|]+', 1, 2);
		vd_StartDate   := regexp_substr(vs_AllFileData, '[^|]+', 1, 3);
		vd_EndDate     := regexp_substr(vs_AllFileData, '[^|]+', 1, 4);
		vs_ProductName := regexp_substr(vs_AllFileData, '[^|]+', 1, 5);
		vn_Fee         := regexp_substr(vs_AllFileData, '[^|]+', 1, 6);
	
		INSERT INTO eduman.billing_invoices
			(invoice_id,
			 msisdn,
			 service_name,
			 start_date,
			 end_date,
			 product_name,
			 fee,
			 gross_fee)
		VALUES
			(eduman.seq_billing_invoices_id.nextval,
			 vs_Msisdn,
			 vs_Service,
			 vd_StartDate,
			 vd_EndDate,
			 vs_ProductName,
			 vn_Fee,
			 (vn_Fee * 1.43));
		COMMIT;
	
	END i_BillingInvoices;

	PROCEDURE GetGlobalConfigurations IS
	BEGIN
		gs_OutDirectoryName := 'USER_DIR';
		gs_OutFileName      := 'invoice_230917.txt';
	END GetGlobalConfigurations;

	PROCEDURE ReadFileData IS
		vt_OutFile UTL_FILE.FILE_TYPE;
	
		vs_AllFileData VARCHAR2(3000);
	
	BEGIN
	
		vt_OutFile := UTL_FILE.FOPEN(gs_OutDirectoryName, gs_OutFileName, 'R');
	
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(vt_OutFile, vs_AllFileData);
				dbms_output.put_line(vs_AllFileData);
			
				i_BillingInvoices(vs_AllFileData);
			
			EXCEPTION
				WHEN no_data_found THEN
					dbms_output.put_line('INFO> All data loaded!');
					EXIT;
			END;
		END LOOP;
	
		IF UTL_FILE.IS_OPEN(vt_OutFile)
		THEN
			UTL_FILE.FCLOSE(vt_OutFile);
		END IF;
	
	END;

	PROCEDURE StartToProcess IS
	BEGIN
		GetGlobalConfigurations;
	
		ReadFileData;
	
	END StartToProcess;

END BILLINGSYSTEM;
/
