CREATE PROCEDURE [dbo].[GeneratePKs]
AS 
DECLARE @tab nvarchar(10), @crlf nvarchar(10), 
	@crlftab nvarchar(10)

SET NOCOUNT ON;

SELECT @tab = CHAR(9)
	, @crlf = CHAR(13) + CHAR(10) 
	, @crlftab = CHAR(13) + CHAR(10) + CHAR(9) 

-----------------
-- PRIMARY KEYS
-----------------
DECLARE @tblpk TABLE
(
	pk_table_schema nvarchar(255), 
	pk_table_name nvarchar(255), 
	pk_column_name nvarchar(255), 
	pk_order int, 
	pk_constraint_name nvarchar(2048)

	, VBNETDECLARATION nvarchar(2048)
	, CSHARPDECLARATION nvarchar(2048)
	, CSHARPCHECKEMPTY nvarchar(2048)
)

INSERT INTO @tblpk
SELECT sch.name AS table_schema, 
	o.name AS table_name, 
	c.name AS column_name, ic.key_ordinal, kc.name
	, '' + c.name + ' AS ' + 
		CASE t.name
			WHEN 'varchar' THEN 'String'
			WHEN 'char' THEN 'String'
			WHEN 'nvarchar' THEN 'String'
			WHEN 'nchar' THEN 'String'
			WHEN 'bigint' THEN 'Long'
			WHEN 'numeric' THEN 'Long'
			WHEN 'int' THEN 'Integer'
			WHEN 'smallint' THEN 'Short'
			WHEN 'tinyint' THEN 'Short'
			WHEN 'smalldatetime' THEN 'DateTime'
			WHEN 'datetime' THEN 'DateTime'
			WHEN 'smallmoney' THEN 'Single'		
			WHEN 'money' THEN 'Single'		
			WHEN 'bit' THEN ' Boolean'
			ELSE 'Object'
		END AS VBNETDECLARATION

		, CSHARPDECLARATION = 
		CASE t.name
			WHEN 'varchar' THEN 'string ' + c.name
			WHEN 'char' THEN 'string ' + c.name
			WHEN 'nvarchar' THEN 'string ' + c.name
			WHEN 'nchar' THEN 'string ' + c.name
			WHEN 'bigint' THEN 'long ' + c.name
			WHEN 'numeric' THEN 'long ' + c.name
			WHEN 'int' THEN 'int ' + c.name
			WHEN 'smallint' THEN 'short ' + c.name
			WHEN 'tinyint' THEN 'short ' + c.name
			WHEN 'smalldatetime' THEN 'DateTime ' + c.name
			WHEN 'datetime' THEN 'DateTime ' + c.name
			WHEN 'smallmoney' THEN 'decimal ' + c.name
			WHEN 'money' THEN 'decimal ' + c.name
			WHEN 'bit' THEN 'bool ' + c.name
			ELSE 'var ' + c.name
		END

		, CASE t.name
			WHEN 'varchar' THEN '' + c.name + ' == ""'
			WHEN 'char' THEN '' + c.name + ' == ""'
			WHEN 'nvarchar' THEN '' + c.name + ' = ""'
			WHEN 'nchar' THEN '' + c.name + ' == ""'
			WHEN 'bigint' THEN '' + c.name + ' == 0L'
			WHEN 'numeric' THEN '' + c.name + ' = 0L'
			WHEN 'int' THEN '' + c.name + ' == 0'
			WHEN 'smallint' THEN '' + c.name + ' == 0'
			WHEN 'tinyint' THEN '' + c.name + ' == 0'
			WHEN 'smalldatetime' THEN '' + c.name + ' == null'
			WHEN 'datetime' THEN '' + c.name + ' == null'
			WHEN 'smallmoney' THEN '' + c.name + ' == 0.0m'
			WHEN 'money' THEN '' + c.name + ' == 0.0m'
			WHEN 'bit' THEN '' + c.name + ' == false'
			ELSE '' + c.name + ' == null'
		END AS CSHARPCHECKEMPTY 

FROM sys.objects AS o

LEFT OUTER JOIN sys.key_constraints AS kc
	ON o.schema_id = kc.schema_id
		AND o.object_id = kc.parent_object_id
		AND kc.type = 'PK'

LEFT OUTER JOIN sys.schemas AS sch
	ON o.schema_id = sch.schema_id

LEFT OUTER JOIN sys.index_columns AS ic
	ON ic.object_id = kc.parent_object_id
		AND ic.index_id = kc.unique_index_id

LEFT OUTER JOIN sys.columns AS c
	ON	kc.parent_object_id = c.object_id
		AND ic.column_id = c.column_id

