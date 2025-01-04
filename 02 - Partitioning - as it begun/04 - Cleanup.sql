/*
	Clean the kitchen
*/
USE ERP_Demo;
GO


DECLARE	@sql_stmt NVARCHAR(4000);
DECLARE	c CURSOR LOCAL READ_ONLY FORWARD_ONLY
FOR
	SELECT	N'DROP TABLE IF EXISTS demo.' + QUOTENAME(t.name) + N';'
	FROM	sys.tables AS t
	WHERE	t.schema_id = SCHEMA_ID(N'demo');

OPEN c;

FETCH NEXT FROM c INTO @sql_stmt;
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC sp_executesql @sql_stmt;
	FETCH NEXT FROM c INTO @sql_stmt;
END

CLOSE c;
DEALLOCATE c;
GO

DROP VIEW IF EXISTS demo.orders;
DROP SCHEMA IF EXISTS demo;
GO
