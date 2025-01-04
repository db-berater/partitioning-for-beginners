/*
	============================================================================
	File:		01 - add a new partition.sql

	Summary:	This script demonstrates how to add another new partition
				for new values to an existing partitioned table

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/*
	The business wants to add new data from the year 2024 in the
	table dbo.orders. Due to the fact that every year should stay
	in a dedicated partition we must add another partition to the
	table.

	This script walks step by step through the process.
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 1);
GO

/*
	The last partition is for the year 2023.
	If we add new data from 2024 they all will go into this
	partition.
	To prevent this we add a new partition for 2024
	- new filegroup
	- new database file
	- split the partition function for the new year
*/
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = N'orders_2024')
BEGIN
	ALTER DATABASE ERP_Demo
	ADD FILEGROUP [orders_2024];

	ALTER DATABASE ERP_Demo
	ADD FILE
	(
		NAME = N'orders_2024',
		FILENAME = N'F:\MSSQL16.SQL_2022\MSSQL\DATA\orders_2024.ndf',
		SIZE = 1024MB,
		FILEGROWTH = 1024MB
	)
	TO FILEGROUP [orders_2024];
END
GO

/*
	Because the partition infrastructure does not know about the new
	filegroup it must be addes to the schema (not the function).

	NOTE:	The schema is the logical presentation of the database
			and points to the physical representation!
*/
ALTER PARTITION SCHEME ps_o_orderdate NEXT USED [orders_2024];
GO

/*
	After adding the new filegroup to the schema it will not be used
	until we change the partition function to route everything from
	the year 2024 into a new partition.
*/
ALTER PARTITION FUNCTION pf_o_orderdate() SPLIT RANGE ('2024-01-01');
GO

/*
	See the results of the METADATA-Operation...
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 1);
GO

/*
	Now we push ~400k rows into the dbo.orders table and check
	afterwards where the data are stored.
*/
;WITH source
AS
(
	SELECT	DATEFROMPARTS(2024, MONTH(o_orderdate), DAY(o_orderdate))	AS	o_orderdate,
			ROW_NUMBER() OVER (ORDER BY o_orderdate)					AS o_orderkey,
			o_custkey,
			o_orderpriority,
			o_shippriority,
			o_clerk,
			o_orderstatus,
			o_totalprice,
			o_comment,
			0		AS	o_storekey
	FROM	dbo.UploadData
	WHERE	o_orderdate >= '1992-01-01'
			AND o_orderdate <= '1992-12-31'
)
INSERT INTO dbo.orders WITH (TABLOCK)
(o_orderdate, o_orderkey, o_custkey, o_orderpriority, o_shippriority, o_clerk, o_orderstatus, o_totalprice, o_comment, o_storekey)
SELECT	source.o_orderdate,
        last_number.max_o_orderkey + source.o_orderkey,
		source.o_custkey,
        source.o_orderpriority,
        source.o_shippriority,
        source.o_clerk,
        source.o_orderstatus,
        source.o_totalprice,
        source.o_comment,
		source.o_storekey
FROM	source
		CROSS APPLY
		(
			SELECT	MAX(o_orderkey) AS max_o_orderkey
			FROM	dbo.orders
		) AS last_number;
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 1);
GO