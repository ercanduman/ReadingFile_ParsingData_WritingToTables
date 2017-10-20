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
	cs_WA_NAME                 eduman.billing_global_config.wa_name%TYPE := 'BILLINGSYSTEM';
	cn_StringFormatColumnCount NUMBER := 6;

	gs_OutDirectoryName eduman.billing_global_config.directory_name%TYPE;
	gs_FileSeparator    eduman.billing_global_config.file_separator%TYPE;
	gs_FilePrefix       eduman.billing_global_config.file_prefix%TYPE;
	gs_OutFileName      VARCHAR2(50);

	gs_InvoiceRemarkSuccess eduman.billing_invoices.remark%TYPE := 'Execution SUCCESSFUL!';
	gs_InvoiceRemarkFailure eduman.billing_invoices.remark%TYPE := 'Execution FAILED!';
	gs_InvoiceStatusSuccess eduman.billing_invoices.status%TYPE := 'S';
	gs_InvoiceStatusFailure eduman.billing_invoices.status%TYPE := 'F';

	gs_ExecutionsLogStatus    eduman.billing_inv_wa_log.status%TYPE := 'S';
	gs_ExecutionLogRemark     eduman.billing_inv_wa_log.remark%TYPE := NULL;
	gn_ExecutionsCount        NUMBER := 0;
	gn_ExecutionsFailureCount NUMBER := 0;

	PROCEDURE GetGlobalConfigurations
	/**************************************************************************************************
    * Purpose    : To load all global configuration variables for execution of package.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : N/A
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
	BEGIN
		SELECT file_separator, directory_name, file_prefix
			INTO gs_FileSeparator, gs_OutDirectoryName, gs_FilePrefix
			FROM eduman.billing_global_config
		 WHERE wa_name = cs_WA_NAME;
	
		gs_OutFileName := to_char(SYSDATE, 'ddmmyyyy');
		gs_OutFileName := gs_FilePrefix || gs_OutFileName || '.txt'; -- File format: invoice_23092017.txt
	END GetGlobalConfigurations;

	PROCEDURE u_BillingInvoices(pis_Msisdn   IN VARCHAR,
															pin_GrossFee IN eduman.billing_invoices.gross_fee%TYPE,
															pis_Remark   IN eduman.billing_invoices.remark%TYPE)
	/**************************************************************************************************
    * Purpose    : To update EDUMAN.BILLING_INVOICES table for given msisdn.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pis_Msisdn      : Phone number of user that sent to this procedure.
      - pin_GrossFee    : Calculated fee gross amount.
      - pis_Remark      : Output message for each exectuion status.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 18.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
	BEGIN
		UPDATE eduman.billing_invoices
			 SET gross_fee = pin_GrossFee,
					 remark    = pis_Remark
		 WHERE msisdn = pis_Msisdn;
		COMMIT;
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END u_BillingInvoices;

	PROCEDURE CalculateGrossFee(pios_Msisdn IN OUT VARCHAR,
															pin_Fee     IN NUMBER)
	/**************************************************************************************************
    * Purpose    : To calculate gross fee related to fee amount. load all global variable for execution of package.
    * Notes      : Gets fee amount and tax rates then do the calculation as: gross_fee = ((tax_rates/100) +1 )* fee_amount
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pios_Msisdn : Phone number of user that retrieved from file data.
      - pin_Fee     : The price (fee amount) parsed fom file data.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
		vn_KDVTaxRate    eduman.billing_product_types.kdv_tax_rate%TYPE;
		vn_OIVTaxRate    eduman.billing_product_types.oiv_tax_rate%TYPE;
		vn_GrossFee      eduman.billing_invoices.gross_fee%TYPE := NULL;
		vs_Remark        eduman.billing_invoices.remark%TYPE;
		vb_GrossFeeValid VARCHAR(1) := 'Y';
		vs_ProductName   eduman.billing_invoices.product_name%TYPE;
	BEGIN
		BEGIN
			SELECT DISTINCT kdv_tax_rate, oiv_tax_rate, bi.product_name
				INTO vn_KDVTaxRate, vn_OIVTaxRate, vs_ProductName
				FROM eduman.billing_invoices bi, eduman.billing_product_types bp
			 WHERE bi.product_name = bp.product_name
				 AND msisdn = pios_Msisdn;
		
		EXCEPTION
			WHEN OTHERS THEN
				vb_GrossFeeValid := 'N';
				dbms_output.put_line('ERROR> PRODUCT_NAME ' || vs_ProductName ||
														 'not found in EDUMAN.BILLING_PRODUCT_TYPES table' ||
														 dbms_utility.format_error_backtrace);
		END;
	
		-- Calculate gross fee
		IF vb_GrossFeeValid <> 'N'
		THEN
			vn_GrossFee := (nvl((vn_KDVTaxRate + vn_OIVTaxRate) / 100, 0) + 1) *
										 pin_Fee;
			vs_Remark   := gs_InvoiceRemarkSuccess;
		ELSE
			vn_GrossFee := pin_Fee;
			vs_Remark   := gs_InvoiceRemarkSuccess || CHR(9) ||
										 ' PRODUCT_NAME not found in EDUMAN.BILLING_PRODUCT_TYPES table so calculation of gross_fee is failed!';
		
		END IF;
	
		u_BillingInvoices(pios_Msisdn, vn_GrossFee, vs_Remark);
	END CalculateGrossFee;

	PROCEDURE i_BillingInvoices(pios_Msisdn       IN OUT eduman.billing_invoices.msisdn%TYPE,
															pis_Service       IN eduman.billing_invoices.service_name%TYPE,
															pid_StartDate     IN eduman.billing_invoices.start_date%TYPE,
															pid_EndDate       IN eduman.billing_invoices.end_date%TYPE,
															pis_ProductName   IN eduman.billing_invoices.product_name%TYPE,
															pion_Fee          IN OUT eduman.billing_invoices.fee%TYPE,
															pis_ProcessedData IN eduman.billing_invoices.processed_data%TYPE)
	/**************************************************************************************************
    * Purpose    : Insertion of EDUMAN.BILLING_INVOICES table.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pios_Msisdn       : Phone number of user that parsed from file data.
      - pis_Service       : Service name that parsed from file data.
      - pid_StartDate     : Service start time that parsed from file data.
      - pid_EndDate       : Service end time that parsed from file data. 
      - pis_ProductName   : Product name which can be SES, DATA, VAS etc.
      - pion_Fee          : Fee amount that parsed from file data..
      - pis_ProcessedData : Executed whole data from row of file.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
	
	BEGIN
		INSERT INTO eduman.billing_invoices bi
			(invoice_id,
			 msisdn,
			 service_name,
			 start_date,
			 end_date,
			 product_name,
			 fee,
			 Processed_Data,
			 remark,
			 status,
			 process_time)
		VALUES
			(eduman.seq_billing_invoices_id.nextval,
			 pios_Msisdn,
			 pis_Service,
			 pid_StartDate,
			 pid_EndDate,
			 pis_ProductName,
			 pion_Fee,
			 pis_ProcessedData,
			 gs_InvoiceRemarkSuccess,
			 gs_InvoiceStatusSuccess,
			 SYSDATE);
		COMMIT;
	
		CalculateGrossFee(pios_Msisdn, pion_Fee);
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END i_BillingInvoices;

	PROCEDURE i_BillingInvoices(pis_ProcessedData IN eduman.billing_invoices.processed_data%TYPE)
	/**************************************************************************************************
    * Purpose    : Insertion of EDUMAN.BILLING_INVOICES table.
    * Notes      : There is another procedure with same name but different variables. This an example of procedure overloading. 
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pis_ProcessedData : Executed whole data from file row.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 19.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
	
	BEGIN
	
		INSERT INTO eduman.billing_invoices
			(invoice_id, processed_data, remark, status, process_time)
		VALUES
			(eduman.seq_billing_invoices_id.nextval,
			 pis_ProcessedData,
			 gs_InvoiceRemarkFailure || ' Wrong data format!',
			 gs_InvoiceStatusFailure,
			 SYSDATE);
		COMMIT;
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END i_BillingInvoices;

	PROCEDURE ParseFileData(pios_FileRowData IN OUT VARCHAR2)
	/**************************************************************************************************
    * Purpose    : To parse/split row data and insert in EDUMAN.BILLING_INVOICES table.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pios_FileRowData : Executed whole data from row.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
		vt_FileRowDataArray dbms_sql.varchar2_table;
	BEGIN
	
		FOR i IN 1 .. cn_StringFormatColumnCount
		LOOP
			vt_FileRowDataArray(i) := regexp_substr(pios_FileRowData,
																							'[^' || gs_FileSeparator || ']+',
																							1,
																							i);
		END LOOP;
	
		i_BillingInvoices(vt_FileRowDataArray(1),
											vt_FileRowDataArray(2),
											vt_FileRowDataArray(3),
											vt_FileRowDataArray(4),
											vt_FileRowDataArray(5),
											vt_FileRowDataArray(6),
											pios_FileRowData);
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END ParseFileData;

	PROCEDURE CheckDataFormat(pios_FileRowData IN OUT VARCHAR2)
	/**************************************************************************************************
    * Purpose    : To checking data format for retrieved row data from file.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pios_FileRowData : Executed whole data from row.
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 18.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
		vn_StringFormatCount NUMBER := 0;
		vs_ProcessedData     eduman.billing_invoices.processed_data%TYPE;
	BEGIN
		vn_StringFormatCount := REGEXP_COUNT(pios_FileRowData, '[^|]+', 1, 'i');
	
		vs_ProcessedData := nvl(pios_FileRowData, 'Empty Row!');
	
		IF vn_StringFormatCount <> cn_StringFormatColumnCount
			 OR vn_StringFormatCount IS NULL
		THEN
			gn_ExecutionsFailureCount := gn_ExecutionsFailureCount + 1;
		
			dbms_output.put_line('ERROR> Wrong Data Format! The data found is ''' ||
													 vs_ProcessedData || '''');
			dbms_output.put_line('INFO> Data format should be as: ' || chr(10) ||
													 '''MSISDN|Service_Name|Start_Date|End_Date|Product_Name|Fee'' i.e.''5552550000|Aylik 1 GB Paketi|23.08.2017|23.09.2017|DATA|15''');
		
			i_BillingInvoices(vs_ProcessedData);
			dbms_output.put_line('INFO> gn_ExecutionsFailureCount ' ||
													 gn_ExecutionsFailureCount);
		ELSE
		
			ParseFileData(pios_FileRowData);
		END IF;
	
	END CheckDataFormat;

	PROCEDURE ReadFileData
	/**************************************************************************************************
    * Purpose    : To read whole file and retrieve data.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : N/A
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
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
				gn_ExecutionsCount := gn_ExecutionsCount + 1;
			
				CheckDataFormat(vs_FileRowData);
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					IF vs_FileRowData IS NOT NULL
					THEN
						dbms_output.put_line('INFO> All data loaded!');
					ELSE
						dbms_output.put_line('ERROR> File is Empty!');
						gs_ExecutionsLogStatus := 'F';
						gs_ExecutionLogRemark  := gs_InvoiceRemarkFailure ||
																			' File is Empty!';
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

	PROCEDURE i_BillingInvoicesWALog(pit_ExecutionStartTime IN eduman.billing_inv_wa_log.proc_start_date%TYPE)
	/**************************************************************************************************
    * Purpose    : To Insertion of EDUMAN.BILLING_INV_WA_LOG table.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
      - pit_ExecutionStartTime  : Start time of package execution
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 19.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
	
	BEGIN
		IF gn_ExecutionsCount IS NOT NULL
		THEN
			gn_ExecutionsCount := gn_ExecutionsCount - gn_ExecutionsFailureCount;
		
			IF gn_ExecutionsCount > 0
			THEN
				gs_ExecutionLogRemark := gn_ExecutionsCount || ' SUCCESSFUL';
			END IF;
		
			IF gn_ExecutionsFailureCount > 0
			THEN
				gs_ExecutionLogRemark := gs_ExecutionLogRemark || CHR(9) ||
																 gn_ExecutionsFailureCount || ' FAILURE';
			END IF;
		END IF;
	
		INSERT INTO EDUMAN.BILLING_INV_WA_LOG
			(inv_log_id, proc_start_date, proc_end_date, status, remark)
		VALUES
			(eduman.seq_billing_inv_wa_log_id.nextval,
			 pit_ExecutionStartTime,
			 systimestamp,
			 gs_ExecutionsLogStatus,
			 gs_ExecutionLogRemark);
		COMMIT;
	
		-- Reset constants at the end
		gn_ExecutionsFailureCount := 0;
		gn_ExecutionsCount        := 0;
		gs_ExecutionLogRemark     := NULL;
	
	END i_BillingInvoicesWALog;

	PROCEDURE StartToProcess
	/**************************************************************************************************
    * Purpose    : The main procedure which apply all configurations and start execution.
    * Notes      : N/A
    * -------------------------------------------------------------------------------------
    * Parameters : 
    * Return     : N/A
    * Exceptions : N/A
    * -------------------------------------------------------------------------------------
    * History    :
     | Author                 | Date                | Purpose
     |-------                 |-----------          |----------------------------------------------
     | Ercan DUMAN            | 17.10.2017          | Procedure creation.
    **************************************************************************************************/
	 IS
		vt_ExecutionStartTime eduman.billing_inv_wa_log.proc_start_date%TYPE;
	
	BEGIN
		vt_ExecutionStartTime := systimestamp;
	
		GetGlobalConfigurations;
	
		ReadFileData;
	
		i_BillingInvoicesWALog(vt_ExecutionStartTime);
	
		dbms_output.put_line('INFO> Run successfully!');
	END StartToProcess;
END BILLINGSYSTEM;
/
