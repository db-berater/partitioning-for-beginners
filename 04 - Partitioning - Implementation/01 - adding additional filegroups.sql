/*
	============================================================================
	File:		01 - adding additional filegroups.sql

	Summary:	This script is used to prepare the logical implementation
				for the goal to partition the dbo.orders table by the
				o_orderyear column.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >=2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
USE ERP_Demo;
GO

/*
	Let's first collect all available years we have in the dbo.orders table
*/
DROP TABLE IF EXISTS #available_years;
GO

CREATE TABLE #available_years (o_orderyear INT NOT NULL PRIMARY KEY CLUSTERED);
GO

INSERT INTO #available_years(o_orderyear)
SELECT	DISTINCT YEAR(o_orderdate)
FROM	dbo.orders;
GO

SELECT * FROM #available_years;

/*
	For the implementation of the different filegroups we put all
	database files in the default location of the database files.
*/
DECLARE	@DataPath	NVARCHAR(256) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(256));

DECLARE	@stmt		NVARCHAR(1024);
DECLARE	@min_year	INT	=	(SELECT	MIN(o_orderyear) FROM #available_years);
DECLARE	@max_year	INT	=	(SELECT MAX(o_orderyear) FROM #available_years);

WHILE @min_year <= @max_year
BEGIN
	BEGIN TRY
		SET	@stmt = N'ALTER DATABASE ERP_Demo ADD FileGroup ' + QUOTENAME(N'orders_' + CAST(@min_year AS NCHAR(4))) + N';';

		RAISERROR ('Statement: %s', 0, 1, @stmt);
		EXEC sys.sp_executeSQL @stmt;

		SET @stmt = N'ALTER DATABASE ERP_Demo
	ADD FILE
	(
		NAME = ' + QUOTENAME(N'orders_' + CAST(@min_year AS NCHAR(4)), '''') + N',
		FILENAME = ''' + @DataPath + N'orders_' + CAST(@min_year AS NCHAR(4)) + N'.ndf'',
		SIZE = 1024MB,
		FILEGROWTH = 1024MB
	)
	TO FILEGROUP ' + QUOTENAME(N'orders_' + CAST(@min_year AS NCHAR(4))) + N';';

		RAISERROR ('Statement: %s', 0, 1, @stmt);
		EXEC sys.sp_executeSQL @stmt;
	END TRY
	BEGIN CATCH
		PRINT ERROR_MESSAGE();
	END CATCH

	SET	@min_year += 1;
END
GO

-- Cross check
SELECT	fg.name				AS	filegroup_name,
		fg.type_desc		AS	filegroup_description,
		mf.name				AS	file_logical_name,
		mf.physical_name	AS	file_physical_location,
		FORMAT
		(
			mf.size / 128,
			'#,##0 MB',
			N'en-us'
		)					AS	size_mb
FROM	sys.filegroups AS fg
		INNER JOIN sys.master_files AS mf
		ON (FG.data_space_id = mf.data_space_id)
WHERE	mf.database_id = DB_ID(N'ERP_Demo');
GO