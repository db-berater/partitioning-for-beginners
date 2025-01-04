/*
	============================================================================
	File:		03 - switch out an existing partition.sql

	Summary:	This script demonstrates how to switch out an existing
				partition.

	Date:		December 2024

	SQL Server Version: >=SQL 2016
------------------------------------------------------------------------------
	Written by Uwe Ricken, db Berater GmbH

	This script is intended only as a supplement to demos and lectures
	given by Uwe Ricken.  
  
	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
	TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/*
	The business don't want to have data older than 10 years
	We shall remove all data older than 10 years from the actual
	year.
*/
SELECT	[Schema.Table],
        [Index ID],
        Structure,
        [Index],
        rows,
        [In-Row MB],
        [LOB MB],
        [Partition #],
        [Partition Function],
        [Boundary Type],
        [Boundary Point],
        Filegroup
FROM	dbo.get_partition_layout_info(N'dbo.orders', N'1')
GO

/*
	Before we can remove a filegroup and associated database file
	the partition must be empty!
	This can be done by migrating data into another partition or
	by truncating the data from the partition.

	Deleting can be:
	- SWITCH OUT a partition from a table
*/

/*
	Example 2:	We truncate data of the year 2011 and
				afterwards we drop the partition
*/

/*
	To identify the partition which holds the data for 2011
	we can use the internal function $PARTITION:

	https://learn.microsoft.com/en-us/sql/t-sql/functions/partition-transact-sql
*/

/*
	For a SWITCH OUT we must have an identical table for the partition
	which needs to be switched out.
	It is mandatory that the short term table is on the same partition scheme!
*/
IF SCHEMA_ID(N'switch') IS NULL
	EXEC sp_executesql N'CREATE SCHEMA switch AUTHORIZATION dbo;'
	GO

DROP TABLE IF EXISTS switch.orders;
GO

CREATE TABLE switch.orders
(
	[o_orderdate]		DATE		NOT NULL,
	[o_orderkey]		BIGINT		NOT NULL,
	[o_custkey]			BIGINT		NOT NULL,
	[o_orderpriority]	CHAR(15)	NULL,
	[o_shippriority]	INT			NULL,
	[o_clerk]			CHAR(15)	NULL,
	[o_orderstatus]		CHAR(1)		NULL,
	[o_totalprice]		MONEY		NULL,
	[o_comment]			VARCHAR(79)	NULL,
	[o_storekey]		BIGINT		NOT NULL
)
ON ps_o_orderdate (o_orderdate);
GO

/*
	Again we need to know the partition number of data from 2012
*/
DECLARE	@partition_number	INT = $PARTITION.pf_o_orderdate('2011-01-01');
SELECT	@partition_number;

ALTER TABLE dbo.orders SWITCH PARTITION @partition_number TO switch.orders PARTITION @partition_number;
GO

/*
	This statement fails because one of the requirements is the identical
	aligned indexes on both tables!
*/
ALTER TABLE switch.orders
ADD CONSTRAINT pk_switch_orders PRIMARY KEY CLUSTERED
(
	o_orderkey,
	o_orderdate
);
GO

BEGIN TRANSACTION switch_data
GO
	DECLARE	@partition_number	INT = $PARTITION.pf_o_orderdate('2011-01-01');
	SELECT	@partition_number;

	ALTER TABLE dbo.orders SWITCH PARTITION @partition_number TO switch.orders PARTITION @partition_number;
	
	SELECT	DISTINCT
			resource_type,
            index_id,
            resource_description,
            request_mode,
            request_type,
            request_status,
            request_session_id,
            blocking_session_id
	FROM	dbo.get_locking_status(@@SPID);

	/*
		Now we can MERGE two partitions into ONE partition
	*/
	ALTER PARTITION FUNCTION pf_o_orderdate() MERGE RANGE ('2012-01-01');
COMMIT TRANSACTION delete_data;
GO

DROP TABLE IF EXISTS switch.orders;
GO

/*
	Let's remove the physical representation of the partitioned table
*/
ALTER DATABASE [ERP_Demo] REMOVE FILE [orders_2012];
ALTER DATABASE [ERP_Demo] REMOVE FILEGROUP [orders_2012];
GO

SELECT	[Schema.Table],
        [Index ID],
        Structure,
        [Index],
        rows,
        [In-Row MB],
        [LOB MB],
        [Partition #],
        [Partition Function],
        [Boundary Type],
        [Boundary Point],
        Filegroup
FROM	dbo.get_partition_layout_info(N'dbo.orders', N'1')
GO
