/*
	============================================================================
	File:		01 - distribute data in existing table.sql

	Summary:	This script uses the partition function to distribute the
				data from the dbo.orders table over all partitions

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >=2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/*
	Let's move the existing table dbo.orders on the partition layout
*/
EXEC dbo.sp_drop_indexes
	@table_name = N'dbo.orders',
    @check_only = 0;
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

/*
	To move the rows of a table in a partition schema you only have to
	remove (if exist) an existing clustered index and recreate it 
	- as Primary Key
	- as native clustered index
	on the partition scheme.
*/
ALTER TABLE dbo.orders
ADD CONSTRAINT pk_orders PRIMARY KEY CLUSTERED
(
	o_orderkey,
	o_orderdate
)
WITH (SORT_IN_TEMPDB = ON)
ON ps_o_orderdate(o_orderdate)
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