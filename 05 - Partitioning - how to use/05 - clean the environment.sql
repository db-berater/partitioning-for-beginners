USE ERP_Demo;
GO

DROP TABLE IF EXISTS demo.regions;
DROP TABLE IF EXISTS demo.nations;
DROP TABLE IF EXISTS demo.customers;
GO

DROP TABLE IF EXISTS demo.orders;
GO

DROP SCHEMA IF EXISTS demo;
GO

/*
	Clean the kitchen before we go to the next chapter
*/
IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.orders', N'U') AND name = N'nix_orders_o_custkey')
	DROP INDEX nix_orders_o_custkey ON dbo.orders;
	GO