LEFT OUTER JOIN sys.types AS t
	ON c.user_type_id = t.user_type_id

WHERE -- kc.type = 'PK'
	o.type IN ('U', 'V')
ORDER BY sch.name, OBJECT_NAME(kc.parent_object_id), kc.name, ic.key_ordinal

-----------------
-- FOREIGN KEYS
-----------------
DECLARE @tblfk_1 TABLE
(
	pk_table_schema nvarchar(255), 
	pk_table_name nvarchar(255), 
	pk_column_name nvarchar(255), 
	pk_constraint_name nvarchar(2048), 
	pk_order int, 
	pk_count int,
	fk_constraint_name nvarchar(2048), 
	fk_table_schema nvarchar(255), 
	fk_table_name nvarchar(255), 
	fk_column_name nvarchar(255), 
	fk_constraint_column_id int, 
	fk_order int 
	-- , fk_count int
)

INSERT INTO @tblfk_1
SELECT 
	-- fk.type AS constraint_type, 
	pksch.name AS pk_table_schema, pktbl.name AS pk_table_name, pkcol.name AS pk_column_name, kc.name AS pk_constraint_name, fkc.referenced_column_id AS pk_order -- , fkc.parent_column_id
	, ROW_NUMBER() OVER(PARTITION BY pksch.name, pktbl.name ORDER BY pksch.name, pktbl.name, pkcol.name) AS pk_count,

	fk.name AS constraint_name, 
	fksch.name AS fk_table_schema, OBJECT_NAME(fk.parent_object_id) AS fk_table_name, fkcol.name AS fk_column_name, fkc.constraint_column_id AS fk_constraint_column_id
	
	-- fk order
	, ROW_NUMBER() OVER(PARTITION BY fksch.name, OBJECT_NAME(fk.parent_object_id) ORDER BY fksch.name, OBJECT_NAME(fk.parent_object_id), fkc.constraint_column_id, fkcol.name) AS fk_order
	-- , ROW_NUMBER() OVER(PARTITION BY pksch.name, pktbl.name, fksch.name, OBJECT_NAME(fk.parent_object_id) ORDER BY fksch.name, OBJECT_NAME(fk.parent_object_id), fkcol.name) AS fk_count

	
FROM sys.foreign_keys AS fk

-- foreign key schema
INNER JOIN sys.schemas AS fksch
	ON fk.schema_id = fksch.schema_id

-- pk table
INNER JOIN sys.tables AS pktbl
	ON fk.referenced_object_id = pktbl.object_id

-- primary key schema
INNER JOIN sys.schemas AS pksch
	ON pktbl.schema_id = pksch.schema_id

INNER JOIN sys.foreign_key_columns AS fkc
	ON fk.object_id = fkc.constraint_object_id

INNER JOIN sys.columns AS pkcol
	ON fkc.referenced_column_id = pkcol.column_id
		AND fkc.referenced_object_id = pkcol.object_id

INNER JOIN sys.columns AS fkcol
	ON fkc.parent_column_id = fkcol.column_id
		AND fkc.parent_object_id = fkcol.object_id

LEFT OUTER JOIN sys.key_constraints AS kc
	ON kc.parent_object_id = fk.referenced_object_id
		AND kc.type = 'PK'	-- primary keys only

ORDER BY -- pksch.name, pktbl.name, fkc.referenced_column_id, 
	fksch.name, OBJECT_NAME(fk.parent_object_id), fkc.constraint_column_id

DECLARE @tblfk0 TABLE
(
	pk_table_schema nvarchar(255), 
	pk_table_name nvarchar(255), 
	pk_column_name nvarchar(255), 
	pk_constraint_name nvarchar(2048), 
	pk_order int, 
	pk_count int,
	fk_constraint_name nvarchar(2048), 
	fk_table_schema nvarchar(255), 
	fk_table_name nvarchar(255), 
	fk_column_name nvarchar(255), 
	fk_constraint_column_id int, 
	fk_order int 
	, fk_count int	-- fk count by pk table, pk constraint name
)

INSERT INTO @tblfk0
SELECT f1.*, f2.fk_count 
FROM @tblfk_1 AS f1

LEFT OUTER JOIN (
	SELECT pk_table_schema, pk_table_name, pk_constraint_name, fk_table_schema, fk_table_name, COUNT(*) AS fk_count
	FROM @tblfk_1 
	GROUP BY pk_table_schema, pk_table_name, pk_constraint_name, fk_table_schema, fk_table_name
) AS f2
	ON f1.pk_table_schema = f2.pk_table_schema
		AND f1.pk_table_name = f2.pk_table_name
		AND f1.pk_constraint_name = f2.pk_constraint_name
		AND f1.fk_table_schema = f2.fk_table_schema
		AND f1.fk_table_name = f2.fk_table_name
