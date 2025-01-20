/*============================================================================
	File:		01 - restoring Filegroups.sql

	Summary:	This script demonstrates a technique to deal with big databases
				and a small RTO for the writeable part of the database.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		January 2025

	SQL Server Version: >= 2016
	============================================================================
*/
USE master;
GO

/*
	Let's create a demo database which will be used for the restore strategy
*/
EXEC dbo.sp_create_demo_db;
GO

USE demo_db;
GO

DROP TABLE IF EXISTS dbo.orders;
GO

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_orderdate')
	DROP PARTITION SCHEME ps_o_orderdate;
	GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_orderdate')
	DROP PARTITION FUNCTION pf_o_orderdate;
	GO

/*
	Create a demo table which contains for each year 1 dedicated partition
*/
SELECT	[o_orderdate],
		[o_orderkey],
		[o_custkey],
		[o_orderpriority],
		[o_shippriority],
		[o_clerk],
		[o_orderstatus],
		[o_totalprice],
		[o_comment],
		[o_storekey]
INTO	demo_db.dbo.orders
FROM	ERP_Demo.dbo.orders
WHERE	o_orderdate >= '2018-01-01T00:00:00'
		AND o_orderdate < '2024-01-01T00:00:00';
GO

/*
	Now we are planning the partitioning strategy.
	Every partitioned year is on its own filegroup.
	This will give us the possibility to restory the database by year!
*/
-- Create additional filegroups for the partitioned database
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt	NVARCHAR(1024);
DECLARE	@Year	INT	=	2018;
WHILE @Year <= 2023
BEGIN
	SET	@stmt = N'ALTER DATABASE demo_db ADD FileGroup ' + QUOTENAME(N'filegroup_' + CAST(@Year AS NCHAR(4))) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET @stmt = N'ALTER DATABASE demo_db
ADD FILE
(
	NAME = ' + QUOTENAME(N'db_file_' + CAST(@Year AS NCHAR(4)), '''') + N',
	FILENAME = ''' + @DataPath + N'db_file_' + CAST(@Year AS NCHAR(4)) + N'.ndf'',
	SIZE = 64MB,
	FILEGROWTH = 64MB
)
TO FILEGROUP ' + QUOTENAME(N'filegroup_' + CAST(@Year AS NCHAR(4))) + N';';
	RAISERROR ('Statement: %s', 0, 1, @stmt);
	EXEC sys.sp_executeSQL @stmt;

	SET	@Year += 1;
END
GO

/*
	Create the partition function
*/
CREATE PARTITION FUNCTION pf_o_orderdate(DATE)
AS RANGE RIGHT FOR VALUES
(
	'2018-01-01T00:00:00',
	'2019-01-01T00:00:00',
	'2020-01-01T00:00:00',
	'2021-01-01T00:00:00',
	'2022-01-01T00:00:00',
	'2023-01-01T00:00:00'
);
GO

/*
	Create the partition schema
*/
CREATE PARTITION SCHEME [ps_o_orderdate]
AS PARTITION pf_o_orderdate
TO
(
	  [filegroup_2018]
	, [filegroup_2019]
	, [filegroup_2020]
	, [filegroup_2021]
	, [filegroup_2022]
	, [filegroup_2023]
	, [PRIMARY]
)
GO

/*
	After the logical and physical infrastructure is done we can
	move the table onto the partitioned schema
*/
ALTER TABLE dbo.orders
ADD CONSTRAINT pk_orders PRIMARY KEY CLUSTERED
(
	o_orderkey,
	o_orderdate
)
WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE)
ON ps_o_orderdate(o_orderdate)
GO

/*
	When our database is in prodcution the DBA's are facing problems
	with the time to restore the database and the given RTO.
	
	The strategy is to mark all filegroups older than the last two
	years as READONLY.
*/
ALTER DATABASE demo_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DECLARE @I INT = 2018;
DECLARE @stmt NVARCHAR(2000);
WHILE @I < 2022
BEGIN
	SET @stmt = N'ALTER DATABASE [demo_db] MODIFY FILEGROUP filegroup_' + CAST(@I AS NVARCHAR(4)) + N' READONLY;';
	EXEC sp_executesql @stmt;
	SET @I += 1;
