/*
	============================================================================
	File:		03 - create the partition scheme.sql

	Summary:	This script creates the partitioning schema which is the logical
				representation of the physical layout for the data.

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
	The partition function will be created in a hard coded ways.
	Basically the implementation would be easier when creating the
	partition function with only ONE partition value and extend it
	by using NEXT USE and SPLIT()
*/
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = N'ps_o_orderdate')
	DROP PARTITION SCHEME ps_o_orderdate;
GO

CREATE PARTITION SCHEME ps_o_orderdate AS PARTITION pf_o_orderdate
TO
(
	[PRIMARY], [orders_2010], [orders_2011], [orders_2012], [orders_2013],
	[orders_2014], [orders_2015], [orders_2016], [orders_2017], [orders_2018],
	[orders_2019], [orders_2020], [orders_2021], [orders_2022], [orders_2023]
);
GO

-- Let's combine all information to an overview
SELECT	pf.type_desc,
		fg.name					AS	[FileGroup],
		pf.boundary_value_on_right,
		prv.boundary_id,
		T.name					AS	data_type,
		CASE WHEN pf.boundary_value_on_right = 0
			THEN N'<=' + CAST(prv.value AS NVARCHAR(128))
			ELSE N'>=' + CAST(prv.value AS NVARCHAR(128))
		END		AS	[Value]
FROM	sys.partition_functions AS pf
		INNER JOIN sys.partition_schemes AS ps
		ON (pf.function_id = ps.function_id)
		INNER JOIN sys.destination_data_spaces AS dds
		ON (ps.data_space_id = DDS.partition_scheme_id)
		INNER JOIN sys.filegroups AS fg
		ON (DDS.data_space_id = fg.data_space_id)
		INNER JOIN sys.partition_range_values AS prv
		ON
		(
			pf.function_id = prv.function_id
            AND DDS.destination_id = prv.boundary_id
		)
		INNER JOIN sys.partition_parameters AS pp
		ON (pf.function_id = pp.function_id)
		INNER JOIN sys.types AS t
		ON (pp.system_type_id = t.system_type_id)
ORDER BY
		prv.boundary_id;
GO

SELECT	dds.*,
		fg.name
FROM	sys.partition_functions AS pf
		INNER JOIN sys.partition_schemes AS ps
		ON (pf.function_id = ps.function_id)
		INNER JOIN sys.destination_data_spaces AS dds
		ON (ps.data_space_id = dds.partition_scheme_id)
		INNER JOIN sys.filegroups AS fg
		ON (dds.data_space_id = fg.data_space_id)

SELECT * FROM sys.partition_range_values
