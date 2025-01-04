/*
	============================================================================
	File:		03 - CHECK Constraints.sql

	Summary:	With CHECK Constraints we can limit the access to the shardend
				tables based on the tables which fulfill the CHECK condition!

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
USE ERP_Demo;
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

--/*
--	Open SQLQueryStress and load the template 0010 - SQLQueryStress - template.json
--	and start the process.
--	Come back to this screen and execute the UPDATE statment.
--	See what happens in SQLQueryStress!
--*/
--BEGIN TRANSACTION
--GO
--	UPDATE	demo.orders_2018
--	SET		o_shippriority = 1
--	WHERE	o_orderkey = 22572525;
--	GO

--ROLLBACK TRANSACTION;
--GO

/*
	To let SQL Server know that there are constraints on the valid date in the tables,
	use CHECK constraints.
*/
DECLARE	@sql_stmt	NVARCHAR(4000);
DECLARE c CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR
	WITH l
	AS
	(
		SELECT	name,
				TRY_CAST(RIGHT(name, 4) AS INT)		AS c_year,
				TRY_CAST(RIGHT(name, 4) AS INT) + 1 AS n_year
		FROM	sys.tables
		WHERE	schema_id = SCHEMA_ID(N'demo')
	)
	SELECT	N'ALTER TABLE demo.' + QUOTENAME(name) + 
	N' ADD CONSTRAINT chk_' + name + N' CHECK (o_orderdate >= ' + QUOTENAME(CAST(DATEFROMPARTS(c_year, 1, 1) AS NCHAR(10)), '''') + 
	N' AND o_orderdate <= ' + QUOTENAME(CAST(DATEFROMPARTS(c_year, 12, 31) AS NCHAR(10)), '''') + N');'
	FROM	l;

OPEN c
FETCH NEXT FROM c INTO @sql_stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN TRY
		EXEC sp_executesql @sql_stmt;
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE()
	END CATCH

	FETCH NEXT FROM c INTO @sql_stmt;
END

CLOSE c;
DEALLOCATE c;
GO

/*
	With the last test we should get a good result because SQL Server can
	now eliminate the access to tables which are not used for a given
	date and time!
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