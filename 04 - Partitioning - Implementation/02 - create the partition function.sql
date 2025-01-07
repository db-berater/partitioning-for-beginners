/*
	============================================================================
	File:		02 - create the partition function.sql

	Summary:	This script creates the partitioning function for the definition
				of the boundaries for each year.

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
	Let's evaluate all available years first so we can than easily extend our
	partition function with the next year
*/
DROP TABLE IF EXISTS #available_years;
GO

CREATE TABLE #available_years
(
	o_orderyear INT NOT NULL PRIMARY KEY CLUSTERED,
	min_value_right_bound AS DATEFROMPARTS(o_orderyear, 1, 1),
	max_value_left_bound  AS DATEFROMPARTS(o_orderyear, 12, 31)
	);
GO

INSERT INTO #available_years(o_orderyear)
SELECT	DISTINCT YEAR(o_orderdate)
FROM	dbo.orders;
GO

SELECT * FROM #available_years;
GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_o_orderdate')
	DROP PARTITION FUNCTION pf_o_orderdate;
GO

DECLARE	@min_orderdate DATE = (SELECT MIN(min_value_right_bound) FROM #available_years);
DECLARE	@max_orderdate DATE = (SELECT MAX(min_value_right_bound) FROM #available_years);

WHILE	@min_orderdate <= @max_orderdate
BEGIN
	IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_o_orderdate')
		CREATE PARTITION FUNCTION pf_o_orderdate (DATE)
		AS RANGE RIGHT FOR VALUES (@min_orderdate);
	ELSE
		ALTER PARTITION FUNCTION pf_o_orderdate()
		SPLIT RANGE (@min_orderdate);
		
	SET	@min_orderdate = DATEADD(YEAR, 1, @min_orderdate);
END
GO

/*
	Let's check the proper configuration of the partition function
	with all correct boundaries.
*/
SELECT	pf.type_desc,
		pf.boundary_value_on_right,
		prv.boundary_id,
		prv.parameter_id,
		CASE WHEN pf.boundary_value_on_right = 1
			THEN '>='
			ELSE '<='
		END							AS	range_definition,
		prv.value
FROM	sys.partition_functions AS pf
		INNER JOIN sys.partition_range_values AS prv
		ON (pf.function_id = prv.function_id)
WHERE	pf.name = N'pf_o_orderdate'
ORDER BY
		prv.boundary_id;
GO