ORDER BY f1.pk_table_schema, f1.pk_table_name



/*
SELECT * FROM @tblpk ORDER BY pk_table_schema, pk_table_name, pk_order		-- (103 rows)
SELECT * FROM @tblfk0 ORDER BY pk_table_schema, pk_table_name, pk_order		-- (92 rows)
*/

DECLARE @tblpkfk0 AS TABLE
(
	fk_table_schema nvarchar(255),
	fk_table_name nvarchar(255),
	fk_column_name nvarchar(255),
	fk_order int,
	fk_constraint_name nvarchar(2048),
	fk_noofpkcols int,
	fk_nooffkcols int,
	isfkcoleqpkcol bit,
	
	pk_table_schema nvarchar(255),
	pk_table_name nvarchar(255),
	pk_column_name nvarchar(255),
	pk_order int,
	pk_constraint_name nvarchar(2048)
	
	, VBNETDECLARATION nvarchar(2048)
	, CSHARPDECLARATION nvarchar(2048)
	, CSHARPCHECKEMPTY nvarchar(2048)

	, pk_noofpkcols int
	-- , pk_nooffkcols int
	, isfkpkcoleqpkcol bit
)

-- combined set (157 rows)
INSERT INTO @tblpkfk0
SELECT fk.fk_table_schema, fk.fk_table_name, fk.fk_column_name, fk.fk_order, fk.fk_constraint_name, 
	fk_pkcols.nofpkcols AS fk_noofpkcols,
	fk_fkcols.nooffkcols AS fk_nooffkcols, 
	isfkcoleqpkcol = 
		CASE ISNULL(fkeqpk.fk_constraint_name, '')
			WHEN '' THEN 0
			ELSE 1
		END,

	pk.*, 
	pk_pkcols.noofpkcols AS pk_noofpkcols,
	isfkpkcoleqpkcol = 
		CASE ISNULL(pkeqpk.pk_constraint_name, '')
			WHEN '' THEN 0
			ELSE 1
		END
FROM @tblfk0 AS fk

-- no of pk cols in each of fk tables
LEFT OUTER JOIN (		
		SELECT p.pk_table_schema, p.pk_table_name, p.pk_constraint_name, COUNT(*) AS nofpkcols
		FROM @tblpk AS p
		LEFT OUTER JOIN @tblfk0 AS f
			-- ON f.pk_constraint_name = p.pk_constraint_name			
			ON f.fk_table_schema = p.pk_table_schema
				AND f.fk_table_name = p.pk_table_name
				AND f.fk_column_name = p.pk_column_name
		GROUP BY p.pk_table_schema, p.pk_table_name, p.pk_constraint_name
		-- ORDER BY p.pk_table_schema, p.pk_table_name, p.pk_constraint_name
	) AS fk_pkcols
	ON fk.fk_table_schema = fk_pkcols.pk_table_schema
		AND fk.fk_table_name = fk_pkcols.pk_table_name

LEFT OUTER JOIN (
		SELECT fk_table_schema, fk_table_name, fk_constraint_name, COUNT(*) AS nooffkcols
		FROM @tblfk0
		GROUP BY fk_table_schema, fk_table_name, fk_constraint_name
		-- ORDER BY fk_table_schema, fk_table_name, fk_constraint_name
	) AS fk_fkcols
	ON fk.fk_constraint_name = fk_fkcols.fk_constraint_name

LEFT OUTER JOIN (
		SELECT f.*
			-- f.fk_table_schema, f.fk_table_name, f.fk_column_name, COUNT(*) AS noof_isfkpk
		FROM @tblfk0 AS f
		INNER JOIN @tblpk AS p
			ON f.fk_table_schema = p.pk_table_schema
				AND f.fk_table_name = p.pk_table_name
				AND f.fk_column_name = p.pk_column_name
	) AS fkeqpk
	ON fk.fk_constraint_name = fkeqpk.fk_constraint_name

RIGHT OUTER JOIN @tblpk AS pk
ON fk.pk_constraint_name = pk.pk_constraint_name	-- check by relationship (constraint name) - col names may not be same

RIGHT OUTER JOIN (
		SELECT pk_table_schema, pk_table_name, pk_constraint_name, COUNT(*) AS noofpkcols
		FROM @tblpk
		GROUP BY pk_table_schema, pk_table_name, pk_constraint_name
		-- ORDER BY pk_table_schema, pk_table_name, pk_constraint_name
	) AS pk_pkcols
	ON pk.pk_constraint_name = pk_pkcols.pk_constraint_name

