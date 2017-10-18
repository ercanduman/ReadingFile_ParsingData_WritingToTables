create table EDUMAN.BILLING_INV_WA_LOG (
		   inv_log_id         NUMBER primary key,
		   proc_start_date    timestamp,
		   proc_end_date      timestamp,
		   Status             VARCHAR2(1),
		   Remark             VARCHAR2(3000)
);

--table comment
comment on table EDUMAN.BILLING_INV_WA_LOG  is 'Stores all executions log info.';

--column comments
comment on column EDUMAN.BILLING_INV_WA_LOG.inv_log_id is 'inv_log_id attribute defines unique identifier and primary key of BILLING_INV_WA_LOG table.';
comment on column EDUMAN.BILLING_INV_WA_LOG.proc_start_date is 'proc_start_date attribute defines execution start time (in timestamp).';
comment on column EDUMAN.BILLING_INV_WA_LOG.proc_end_date is 'proc_end_date attribute defines execution end time (in timestamp).';
comment on column EDUMAN.BILLING_INV_WA_LOG.Status is 'Status attribute defines the status of execution: (S)Success (F)Fail.';
comment on column EDUMAN.BILLING_INV_WA_LOG.Remark is 'Remark attribute defines the remark and count of invoices processed.';

--instead of writing Operand_id values one by one, a sequence created
CREATE sequence EDUMAN.seq_BILLING_INV_WA_log_id start with 1 increment by 1 cache 10 order nocycle;

-- CONSTRAINT
ALTER TABLE EDUMAN.BILLING_INV_WA_LOG ADD CONSTRAINT CK_BILLING_INV_WA_STATUS CHECK ( STATUS IN ('S', 'F'));

