/*
	============================================================================
	File:		02 - aggregations in partitioned tables.sql

	Summary:	This script demonstrates the drawback of partitioning when it
				comes to aggregations over all partitions.

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
	We want to have the max value of the orderkey [o_orderkey]
*/
SELECT	MAX(o_orderkey)
FROM	dbo.orders
OPTION	(MAXDOP 1, QUERYTRACEON 9130);
GO

/*
	Let's see whether it is as bad when we use only 1 partition
*/
SELECT	MAX(o_orderkey)
FROM	dbo.orders
WHERE	o_orderdate >= '2020-01-01'
		AND o_orderdate <= '2020-12-31'
OPTION	(MAXDOP 1, QUERYTRACEON 9130);
GO

/*
	What about using not the date (range scan) but the partition_number?
*/
SELECT	MAX(o_orderkey)
FROM	dbo.orders
WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = 12
OPTION	(MAXDOP 1, QUERYTRACEON 9130);
GO

/*
	Finally, we want to summarize our findings into a solution.

	1. Let's walk through each partition to get the max INSIDE the partition
*/
SELECT	DISTINCT p.partition_number,
		agg.max_o_orderkey
FROM	sys.partitions AS p
		CROSS APPLY
		(
			SELECT	MAX(o_orderkey)	AS	max_o_orderkey
			FROM	dbo.orders
			WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = p.partition_number
		) AS agg
WHERE	object_id = OBJECT_ID(N'dbo.orders', N'U')
OPTION	(MAXDOP 1, QUERYTRACEON 9130);
GO

SELECT	MAX(agg.max_o_orderkey) AS	max_o_orderkey
FROM	sys.partitions AS p
		CROSS APPLY
		(
			SELECT	MAX(o_orderkey)	AS	max_o_orderkey
			FROM	dbo.orders
			WHERE	$PARTITION.pf_o_orderdate(o_orderdate) = p.partition_number
		) AS agg
WHERE	object_id = OBJECT_ID(N'dbo.orders', N'U')
OPTION	(MAXDOP 1, QUERYTRACEON 9130);
GO