/*
	============================================================================
	File:		04 - querying partitioned tables.sql

	Summary:	This script shows several examples how to optimize querying 
				data from a partitioned table.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DBCC TRACEON (3604);
GO

USE ERP_Demo;
GO

/*
	Let's first check the partitioning information of dbo.orders table!
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
	The table has only a clustered index which is definied as follows:
	- PRIMARY KEY
		- o_orderkey
		- o_orderdate
	- Partition Key
		- o_orderdate
*/

/*
	Example of partition eliminiation when only dedicated paritions will be used
*/
SET STATISTICS IO, TIME ON;
GO

/*
	Full scan because there is no predicate!

	Table 'orders'.
		Scan count 13,
		logical reads 385285,
		...

	SQL Server Execution Times:
		CPU time = 40282 ms,  elapsed time = 11479 ms.
*/
SELECT	DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
GROUP BY
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 4);
GO

/*
	If we do the same query for a dedicated partition range we 
	will generate less IO!

	Table 'orders'.
		Scan count 7,
		logical reads 21072

	SQL Server Execution Times:
		CPU time = 1438 ms,  elapsed time = 394 ms.
*/
SELECT	DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
WHERE	o_orderdate > = '2019-01-01'
		AND o_orderdate <= '2019-12-31'
GROUP BY
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 4);
GO

/*
	Partition eliminiation will/can not work if we run queries
	with predicates against other attributes.
*/
SELECT	o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
/* This predicate does not have an index */
WHERE	o_custkey <= 10
GROUP BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 4, QUERYTRACEON 9130);
GO

/*
	... so we create an index on o_custkey with the expectation to 
	have a better performance.
*/
CREATE NONCLUSTERED INDEX nix_orders_o_custkey
ON dbo.orders (o_custkey)
WITH (SORT_IN_TEMPDB = ON);
GO

/*
	Let's run the query again to see what happens.

	Table 'orders'.
		Scan count 13,
		logical reads 36,

	SQL Server Execution Times:
		CPU time = 16 ms,  elapsed time = 42 ms.
*/
SELECT	o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
/* This predicate does not have an index */
WHERE	o_custkey <= 10
GROUP BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 4, QUERYTRACEON 9130);
GO

SELECT	o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
WHERE	o_custkey <= 10
		AND o_orderdate >= '2020-01-01'
		AND o_orderdate <= '2020-12-31'
GROUP BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 6, QUERYTRACEON 9130);
GO

/*
	For optimization you must have a non partitioned index.
	NOTE: Non aligned indexes cannot work with partition SWITCHes
*/
CREATE NONCLUSTERED INDEX nix_orders_o_custkey
ON dbo.orders (o_custkey)
WITH (SORT_IN_TEMPDB = ON, DROP_EXISTING = ON)
ON [PRIMARY];
GO

/*
	Table 'orders'.
		Scan count 1,
		logical reads 3,

	SQL Server Execution Times:
		CPU time = 0 ms,  elapsed time = 42 ms.
*/
SELECT	o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
WHERE	o_custkey <= 10
GROUP BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 6);
GO

SELECT	o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)	AS	order_year,
		COUNT_BIG(*)						AS	order_records
FROM	dbo.orders
WHERE	o_custkey <= 10
		AND o_orderdate >= '2020-01-01'
		AND o_orderdate <= '2020-12-31'
GROUP BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
ORDER BY
		o_custkey,
		DATE_BUCKET(YEAR, 1, o_orderdate)
OPTION	(MAXDOP 6);
GO