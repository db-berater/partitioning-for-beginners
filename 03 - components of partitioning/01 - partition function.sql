/*
	============================================================================
	File:		01 - partition function.sql

	Summary:	This script demonstrates the functionality of partition functions
				- creation of a partition function
				- usage of a partition function

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

USE ERP_Demo
GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO

/*
	The first demo shows a partition function based on INT values and
	how they get mapped to a partition
*/
CREATE PARTITION FUNCTION pf_demo(INT)
AS RANGE LEFT FOR VALUES
(1, 10, 100);
GO

;WITH l
AS
(
	SELECT	-10	AS	value

	UNION ALL

	SELECT	[value] + 1
	FROM	l
	WHERE	[value] < 200
)
SELECT	*,
		$PARTITION.pf_demo([value]) AS partition_id
FROM	l
OPTION	(MAXRECURSION 0);
GO

/*
	We drop the partition function and create another partition function
	based on a DATE type!
*/
IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO

CREATE PARTITION FUNCTION pf_demo(DATE)
AS RANGE RIGHT FOR VALUES
(
	'2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01',
	'2024-05-01', '2024-06-01', '2024-07-01', '2024-08-01',
	'2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01'
);
GO

;WITH d
AS
(
	SELECT	CAST('2023-12-31' AS DATE)	AS	[value]
	UNION ALL
	SELECT	DATEADD(DAY, 1, [value])
	FROM	d
	WHERE	[value]< '2024-03-31'
)
SELECT	*,
		$PARTITION.pf_demo([value]) AS partition_id
FROM	d
OPTION	(MAXRECURSION 0);
GO

/*
	See, what happens if the range for the boundary is on the
	LEFT side.
*/
IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO

CREATE PARTITION FUNCTION pf_demo(DATE)
AS RANGE LEFT FOR VALUES
(
	'2024-01-01', '2024-02-01', '2024-03-01', '2024-04-01',
	'2024-05-01', '2024-06-01', '2024-07-01', '2024-08-01',
	'2024-09-01', '2024-10-01', '2024-11-01', '2024-12-01'
);
GO

;WITH d
AS
(
	SELECT	CAST('2023-12-31' AS DATE)	AS	[value]
	UNION ALL
	SELECT	DATEADD(DAY, 1, [value])
	FROM	d
	WHERE	[value]< '2024-03-31'
)
SELECT	*,
		$PARTITION.pf_demo([value]) AS partition_id
FROM	d
OPTION	(MAXRECURSION 0);
GO

/*
	Fix it by adjusting the boundary values!
*/
IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO

CREATE PARTITION FUNCTION pf_demo(DATE)
AS RANGE LEFT FOR VALUES
(
	'2024-01-31', '2024-02-29', '2024-03-31', '2024-04-30',
	'2024-05-31', '2024-06-30', '2024-07-31', '2024-08-31',
	'2024-09-30', '2024-10-31', '2024-11-30', '2024-12-31'
);
GO

;WITH d
AS
(
	SELECT	CAST('2023-12-31' AS DATE)	AS	[value]
	UNION ALL
	SELECT	DATEADD(DAY, 1, [value])
	FROM	d
	WHERE	[value]< '2024-03-31'
)
SELECT	*,
		$PARTITION.pf_demo([value]) AS partition_id
FROM	d
OPTION	(MAXRECURSION 0);
GO

/*
	The following system views (DMV) can be used to investigate
	the current settings:

	- sys.partition_functions
	- sys.partition_parameters
	- sys.partition_range_values
*/
SELECT	name,
		function_id,
		type,
		type_desc,
		fanout,
		boundary_value_on_right,
		is_system,
		create_date,
		modify_date
FROM	sys.partition_functions;
GO

SELECT	PF.name,
		PP.parameter_id,
		PP.system_type_id,
		T.name,
		PP.max_length,
		PP.precision,
		PP.scale,
		PP.collation_name,
		PP.user_type_id
FROM	sys.partition_functions AS PF
		INNER JOIN sys.partition_parameters AS PP
		ON (PF.function_id = PP.function_id)
		INNER JOIN sys.types AS T
		ON (PP.system_type_id = T.system_type_id)
GO

SELECT	PF.type_desc,
		PF.boundary_value_on_right,
		PRV.boundary_id,
		PRV.parameter_id,
		PRV.value
FROM	sys.partition_functions AS PF
		INNER JOIN sys.partition_range_values AS PRV
		ON (PF.function_id = PRV.function_id)
ORDER BY
		PRV.boundary_id;
GO