/*
	============================================================================
	File:		02 - optimization of shardened tables.sql

	Summary:	This script uses the previously created view for the selection
				of data and we try to optimize the query with indexes.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

ALTER DATABASE ERP_Demo SET QUERY_STORE CLEAR;
GO

USE ERP_Demo;
GO

/* First test with FULL SCAN to all tables addressed in the view */
SET STATISTICS TIME, IO ON;
GO

SELECT	o_orderdate,
        o_orderkey,
        o_custkey,
        o_orderpriority,
        o_shippriority,
        o_clerk,
        o_orderstatus,
        o_totalprice,
        o_comment
FROM	demo.orders
WHERE	o_orderdate >= '2019-01-01'
		AND o_orderdate < '2019-01-02';
GO

SET STATISTICS TIME, IO OFF;
GO

/*
	For optimization reasons we create a "partitioning index" on the order date
	for a better performance of the query. We create a Clustered index on the
	o_orderdate attribute because this attribute is mostly used in this scenario.
*/
DECLARE	@sql_stmt	NVARCHAR(4000);
DECLARE	c CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR
	SELECT	N'CREATE CLUSTERED INDEX cuix_' + name + N' ON demo.' + QUOTENAME(name) + N'(o_orderdate);'
	FROM	sys.tables
	WHERE	schema_id = SCHEMA_ID(N'demo');

OPEN c;

FETCH NEXT FROM c INTO @sql_stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN TRY
		PRINT @sql_stmt;
		EXEC sp_executesql @sql_stmt;
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE();
	END CATCH
	FETCH NEXT FROM c INTO @sql_stmt;
END

CLOSE c;
DEALLOCATE c;
GO

/*
	The second test seems to be perfect but please note that we have to
	address ALL table objects from within the view.

	Microsoft SQL Server cannot separate the tables by the given date.
	Microsoft SQL Server does not "know" where the data are.
	This can lead to complex problems!

	Start SQLQueryStress and load the template 0010!
*/
SET STATISTICS TIME, IO ON;
GO

SELECT	o_orderdate,
        o_orderkey,
        o_custkey,
        o_orderpriority,
        o_shippriority,
        o_clerk,
        o_orderstatus,
        o_totalprice,
        o_comment
FROM	demo.orders
WHERE	o_orderdate >= '2019-01-01'
		AND o_orderdate < '2019-01-02';
GO

SET STATISTICS TIME, IO OFF;
GO