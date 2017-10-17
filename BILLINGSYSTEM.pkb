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
	gs_OutDirectoryName eduman.billing_global_config.directory_name%TYPE;
	gs_FileSeparator    eduman.billing_global_config.file_separator%TYPE;
	gs_FilePrefix       eduman.billing_global_config.file_prefix%TYPE;
	gs_OutFileName      VARCHAR2(50);

	cs_WA_NAME eduman.billing_global_config.wa_name%TYPE := 'BILLINGSYSTEM';

	PROCEDURE GetGlobalConfigurations IS
	BEGIN
	
		SELECT bg.file_separator, bg.directory_name, bg.file_prefix
			INTO gs_FileSeparator, gs_OutDirectoryName, gs_FilePrefix
			FROM eduman.billing_global_config bg
		 WHERE wa_name = cs_WA_NAME;
	
		gs_OutFileName := to_char(SYSDATE, 'ddmmyyyy');
		gs_OutFileName := gs_FilePrefix || gs_OutFileName || '.txt';
		dbms_output.put_line('INFO> gs_OutFileName: ' || gs_OutFileName); -- File format: invoice_230917.txt
	
	END GetGlobalConfigurations;

	PROCEDURE CalculateGrossFee(vs_Msisdn IN OUT VARCHAR,
															pin_Fee   IN OUT NUMBER) IS
	
		vn_KDVTaxRate eduman.billing_product_types.kdv_tax_rate%TYPE;
		vn_OIVTaxRate eduman.billing_product_types.oiv_tax_rate%TYPE;
		vn_GrossFee   eduman.billing_invoices.gross_fee%TYPE := NULL;
	
	BEGIN
		SELECT DISTINCT kdv_tax_rate, oiv_tax_rate
			INTO vn_KDVTaxRate, vn_OIVTaxRate
			FROM eduman.billing_invoices bi, eduman.billing_product_types bp
		 WHERE bi.product_name = bp.product_name
			 AND msisdn = vs_Msisdn;
	
		vn_GrossFee := (nvl((vn_KDVTaxRate + vn_OIVTaxRate) / 100, 0) + 1) *
									 pin_Fee;
		dbms_output.put_line('INFO> Fee: ' || pin_Fee || ' vn_GrossFee: ' ||
												 vn_GrossFee);
	
		UPDATE eduman.billing_invoices bi
			 SET bi.gross_fee = vn_GrossFee
		 WHERE msisdn = vs_Msisdn;
		COMMIT;
	
	END CalculateGrossFee;

	PROCEDURE i_BillingInvoices(vs_Msisdn      IN OUT VARCHAR,
															vs_Service     IN OUT VARCHAR,
															vd_StartDate   IN OUT DATE,
															vd_EndDate     IN OUT DATE,
															vs_ProductName IN OUT VARCHAR,
															pin_Fee        IN OUT NUMBER) IS
	
	BEGIN
		INSERT INTO eduman.billing_invoices
			(invoice_id,
			 msisdn,
			 service_name,
			 start_date,
			 end_date,
			 product_name,
			 fee,
			 process_time)
		VALUES
			(eduman.seq_billing_invoices_id.nextval,
			 vs_Msisdn,
			 vs_Service,
			 vd_StartDate,
			 vd_EndDate,
			 vs_ProductName,
			 pin_Fee,
			 SYSDATE);
		COMMIT;
	
		CalculateGrossFee(vs_Msisdn, pin_Fee);
	
	END i_BillingInvoices;

	PROCEDURE ParseFileData(vs_AllFileData IN OUT VARCHAR2) IS
		vs_Msisdn      VARCHAR(2000);
		vs_Service     VARCHAR(2000);
		vd_StartDate   DATE;
		vd_EndDate     DATE;
		vs_ProductName VARCHAR(200);
		vn_Fee         NUMBER;
	
	BEGIN
	
		vs_msisdn      := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		1);
		vs_Service     := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		2);
		vd_StartDate   := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		3);
		vd_EndDate     := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		4);
		vs_ProductName := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		5);
		vn_Fee         := regexp_substr(vs_AllFileData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		6);
	
		i_BillingInvoices(vs_Msisdn,
											vs_Service,
											vd_StartDate,
											vd_EndDate,
											vs_ProductName,
											vn_Fee);
	
	END ParseFileData;

	PROCEDURE ReadFileData IS
		vt_OutFile UTL_FILE.FILE_TYPE;
	
		vs_AllFileData VARCHAR2(3000);
	BEGIN
	
		vt_OutFile := UTL_FILE.FOPEN(gs_OutDirectoryName, gs_OutFileName, 'R');
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(vt_OutFile, vs_AllFileData);
				--dbms_output.put_line(vs_AllFileData);
			
				ParseFileData(vs_AllFileData);
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
