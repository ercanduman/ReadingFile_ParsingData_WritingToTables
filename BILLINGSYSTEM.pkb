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
	
		SELECT file_separator, directory_name, file_prefix
			INTO gs_FileSeparator, gs_OutDirectoryName, gs_FilePrefix
			FROM eduman.billing_global_config
		 WHERE wa_name = cs_WA_NAME;
	
		gs_OutFileName := to_char(SYSDATE, 'ddmmyyyy');
		gs_OutFileName := gs_FilePrefix || gs_OutFileName || '.txt'; -- File format: invoice_23092017.txt
	
	END GetGlobalConfigurations;

	PROCEDURE u_BillingInvoices(vs_Msisdn   IN OUT VARCHAR,
															vn_GrossFee IN OUT eduman.billing_invoices.gross_fee%TYPE) IS
	BEGIN
		UPDATE eduman.billing_invoices bi
			 SET bi.gross_fee = vn_GrossFee
		 WHERE msisdn = vs_Msisdn;
		COMMIT;
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
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
	
		-- calculation of gross fee
		vn_GrossFee := (nvl((vn_KDVTaxRate + vn_OIVTaxRate) / 100, 0) + 1) *
									 pin_Fee;
	
		u_BillingInvoices(vs_Msisdn, vn_GrossFee);
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
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
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END i_BillingInvoices;

	PROCEDURE ParseFileData(pis_FileRowData IN OUT VARCHAR2) IS
		vt_FileRowDataArray dbms_sql.varchar2_table;
	BEGIN
	
		FOR i IN 1 .. cn_StringFormatColumnCount
		LOOP
			vt_FileRowDataArray(i) := regexp_substr(pis_FileRowData,
																							'[^' || gs_FileSeparator || ']+',
																							1,
																							i);
		END LOOP;
	
		dbms_output.put_line('INFO> vs_Msisdn: ' || vt_FileRowDataArray(1));
		dbms_output.put_line('INFO> vs_Service: ' || vt_FileRowDataArray(2));
		dbms_output.put_line('INFO> vd_StartDate: ' || vt_FileRowDataArray(3));
		dbms_output.put_line('INFO> vd_EndDate: ' || vt_FileRowDataArray(4));
		dbms_output.put_line('INFO> vs_ProductName: ' ||
												 vt_FileRowDataArray(5));
		dbms_output.put_line('INFO> vn_Fee: ' || vt_FileRowDataArray(6));
	
		/*    i_BillingInvoices(vt_FileRowDataArray(1),
    vt_FileRowDataArray(2),
    vt_FileRowDataArray(3),
    vt_FileRowDataArray(4),
    vt_FileRowDataArray(5),
    vt_FileRowDataArray(6));*/
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END ParseFileData;

	PROCEDURE CheckDataFormat(pis_FileRow IN OUT VARCHAR2) IS
		vn_StringFormatCount NUMBER := 0;
	BEGIN
		vn_StringFormatCount := REGEXP_COUNT(pis_FileRow, '[^|]+', 1, 'i');
		dbms_output.put_line('INFO>vn_StringFormatCount: ' ||
												 vn_StringFormatCount);
		IF vn_StringFormatCount <> cn_StringFormatColumnCount
			 OR vn_StringFormatCount IS NULL
		THEN
			dbms_output.put_line('ERROR> Wrong Data Format! The data found is ''' ||
													 nvl(pis_FileRow, 'Empty Row!') || '''');
			dbms_output.put_line('INFO> Data format should be as: ' || chr(10) ||
													 '''MSISDN|Service_Name|Start_Date|End_Date|Product_Name|Fee'' i.e.''5552550000|Aylik 1 GB Paketi|23.08.2017|23.09.2017|DATA|15''');
		ELSE
			dbms_output.put_line('INFO> Correct format, start execution!');
			ParseFileData(pis_FileRow);
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
				dbms_output.put_line('INFO!> Error occurred with file operation. Please check privileges or file name and/or directory name!');
		END;
		LOOP
			BEGIN
				UTL_FILE.GET_LINE(vt_OutFile, vs_FileRowData);
			
				CheckDataFormat(vs_FileRowData);
			
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
