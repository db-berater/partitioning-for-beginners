/*
	============================================================================
	File:		04 - truncate and remove an existing partition.sql

	Summary:	This script demonstrates how to truncate an existing
				partition.

	Date:		December 2024

	SQL Server Version: >=SQL 2016
	============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
GO

/*
	The business don't want to have data older than 10 years
	We shall remove all data older than 10 years from the actual
	year.
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', N'1')
GO

/*
	Before we can remove a filegroup and associated database file
	the partition must be empty!
	This can be done by migrating data into another partition or
	by truncating the data from the partition.

	Deleting can be:
	- TRUNCATE TABLE dbo.orders WITH (PARTITIONS(x));
		!!! Available since SQL 2016 !!!!
*/

/*
	Example 2:	We truncate data of the year 2011 and
				afterwards we drop the partition
*/

/*
	To identify the partition which holds the data for 2011
	we can use the internal function $PARTITION:

	https://learn.microsoft.com/en-us/sql/t-sql/functions/partition-transact-sql
*/
BEGIN TRANSACTION delete_data
GO
	DECLARE	@partition_number	INT = $PARTITION.pf_o_orderdate('2011-01-01');
	SELECT	@partition_number;

	TRUNCATE TABLE dbo.orders WITH (PARTITIONS(@partition_number));
	
	SELECT	resource_type,
            index_id,
            resource_description,
            request_mode,
            request_type,
            request_status,
            request_session_id,
            blocking_session_id
	FROM	dbo.get_locking_status(@@SPID);

	/*
		Now we can MERGE two partitions into ONE partition
	*/
	ALTER PARTITION FUNCTION pf_o_orderdate() MERGE RANGE ('2011-01-01');
COMMIT TRANSACTION delete_data;
GO

/*
	Let's remove the physical representation of the partitioned table
*/
ALTER DATABASE [ERP_Demo] REMOVE FILE [orders_2011];
ALTER DATABASE [ERP_Demo] REMOVE FILEGROUP [orders_2011];
GO

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
FROM	dbo.get_partition_layout_info(N'dbo.orders', N'1')
GO