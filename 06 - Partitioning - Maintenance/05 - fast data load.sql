/*
	============================================================================
	File:		0075 - Maintenance - Fast Data Load.sql

	Summary:	This script demonstrates how to use the SWITCH command to
				insert new data into a partitioned table

	Date:		September 2024

	SQL Server Version: >= 2016
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
FROM	dbo.get_partition_info(N'dbo.orders', 1);
GO

/*
	Customers want to add data for a new partition into the table.
	There are big problems when it comes to the LOAD process

	- We create a new Filegroup and a database file
	- we SPLIT() the partition function to add the year 2025
*/
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = N'orders_2025')
	ALTER DATABASE ERP_Demo ADD FILEGROUP [orders_2025];
	GO

IF NOT EXISTS (SELECT * FROM sys.master_files WHERE database_id = DB_ID() AND name = N'orders_2025')
BEGIN
	DECLARE	@default_path	NVARCHAR(128) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(128));
	DECLARE	@sql_stmt		NVARCHAR(2048) = N'
ALTER DATABASE ERP_Demo
ADD FILE
(
	NAME = N''orders_2025'',
	FILENAME = ''' + @default_path + N'orders_2025.ndf'',
	SIZE = 1024MB,
	FILEGROWTH = 1024MB
)
TO FILEGROUP [orders_2025];';
	EXEC sp_executesql @sql_stmt;
END
GO

ALTER PARTITION SCHEME ps_o_orderdate NEXT USED [orders_2025];
GO

/*
	After adding the new filegroup to the schema it will not be used
	until we change the partition function to route everything from
	the year 2024 into a new partition.
*/
ALTER PARTITION FUNCTION pf_o_orderdate() SPLIT RANGE ('2025-01-01');
GO

DROP INDEX nix_orders_o_custkey ON dbo.orders;
SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.orders', N'U');

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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 1);
GO

/*
	Prepare the data in UploadData table
*/
UPDATE	ud
SET		ud.o_orderdate = DATEFROMPARTS(2025, MONTH(ud.o_orderdate), DAY(ud.o_orderdate))
FROM	dbo.UploadData AS ud
WHERE	(
			ud.o_orderdate >= '1992-03-01'
			AND ud.o_orderdate <= '1992-12-31'
		)
		AND ud.o_orderdate <> '1992-02-29'
GO


/*
	Let's import 50.000 rows into the new partition!
*/
BEGIN TRANSACTION insert_partition_data
GO
	;WITH source
	AS
	(
		SELECT	TOP (50000)
				o_orderdate									AS	o_orderdate,
				ROW_NUMBER() OVER (ORDER BY o_orderdate)	AS o_orderkey,
				o_custkey,
				o_orderpriority,
				o_shippriority,
				o_clerk,
				o_orderstatus,
				o_totalprice,
				o_comment
		FROM	dbo.UploadData
		WHERE	o_orderdate >= '2025-01-01'
				AND o_orderdate <= '2025-12-31'
	)
	INSERT INTO dbo.orders
	(o_orderdate, o_orderkey, o_custkey, o_orderpriority, o_shippriority, o_clerk, o_orderstatus, o_totalprice, o_comment)
	SELECT	source.o_orderdate,
			last_number.max_o_orderkey + source.o_orderkey,
			source.o_custkey,
			source.o_orderpriority,
			source.o_shippriority,
			source.o_clerk,
			source.o_orderstatus,
			source.o_totalprice,
			source.o_comment
	FROM	source
			CROSS APPLY
			(
				SELECT	MAX(o_orderkey) AS max_o_orderkey
				FROM	dbo.orders
			) AS last_number;
	GO

	SELECT	DISTINCT
			resource_type,
            index_id,
            resource_description,
            request_mode,
            request_type,
            request_status,
            request_session_id,
            blocking_session_id
	FROM	dbo.get_locking_status(@@SPID)
	WHERE	resource_type IN(N'OBJECT', N'HOBT', N'EXTENT')
			AND resource_description NOT IN (N'get_locking_status', N'sysrowsets')
	ORDER BY
			resource_type DESC;

	SELECT * FROM dbo.get_partition_layout_info(N'dbo.orders', 1)

	SELECT	@@TRANCOUNT;
ROLLBACK;
GO

/*
	To optimize loads without locking the whole table it is
	mandatory to set LOCK_ESCALATION to AUTO!
*/
ALTER TABLE dbo.orders
SET	(LOCK_ESCALATION = AUTO);
GO

BEGIN TRANSACTION insert_partition_data
GO
	;WITH source
	AS
	(
		SELECT	TOP (50000)
				DATEFROMPARTS(2025, MONTH(o_orderdate), DAY(o_orderdate))	AS	o_orderdate,
				ROW_NUMBER() OVER (ORDER BY o_orderdate)					AS o_orderkey,
				o_custkey,
				o_orderpriority,
				o_shippriority,
				o_clerk,
				o_orderstatus,
				o_totalprice,
				o_comment
		FROM	dbo.UploadData
		WHERE	o_orderdate >= '1992-01-01'
				AND o_orderdate <= '1992-12-31'
	)
	INSERT INTO dbo.orders
	(o_orderdate, o_orderkey, o_custkey, o_orderpriority, o_shippriority, o_clerk, o_orderstatus, o_totalprice, o_comment)
	SELECT	source.o_orderdate,
			last_number.max_o_orderkey + source.o_orderkey,
			source.o_custkey,
			source.o_orderpriority,
			source.o_shippriority,
			source.o_clerk,
			source.o_orderstatus,
			source.o_totalprice,
			source.o_comment
	FROM	source
			CROSS APPLY
			(
				SELECT	MAX(o_orderkey) AS max_o_orderkey
				FROM	dbo.orders
			) AS last_number;
	GO

	SELECT	DISTINCT
			resource_type,
            index_id,
            resource_description,
            request_mode,
            request_type,
            request_status,
            request_session_id,
            blocking_session_id
	FROM	dbo.get_locking_status(@@SPID)
	WHERE	resource_type IN (N'OBJECT', N'HoBT');

	SELECT	@@TRANCOUNT;
ROLLBACK;
GO