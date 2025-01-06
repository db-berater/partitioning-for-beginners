SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

USE ERP_Demo;
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
FROM	dbo.get_partition_layout_info(N'dbo.orders', N'1')
GO

/*
    The partition you want to switch out is on a filegroup.

*/
IF SCHEMA_ID(N'switch') IS NULL
	EXEC sp_executesql N'CREATE SCHEMA switch AUTHORIZATION dbo;'
	GO

DROP TABLE IF EXISTS switch.orders;
GO

CREATE TABLE switch.orders
(
	[o_orderdate]		DATE		NOT NULL,
	[o_orderkey]		BIGINT		NOT NULL,
	[o_custkey]			BIGINT		NOT NULL,
	[o_orderpriority]	CHAR(15)	NULL,
	[o_shippriority]	INT			NULL,
	[o_clerk]			CHAR(15)	NULL,
	[o_orderstatus]		CHAR(1)		NULL,
	[o_totalprice]		MONEY		NULL,
	[o_comment]			VARCHAR(79)	NULL,
	[o_storekey]		BIGINT		NOT NULL,

    CONSTRAINT pk_switch_orders PRIMARY KEY CLUSTERED
    (
        o_orderkey,
        o_orderdate
    )
)
ON [orders_2013]
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

ALTER TABLE dbo.orders SWITCH PARTITION 2 TO switch.orders;
ALTER PARTITION FUNCTION pf_o_orderdate() MERGE RANGE ('2013-01-01');
DROP TABLE IF EXISTS switch.orders;
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