/*
	============================================================================
	File:		02 - delete an existing partition.sql

	Summary:	This script demonstrates how to delete an existing
				partition.

				THIS SCRIPT IS PART OF THE TRACK:
					Session - Introduction to Partitioning

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
	by deleting the data from the partition.

	Deleting can be:
	- DELETE from dbo.orders WHERE ...
	- TRUNCATE TABLE dbo.orders WITH (PARTITIONS(x));
		Available since SQL 2016!
*/

/*
	Example 1:	We delete all data for the year 2010 and afterwards
				we drop the partition
*/
BEGIN TRANSACTION delete_data
GO
	DELETE	dbo.orders
	WHERE	o_orderdate >= '2010-01-01'
			AND o_orderdate <= '2010-12-31';
	GO

	SELECT	resource_type,
            index_id,
            resource_description,
            request_mode,
            request_type,
            request_status,
            request_session_id,
            blocking_session_id
	FROM	dbo.get_locking_status(@@SPID);
	GO

	/*
		Now we can MERGE two partitions into ONE partition
	*/
	ALTER PARTITION FUNCTION pf_o_orderdate() MERGE RANGE ('2010-01-01');
COMMIT TRANSACTION delete_data;
GO

/*
	Let's remove the physical representation of the partitioned table
*/
ALTER DATABASE [ERP_Demo] REMOVE FILE [orders_2010];
ALTER DATABASE [ERP_Demo] REMOVE FILEGROUP [orders_2010];
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