-- pk_pkcol eq fk_pkcol
FULL OUTER JOIN (
		SELECT p.pk_table_schema, p.pk_table_name, p.pk_column_name, p.pk_constraint_name, p.pk_order, COUNT(*) AS nooffk_pkcoleqpk_pkcol
		FROM @tblpk AS p
		INNER JOIN @tblfk0 AS f
			ON p.pk_constraint_name = f.pk_constraint_name
		GROUP BY p.pk_table_schema, p.pk_table_name, p.pk_column_name, p.pk_constraint_name, p.pk_order
		-- ORDER BY p.pk_table_schema, p.pk_table_name, p.pk_order
	) AS pkeqpk
	ON pk.pk_constraint_name = pkeqpk.pk_constraint_name

/*
-- original query
SELECT * 	
	, Relationship = 
	CASE
		WHEN ISNULL(fk_noofpkcols, 0) = 1 AND ISNULL(pk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN '1:1'
		WHEN ISNULL(fk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 0 THEN '1:n'
		WHEN ISNULL(pk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 0 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN 'n:1'
		ELSE 'n:n'
	END
	
FROM @tblpkfk0
ORDER BY fk_table_schema, fk_table_name, fk_constraint_name, pk_table_schema, pk_table_name, pk_order
*/

DECLARE @tblpkfk AS TABLE
(
	fk_table_schema nvarchar(255),
	fk_table_name nvarchar(255),
	fk_column_name nvarchar(255),
	fk_order int,
	fk_constraint_name nvarchar(2048),
	fk_noofpkcols int,
	fk_nooffkcols int,
	isfkcoleqpkcol bit,
	
	pk_table_schema nvarchar(255),
	pk_table_name nvarchar(255),
	pk_column_name nvarchar(255),
	pk_order int,
	pk_constraint_name nvarchar(2048)
	
	, VBNETDECLARATION nvarchar(2048)
	, CSHARPDECLARATION nvarchar(2048)
	, CSHARPCHECKEMPTY nvarchar(2048)

	, pk_noofpkcols int
	, isfkpkcoleqpkcol bit
	, Relationship nvarchar(50)
)

