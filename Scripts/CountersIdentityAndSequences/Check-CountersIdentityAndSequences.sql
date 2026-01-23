-- Run in each project collection database. Read-only.

GO
DROP TABLE IF EXISTS #CounterIdentSeq
GO
CREATE TABLE #CounterIdentSeq 
(ObjectType    VARCHAR(20),  -- tbl_Counter, Identity Column, Sequence
PartitionId    INT,
DataspaceId    INT,
ObjectName     NVARCHAR(1000),
ObjectDataType VARCHAR(20),
IncrementValue INT,
MinimumValue   BIGINT,
MaximumValue   BIGINT,
CurrentValue   BIGINT,
PercentageUsed INT)

GO

-- Get the tbl_Counters data
INSERT #CounterIdentSeq (ObjectType,   
                         PartitionId, 
                         DataspaceId,  
                         ObjectName,    
                         ObjectDataType,
                         IncrementValue,
                         MinimumValue, 
                         MaximumValue, 
                         CurrentValue,
                         PercentageUsed)
SELECT  'tbl_Counter' AS ObjectType,
        TC.PartitionId AS PartitionId,
        TC.DataspaceId AS DataspaceId,
        TC.CounterName AS ObjectName,
        'int' AS ObjectDataType,
        1 AS IncrementValue,
        1 AS MinimumValue,
        2147483647 AS MaximumValue,
        TC.CounterValue AS CurrentValue,
        ((TC.CounterValue * 100) / 2147483647) AS PercentageUsed
FROM    dbo.tbl_Counter TC
WHERE   PartitionId > 0


-- Get the Identity Columns data
;WITH IdentityColumns
AS
(
    SELECT  SCHEMA_NAME(TN.schema_ID) AS SchemaName,
            OBJECT_NAME (IC.object_id) AS TableName,
            IC.name AS ColumnName,
            TYPE_NAME(IC.system_type_id) AS ColumnDataType,
            IC.seed_value IdentitySeed,
            IC.increment_value AS IdentityIncrement,
            IC.last_value As LastValue,
            DBPS.row_count AS NumberOfRows,
            DBPS.partition_number AS PartitionId
    FROM    sys.identity_columns IC
    JOIN    sys.tables TN
    ON      IC.object_id = TN.object_id
    JOIN    sys.dm_db_partition_stats DBPS
    ON      DBPS.object_id = IC.object_id
            AND DBPS.index_id in (0,1)      
    WHERE   DBPS.row_count > 0
)
INSERT #CounterIdentSeq (ObjectType,   
                         PartitionId, 
                         DataspaceId,  
                         ObjectName,    
                         ObjectDataType,
                         IncrementValue,
                         MinimumValue, 
                         MaximumValue, 
                         CurrentValue,
                         PercentageUsed)
SELECT    'Identity Column' AS ObjectType,
          PartitionId,
          NULL AS DataspaceId,
          SchemaName + '.' + TableName + '.' + ColumnName AS ObjectName,
          ColumnDataType AS ObjectDataType,
          CAST(IdentityIncrement AS int) AS IncrementValue,
          CASE ColumnDataType
              WHEN 'tinyint' THEN -127
              WHEN 'smallint' THEN -32767
              WHEN 'int' THEN -2147483647
              WHEN 'bigint' THEN -9223372036854775807
              ELSE 1
          END AS MinimumValue,
          CASE ColumnDataType
              WHEN 'tinyint' THEN 127
              WHEN 'smallint' THEN 32767
              WHEN 'int' THEN 2147483647
              WHEN 'bigint' THEN 9223372036854775807
              ELSE 1
          END AS MaximumValue,
          CAST(LastValue AS bigint) AS CurrentValue,
          NULL AS PercentageUsed
FROM      IdentityColumns
GROUP BY  SchemaName,
          TableName,
          ColumnName,
          ColumnDataType,
          IdentitySeed,
          IdentityIncrement,
          PartitionId,
          LastValue
HAVING    PartitionId > 0

-- Get the sys.sequences data
INSERT #CounterIdentSeq (ObjectType,   
                         PartitionId, 
                         DataspaceId,  
                         ObjectName,    
                         ObjectDataType,
                         IncrementValue,
                         MinimumValue, 
                         MaximumValue, 
                         CurrentValue,
                         PercentageUsed)
SELECT  'sys.sequences' AS ObjectType,
        0 AS PartitionId,
        0 AS DataspaceId,
        name AS ObjectName,
        TYPE_NAME(system_type_id) AS ColumnDataType,
        CAST(increment AS int) AS IncrementValue,
        CAST(minimum_value AS BIGINT) AS MinimumValue,
        CAST(maximum_value AS BIGINT) AS MaximumValue,
        CAST(current_value AS BIGINT) AS CurrentValue,
        null AS PercentageUsed
FROM    sys.sequences ss

UPDATE #CounterIdentSeq
SET PercentageUsed = CASE 
                         WHEN IncrementValue < 0 THEN ABS(((CurrentValue * 100) / MinimumValue))
                         WHEN IncrementValue > 0 THEN ABS(((CurrentValue * 100) / MaximumValue))
                         END 
WHERE PercentageUsed IS NULL

SELECT * FROM #CounterIdentSeq WHERE PercentageUsed > 50 ORDER BY PercentageUsed DESC
