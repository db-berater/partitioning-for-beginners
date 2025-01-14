/*
	============================================================================
	File:		02 - Example of partition schemes.sql

	Summary:	This script demonstrates the different scenarios
				for the usage of partition schemes

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

	Date:		December 2024

	SQL Server Version: >= 2024
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/*
	We want to make sure no objects from earlier demos are present
*/
DROP TABLE IF EXISTS dbo.demo_table;
GO

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_demo')
	DROP PARTITION SCHEME ps_demo;
	GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO

/*
	Let's start with the partition function which will separate
	three different value ranges into partitions
*/
CREATE PARTITION FUNCTION pf_demo (INT)
AS RANGE RIGHT FOR VALUES (1, 10, 100);
GO

/*
	For simplification we put all partition keys to only ONE filegroup
*/
CREATE PARTITION SCHEME ps_demo
AS PARTITION pf_demo
ALL TO ([PRIMARY]);
GO

/*
	Now we create a new table which uses the partition scheme as
	default logical storage component for the data
*/
CREATE TABLE dbo.demo_table
(
	c_custkey	BIGINT		NOT NULL,
	c_name		VARCHAR(25)	NOT NULL,
	c_partKey	INT			NOT NULL,

	CONSTRAINT pk_c_custkey PRIMARY KEY CLUSTERED
	(
		c_custkey,
		c_partKey
	)
	ON ps_demo (c_partkey)
)
ON ps_demo (c_partkey);
GO

SELECT * FROM dbo.get_partition_layout_info(N'dbo.demo_table', 1)
GO


/*
	Follow the next steps to demonstrate how partitioning works:

	- create the stored procedure below
	- open Windows Admin Center and load the template 01 - partitioning loading
	- execute the stored procedure
*/
CREATE OR ALTER PROCEDURE dbo.partition_demo
	@number_of_rows	BIGINT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE	@actual_number	BIGINT = 0;
	DECLARE	@counter_01		INT;
	DECLARE	@counter_02		INT;
	DECLARE	@counter_03		INT;
	DECLARE	@counter_04		INT;

	WHILE @actual_number < = @number_of_rows
	BEGIN
		INSERT INTO dbo.demo_table
		(c_custkey, c_name, c_partKey)
		SELECT	c_custkey, c_name, c_custkey % 200
		FROM	dbo.customers
		WHERE	c_custkey = @actual_number;

		SELECT	@counter_01 = [1],
				@counter_02 = [2],
				@counter_03 = [3],
				@counter_04 = [4]
		FROM	
		(
			SELECT	partition_number,
					rows
			FROM	sys.partitions
			WHERE	object_id = OBJECT_ID(N'dbo.demo_table', N'U')
		) AS x
		PIVOT
		(
			MAX(rows)
			FOR partition_number IN ([1], [2], [3], [4])
		) AS p;

		/*
			Update the user counters which represent the 4 partitions
		*/
		dbcc setinstance ('SQLServer:User Settable', 'Query', 'User counter 1', @counter_01);
		dbcc setinstance ('SQLServer:User Settable', 'Query', 'User counter 2', @counter_02);
		dbcc setinstance ('SQLServer:User Settable', 'Query', 'User counter 3', @counter_03);
		dbcc setinstance ('SQLServer:User Settable', 'Query', 'User counter 4', @counter_04);

		SET	@actual_number += 1;
	END
END
GO

/*
	Now we can run the procedure with 25.000 rows
	Make sure that all counters are reset to the value 0!
*/
TRUNCATE TABLE dbo.demo_table
GO

DBCC SETINSTANCE ('SQLServer:User Settable', 'Query', 'User counter 1', 0);
DBCC SETINSTANCE ('SQLServer:User Settable', 'Query', 'User counter 2', 0);
DBCC SETINSTANCE ('SQLServer:User Settable', 'Query', 'User counter 3', 0);
DBCC SETINSTANCE ('SQLServer:User Settable', 'Query', 'User counter 4', 0);
GO

/* Now we start the stored procedure and insert 10,000 rows */
EXEC dbo.partition_demo @number_of_rows = 10000;
GO

/*
	How many rows do we have in each partition?
*/
SELECT	[1],
		[2],
		[3],
		[4]
FROM	
(
	SELECT	partition_number,
			rows
	FROM	sys.partitions
	WHERE	object_id = OBJECT_ID(N'dbo.demo_table', N'U')
) AS x
PIVOT
(
	MAX(rows)
	FOR partition_number IN ([1], [2], [3], [4])
) AS p;

/*
	Let's have a look into the table
*/
SELECT	*
		, $PARTITION.pf_demo(c_partkey)	AS partition_number
FROM	dbo.demo_table
ORDER BY
		c_custkey ASC;
GO

-- Let's combine all information to an overview
SELECT	PF.type_desc,
		F.name					AS	[FileGroup],
		PF.boundary_value_on_right,
		PRV.boundary_id,
		T.name					AS	data_type,
		CASE WHEN PF.boundary_value_on_right = 0
			THEN N'<=' + CAST(PRV.value AS NVARCHAR(128))
			ELSE N'>=' + CAST(PRV.value AS NVARCHAR(128))
		END		AS	[Value]
FROM	sys.partition_functions AS PF
		INNER JOIN sys.partition_schemes AS PS
		ON (PF.function_id = PS.function_id)
		INNER JOIN sys.destination_data_spaces AS DDS
		ON (PS.data_space_id = DDS.partition_scheme_id)
		INNER JOIN sys.filegroups AS F
		ON (DDS.data_space_id = F.data_space_id)
		INNER JOIN sys.partition_range_values AS PRV
		ON
		(
			PF.function_id = PRV.function_id
            AND DDS.destination_id = PRV.boundary_id
		)
		INNER JOIN sys.partition_parameters AS PP
		ON (PF.function_id = PP.function_id)
		INNER JOIN sys.types AS T
		ON (PP.system_type_id = T.system_type_id)
ORDER BY
		PRV.boundary_id;
GO

/*
	And clean the database from the demo objects
*/
DROP TABLE IF EXISTS dbo.demo_table;
GO

IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_demo')
	DROP PARTITION SCHEME ps_demo;
	GO

IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = N'pf_demo')
	DROP PARTITION FUNCTION pf_demo;
	GO