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

	gs_InvoiceRemarkSuccess   eduman.billing_invoices.remark%TYPE := 'Execution SUCCESSFUL!';
	gs_InvoiceRemarkFailure   eduman.billing_invoices.remark%TYPE := 'Execution FAILED!';
	gs_InvoiceStatusSuccess   eduman.billing_invoices.status%TYPE := 'S';
	gs_InvoiceStatusFailure   eduman.billing_invoices.status%TYPE := 'F';
	gn_ExecutionsCount        NUMBER := 0;
	gn_ExecutionsFailureCount NUMBER := 0;

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
															vn_GrossFee IN OUT eduman.billing_invoices.gross_fee%TYPE,
															pis_Remark  IN eduman.billing_invoices.remark%TYPE) IS
	BEGIN
		UPDATE eduman.billing_invoices
			 SET gross_fee = vn_GrossFee,
					 remark    = pis_Remark
		 WHERE msisdn = vs_Msisdn;
		COMMIT;
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END u_BillingInvoices;

	PROCEDURE CalculateGrossFee(vs_Msisdn IN OUT VARCHAR,
															pin_Fee   IN OUT NUMBER) IS
	
		vn_KDVTaxRate    eduman.billing_product_types.kdv_tax_rate%TYPE;
		vn_OIVTaxRate    eduman.billing_product_types.oiv_tax_rate%TYPE;
		vn_GrossFee      eduman.billing_invoices.gross_fee%TYPE := NULL;
		vs_Remark        eduman.billing_invoices.remark%TYPE;
		vb_GrossFeeValid VARCHAR(1) := 'Y';
	
	BEGIN
		BEGIN
			SELECT DISTINCT kdv_tax_rate, oiv_tax_rate
				INTO vn_KDVTaxRate, vn_OIVTaxRate
				FROM eduman.billing_invoices bi, eduman.billing_product_types bp
			 WHERE bi.product_name = bp.product_name
				 AND msisdn = vs_Msisdn;
		
		EXCEPTION
			WHEN OTHERS THEN
				vb_GrossFeeValid := 'N';
				dbms_output.put_line('ERROR> PRODUCT_NAME not found in EDUMAN.BILLING_PRODUCT_TYPES table. ' ||
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
										 ' PRODUCT_NAME not found in EDUMAN.BILLING_PRODUCT_TYPES table';
		
		END IF;
	
		u_BillingInvoices(vs_Msisdn, vn_GrossFee, vs_Remark);
	END CalculateGrossFee;

	PROCEDURE i_BillingInvoices(vs_Msisdn         IN OUT eduman.billing_invoices.msisdn%TYPE,
															vs_Service        IN eduman.billing_invoices.service_name%TYPE,
															vd_StartDate      IN eduman.billing_invoices.start_date%TYPE,
															vd_EndDate        IN eduman.billing_invoices.end_date%TYPE,
															vs_ProductName    IN eduman.billing_invoices.product_name%TYPE,
															pin_Fee           IN OUT eduman.billing_invoices.fee%TYPE,
															pis_ProcessedData IN eduman.billing_invoices.processed_data%TYPE) IS
	
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
			 vs_Msisdn,
			 vs_Service,
			 vd_StartDate,
			 vd_EndDate,
			 vs_ProductName,
			 pin_Fee,
			 pis_ProcessedData,
			 gs_InvoiceRemarkSuccess,
			 gs_InvoiceStatusSuccess,
			 SYSDATE);
		COMMIT;
	
		CalculateGrossFee(vs_Msisdn, pin_Fee);
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END i_BillingInvoices;

	PROCEDURE i_BillingInvoices(vs_ProcessedData IN eduman.billing_invoices.processed_data%TYPE) IS
	BEGIN
		INSERT INTO eduman.billing_invoices
			(invoice_id, processed_data, remark, status, process_time)
		VALUES
			(eduman.seq_billing_invoices_id.nextval,
			 vs_ProcessedData,
			 gs_InvoiceRemarkFailure || ' Wrong data format!',
			 gs_InvoiceStatusFailure,
			 SYSDATE);
		COMMIT;
	
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
	
		i_BillingInvoices(vt_FileRowDataArray(1),
											vt_FileRowDataArray(2),
											vt_FileRowDataArray(3),
											vt_FileRowDataArray(4),
											vt_FileRowDataArray(5),
											vt_FileRowDataArray(6),
											pis_FileRowData);
	
	EXCEPTION
		WHEN OTHERS THEN
			dbms_output.put_line('ERROR> ' || SQLERRM ||
													 dbms_utility.format_error_backtrace);
	END ParseFileData;

	PROCEDURE CheckDataFormat(pis_FileRow IN OUT VARCHAR2) IS
		vn_StringFormatCount NUMBER := 0;
		vs_ProcessedData     eduman.billing_invoices.processed_data%TYPE;
	BEGIN
		vn_StringFormatCount := REGEXP_COUNT(pis_FileRow, '[^|]+', 1, 'i');
	
		vs_ProcessedData := nvl(pis_FileRow, 'Empty Row!');
	
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
				gn_ExecutionsCount := gn_ExecutionsCount + 1;
			
				CheckDataFormat(vs_FileRowData);
				dbms_output.put_line('INFO> gn_ExecutionsCount ' ||
														 gn_ExecutionsCount);
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

	PROCEDURE i_BillingInvoicesWALog(vt_ExecutionStartTime IN OUT eduman.billing_inv_wa_log.proc_start_date%TYPE) IS
		vs_ExectuionRemark eduman.billing_inv_wa_log.remark%TYPE;
	
	BEGIN
		IF gn_ExecutionsCount IS NOT NULL
		THEN
			gn_ExecutionsCount := gn_ExecutionsCount - gn_ExecutionsFailureCount;
		
			IF gn_ExecutionsCount > 0
			THEN
				vs_ExectuionRemark := gn_ExecutionsCount || ' SUCCESSFUL';
			END IF;
		
			IF gn_ExecutionsFailureCount > 0
			THEN
				vs_ExectuionRemark := vs_ExectuionRemark || CHR(9) ||
															gn_ExecutionsFailureCount || ' FAILURE.';
			END IF;
		END IF;
	
		INSERT INTO eduman.billing_inv_wa_log
			(inv_log_id, proc_start_date, proc_end_date, status, remark)
		VALUES
			(eduman.seq_billing_inv_wa_log_id.nextval,
			 vt_ExecutionStartTime,
			 systimestamp,
			 gs_InvoiceStatusSuccess,
			 vs_ExectuionRemark);
		COMMIT;
	
		-- Reset counts
		gn_ExecutionsFailureCount := 0;
		gn_ExecutionsCount        := 0;
	END i_BillingInvoicesWALog;

	PROCEDURE StartToProcess IS
		vt_ExecutionStartTime eduman.billing_inv_wa_log.proc_start_date%TYPE;
	
	BEGIN
		vt_ExecutionStartTime := systimestamp;
	
		GetGlobalConfigurations;
	
		ReadFileData;
	
		i_BillingInvoicesWALog(vt_ExecutionStartTime);
	
	END StartToProcess;
END BILLINGSYSTEM;
/
