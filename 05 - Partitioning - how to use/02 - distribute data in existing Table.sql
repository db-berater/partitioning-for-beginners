/*
	============================================================================
	File:		02 - distribute data in existing Table.sql

	Summary:	This script uses the partition function to distribute the
				data from the dbo.orders table over all partitions

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
	Let's move the existing table dbo.orders on the partition layout
*/
EXEC dbo.sp_drop_indexes
	@table_name = N'dbo.orders',
    @check_only = 0;
GO

/*
    This is a preparation step to make sure that the table dbo.orders
    is on the PRIMARY filegroup without any partitioning
*/
IF 
(
    SELECT  COUNT_BIG(*)
    FROM    sys.indexes AS i
            INNER JOIN sys.partitions AS p
            ON
            (
                i.object_id = p.object_id
                AND i.index_id = p.index_id
            )
    WHERE   i.object_id = OBJECT_ID(N'dbo.orders', N'U')
            AND i.index_id = 0
) > 1
BEGIN
    /* Move the table on the PRIMARY filegroup by adding a clustered index */
    CREATE UNIQUE CLUSTERED INDEX cuix_orders_o_orderkey
    ON dbo.orders (o_orderkey)
    WITH (SORT_IN_TEMPDB = ON)
    ON [PRIMARY];

    /* Now the table is not partitioned anymore and we can drop the index */
    DROP INDEX cuix_orders_o_orderkey ON dbo.orders;
END
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 0);
GO

/*
    Paritioning a HEAP table requires only the creation of a clustered index
    on the partition scheme!

    If you want to have the HEAP table back just drop the Clustered Index afterwards!
*/
ALTER TABLE dbo.orders
ADD CONSTRAINT pk_orders PRIMARY KEY CLUSTERED
(
	o_orderkey,
	o_orderdate
)
WITH (SORT_IN_TEMPDB = ON)
ON ps_o_orderdate(o_orderdate)
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 1);
GO

/*
    To revert it back to a HEAP just drop the Primary Key / Clustered Index
*/
ALTER TABLE dbo.orders
DROP CONSTRAINT pk_orders;
GO

/*
    The used function is part of the framework of the demo database ERP_Demo.
    Download: https://www.db-berater.de/downloads/ERP_DEMO_2012.BAK
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 0);
GO

/*
    This is a preparation step to make sure that the table dbo.orders
    is on the PRIMARY filegroup without any partitioning
*/
IF 
(
    SELECT  COUNT_BIG(*)
    FROM    sys.indexes AS i
            INNER JOIN sys.partitions AS p
            ON
            (
                i.object_id = p.object_id
                AND i.index_id = p.index_id
            )
    WHERE   i.object_id = OBJECT_ID(N'dbo.orders', N'U')
            AND i.index_id = 0
) > 1
BEGIN
    /* Move the table on the PRIMARY filegroup by adding a clustered index */
    CREATE UNIQUE CLUSTERED INDEX cuix_orders_o_orderkey
    ON dbo.orders (o_orderkey)
    WITH (SORT_IN_TEMPDB = ON)
    ON [PRIMARY];

    /* Now the table is not partitioned anymore and we can drop the index */
    DROP INDEX cuix_orders_o_orderkey ON dbo.orders;
END
GO

/*
    Columnstore Index is more complex because the data must be available
    by the partition key!
*/
CREATE CLUSTERED COLUMNSTORE INDEX cci_orders_o_orderdate
ON dbo.orders
ON ps_o_orderdate(o_orderdate);
GO

/*
    Step 1: Create a clustered index on the partition scheme!
*/
CREATE CLUSTERED INDEX cuix_orders_o_orderdate ON dbo.orders (o_orderdate)
ON ps_o_orderdate(o_orderdate);
GO

/*
    Step 2: Remove the clustered index! The Heap will stay on the partition scheme.
*/
DROP INDEX cuix_orders_o_orderdate ON dbo.orders;
GO

/*
    Step 3: Create the columnstore index on the partition scheme.
*/
CREATE CLUSTERED COLUMNSTORE INDEX cci_orders_o_orderdate
ON dbo.orders
ON ps_o_orderdate(o_orderdate);
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', NULL);
GO

/*
    Remove all indexes from dbo.orders for the next demo!
*/
EXEC dbo.sp_drop_indexes
	@table_name = N'dbo.orders',
    @check_only = 0;
GO

/* Although we removed all indexes the table stays partitioned! */
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', 0);
GO