END
GO

ALTER DATABASE demo_db SET MULTI_USER;
GO

SELECT	name,
		data_space_id,
		type,
		CASE WHEN is_read_only = 1
			 THEN 'read-only'
			 ELSE 'read-write'
		END		AS	[status]
FROM	demo_db.sys.filegroups;
GO

/*
	A nightmare for the DBA starts and we want to test the RTO for the restore process!
*/
BACKUP DATABASE demo_db 
TO DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH
	STATS,
	INIT,
	FORMAT,
	COMPRESSION;
GO

USE master;
GO

DROP DATABASE demo_db;
GO

/*
	How long will it take to bring the database online again?
*/
SET STATISTICS TIME ON;
GO

RESTORE DATABASE demo_db
FROM DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH
	RECOVERY;
GO

/*
	To make the most important filegroup available we have to restore PRIMARY 
	and ALL readably Filgroups first!
*/
RESTORE DATABASE demo_db READ_WRITE_FILEGROUPS
FROM DISK = N'S:\Backup\demo_db_partitioned_full.bak'
WITH
	PARTIAL,
	RECOVERY;
GO

SELECT file_id,
       type,
       type_desc,
       data_space_id,
       name,
       physical_name,
       state_desc,
       is_read_only,
       is_sparse,
       backup_lsn
FROM demo_db.sys.database_files;
GO

-- Work!
SELECT	[o_orderdate],
		[o_orderkey],
		[o_custkey],
		[o_orderpriority],
		[o_shippriority],
		[o_clerk],
		[o_orderstatus],
		[o_totalprice],
		[o_comment],
		[o_storekey]
FROM	demo_db.dbo.orders
WHERE	o_orderdate >= '2023-01-01T00:00:00'
		AND o_orderDate < '2023-01-02T00:00:00';
GO

/* These kind of queries cannot work because the query needs all partitions */
SELECT	[o_orderdate],
		[o_orderkey],
		[o_custkey],
		[o_orderpriority],
		[o_shippriority],
		[o_clerk],
		[o_orderstatus],
		[o_totalprice],
		[o_comment],
		[o_storekey]
FROM	demo_db.dbo.orders
WHERE	o_custkey = 10;
GO

/* Same with DML! Will not work if you do not cover the partition boundaries! */
UPDATE	demo_db.dbo.orders
SET		o_custkey = 546421
WHERE	o_orderkey = 1169;
GO

/* You must add the partition boundaries to run successfull DML Operations */
UPDATE	demo_db.dbo.orders
SET		o_custkey = 546421
WHERE	o_orderkey = 1169
		AND o_orderdate >= '2023-01-01T00:00:00'
		AND o_orderdate < '2024-01-01T00:00:00';
GO

/* 
	Let's restore the other filegroups without harming the business
*/
DECLARE @I INT = 2018;
DECLARE	@exec_stmt	NVARCHAR(MAX);
DECLARE	@sql_stmt NVARCHAR(MAX) = N'RESTORE DATABASE demo_db
FILEGROUP = N''filegroup_%year%''
FROM DISK = N''S:\Backup\demo_db_partitioned_full.bak''
WITH
	RECOVERY;';

WHILE @I <= 2021
BEGIN
	SET	@exec_stmt = REPLACE(@sql_stmt, '%year%', CAST(@i AS NCHAR(4)));
	PRINT @exec_stmt;
	EXEC sp_executesql @exec_stmt;
	SET @I += 1;
END;
GO

SELECT file_id,
       type,
       type_desc,
       data_space_id,
       name,
       physical_name,
       state_desc,
       is_read_only,
       is_sparse,
       backup_lsn
FROM demo_db.sys.database_files;
GO

/* Clean the environment */
USE master;
GO

ALTER DATABASE demo_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE demo_db;
GO
