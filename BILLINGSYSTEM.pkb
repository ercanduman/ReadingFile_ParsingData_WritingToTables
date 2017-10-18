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

	cs_WA_NAME                 eduman.billing_global_config.wa_name%TYPE := 'BILLINGSYSTEM';
	cn_StringFormatColumnCount NUMBER := 6;

	PROCEDURE GetGlobalConfigurations IS
	BEGIN
	
		SELECT bg.file_separator, bg.directory_name, bg.file_prefix
			INTO gs_FileSeparator, gs_OutDirectoryName, gs_FilePrefix
			FROM eduman.billing_global_config bg
		 WHERE wa_name = cs_WA_NAME;
	
		gs_OutFileName := to_char(SYSDATE, 'ddmmyyyy');
		gs_OutFileName := gs_FilePrefix || gs_OutFileName || '.txt'; -- File format: invoice_230917.txt
	
	END GetGlobalConfigurations;

	PROCEDURE u_BillingInvoices(vs_Msisdn   IN OUT VARCHAR,
															vn_GrossFee IN OUT eduman.billing_invoices.gross_fee%TYPE) IS
	BEGIN
		UPDATE eduman.billing_invoices bi
			 SET bi.gross_fee = vn_GrossFee
		 WHERE msisdn = vs_Msisdn;
		COMMIT;
	END u_BillingInvoices;

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
	
		u_BillingInvoices(vs_Msisdn, vn_GrossFee);
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

	PROCEDURE ParseFileData(pis_FileRowData IN OUT VARCHAR2) IS
		vs_Msisdn      VARCHAR(2000);
		vs_Service     VARCHAR(2000);
		vd_StartDate   DATE;
		vd_EndDate     DATE;
		vs_ProductName VARCHAR(200);
		vn_Fee         NUMBER;
	
	BEGIN
	
		vs_msisdn      := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		1);
		vs_Service     := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		2);
		vd_StartDate   := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		3);
		vd_EndDate     := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		4);
		vs_ProductName := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		5);
		vn_Fee         := regexp_substr(pis_FileRowData,
																		'[^' || gs_FileSeparator || ']+',
																		1,
																		6);
	
		dbms_output.put_line('INFO> vs_Msisdn: ' || vs_Msisdn);
		dbms_output.put_line('INFO> vs_Service: ' || vs_Service);
		dbms_output.put_line('INFO> vd_StartDate: ' || vd_StartDate);
		dbms_output.put_line('INFO> vd_EndDate: ' || vd_EndDate);
		dbms_output.put_line('INFO> vs_ProductName: ' || vs_ProductName);
		dbms_output.put_line('INFO> vn_Fee: ' || vn_Fee);
		/*i_BillingInvoices(vs_Msisdn,
    vs_Service,
    vd_StartDate,
    vd_EndDate,
    vs_ProductName,
    vn_Fee);*/
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END ParseFileData;

	PROCEDURE CheckDataFormat(pis_FileRow IN OUT VARCHAR2) IS
		vn_StringFormatCount NUMBER := 0;
	BEGIN
		vn_StringFormatCount := REGEXP_COUNT(pis_FileRow, '[^|]+', 1, 'i');
	
		IF vn_StringFormatCount <> cn_StringFormatColumnCount
		THEN
			dbms_output.put_line('ERROR> Wrong Data Format!');
			dbms_output.put_line('INFO> Data format should be as: ' || chr(10) ||
			ParseFileData(pis_FileRow);
		ELSE
			dbms_output.put_line('INFO> Correct format, Start execution!');
		
		END IF;
	
	END CheckDataFormat;

	PROCEDURE ReadFileData IS
		vt_OutFile UTL_FILE.FILE_TYPE;
	
		vs_FileRowData VARCHAR2(3000);
	BEGIN
	
		BEGIN
			vt_OutFile := UTL_FILE.FOPEN(gs_OutDirectoryName, gs_OutFileName, 'R');
		EXCEPTION
			WHEN OTHERS THEN
				dbms_output.put_line('INFO!> Error occurred with file operation. Please check privileges or file name and directory name!');
		END;
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(vt_OutFile, vs_FileRowData);
			
				IF length(vs_FileRowData) > 0
					 OR vs_FileRowData IS NOT NULL
				THEN
					CheckDataFormat(vs_FileRowData);
				ELSE
					RAISE NO_DATA_FOUND;
				END IF;
			
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					IF vs_FileRowData IS NOT NULL
					THEN
						dbms_output.put_line('INFO> All data loaded!');
					ELSE
						dbms_output.put_line('ERROR> File is Empty!');
					END IF;
					EXIT;
			END;
		END LOOP;
	
		IF UTL_FILE.IS_OPEN(vt_OutFile)
		THEN
			UTL_FILE.FCLOSE(vt_OutFile);
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> Error occurred! ' || SQLERRM);
	END;

	PROCEDURE StartToProcess IS
	BEGIN
	
		GetGlobalConfigurations;
	
		ReadFileData;
	
	END StartToProcess;
END BILLINGSYSTEM;
/
