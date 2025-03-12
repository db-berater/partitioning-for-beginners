/*
	============================================================================
	File:		01 - distribute data in new table.sql

	Summary:	This script uses the partition function to distribute the
				data from the CustomerOrders table over all partitions

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

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

/*
	Let's create a demo schema first for the new table
*/
IF SCHEMA_ID(N'demo') IS NULL
	EXEC sp_executesql N'CREATE SCHEMA demo AUTHORIZATION dbo;'
	GO

/*
    Heaps can only be published on a schema at the creation time!
    Afterwards you must add a clustered index and remove it again!
*/
DROP TABLE IF EXISTS demo.orders;
GO

CREATE TABLE demo.orders
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
    [o_storekey]        BIGINT      NOT NULL
)
ON ps_o_orderdate (o_orderdate);
GO

/*
	Let's push data from only 1 partition into the new table
*/
INSERT INTO demo.orders WITH (TABLOCK)
(o_orderdate, o_orderkey, o_custkey, o_orderpriority, o_shippriority, o_clerk, o_orderstatus, o_totalprice, o_comment, o_storekey)
SELECT	o_orderdate,
        o_orderkey,
        o_custkey,
        o_orderpriority,
        o_shippriority,
        o_clerk,
        o_orderstatus,
        o_totalprice,
        o_comment,
        o_storekey
FROM	dbo.orders
WHERE	o_orderdate >= '2010-01-01'
		AND o_orderdate <= '2010-12-31';
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
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
FROM	dbo.get_partition_layout_info(N'demo.orders', 0);
GO

/*
    The technique for a clustered index table is the same!
*/
DROP TABLE IF EXISTS demo.orders;
GO

CREATE TABLE demo.orders
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
    [o_storekey]        BIGINT      NOT NULL,

    CONSTRAINT pk_demo_orders PRIMARY KEY CLUSTERED
    (
        o_orderkey
        , o_orderdate
    )
)
ON ps_o_orderdate (o_orderdate);
GO

/* Let's insert the orders from 2011 into the new table */
INSERT INTO demo.orders WITH (TABLOCK)
(o_orderdate, o_orderkey, o_custkey, o_orderpriority, o_shippriority, o_clerk, o_orderstatus, o_totalprice, o_comment, o_storekey)
SELECT	o_orderdate,
        o_orderkey,
        o_custkey,
        o_orderpriority,
        o_shippriority,
        o_clerk,
        o_orderstatus,
        o_totalprice,
        o_comment,
        o_storekey
FROM	dbo.orders
WHERE	o_orderdate >= '2010-01-01'
		AND o_orderdate <= '2013-12-31';
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
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
FROM	dbo.get_partition_layout_info(N'demo.orders', 1);
GO

/*
    Clean the environment for the next demo!
*/
DROP TABLE IF EXISTS demo.orders;
DROP SCHEMA IF EXISTS demo;
GO
