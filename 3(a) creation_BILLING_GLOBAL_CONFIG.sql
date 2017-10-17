create table EDUMAN.BILLING_GLOBAL_CONFIG (
	file_separator VARCHAR2(5),
	Directory_Name VARCHAR2(20),
	file_prefix    VARCHAR(20),
	WA_Name        VARCHAR(50)
);
  
--table comment
comment on table EDUMAN.BILLING_GLOBAL_CONFIG  is 'Stores all configurations for package execution.';

--column comments
comment on column EDUMAN.BILLING_GLOBAL_CONFIG.file_separator is 'file_separator attribute defines the character value that put between text of file data.';
comment on column EDUMAN.BILLING_GLOBAL_CONFIG.Directory_Name is 'Directory_Name attribute defines the file path that file indexed.';
comment on column EDUMAN.BILLING_GLOBAL_CONFIG.file_prefix is 'file_prefix attribute defines the extra text which will be added to the beginning of created file (i.e. invoice_230917.txt  -> invoice_ is the prefix part )';
comment on column EDUMAN.BILLING_GLOBAL_CONFIG.WA_Name is 'WA_Name attribute defines project package name to get corresponding data.';