-- modified query
INSERT INTO @tblpkfk
SELECT 
	*, 
	Relationship = 
		CASE
			--WHEN ISNULL(fk_noofpkcols, 0) = 1 AND ISNULL(pk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN '1:1'
			WHEN ISNULL(fk_noofpkcols, 0) = ISNULL(pk_noofpkcols, 0) AND ISNULL(isfkcoleqpkcol, 0) = 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN '1:1'

			WHEN ISNULL(fk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 0 THEN 'n:1'	-- 1:n
			
			-- WHEN ISNULL(pk_noofpkcols, 0) = 1 AND ISNULL(isfkcoleqpkcol, 0) = 0 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN '1:n'	-- n:1
			WHEN ISNULL(pk_noofpkcols, 0) = 1 AND ISNULL(fk_noofpkcols, 0) >= 1 AND ISNULL(isfkpkcoleqpkcol, 0) = 1 THEN '1:n'	-- n:1

			ELSE 'n:n'
		END
	-- , pk_table_schema, pk_table_name, pk_column_name, pk_constraint_name, pk_order, pk_noofpkcols 	
	-- , fk_table_schema, fk_table_name, fk_column_name, fk_order, fk_constraint_name

FROM @tblpkfk0

/*
SELECT * 
FROM @tblpkfk
-- ORDER BY fk_table_schema, fk_table_name, fk_constraint_name, pk_table_schema, pk_table_name, pk_order
ORDER BY pk_table_schema, pk_table_name, pk_order, fk_table_schema, fk_table_name,  fk_constraint_name
*/

DECLARE @tblfk TABLE
(
	pk_table_schema nvarchar(255), 
	pk_table_name nvarchar(255), 
	pk_column_name nvarchar(255), 
	pk_constraint_name nvarchar(2048), 
	pk_order int, 
	pk_count int,
	fk_constraint_name nvarchar(2048), 
	fk_table_schema nvarchar(255), 
	fk_table_name nvarchar(255), 
	fk_column_name nvarchar(255), 
	fk_constraint_column_id int, 
	fk_order int,
	fk_count int, 
	Relationship nvarchar(50)
)

INSERT INTO @tblfk
SELECT DISTINCT t.*, t2.Relationship 
FROM @tblfk0 AS t

LEFT OUTER JOIN @tblpkfk AS t2
	ON t.pk_constraint_name = t2.pk_constraint_name
		AND t.fk_constraint_name = t2.fk_constraint_name

/*
SELECT * 
FROM @tblfk AS t
ORDER BY t.pk_table_schema, t.pk_table_name, t.pk_order, t.fk_table_schema, t.fk_table_name,  t.fk_constraint_name
*/

DECLARE @tblpkfinal AS TABLE
(
	TABLE_SCHEMA nvarchar(255), 
	TABLE_NAME nvarchar(255), 
	--CONSTRAINT_TYPE nvarchar(255), 
	COLCOUNT bigint, 
	PKCOLS nvarchar(max),
	VBPKDECLARATIONS nvarchar(max), 
	CSHARPPKDECLARATIONS nvarchar(max), 
	CSHARPPKCHECKEMPTY nvarchar(max)
)

INSERT INTO @tblpkfinal
SELECT pk_table_schema, pk_table_name
	, COUNT(*) AS COLCOUNT
	, PKCOLS = 
			LTRIM(RTRIM(STUFF(
				(
					SELECT DISTINCT ', ' + CAST(t2.pk_column_name as nvarchar(max))
					FROM @tblpk t2
					WHERE t.pk_table_schema = t2.pk_table_schema AND t.pk_table_name = t2.pk_table_name
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
	
	, VBPKDECLARATIONS = 
			LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + CAST(t2.VBNETDECLARATION as nvarchar(max))
					FROM @tblpk t2
					WHERE t.pk_table_schema = t2.pk_table_schema AND t.pk_table_name = t2.pk_table_name
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))

		, CSHARPPKDECLARATIONS = 
			LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + CAST(t2.CSHARPDECLARATION as nvarchar(max))
					FROM @tblpk t2
					WHERE t.pk_table_schema = t2.pk_table_schema AND t.pk_table_name = t2.pk_table_name
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))

		, CSHARPPKCHECKEMPTY = 
			LTRIM(RTRIM(STUFF(
				(
					SELECT ' ' + LOWER(REPLACE(t2.pk_table_schema + '_', 'dbo_', '') + t2.pk_table_name) + '.' + CAST(t2.CSHARPCHECKEMPTY as nvarchar(max)) + 
						CASE 
							WHEN (SELECT COUNT(*) FROM @tblpk AS t3 WHERE t3.pk_table_schema = t.pk_table_schema AND t3.pk_table_name = t.pk_table_name) > 1  THEN ' && '
							ELSE ''
						END
					FROM @tblpk t2
					WHERE t.pk_table_schema = t2.pk_table_schema AND t.pk_table_name = t2.pk_table_name
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))

FROM @tblpk AS t
GROUP BY t.pk_table_schema, t.pk_table_name
ORDER BY t.pk_table_schema, t.pk_table_name

-- get default values for all columns in a given database
DECLARE @tbldefvals0 AS TABLE
(
	table_schema nvarchar(255), 
	table_name nvarchar(255), 
	column_name nvarchar(255),
	data_type nvarchar(255),
	def_constraint_name nvarchar(255),
	default_value nvarchar(2048), 
	CSHARPDEFVAL nvarchar(2048)
)

INSERT INTO @tbldefvals0
SELECT
    S.name AS TABLE_SCHEMA, T.name AS TABLE_NAME
	, C.name AS COLUMN_NAME, TP.name AS DATA_TYPE
	, DC.name AS DEF_CONSTRAINT_NAME
	, DC.[definition] AS DEFAULT_VALUE

	, CSHARPDEFVAL = C.name + ' = ' + 
		CASE TP.name
			WHEN 'uniqueidentifier' THEN 'System.Guid.NewGuid();'
			WHEN 'smalldatetime' THEN 'System.DateTime.Now;'
			WHEN 'datetime' THEN 'System.DateTime.Now;'
			WHEN 'bit' THEN 
				CASE DC.[definition]
					WHEN '((1))' THEN 'true;'
					WHEN '((0))' THEN 'false;'
					ELSE 'System.Convert.ToBoolean(' + CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ');'
				END
			
			WHEN 'tinyint' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ';'
			WHEN 'smallint' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ';'
			WHEN 'int' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ';'
			WHEN 'bigint' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + 'L;'
			
			WHEN 'decimal' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ';'
			WHEN 'numeric' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ';'
			
			WHEN 'smallmoney' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + 'M;'
			WHEN 'money' THEN CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + 'M;'
			
			WHEN 'char' THEN '''' + CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ''';'
			WHEN 'nchar' THEN '''' + CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ''';'
			WHEN 'varchar' THEN '''' + CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ''';'
			WHEN 'nvarchar' THEN '''' + CAST(REPLACE(REPLACE(DC.[definition], '(', ''), ')', '') AS varchar(100)) + ''';'
			
			ELSE DC.[definition] + ';'
		END

FROM sys.all_columns AS C
INNER JOIN sys.tables AS T
	ON C.object_id = T.object_id
INNER JOIN sys.schemas AS S
	ON T.schema_id = S.schema_id
INNER JOIN sys.default_constraints AS DC
	ON C.default_object_id = DC.object_id
INNER JOIN sys.types AS TP
	ON C.system_type_id = TP.system_type_id

WHERE TP.is_user_defined = 0
ORDER BY S.name, T.name, C.name

DECLARE @tbldefvals AS TABLE
(
	table_schema nvarchar(255), 
	table_name nvarchar(255), 
	CSHARPDEFVALS nvarchar(max)
)

INSERT INTO @tbldefvals
SELECT table_schema, table_name
	, CSHARPDEFVALS = @crlf + 
		LTRIM(RTRIM(STUFF(
				(
					SELECT @crlf + CAST(t2.CSHARPDEFVAL as nvarchar(max))
					FROM @tbldefvals0 t2
					WHERE t.table_schema = t2.table_schema AND t.table_name = t2.table_name -- AND t.column_name = t2.column_name
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
FROM @tbldefvals0 AS t
GROUP BY table_schema, table_name
ORDER BY table_schema, table_name

DECLARE @tblfkfinal TABLE 
(
	PK_TABLE_SCHEMA nvarchar(255), 
	PK_TABLE_NAME nvarchar(255), 
	PK_COLS nvarchar(max),		-- PK_COLUMN_NAME nvarchar(255), 
	FK_TABLES nvarchar(max), 
	FK_DEF nvarchar(max), 
	FK_CONSTR nvarchar(max), 
	FK_COLS nvarchar(max)	
)

INSERT INTO @tblfkfinal
SELECT DISTINCT t.pk_table_schema, t.pk_table_name
	, PK_COLS = 		
			LTRIM(RTRIM(STUFF(
					(
						SELECT ', ' + CAST('[' + t2.PK_TABLE_SCHEMA + '].[' + t2.PK_TABLE_NAME + '].[' + t2.PK_COLUMN_NAME + ']' as nvarchar(max))
						FROM @tblfk t2
						WHERE t.PK_TABLE_SCHEMA = t2.PK_TABLE_SCHEMA
							AND t.PK_TABLE_NAME = t2.PK_TABLE_NAME
							--AND t.PK_COLUMN_NAME = t2.PK_COLUMN_NAME    
						GROUP BY t2.PK_TABLE_SCHEMA, t2.PK_TABLE_NAME, t2.pk_order, t2.PK_COLUMN_NAME
						ORDER BY t2.pk_order
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, ''))) 

	, FK_TABLES = 
			LTRIM(RTRIM(STUFF(
					(
						SELECT DISTINCT ', ' + CAST(t2.FK_TABLE_NAME as nvarchar(max))
						FROM @tblfk t2
						WHERE t.PK_TABLE_SCHEMA = t2.PK_TABLE_SCHEMA
							AND t.PK_TABLE_NAME = t2.PK_TABLE_NAME
							--AND t.PK_COLUMN_NAME = t2.PK_COLUMN_NAME    
						-- GROUP BY t2.FK_TABLE_SCHEMA, t2.FK_TABLE_NAME, t2.FK_ORDINALPOSITION
						-- ORDER BY t2.FK_ORDINALPOSITION 
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, '')))
		
		, FK_DEF = 
			LTRIM(RTRIM(STUFF(
					(
						SELECT DISTINCT @crlftab + @tab + 'public virtual ' + 
							CASE t2.Relationship
								WHEN '1:1' THEN '' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + ' ' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + ' { get; set; } // 1:1 relationship - PK: [' + t2.PK_TABLE_SCHEMA + '].[' + t2.PK_TABLE_NAME + '].[' + t2.PK_COLUMN_NAME + '] - FK: [' + t2.FK_TABLE_SCHEMA + '].[' + t2.FK_TABLE_NAME + '].[' + t2.FK_COLUMN_NAME + ']'
								WHEN 'n:1' THEN '' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + ' ' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + ' { get; set; } // n:1 relationship - PK: [' + t2.PK_TABLE_SCHEMA + '].[' + t2.PK_TABLE_NAME + '].[' + t2.PK_COLUMN_NAME + '] - FK: [' + t2.FK_TABLE_SCHEMA + '].[' + t2.FK_TABLE_NAME + '].[' + t2.FK_COLUMN_NAME + ']'
								WHEN '1:n' THEN 'ICollection<' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + '> ' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + 
										CASE 
											WHEN t2.fk_count > 1 THEN '_' + t2.fk_column_name
											ELSE ''
										END +
										's { get; set; } // 1:n relationship - PK: [' + t2.PK_TABLE_SCHEMA + '].[' + t2.PK_TABLE_NAME + '].[' + t2.PK_COLUMN_NAME + '] - FK: [' + t2.FK_TABLE_SCHEMA + '].[' + t2.FK_TABLE_NAME + '].[' + t2.FK_COLUMN_NAME + ']'
								ELSE 'ICollection<' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + '> ' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + 
										CASE 
											WHEN t2.fk_count > 1 THEN '_' + t2.fk_column_name
											ELSE ''
										END +
										's { get; set; } // n:n relationship - PK: [' + t2.PK_TABLE_SCHEMA + '].[' + t2.PK_TABLE_NAME + '].[' + t2.PK_COLUMN_NAME + '] - FK: [' + t2.FK_TABLE_SCHEMA + '].[' + t2.FK_TABLE_NAME + '].[' + t2.FK_COLUMN_NAME + ']'
							END
							
						FROM @tblfk t2
						WHERE t.PK_TABLE_SCHEMA = t2.PK_TABLE_SCHEMA
							AND t.PK_TABLE_NAME = t2.PK_TABLE_NAME
							-- AND t.PK_COLUMN_NAME = t2.PK_COLUMN_NAME    
						-- GROUP BY t2.FK_TABLE_SCHEMA, t2.FK_TABLE_NAME, t2.FK_ORDINALPOSITION
						-- ORDER BY t2.FK_ORDINALPOSITION           
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, @tab + '// Foreign Key Table/s' + @crlf)))
		
		, FK_CONSTR = 
			@crlftab + @tab + @tab + 
			LTRIM(RTRIM(STUFF(
					(
						SELECT DISTINCT @crlftab + @tab + @tab + 
							-- CAST(t2.FK_TABLE_SCHEMA + '_' + t2.FK_TABLE_NAME as nvarchar(max))

							CASE 
								WHEN t2.fk_count > 1 THEN '' + REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME + '_' + t2.FK_COLUMN_NAME 
								ELSE '' + REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME
							END

							 + 's = new List<' + CAST(REPLACE(t2.FK_TABLE_SCHEMA + '_', 'dbo_', '') + t2.FK_TABLE_NAME as nvarchar(max)) + '>(); '
						FROM @tblfk0 t2
						WHERE t.PK_TABLE_SCHEMA = t2.PK_TABLE_SCHEMA
							AND t.PK_TABLE_NAME = t2.PK_TABLE_NAME
							-- AND t.PK_COLUMN_NAME = t2.PK_COLUMN_NAME    
						-- GROUP BY t2.FK_TABLE_SCHEMA, t2.FK_TABLE_NAME, t2.FK_ORDINALPOSITION
						-- ORDER BY t2.FK_ORDINALPOSITION           
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, '// Foreign Key Table/s' + @crlf)))

		, FK_COLS = 
			LTRIM(RTRIM(STUFF(
					(
						SELECT ', ' + CAST('[' + t2.FK_TABLE_SCHEMA + '].[' + t2.FK_TABLE_NAME + '].[' + t2.FK_COLUMN_NAME + ']' as nvarchar(max))
						FROM @tblfk t2
						WHERE t.PK_TABLE_SCHEMA = t2.PK_TABLE_SCHEMA
							AND t.PK_TABLE_NAME = t2.PK_TABLE_NAME
							--AND t.PK_COLUMN_NAME = t2.PK_COLUMN_NAME    
						GROUP BY t2.FK_TABLE_SCHEMA, t2.FK_TABLE_NAME, t2.fk_order, t2.FK_COLUMN_NAME
						ORDER BY t2.fk_order	          
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					
					), 1, 1, '')))

FROM @tblfk AS t
GROUP BY t.pk_table_schema, t.pk_table_name
ORDER BY t.pk_table_schema, t.pk_table_name

SELECT DISTINCT P.*, 
	FK_DEFS = ISNULL(
		CASE 
			WHEN F.FK_DEF IS NULL THEN (
					LTRIM(RTRIM(STUFF(
					(
						SELECT  DISTINCT @crlf + @tab + @tab + 'public virtual ' + REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME  + ' ' + REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME + ' { get; set; } // PK Column/s: ' + T.PK_COLS
						FROM @tblfkfinal AS T 
						WHERE T.FK_TABLES LIKE '%' + P.TABLE_NAME + '%'
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, @tab + '// Primary Key Table/s' + @crlf)))
				)
			ELSE F.FK_DEF + 
				ISNULL(
				LTRIM(RTRIM(STUFF(
					(
						SELECT  DISTINCT @crlf + @tab + @tab + 'public virtual ' + 
							CASE 
								WHEN T.fk_count > 1 THEN REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME  + ' ' + REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME + '_' + T.FK_COLUMN_NAME 
								ELSE REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME  + ' ' + REPLACE(T.PK_TABLE_SCHEMA + '_', 'dbo_', '') + T.PK_TABLE_NAME
							END
							+ ' { get; set; } // PK: [' + T.PK_TABLE_SCHEMA + '].[' + T.PK_TABLE_NAME + '].[' + T.PK_COLUMN_NAME + '] - FK: [' + T.FK_TABLE_SCHEMA + '].[' + T.FK_TABLE_NAME + '].[' + T.FK_COLUMN_NAME + ']' + ' pk_count: ' + CAST(T.pk_count AS varchar(20))
						FROM @tblfk0 AS T 
						WHERE P.TABLE_SCHEMA = T.FK_TABLE_SCHEMA
							AND P.TABLE_NAME = T.FK_TABLE_NAME
						-- WHERE P.TABLE_NAME IN ( SELECT Item FROM dbo.SplitStrings_CLR(T.FK_TABLES, ', ') )
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, @crlftab + @crlftab + @tab + '// Primary Key Table/s' + @crlf)))
					, '')


		END, '')
	
	, FK_CONSTR =  
			ISNULL(
				LTRIM(RTRIM(STUFF(
					(
						SELECT @crlftab + @tab + @tab + CAST(t2.CSHARPDEFVAL as nvarchar(max))
						FROM @tbldefvals0 t2
						WHERE P.table_schema = t2.table_schema AND P.table_name = t2.table_name
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, 
						@crlftab + @tab + '// Constructor for default values' + @crlftab + @tab + 'public ' + REPLACE(P.TABLE_SCHEMA + '_', 'dbo_', '') + P.TABLE_NAME + '()' + @crlftab + @tab + '{' + @crlftab + @tab + @tab + 
						'// [' + P.table_schema + '].[' + P.table_name + ']' + @crlf)))

					+ @crlftab + ISNULL(F.FK_CONSTR, '') 
					+  @crlftab + @tab + '}'
				, '')
	, MODEL_FK_COLS = 	
		ISNULL(
		LTRIM(RTRIM(STUFF(
					(
						SELECT  DISTINCT @crlftab + @tab + @tab + 
							-- T.PK_TABLE_SCHEMA + '_' + T.PK_TABLE_NAME + @tab + @tab + T.FK_TABLE_SCHEMA + '_' + T.FK_TABLE_NAME + @tab + T.fk_column_name + @tab + T.fk_constraint_name
							CASE ISNULL(c.is_nullable, '')
								WHEN 1 THEN 'HasOptional'
								ELSE 'HasRequired'
							END + 
							'(a => a.' + REPLACE(t2.pk_table_schema + '_', 'dbo_', '') + t2.pk_table_name + ')' + 
							CASE t2.Relationship
								WHEN '1:1' THEN '.WithOptional(b => b.' + REPLACE(t2.fk_table_schema + '_', 'dbo_', '') + t2.fk_table_name + '); // ' + t2.fk_constraint_name
								WHEN 'n:1' THEN '.WithOptional(b => b.' + REPLACE(t2.fk_table_schema + '_', 'dbo_', '') + t2.fk_table_name + '); // ' + t2.fk_constraint_name
								ELSE '.WithMany(b => b.' + REPLACE(t2.fk_table_schema + '_', 'dbo_', '') + t2.fk_table_name + 
											').HasForeignKey(c => c.' + t2.fk_column_name + '); // ' + t2.fk_constraint_name
							END
							
						FROM @tblfk AS t2 
						LEFT OUTER JOIN sys.columns AS c
							ON OBJECT_ID(t2.fk_table_schema + '.' + t2.fk_table_name) = c.object_id
								AND t2.fk_column_name = c.[name]
						WHERE P.TABLE_SCHEMA = t2.FK_TABLE_SCHEMA
							AND P.TABLE_NAME = t2.FK_TABLE_NAME
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, @crlftab + @tab + @tab + '// Foreign Keys' + @crlf)))
					, '')
FROM @tblpkfinal AS P
LEFT OUTER JOIN @tblfkfinal AS F
	ON P.TABLE_SCHEMA = F.PK_TABLE_SCHEMA
		AND P.TABLE_NAME = F.PK_TABLE_NAME
GO
