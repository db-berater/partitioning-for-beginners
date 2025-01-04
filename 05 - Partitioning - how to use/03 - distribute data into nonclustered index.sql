/*
	============================================================================
	File:		03 - distribute data into nonclustered index.sql

	Summary:	This script takes the demo.orders table with a clustered primary
				key for this demos

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

IF EXISTS
(
	SELECT	*
	FROM	sys.indexes AS i
	WHERE	i.name = N'nix_demo_orders_o_custkey'
			AND i.object_id = OBJECT_ID(N'demo.orders', N'U')
)
	DROP INDEX nix_demo_orders_o_custkey ON demo.orders;
	GO


/*
	The request is an index on the o_custkey which includes the o_totalprice
	for a report.

	NOTE: The partition scheme has not been named explicitly!
*/
CREATE NONCLUSTERED INDEX nix_demo_orders_o_custkey
ON demo.orders (o_custkey)
INCLUDE (o_totalprice)
WITH (SORT_IN_TEMPDB = ON);
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
*/
;WITH i
AS
(
	SELECT	index_id
	FROM	sys.indexes
	WHERE	object_id = OBJECT_ID(N'demo.orders', N'U')
			AND name = N'nix_demo_orders_o_custkey'
)
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
FROM	i
		CROSS APPLY dbo.get_partition_layout_info(N'demo.orders', i.index_id);
GO

/*
	Let's check the performance of the query by selecting an
	aggregate for a dedicated customer.
*/
SET STATISTICS IO, TIME ON;
GO

SELECT	o_custkey,
		SUM(o_totalprice)	AS	sum_totalprice
FROM	demo.orders
WHERE	o_custkey = 1467419
GROUP BY
		o_custkey;
GO

SET STATISTICS IO, TIME ON;
GO

/*
	If an index should NOT be partitioned you must recreate in in a 
	non partitioned filegroup!
*/
CREATE NONCLUSTERED INDEX nix_demo_orders_o_custkey
ON demo.orders
(
	o_custkey
)
INCLUDE (o_totalprice)
WITH (SORT_IN_TEMPDB = ON, DROP_EXISTING = ON)
ON [PRIMARY];
GO

SET STATISTICS IO, TIME ON;
GO

SELECT	o_custkey,
		SUM(o_totalprice)	AS	sum_totalprice
FROM	demo.orders
WHERE	o_custkey = 1467419
GROUP BY
		o_custkey;
GO

SET STATISTICS IO, TIME ON;
GO

/*
	We can clean the kitchen here because a new chapter starts
*/
DROP TABLE IF EXISTS demo.orders;
GO

