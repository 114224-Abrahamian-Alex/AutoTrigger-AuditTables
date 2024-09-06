DECLARE @TableName NVARCHAR(128)
DECLARE @ColumnList NVARCHAR(MAX)
DECLARE @PrimaryKey NVARCHAR(128)
DECLARE @InsertColumnList NVARCHAR(MAX)
DECLARE @SelectColumnList NVARCHAR(MAX)
DECLARE @SQL NVARCHAR(MAX)
DECLARE @TriggerSQL NVARCHAR(MAX)

DECLARE TableCursor CURSOR FOR
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME NOT LIKE '%_audit'; -- Excluir tablas de auditor�a

OPEN TableCursor
FETCH NEXT FROM TableCursor INTO @TableName

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ColumnList = (
        SELECT STRING_AGG(COLUMN_NAME + ' ' + DATA_TYPE +
               CASE 
                   WHEN DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar') THEN '(' + 
                        CASE WHEN CHARACTER_MAXIMUM_LENGTH = -1 THEN 'MAX' ELSE CAST(CHARACTER_MAXIMUM_LENGTH AS NVARCHAR) END + ')'
                   WHEN DATA_TYPE IN ('decimal', 'numeric') THEN '(' + CAST(NUMERIC_PRECISION AS NVARCHAR) + ',' + CAST(NUMERIC_SCALE AS NVARCHAR) + ')'
                   ELSE ''
               END, ', ')
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @TableName
    )

    SET @InsertColumnList = (
        SELECT STRING_AGG(COLUMN_NAME, ', ')
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @TableName
    )

    SET @SelectColumnList = @InsertColumnList

    SET @PrimaryKey = (
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_NAME = @TableName
          AND OBJECTPROPERTY(OBJECT_ID(CONSTRAINT_SCHEMA + '.' + CONSTRAINT_NAME), 'IsPrimaryKey') = 1
    )

    SET @SQL = '
    CREATE TABLE ' + @TableName + '_audit (
        ' + @ColumnList + ',
        version INT NOT NULL IDENTITY(1,1),
        PRIMARY KEY(' + @PrimaryKey + ', version)
    );
    '
    EXEC sp_executesql @SQL

    SET @TriggerSQL = '
    CREATE TRIGGER trg_' + @TableName + '_audit
    ON ' + @TableName + '
    AFTER INSERT, UPDATE, DELETE
    AS
    BEGIN
        -- Manejar inserciones
        IF EXISTS(SELECT * FROM INSERTED)
        BEGIN
            INSERT INTO ' + @TableName + '_audit (' + @InsertColumnList + ')
            SELECT ' + @SelectColumnList + '
            FROM INSERTED;
        END

        -- Manejar eliminaciones
        IF EXISTS(SELECT * FROM DELETED)
        BEGIN
            INSERT INTO ' + @TableName + '_audit (' + @InsertColumnList + ')
            SELECT ' + @SelectColumnList + '
            FROM DELETED;
        END
    END;
    '

    EXEC sp_executesql @TriggerSQL

    FETCH NEXT FROM TableCursor INTO @TableName
END

CLOSE TableCursor
DEALLOCATE TableCursor

