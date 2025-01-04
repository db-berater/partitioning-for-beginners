/*
	============================================================================
	File:		01 - Preparation.sql

	Summary:	This script is part of the demonstration of Partitioning with
				sharded tables within the same database. It prepares a demo
				schema [demo] with one table / year.

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

RAISERROR ('Creating necessary indexes on dbo.orders for better performance of the preparation phase...', 0, 1) WITH NOWAIT;
GO
EXEC dbo.sp_create_indexes_orders
	@column_list = N'o_orderkey, o_orderdate';
GO

IF SCHEMA_ID(N'demo') IS NULL
BEGIN
	RAISERROR ('Creating the schema [demo] as container for sharded tables', 0, 1) WITH NOWAIT;
	EXEC sp_executesql N'CREATE SCHEMA demo AUTHORIZATION dbo;';
END
GO

/*
	Let's create a temporary table with all available years from
	dbo.customers.
*/
DROP TABLE IF EXISTS #available_years;
CREATE TABLE #available_years
(
	a_year		INT				NOT NULL PRIMARY KEY CLUSTERED,
	a_sql_stmt	NVARCHAR(4000)	NOT NULL
);
GO

INSERT INTO #available_years(a_year, a_sql_stmt)
SELECT DISTINCT
		YEAR(o_orderdate),
		N'DROP TABLE IF EXISTS [demo].[orders_%aj%];

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
INTO	[demo].[orders_%aj%]
FROM	dbo.orders
WHERE	o_orderdate >= DATEFROMPARTS(%aj%, 1, 1)
		AND o_orderdate <= DATEFROMPARTS(%aj%, 12, 31);
		
ALTER TABLE [demo].[orders_%aj%] ADD CONSTRAINT pk_orders_%aj%
PRIMARY KEY NONCLUSTERED (o_orderkey)
WITH (DATA_COMPRESSION = PAGE, SORT_IN_TEMPDB = ON);'
FROM dbo.orders;
GO

UPDATE	#available_years
SET		a_sql_stmt = REPLACE(a_sql_stmt, N'%aj%', CAST(a_year AS NCHAR(4)));
GO

/*
	A "manual" partitioning by OrderYear requires a separate table for each order year
	from 2010 up 2023 we create a table for each year in a cursor!
*/
RAISERROR ('Creating the tables in [demo] schema', 0, 1) WITH NOWAIT;
GO

DECLARE	@sql_stmt	NVARCHAR(4000);
DECLARE	c CURSOR LOCAL READ_ONLY FORWARD_ONLY
FOR
	SELECT	a_sql_stmt
	FROM	#available_years
	ORDER BY
			a_year;

OPEN c;

FETCH NEXT FROM c INTO @sql_stmt;
WHILE @@FETCH_STATUS <> -1
BEGIN
	EXEC sys.sp_executesql @sql_stmt;

	FETCH NEXT FROM c INTO @sql_stmt;
END

CLOSE c;
DEALLOCATE c;
GO

/*
	when all tables are created an access object (view) gets created which covers
	all entities with a UNION ALL operation.
*/
RAISERROR ('Creating a covering view for access to the sharded tables', 0, 1) WITH NOWAIT;
GO

CREATE OR ALTER VIEW demo.orders
AS
	SELECT * FROM demo.Orders_2010
	UNION ALL
	SELECT * FROM demo.Orders_2011
	UNION ALL
	SELECT * FROM demo.Orders_2012
	UNION ALL
	SELECT * FROM demo.Orders_2013
	UNION ALL
	SELECT * FROM demo.Orders_2014
	UNION ALL
	SELECT * FROM demo.Orders_2015
	UNION ALL
	SELECT * FROM demo.Orders_2016
	UNION ALL
	SELECT * FROM demo.Orders_2017
	UNION ALL
	SELECT * FROM demo.Orders_2018
	UNION ALL
	SELECT * FROM demo.Orders_2019
	UNION ALL
	SELECT * FROM demo.Orders_2020
	UNION ALL
	SELECT * FROM demo.Orders_2021
	UNION ALL
	SELECT * FROM demo.Orders_2022
	UNION ALL
	SELECT * FROM demo.Orders_2023
GO