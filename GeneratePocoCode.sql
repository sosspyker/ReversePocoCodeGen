CREATE PROCEDURE dbo.GeneratePocoCode(
	/**
	*	Author: sosspyker
	*	Purpose: Generates .NET reverse poco classes for a given Micrsoft SQL Server (ver. 2005 or later) database
	*	Requirements:
	*		For code generation: Microsoft SQL Server version 2005 or later
	*		For using the generated code: C#, Entity Framework 6.0 or later, NInject (for dependency injection)
	*	How to use: 
	*		Simply copy stored procedures: 
	*				GeneratePocoCode and 
	*				GeneratePKs 
	*		to your Microsoft SQL Server (version >= 2005) database and then run this stored procedure.
	*		1. Open SQL Server Query Analyser, 
	*		2. Select New Query and select the database from drop-down list  from toolbar that needs code generation
	*		3. Execute below stored produre like below:
	*		Ex: 
	*			exec GeneratePocoCode 
	*				'MyDb',					-- name of your application
	*				'C:\MyTest\Domain'		-- root folder where your reverse poco classes need to be generated
	*		Optionally you may also specify individual folders for entities, interfaces, interface implementations etc.,
	*	What does it do?
	*		Running this stored procedure generates the .NET reverse Poco classes in C# (VB.NET generation may be added later)
	*		under four different folders: Entities, Abstract, Concrete and Infrastructure respectevily
	*		
	*/
	@appname nvarchar(500), 
	@RootFolder varchar(1000),									-- full path of the root folder ex: C:\MyApp\Domain
	@AutoPropsFolder varchar(1000) = '\Entities\',				-- path (relative to root) for entity classes - ex: '\Entities\'
	@IRepositoryFolder varchar(1000) = '\Abstract\',			-- path (relative to root) for repository interfaces - ex: '\Abstract\'
	@RepositoryFolder varchar(1000) = '\Concrete\',				-- path (relative to root) for classes that implement repository interfaces - ex: '\Concrete\'
	@InfrastructureFolder varchar(1000) = '\Infrastructure\',	-- path (relative to root) for entity framework view models, dbcontext and NInject (for dependency injection) classes - ex: '\Infrastructure\'
    @IsEntitiesInSepFolder bit = 0								-- if true then writes each of the entity classes as a seperate file to AutoPropsFolder folder, 
																-- if false then merges these classes under Infrastructure folder in a single file
)
AS

-- write to files
DECLARE @bcpCommand nvarchar(2000)

-----------------------------------------------------------------
-- INPUTS: user needs to input these
-----------------------------------------------------------------
-- 1. Specify app name and ef dbcontext names
SET @appname = 'MyDb'

DECLARE @dbcontextname nvarchar(255)
SET @dbcontextname = @appname + 'DBContext'

-- 2. Specify destination folders
SELECT 
	@AutoPropsFolder = @RootFolder + '\Entities\', 
	@IRepositoryFolder = @RootFolder + '\Abstract\', 
	@RepositoryFolder = @RootFolder + '\Concrete\', 
	@InfrastructureFolder = @RootFolder + '\Infrastructure\'

DECLARE @tab nvarchar(10), @crlf nvarchar(10), 
	@crlftab nvarchar(10)

SELECT @tab = CHAR(9)
	, @crlf = CHAR(13) + CHAR(10) 
	, @crlftab = CHAR(13) + CHAR(10) + CHAR(9) 

DECLARE @entitynamespace nvarchar(255), 
	@entityimports nvarchar(1000), 

	@abstractnamespace nvarchar(255), 
	@abstractimports nvarchar(1000), 

	@concretenamespace nvarchar(255), 
	@concreteimports nvarchar(1000), 

	@infrastructurenamespace nvarchar(255), 
	@infrastructureimports nvarchar(1000), 

	@efdbcontextimports nvarchar(1000), 

	@sImportsForDbContext nvarchar(2048)		-- import assemblies for dbcontext classes

-- 3. Specify namespaces and imports for each of the folders
SELECT @entitynamespace = @appname + '.Domain.Entities', 
	@entityimports = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Text;' + @crlf + 
					'using System.Threading.Tasks;' + @crlf + 
					'using System.Web.Mvc;' + @crlf + 
					'using System.ComponentModel.DataAnnotations;' + @crlf + 
					'using System.ComponentModel.DataAnnotations.Schema;' + @crlf,
					 
	@abstractnamespace = @appname + '.Domain.Abstract', 
	@abstractimports = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Text;' + @crlf + 
					'using System.Threading.Tasks;' + @crlf + 
					'using ' + @entitynamespace + ';' + @crlf, 
	
	@concretenamespace = @appname + '.Domain.Concrete', 
	@concreteimports = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Text;' + @crlf + 
					'using System.Threading.Tasks;' + @crlf + 
					'using ' + @abstractnamespace + ';' + @crlf + 
					'using ' + @entitynamespace + ';' + @crlf, 

	@efdbcontextimports = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Text;' + @crlf + 
					'using System.Threading.Tasks;' + @crlf + 
					'using ' + @entitynamespace + ';' + @crlf + 
					'using System.Data.Entity;' + @crlf, 

	@infrastructurenamespace = @appname + '.Infrastructure', 
	@infrastructureimports = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Web;' + @crlf + 
					'using System.Web.Mvc;									// added MVC' + @crlf + 
					'using Ninject;											// added Ninject' + @crlf + 
					'//using Moq;												// added Moq' + @crlf + 
					'using ' + @abstractnamespace + ';						// added Abstract' + @crlf + 
					'using ' + @entitynamespace + ';						// added Entities' + @crlf + 
					'using ' + @concretenamespace + ';						// added Concrete' + @crlf + 
					'using System.Configuration;							// added System.Configuration' + @crlf + 
					'// register FormsAuthProvider with Ninject' + @crlf + 
					'//using ' + @appname + '.Infrastructure.Abstract;				// added Abstract' + @crlf + 
					'//using ' + @appname + '.Infrastructure.Concrete;				// added Concrete' + @crlf, 

	@sImportsForDbContext = 'using System;' + @crlf + 
					'using System.Collections.Generic;' + @crlf + 
					'using System.Collections.ObjectModel;' + @crlf + 
					'using System.Linq;' + @crlf + 
					'using System.Linq.Expressions;' + @crlf + 
					'using System.ComponentModel.DataAnnotations;' + @crlf + 
					'using System.ComponentModel.DataAnnotations.Schema;' + @crlf + 
					'using System.Data.Entity;' + @crlf + 
					'using System.Data;' + @crlf + 
					'using System.Data.SqlClient;' + @crlf + 
					'using System.Data.Entity.ModelConfiguration;' + @crlf + 
					'using System.Threading;' + @crlf + 
					'using System.Threading.Tasks;' + @crlf + 
					CASE ISNULL(@IsEntitiesInSepFolder, 0)
						WHEN 1 THEN 'using ' + @entitynamespace + ';'
						ELSE ''
					END + @crlf +  
					-- 'using ' + @entitynamespace + ';' + @crlf + 
					'using DatabaseGeneratedOption = System.ComponentModel.DataAnnotations.Schema.DatabaseGeneratedOption;' + @crlf;

-- show attributes in entity classes
DECLARE @isshowattr bit
SET @isshowattr = 1		-- 0: do not show attributes, 1: show attributes
-----------------------------------------------------------------
-- END INPUTS: user needs to input these
-----------------------------------------------------------------

DECLARE @CS2CLR AS TABLE
(
	[Id] [int] NOT NULL,
	[CSharpType] [varchar](255) NULL,
	[CLRType] [varchar](255) NULL,
	[VBType] [varchar](255) NULL
)

INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 116 AS [Id], 'bool' AS [CSharpType], 'System.Boolean' AS [CLRType], 'Boolean' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 117 AS [Id], 'byte' AS [CSharpType], 'System.Byte' AS [CLRType], 'Byte' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 118 AS [Id], 'sbyte' AS [CSharpType], 'System.SByte' AS [CLRType], 'SByte' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 119 AS [Id], 'char' AS [CSharpType], 'System.Char' AS [CLRType], 'Char' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 120 AS [Id], 'decimal' AS [CSharpType], 'System.Decimal' AS [CLRType], 'Decimal' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 121 AS [Id], 'double' AS [CSharpType], 'System.Double' AS [CLRType], 'Double' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 122 AS [Id], 'float' AS [CSharpType], 'System.Single' AS [CLRType], 'Single' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 123 AS [Id], 'int' AS [CSharpType], 'System.Int32' AS [CLRType], 'Integer' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 124 AS [Id], 'uint' AS [CSharpType], 'System.UInt32' AS [CLRType], 'UInteger' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 125 AS [Id], 'long' AS [CSharpType], 'System.Int64' AS [CLRType], 'Long' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 126 AS [Id], 'ulong' AS [CSharpType], 'System.UInt64' AS [CLRType], 'ULong' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 127 AS [Id], 'object' AS [CSharpType], 'System.Object' AS [CLRType], 'Object' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 128 AS [Id], 'short' AS [CSharpType], 'System.Int16' AS [CLRType], 'Short' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 129 AS [Id], 'ushort' AS [CSharpType], 'System.UInt16' AS [CLRType], 'UShort' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 130 AS [Id], 'string' AS [CSharpType], 'System.String' AS [CLRType], 'String' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 131 AS [Id], 'DateTime' AS [CSharpType], 'System.DateTime' AS [CLRType], 'DateTime' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 132 AS [Id], 'DateTimeOffset' AS [CSharpType], 'System.DateTimeOffset' AS [CLRType], 'DateTimeOffset' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 133 AS [Id], 'TimeSpan' AS [CSharpType], 'System.TimeSpan' AS [CLRType], 'TimeSpan' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 134 AS [Id], 'Guid' AS [CSharpType], 'System.Guid' AS [CLRType], 'Guid' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 135 AS [Id], 'string' AS [CSharpType], 'System.Xml' AS [CLRType], 'String' AS [VBType]
INSERT INTO @CS2CLR ([Id], [CSharpType], [CLRType], [VBType]) SELECT 136 AS [Id], 'System.Data.Entity.Spatial.DbGeography' AS [CSharpType], 'System.Data.Entity.Spatial.DbGeography' AS [CLRType], 'System.Data.Entity.Spatial.DbGeography' AS [VBType]

DECLARE @SQL2CLR AS TABLE
(
	[Id] [int] NOT NULL,
	[SQLType] [varchar](255) NULL,
	[CLRType] [varchar](255) NULL
)

INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 101 AS [Id], 'bigint' AS [SQLType], 'System.Int64' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 102 AS [Id], 'binary' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 103 AS [Id], 'bit' AS [SQLType], 'System.Boolean' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 104 AS [Id], 'char' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 105 AS [Id], 'char' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 106 AS [Id], 'date' AS [SQLType], 'System.DateTime' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 107 AS [Id], 'datetime' AS [SQLType], 'System.DateTime' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 108 AS [Id], 'datetime2' AS [SQLType], 'System.DateTime' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 109 AS [Id], 'datetimeoffset' AS [SQLType], 'System.DateTimeOffset' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 110 AS [Id], 'decimal' AS [SQLType], 'System.Decimal' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 111 AS [Id], 'FILESTREAM attribute (varbinary(max))' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 112 AS [Id], 'float' AS [SQLType], 'System.Double' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 113 AS [Id], 'image' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 114 AS [Id], 'int' AS [SQLType], 'System.Int32' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 115 AS [Id], 'money' AS [SQLType], 'System.Decimal' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 116 AS [Id], 'nchar' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 117 AS [Id], 'nchar' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 118 AS [Id], 'ntext' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 119 AS [Id], 'ntext' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 120 AS [Id], 'numeric' AS [SQLType], 'System.Decimal' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 121 AS [Id], 'nvarchar' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 122 AS [Id], 'nvarchar' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 123 AS [Id], 'real' AS [SQLType], 'System.Single' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 124 AS [Id], 'rowversion' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 125 AS [Id], 'smalldatetime' AS [SQLType], 'System.DateTime' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 126 AS [Id], 'smallint' AS [SQLType], 'System.Int16' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 127 AS [Id], 'smallmoney' AS [SQLType], 'System.Decimal' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 128 AS [Id], 'sql_variant' AS [SQLType], 'System.Object' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 129 AS [Id], 'text' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 130 AS [Id], 'text' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 131 AS [Id], 'time' AS [SQLType], 'System.TimeSpan' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 132 AS [Id], 'timestamp' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 133 AS [Id], 'tinyint' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 134 AS [Id], 'uniqueidentifier' AS [SQLType], 'System.Guid' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 135 AS [Id], 'varbinary' AS [SQLType], 'System.Byte' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 136 AS [Id], 'varchar' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 137 AS [Id], 'varchar' AS [SQLType], 'System.Char' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 138 AS [Id], 'xml' AS [SQLType], 'System.Xml' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 139 AS [Id], 'hierarchyid' AS [SQLType], 'System.String' AS [CLRType]
INSERT INTO @SQL2CLR ([Id], [SQLType], [CLRType]) SELECT 140 AS [Id], 'geography' AS [SQLType], 'System.Data.Entity.Spatial.DbGeography' AS [CLRType]

DECLARE @tblpk AS TABLE
(
	-- TABLE_CATALOG nvarchar(255), 
	TABLE_SCHEMA nvarchar(255), 
	TABLE_NAME nvarchar(255), 
	-- CONSTRAINT_TYPE nvarchar(255), 
	COLCOUNT bigint, 
	PKCOLS nvarchar(max),
	VBPKDECLARATIONS nvarchar(max), 
	CSHARPPKDECLARATIONS nvarchar(max), 
	CSHARPPKCHECKEMPTY nvarchar(max), 
	FK_DEF nvarchar(max), 
	FK_CONSTR nvarchar(max), 
	MODEL_FK_COLS nvarchar(max)
)
INSERT INTO @tblpk
exec GeneratePKs

-- SELECT * FROM @tblpk


DECLARE @t TABLE
(
	TABLE_SCHEMA nvarchar(255)
	, TABLE_NAME nvarchar(255)
	, COLNAME nvarchar(255)
	, ORDINALPOSITION int
	, ISPK bit
	, COLDEFINITION nvarchar(255)
	, COLVARIABLE nvarchar(300)
	, COLVARIABLEDEFINITION nvarchar(1000)
	, COLASSIGNMENT nvarchar(1000)
	, COLVARASFIELD nvarchar(1000)
	, COLVARASSIGNMENT nvarchar(1000)
	, COLSTRFORINSERT nvarchar(2000)

	, VBNETDECLARATIONS nvarchar(1000)
	, VBNETDECLARATIONSNODEFAULTS nvarchar(1000)
	, VBNETASSIGNMENTS nvarchar(2000)
	, VBNETAUTOPROPERTIES nvarchar(2000)
	
	, CSHARPDECLARATIONS nvarchar(1000)
	, CSHARPDECLARATIONSNODEFAULTS nvarchar(1000)
	, CSHARPASSIGNMENTS nvarchar(2000)
	, CSHARPIMPLICITASSIGNMENTS nvarchar(2000)
	, CSHARPAUTOPROPERTIES nvarchar(2000)

	, CSHARPCUSTOMASSIGNMENT1 nvarchar(1000)
)

--INSERT INTO @t 
--exec GenerateCodeExcerpts NULL
------------------------------------
DECLARE	@tblname nvarchar(255)
SET @tblname = NULL

-- name of dbEntry object (assuming EntityFramework is used)
DECLARE @dbentry nvarchar(255)
SET @dbentry = 'dbEntry'

DECLARE @tblpococols AS TABLE
(
	table_schema nvarchar(255)
	, table_name nvarchar(255)
	, table_type nchar(1)
	, column_ordinal int
	, column_name nvarchar(255)
	, m_column_name nvarchar(256)
	, column_data_type nvarchar(255)
	, column_max_length int
	, column_precision int
	, column_scale int
	, column_is_nullable bit
	, column_is_identity bit
	, column_is_computed bit
	, column_is_rowguidcol bit
	, column_is_filestream bit
	, column_is_sparse bit
	, column_is_xml_document bit

	, pk_name nvarchar(255)
	, pk_column_name nvarchar(255)
	, pk_key_ordinal nvarchar(255)
	, constraint_type nvarchar(20)

	, SQLType nvarchar(255)
	, CLRType nvarchar(255)
	, CSharpType nvarchar(255)
	, VBType nvarchar(255)
) 

INSERT INTO @tblpococols
SELECT s.name AS table_schema, o.name AS table_name, o.type AS table_type, c.column_id AS column_ordinal, c.name AS column_name, 
	REPLACE(REPLACE(
			CASE 
				WHEN ISNUMERIC(c.name) = 1 THEN 'C' + c.name
				ELSE c.name
			END
			, ' ', ''), '.', '46') AS m_column_name,	-- column name for vb or c# vars
	column_data_type = 
		CASE 
			WHEN stp.name IS NULL THEN tp.name	-- usually occurs in case hierarchyid, geography data types
			ELSE stp.name
		END,
	c.max_length AS column_max_length, c.precision AS column_precision, c.scale AS column_scale, 
	c.is_nullable AS column_is_nullable, c.is_identity AS column_is_identity, c.is_computed AS column_is_computed, 
	c.is_rowguidcol AS column_is_rowguidcol, c.is_filestream AS column_is_filestream, c.is_sparse AS column_is_sparse, c.is_xml_document AS column_is_xm_document, 
	
	pk.pk_name, pk_column_name, pk.pk_key_ordinal, pk.constraint_type, 
	DTP.SQLType, DTP.CLRType, DTP.CSharpType, DTP.VBType

FROM sys.objects AS o

LEFT OUTER JOIN sys.schemas AS s
	ON o.schema_id = s.schema_id

LEFT OUTER JOIN sys.columns AS c
	ON c.object_id = o.object_id

LEFT OUTER JOIN sys.types AS tp
	ON tp.user_type_id = c.user_type_id
					
LEFT OUTER JOIN sys.types AS stp
	ON tp.system_type_id = stp.system_type_id
		AND stp.system_type_id = stp.user_type_id

LEFT OUTER JOIN (
	SELECT sch.schema_id AS pk_table_schema_id, sch.name AS pk_table_schema, kc.parent_object_id AS pk_table_object_id, OBJECT_NAME(kc.parent_object_id) AS pk_table_name, c.object_id AS pk_column_object_id, c.name AS pk_column_name, ic.key_ordinal AS pk_key_ordinal, kc.name AS pk_name, kc.type AS constraint_type
	FROM sys.key_constraints AS kc

	INNER JOIN sys.schemas AS sch
		ON kc.schema_id = sch.schema_id

	INNER JOIN sys.index_columns AS ic
		ON ic.object_id = kc.parent_object_id
			AND ic.index_id = kc.unique_index_id

	INNER JOIN sys.columns AS c
		ON kc.parent_object_id = c.object_id
			AND ic.column_id = c.column_id
) AS pk
	ON s.name = pk.pk_table_schema
		AND o.name = pk.pk_table_name
		-- AND c.object_id = pk.pk_column_object_id
		AND c.name = pk.pk_column_name	

LEFT OUTER JOIN (
	SELECT S.Id, S.SQLType, S.CLRType, 
	C.CSharpType, C.VBType
	-- FROM MyDB.dbo.SQLToCLRDataMap AS S
	FROM @SQL2CLR AS S
	-- LEFT OUTER JOIN MyDB.dbo.CSharpToCLRDataMap AS C
	LEFT OUTER JOIN @CS2CLR AS C
	ON S.CLRType = C.CLRType
	WHERE S.CLRType <> 'System.Char'

) AS DTP
ON DTP.SQLType = 
	CASE 
		WHEN stp.name IS NULL THEN tp.name
		ELSE stp.name
	END

WHERE o.type in ('U', 'V')
	AND ISNULL(o.is_ms_shipped, 0) = 0

SELECT * FROM @tblpococols
ORDER BY table_schema, table_name, column_ordinal

INSERT INTO @t
SELECT table_schema AS TABLE_SCHEMA, table_name AS TABLE_NAME, '[' + column_name + '], ' AS COLNAME, column_ordinal AS ORDINAL_POSITION 
	, ISPK = 
	CASE 
		WHEN ISNULL(pk_name, '') <> '' THEN 1
		ELSE 0
	END 
	, COLDEFINITION = 
		'[' + column_name + '] ' + column_data_type + 	
			CASE
				WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 
					CASE 
						WHEN column_max_length > 0 THEN '(' + CAST(column_max_length AS varchar(10)) + '), '
						ELSE '(max), '
					END
				WHEN column_data_type IN ('numeric', 'decimal', 'money', 'smallmoney') THEN '(' + CAST(column_precision AS varchar(10)) + ', ' + CAST(column_scale AS varchar(10)) +  '), '
				ELSE ','
			END 
	, '@' + m_column_name + ', ' AS COLVARIABLE
	, COLVARIABLEDEFINITION = 
		'@' + m_column_name + ' ' + column_data_type + 	
			CASE
				WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 
					CASE 
						WHEN column_max_length > 0 THEN '(' + CAST(column_max_length AS varchar(10)) + '), '
						ELSE '(max), '
					END
				WHEN column_data_type IN ('numeric', 'decimal', 'money', 'smallmoney') THEN '(' + CAST(column_precision AS varchar(10)) + ', ' + CAST(column_scale AS varchar(10)) +  '), '
				ELSE ','
			END 
	, COLASSIGNMENT = '@' + m_column_name + ' = ' + '[' + column_name + '], '
	, COLVARASFIELD = 
		CASE
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 'LTRIM(RTRIM('
			ELSE ''
		END + 
		'@' + m_column_name + 
		CASE
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN '))'
			ELSE ''
		END + ' AS ' + '[' + column_name + '], '
	, COLVARASSIGNMENT = '[' + column_name + '] = ' + 
		CASE
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 'LTRIM(RTRIM('
			ELSE ''
		END + 
		'@' + m_column_name + 
		CASE
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN '))'
			ELSE ''
		END + ', '
	, COLSTRFORINSERT = 
		CASE
			WHEN column_data_type IN ('numeric', 'decimal') THEN 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE ' + 'CAST(' + column_name + ' AS varchar(' + CAST(column_precision AS varchar(40)) + ')) END + '' AS [' + column_name + '], '' + '
			WHEN column_data_type IN ('int', 'integer', 'smallint', 'tinyint') THEN 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE ' + 'CAST(' + column_name + ' AS varchar(40)) END + '' AS [' + column_name + '], '' + '
			WHEN column_data_type IN ('money', 'smallmoney') THEN 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE ' + 'CAST(' + column_name + ' AS varchar(20)) END + '' AS [' + column_name + '], '' + '
			WHEN column_data_type IN ('datetime', 'smalldatetime', 'date') THEN 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE ' + ' '''''''' + CAST(' + column_name + ' AS varchar(100)) + '''''''' END + '' AS [' + column_name + '], '' + '
			WHEN column_data_type IN ('bit') THEN 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE ' + 'CAST(' + column_name + ' AS char(1)) END + '' AS [' + column_name + '], '' + '
			ELSE 'CASE WHEN [' + column_name + '] IS NULL THEN ''NULL'' ELSE '''''''' + LTRIM(RTRIM(REPLACE(CAST([' + column_name + '] AS varchar(max)), '''''''', ''''''''''''))) + '''''''' END + '' AS [' + column_name + '], '' + '
		END
	, VBNETDECLARATIONS = ' m' + 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN m_column_name + ' As ' + 'String = "", _ '			

			WHEN column_data_type = 'bigint' THEN m_column_name + ' As ' + 'Long = 0L, _ '
			WHEN column_data_type = 'int' THEN m_column_name + ' As ' + 'Integer = 0, _ '
			WHEN column_data_type = 'smallint' THEN m_column_name + ' As ' + 'Short = 0, _ '
			WHEN column_data_type = 'tinyint' THEN m_column_name + ' As ' + 'Byte, _ '

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN m_column_name + ' As ' + 'Decimal = 0.0M, _ '
			
			WHEN column_data_type = 'float' THEN m_column_name + ' As ' + 'Double = 0.0D, _ '
			WHEN column_data_type = 'real' THEN m_column_name + ' As ' + 'Float = 0.0F, _ '

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN m_column_name + ' As ' + 'DateTime, _ '
			WHEN column_data_type = 'datetimeoffset' THEN m_column_name + ' As ' + 'DateTimeOffset, _ '

			WHEN column_data_type = 'time' THEN m_column_name + ' As ' + 'TimeSpan, _ '

			WHEN column_data_type = 'bit' THEN m_column_name + ' As ' + 'Boolean = False, _ '
			WHEN column_data_type = 'uniqueidentifier' THEN m_column_name + ' As ' + 'Guid, _ '
			
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'binary' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'varbinary' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'varbinary(max)' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte, _ '
			
			WHEN column_data_type = 'geography' THEN m_column_name + '() As ' + 'System.Data.Entity.Spatial.DbGeography, _ '

			ELSE m_column_name + ' As ' + 'String = "", _ '
		END
	, VBNETDECLARATIONSNODEFAULTS = ' m' + 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN m_column_name + ' As ' + 'String, _ '
			
			WHEN column_data_type = 'bigint' THEN m_column_name + ' As ' + 'Long, _ '
			WHEN column_data_type = 'int' THEN m_column_name + ' As ' + 'Integer, _ '
			WHEN column_data_type = 'smallint' THEN m_column_name + ' As ' + 'Short, _ '
			WHEN column_data_type = 'tinyint' THEN m_column_name + ' As ' + 'Byte, _ '

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN m_column_name + ' As ' + 'Decimal, _ '			

			WHEN column_data_type = 'float' THEN m_column_name + ' As ' + 'Double, _ '
			WHEN column_data_type = 'real' THEN m_column_name + ' As ' + 'Float, _ '

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN m_column_name + ' As ' + 'DateTime, _ '
			WHEN column_data_type = 'datetimeoffset' THEN m_column_name + ' As ' + 'DateTimeOffset, _ '

			WHEN column_data_type = 'time' THEN m_column_name + ' As ' + 'TimeSpan, _ '

			WHEN column_data_type = 'bit' THEN m_column_name + ' As ' + 'Boolean, _ '
			WHEN column_data_type = 'uniqueidentifier' THEN m_column_name + ' As ' + 'Guid, _ '
			
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'binary' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'varbinary' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'varbinary(max)' THEN m_column_name + '() As ' + 'Byte, _ '
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte, _ '

			WHEN column_data_type = 'geography' THEN m_column_name + '() As ' + 'System.Data.Entity.Spatial.DbGeography, _ '
			
			ELSE m_column_name + ' As ' + 'String, _ '
		END
	, VBNETASSIGNMENTS = '.' + m_column_name + ' = ' + 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN m_column_name + '.ToString().Trim()'
			
			WHEN column_data_type = 'bigint' THEN '' + m_column_name
			WHEN column_data_type = 'int' THEN '' + m_column_name
			WHEN column_data_type = 'smallint' THEN '' + m_column_name
			WHEN column_data_type = 'tinyint' THEN '' + m_column_name

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN '' + m_column_name

			WHEN column_data_type = 'float' THEN '' + m_column_name
			WHEN column_data_type = 'real' THEN '' + m_column_name

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN 'System.Convert.ToDateTime(' + m_column_name + ')'
			WHEN column_data_type = 'datetimeoffset' THEN '' + m_column_name

			WHEN column_data_type = 'time' THEN '' + m_column_name

			WHEN column_data_type = 'bit' THEN 'System.Convert.ToBoolean(' + m_column_name + ')'
			WHEN column_data_type = 'uniqueidentifier' THEN '' + m_column_name
			
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN '' + m_column_name
			WHEN column_data_type = 'binary' THEN '' + m_column_name
			WHEN column_data_type = 'varbinary' THEN '' + m_column_name
			WHEN column_data_type = 'varbinary(max)' THEN '' + m_column_name
			WHEN column_data_type = 'image' THEN '' + m_column_name
			
			ELSE '' + m_column_name
		END
	, VBNETAUTOPROPERTIES = ' Public Property ' + 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN m_column_name + ' As ' + 'String'
			
			WHEN column_data_type = 'bigint' THEN m_column_name + ' As ' + 'Long'
			WHEN column_data_type = 'int' THEN m_column_name + ' As ' + 'Integer'
			WHEN column_data_type = 'smallint' THEN m_column_name + ' As ' + 'Short'
			WHEN column_data_type = 'tinyint' THEN m_column_name + ' As ' + 'Byte'

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN m_column_name + ' As ' + 'Decimal'

			WHEN column_data_type = 'float' THEN m_column_name + ' As ' + 'Double'
			WHEN column_data_type = 'real' THEN m_column_name + ' As ' + 'Float'

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN m_column_name + ' As ' + 'DateTime'
			WHEN column_data_type = 'datetimeoffset' THEN m_column_name + ' As ' + 'DateTimeOffset'

			WHEN column_data_type = 'time' THEN m_column_name + ' As ' + 'TimeSpan'

			WHEN column_data_type = 'bit' THEN m_column_name + ' As ' + 'Boolean'
			WHEN column_data_type = 'uniqueidentifier' THEN m_column_name + ' As ' + 'Guid'
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte'
			WHEN column_data_type = 'binary' THEN m_column_name + '() As ' + 'Byte'
			WHEN column_data_type = 'varbinary' THEN m_column_name + '() As ' + 'Byte'
			WHEN column_data_type = 'varbinary(max)' THEN m_column_name + '() As ' + 'Byte'
			WHEN column_data_type = 'image' THEN m_column_name + '() As ' + 'Byte'

			WHEN column_data_type = 'geography' THEN m_column_name + '() As ' + 'System.Data.Entity.Spatial.DbGeography'
			ELSE m_column_name + '() As String'
		END
	, CSHARPDECLARATIONS = 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 'string m' + m_column_name + ' = "";'

			WHEN column_data_type = 'bigint' THEN 'long m' + m_column_name + ' = 0L;'
			WHEN column_data_type = 'int' THEN 'int m' + m_column_name + ' = 0;'
			WHEN column_data_type = 'smallint' THEN 'short m' + m_column_name + ' = 0;'
			WHEN column_data_type = 'tinyint' THEN 'byte m' + m_column_name + ' = 0;'

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN 'decimal m' + m_column_name + ' = 0.0M;'
			
			WHEN column_data_type = 'float' THEN 'double m' + m_column_name + ' = 0.0D;'
			WHEN column_data_type = 'real' THEN 'float m' + m_column_name + ' = 0.0F;'

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN 'DateTime m' + m_column_name + ';'
			WHEN column_data_type = 'datetimeoffset' THEN 'DateTimeOffset m' + m_column_name + ';'

			WHEN column_data_type = 'time' THEN 'TimeSpan m' + m_column_name + ';'

			WHEN column_data_type = 'bit' THEN 'boolean m' + m_column_name + ' = false;'
			WHEN column_data_type = 'uniqueidentifier' THEN 'Guid m' + m_column_name + ';'
			
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'binary' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'varbinary' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'varbinary(max)' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'image' THEN 'byte[] m' + m_column_name + ';'
			
			WHEN column_data_type = 'geography' THEN 'System.Data.Entity.Spatial.DbGeography m' + m_column_name + ';'

			ELSE 'string m' + m_column_name + ';'
		END
	, CSHARPDECLARATIONSNODEFAULTS = 
		CASE 
			WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 'string m' + m_column_name + ';'

			WHEN column_data_type = 'bigint' THEN 'long m' + m_column_name + ';'
			WHEN column_data_type = 'int' THEN 'int m' + m_column_name + ';'
			WHEN column_data_type = 'smallint' THEN 'short m' + m_column_name + ';'
			WHEN column_data_type = 'tinyint' THEN 'byte m' + m_column_name + ';'

			WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN 'decimal m' + m_column_name + ';'
			
			WHEN column_data_type = 'float' THEN 'double m' + m_column_name + ';'
			WHEN column_data_type = 'real' THEN 'float m' + m_column_name + ';'

			WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN 'DateTime m' + m_column_name + ';'
			WHEN column_data_type = 'datetimeoffset' THEN 'DateTimeOffset m' + m_column_name + ';'

			WHEN column_data_type = 'time' THEN 'TimeSpan m' + m_column_name + ';'

			WHEN column_data_type = 'bit' THEN 'boolean m' + m_column_name + ';'
			WHEN column_data_type = 'uniqueidentifier' THEN 'Guid m' + m_column_name + ';'
			
			-- Byte Arrays
			WHEN column_data_type = 'image' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'binary' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'varbinary' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'varbinary(max)' THEN 'byte[] m' + m_column_name + ';'
			WHEN column_data_type = 'image' THEN 'byte[] m' + m_column_name + ';'
			
			WHEN column_data_type = 'geography' THEN 'System.Data.Entity.Spatial.DbGeography m' + m_column_name + ';'

			ELSE 'string m' + m_column_name + ';'
		END
		, CSHARPASSIGNMENTS = 'm' + m_column_name + ' = ' + 
			CASE 
				WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN m_column_name + '.ToString().Trim()'
			
				WHEN column_data_type = 'bigint' THEN '' + m_column_name
				WHEN column_data_type = 'int' THEN '' + m_column_name
				WHEN column_data_type = 'smallint' THEN '' + m_column_name
				WHEN column_data_type = 'tinyint' THEN '(byte)' + m_column_name

				WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN '' + m_column_name

				WHEN column_data_type = 'float' THEN '' + m_column_name
				WHEN column_data_type = 'real' THEN '' + m_column_name

				WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN 'System.Convert.ToDateTime(' + m_column_name + ')'
				WHEN column_data_type = 'datetimeoffset' THEN '' + m_column_name

				WHEN column_data_type = 'time' THEN '' + m_column_name

				WHEN column_data_type = 'bit' THEN 'System.Convert.ToBoolean(' + m_column_name + ')'
				WHEN column_data_type = 'uniqueidentifier' THEN '' + m_column_name
			
				-- Byte Arrays
				WHEN column_data_type = 'image' THEN '' + m_column_name
				WHEN column_data_type = 'binary' THEN '' + m_column_name
				WHEN column_data_type = 'varbinary' THEN '' + m_column_name
				WHEN column_data_type = 'varbinary(max)' THEN '' + m_column_name
				WHEN column_data_type = 'image' THEN '' + m_column_name
			
				ELSE '' + m_column_name
			END + ';'
		, CSHARPIMPLICITASSIGNMENTS = 
			CASE 
				WHEN column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') THEN '' + m_column_name + ': "", '

				WHEN column_data_type = 'bigint' THEN '' + column_name + ': 0L, '
				WHEN column_data_type = 'int' THEN '' + column_name + ': 0, '
				WHEN column_data_type = 'smallint' THEN '' + column_name + ': 0, '
				WHEN column_data_type = 'tinyint' THEN '' + m_column_name + ': 0, '

				WHEN column_data_type IN ('decimal', 'numeric', 'smallmoney', 'money') THEN '' + column_name + ': 0.0M, '
			
				WHEN column_data_type = 'float' THEN '' + column_name + ': 0.0D, '
				WHEN column_data_type = 'real' THEN '' + column_name + ': 0.0F, '

				WHEN column_data_type IN ('smalldatetime', 'datetime', 'datetime2', 'date') THEN '' + column_name + ': DateTime.Now, '
				WHEN column_data_type = 'datetimeoffset' THEN '' + column_name + ': DateTime.Now, '

				WHEN column_data_type = 'time' THEN '' + column_name + ': DateTime.Now.TimeSpan, '

				WHEN column_data_type = 'bit' THEN '' + column_name + ': false, '
				WHEN column_data_type = 'uniqueidentifier' THEN '' + column_name + ': Guid.NewGuid(), '
			
				-- Byte Arrays
				WHEN column_data_type = 'image' THEN '' + column_name + ': , '
				WHEN column_data_type = 'binary' THEN '' + column_name + ': , '
				WHEN column_data_type = 'varbinary' THEN '' + column_name + ': , '
				WHEN column_data_type = 'varbinary(max)' THEN '' + column_name + ': , '
				WHEN column_data_type = 'image' THEN '' + column_name + ': , '
			
				ELSE '' + column_name + ': "", '
			END
		, CSHARPAUTOPROPERTIES = 
			-- [Required]
			CASE 
				-- TABLE_NAME + ' ' + 
				WHEN ISNULL(@isshowattr, 0) = 1 AND column_is_nullable = 0 THEN '[Required(ErrorMessage = "Please specify a value for ' + column_name + '")]' + @crlftab + @tab
				ELSE ''
			END + 
			
			/*
			-- [Key]
			CASE 
				WHEN ISNULL(@isshowattr, 0) = 1 AND pk_column_name IS NOT NULL THEN '[Key]' + @crlftab + @tab
				ELSE ''
			END + 

			-- [Column("COLUMN_NAME", TypeName = "DATA_TYPE"[, Order = pk_order])
			CASE ISNULL(@isshowattr, 0)
				WHEN 1 THEN 
					'[Column(' + '"' + column_name + '", TypeName = "' + column_data_type + 	
					CASE 
						WHEN pk_column_name IS NOT NULL THEN '", Order = ' + CAST(pk_key_ordinal AS varchar(20)) + ''
						ELSE '"'
					END +  
					')]' + @crlftab + @tab
				ELSE ''
			END + 
			*/
	
			-- [MaxLength(maxlen, ErrorMessage = "error message here")]
			CASE 
				WHEN (ISNULL(@isshowattr, 0) = 1 AND column_data_type IN ('char', 'varchar', 'nchar', 'nvarchar') AND column_max_length > 0) THEN '[MaxLength(' + CAST(column_max_length/2 AS varchar(20)) + ', ErrorMessage = "' + column_name + ' must be ' + CAST(column_max_length/2 AS varchar(20)) + ' characters or less")]' + @crlftab + @tab
				
				--  WHEN (column_data_type = 'nvarchar' AND column_max_length > 0) THEN '[MaxLength(' + CAST(column_max_length AS varchar(20)) + ', ErrorMessage = "' + column_name + ' must be ' + CAST(column_max_length AS varchar(20)) + ' characters or less")]' + @crlftab + @tab
				--WHEN 'numeric' THEN '[MaxLength(' + column_scale + ', ErrorMessage = "' + column_name + ' must be ' + column_max_length + ' characters or less")]' + @crlf
				--WHEN 'decimal' THEN '[MaxLength(' + column_scale + ', ErrorMessage = "' + column_name + ' must be ' + column_max_length + ' characters or less")]' + @crlf
				
				ELSE ''
			END + 

			'public ' + CSharpType + 
			CASE column_is_nullable
				WHEN 1 THEN 
					CASE  
						WHEN column_data_type IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'decimal', 'numeric', 'money', 'smallmoney', 'int', 'smallint', 'tinyint', 'bit') THEN '?'
						ELSE ''
					END
				ELSE ''
			END + 
			' ' + REPLACE(REPLACE(
				CASE 
					WHEN ISNUMERIC(column_name) = 1 THEN 'C' + column_name
					ELSE column_name
				END
				, ' ', ''), '.', '46') + '' + ' { get; set; }'

	, (@dbentry + '.' + column_name + ' = ' + LOWER(table_name) + '.' + column_name) AS CSHARPCUSTOMASSIGNMENT1

FROM @tblpococols
ORDER BY table_schema, table_name, column_ordinal
------------------------------------
-- SELECT * FROM @t

-- POCO Configuration
DECLARE @tblpococonfig AS TABLE
(
	table_schema nvarchar(255)
	, table_name nvarchar(255)
	, poco_table nvarchar(max)
)

INSERT INTO @tblpococonfig
SELECT 
	s.name AS table_schema, o.name AS table_name, 
	poco_table = 
	@crlftab + '// [' + s.name + '].[' + o.name + ']' + 
	@crlftab + 'internal class ' + REPLACE(s.name + '_', 'dbo_', '') + o.name + 'Configuration : EntityTypeConfiguration<' + REPLACE(s.name + '_', 'dbo_', '') + o.name + '>' + 
	@crlftab + '{' + 
	@crlftab + @tab + 'public ' + REPLACE(s.name + '_', 'dbo_', '') + o.name + 'Configuration(string schema = "' + s.name + '")' + 
	@crlftab + @tab + '{' + 
	@crlftab + @tab + @tab + 'ToTable(schema + ".' + o.name + '");' +  
	CASE o.type 
		WHEN 'U' THEN 
			@crlftab + @tab + @tab + 
				REPLACE(
				CASE 
					WHEN P.COLCOUNT > 1 THEN  'HasKey(x => new { '
					ELSE 'HasKey(x => '
				END + 
				ISNULL(
				LTRIM(RTRIM(STUFF(
				(	
					SELECT ', x.' + REPLACE(REPLACE(
						CASE 
							WHEN ISNUMERIC(t2.column_name) = 1 THEN 'C' + t2.column_name
							ELSE t2.column_name
						END
						, ' ', ''), '.', '46')
					FROM @tblpococols t2
					WHERE t2.table_type = 'U' AND t2.pk_name IS NOT NULL AND t2.constraint_type = 'PK'
						AND o.[type] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_type COLLATE SQL_Latin1_General_CP1_CI_AS
						AND s.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_schema COLLATE SQL_Latin1_General_CP1_CI_AS
						AND o.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_name COLLATE SQL_Latin1_General_CP1_CI_AS						
					ORDER BY t2.table_type, t2.table_schema, t2.table_name, t2.pk_key_ordinal
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
				, '')
				+ 
				CASE 
					WHEN P.COLCOUNT > 1 THEN ' });' 
					ELSE ' );'
				END
				, 'HasKey(x => new {  });', '') + @crlf
		WHEN 'V' THEN 
			@crlftab + @tab + @tab + 
				REPLACE(
				'HasKey(x => new { ' + 
				ISNULL(
				LTRIM(RTRIM(STUFF(
				(	
					SELECT ', x.' + REPLACE(REPLACE(
						CASE 
							WHEN ISNUMERIC(t2.column_name) = 1 THEN 'C' + t2.column_name
							ELSE t2.column_name
						END
						, ' ', ''), '.', '46')
					FROM @tblpococols t2
					WHERE t2.table_type = 'V' AND t2.column_is_nullable = 0
						AND o.[type] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_type COLLATE SQL_Latin1_General_CP1_CI_AS
						AND s.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_schema COLLATE SQL_Latin1_General_CP1_CI_AS
						AND o.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_name COLLATE SQL_Latin1_General_CP1_CI_AS
					ORDER BY t2.table_type, t2.table_schema, t2.table_name, t2.pk_key_ordinal
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
				, '')
				+ ' });' 
				, 'HasKey(x => new {  });', '') + @crlf
		END + 
	@crlf +  
	LTRIM(RTRIM(STUFF(
			(	
				SELECT  
					@crlftab + @tab + @tab + 
					'Property(x => x.' + REPLACE(REPLACE(
							CASE 
								WHEN ISNUMERIC(t2.column_name) = 1 THEN 'C' + t2.column_name
								ELSE t2.column_name
							END
							, ' ', ''), '.', '46') + ').HasColumnName("' + t2.column_name + '")' + 
						CASE t2.column_is_nullable
							WHEN 1 THEN '.IsOptional()'
							ELSE '.IsRequired()'
						END + 
						CASE 
							WHEN t2.column_is_identity = 1 THEN '.HasDatabaseGeneratedOption(DatabaseGeneratedOption.Identity)'
							WHEN t2.column_is_computed = 1 THEN '.HasDatabaseGeneratedOption(DatabaseGeneratedOption.Computed)'
							WHEN t2.column_is_identity = 0 AND t2.column_is_computed = 0 AND t2.constraint_type = 'PK' THEN '.HasDatabaseGeneratedOption(DatabaseGeneratedOption.None)'
							ELSE ''
						END + 
						CASE 
							WHEN t2.column_data_type IN ('varchar', 'nvarchar') AND t2.column_max_length > 0 THEN '.HasMaxLength('
								 + CAST(
									CASE 
										WHEN t2.column_max_length > 0 THEN t2.column_max_length/2 
										ELSE t2.column_max_length
									END
								AS varchar(20)) + ')'
							WHEN t2.column_data_type IN ('char', 'nchar') THEN '.IsFixedLength().HasMaxLength('
								 + CAST(
									CASE 
										WHEN t2.column_max_length > 0 THEN t2.column_max_length/2 
										ELSE t2.column_max_length
									END
								AS varchar(20)) + ')'
							WHEN t2.column_data_type IN ('numeric', 'decimal', 'smallmoney', 'money') THEN '.HasPrecision(' + CAST(t2.column_precision AS varchar(20)) + ', ' + CAST(t2.column_scale AS varchar(20)) + ')'
							ELSE ''
						END
						+ ';'
						

				
				FROM @tblpococols t2
				WHERE o.[type] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_type COLLATE SQL_Latin1_General_CP1_CI_AS
					AND s.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_schema COLLATE SQL_Latin1_General_CP1_CI_AS
					AND o.[name] COLLATE SQL_Latin1_General_CP1_CI_AS = t2.table_name COLLATE SQL_Latin1_General_CP1_CI_AS
				
				ORDER BY t2.table_schema, t2.table_name, t2.column_ordinal
				FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
			), 1, 1, '')))

			+ @crlftab + @tab + @tab + @tab + @tab
			+ P.MODEL_FK_COLS


			+ @crlftab + @tab + '}' + 
			@crlftab + '}' + @crlftab
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
	ON o.schema_id = s.schema_id

LEFT OUTER JOIN @tblpk AS P
	ON s.name = p.TABLE_SCHEMA AND 
		o.name = P.TABLE_NAME		

WHERE o.type IN ('U', 'V')

-- SELECT * FROM @tblpococonfig

DECLARE @pococonfig nvarchar(max)
SELECT @pococonfig = STUFF
(
	(
		SELECT 
			CAST(t2.poco_table AS nvarchar(max))
		FROM @tblpococonfig AS t2
		ORDER BY t2.table_schema, t2.table_name
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 1, ''
)
SELECT @pococonfig AS PocoConfig

/*DECLARE @CSharpAutoProp nvarchar(max)
SELECT @CSharpAutoProp = COALESCE(@CSharpAutoProp, ' ', '') + Char(13) + Char(10) + CSHARPAUTOPROPERTIES
FROM @t
SELECT @CSharpAutoProp
*/

DECLARE @tblout1 AS TABLE(
	TableSchema nvarchar(255), 
	TableName nvarchar(255), 
	ColCount bigint, 
	AutoProps nvarchar(max), 
	IRepository nvarchar(max), 
	Repository nvarchar(max)
)

INSERT INTO @tblout1
SELECT t.TABLE_SCHEMA AS TableSchema, t.TABLE_NAME AS TableName, count(*) ColCount,
		CASE ISNULL(@IsEntitiesInSepFolder, 0)
			WHEN 1 THEN @entityimports + @crlf + 'namespace ' + @entitynamespace + @crlf + '{' + @crlftab
			ELSE ''
		END + 
		-- @entityimports + @crlf + 'namespace ' + @entitynamespace + @crlf + '{' + @crlftab + 
		CASE ISNULL(@isshowattr, 0)
			WHEN 1 THEN		'[Table("' +  t.TABLE_NAME + '", Schema = "' + t.TABLE_SCHEMA + '")]'
			ELSE ''
		END + 
	  STUFF	
		(
			(
				SELECT @crlftab + @tab + cast(t2.CSHARPAUTOPROPERTIES as nvarchar(4000)) + @crlftab + @tab 
				FROM @t t2
				WHERE t.TABLE_NAME = t2.TABLE_NAME            
				ORDER BY t2.TABLE_NAME, t2.ORDINALPOSITION
				FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'				
			)
			, 1, 1, 
			@crlftab + 'public class ' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + @crlftab + '{' + @crlf
		) 
			+ @crlftab + (SELECT p.FK_DEF + @crlftab + p.FK_CONSTR FROM @tblpk AS p WHERE t.TABLE_SCHEMA = p.TABLE_SCHEMA AND t.TABLE_NAME = p.TABLE_NAME)
			+ @crlftab + '}' 
			+ CASE ISNULL(@IsEntitiesInSepFolder, 0)
				WHEN 1 THEN @crlf + '}' -- for namespace
				ELSE ''
			END
				--  + @crlf + '}' -- for namespace
			AS AutoProps
	
	, IRepository = @abstractimports + @crlf + 'namespace ' + @abstractnamespace + @crlf + '{' + @tab + 
		@crlftab + 'public interface I' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 'Repository' + @crlftab + '{'
			+ @crlftab + @tab + 'IEnumerable<' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '> ' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's { get; }'
			
			--+ @crlftab + @tab + 'IEnumerable<' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '> FindAll();'
			-- + @crlftab + @tab + 'IEnumerable<' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '> FindById(' + (SELECT CSHARPPKDECLARATIONS FROM @tblpk t3 WHERE t.TABLE_NAME = t3.TABLE_NAME) + ');'			
			--  + @crlftab + @tab + 'void Add' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' ' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME) + ');'
			
			-- + @crlftab + @tab + 'void Save' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' ' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME) + ');'
			+ 
			CASE 
				WHEN EXISTS(SELECT * FROM sys.schemas AS s1 INNER JOIN sys.objects AS o1 ON s1.schema_id = o1.schema_id WHERE s1.name = t.TABLE_SCHEMA AND o1.name = t.TABLE_NAME AND o1.type = 'U') THEN 
					@crlftab + @tab + 'void Save' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' ' + LOWER(REPLACE(t.TABLE_SCHEMA, 'dbo_', '') + '_' + t.TABLE_NAME) + ');'
					+ @crlftab + @tab + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' Delete' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + (SELECT CSHARPPKDECLARATIONS FROM @tblpk t3 WHERE t.TABLE_SCHEMA = t3.TABLE_SCHEMA AND t.TABLE_NAME = t3.TABLE_NAME) + ');'
				ELSE ''	-- no need of Add/Update/Delete for views
			END
			
			+ @crlftab + '}' 
			+ @crlf + '}'

	-- , tp1 = (SELECT TOP 1 COLVARIABLEDEFINITION FROM @t t3 WHERE t.TABLE_SCHEMA = t3.TABLE_SCHEMA AND t.TABLE_NAME = t3.TABLE_NAME)
	

	, Repository = @concreteimports + @crlf + 'namespace ' + @concretenamespace 
		+ @crlf + '{' + @tab + 
		
		@crlftab + 'public class EF' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 'Repository : I' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 'Repository'
		+ @crlftab + '{'
		
		+ @crlftab + @tab + 'private ' + @dbcontextname + ' context = new ' + @dbcontextname + '();' + @crlftab
		
		+ @crlftab + @tab + 'public IEnumerable<' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '> ' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's'
		+ @crlftab + @tab + '{'
		+ @crlftab + @tab + @tab + 'get'
		+ @crlftab + @tab + @tab + '{'
		+ @crlftab + @tab + @tab + @tab + 'return context.' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's;'
		+ @crlftab + @tab + @tab + '}'
		+ @crlftab + @tab + '}' + @crlftab

		+ 
		CASE 
				WHEN EXISTS(SELECT * FROM sys.schemas AS s1 INNER JOIN sys.objects AS o1 ON s1.schema_id = o1.schema_id WHERE s1.name = t.TABLE_SCHEMA AND o1.name = t.TABLE_NAME AND o1.type = 'U') THEN 
					@crlftab + @tab + 'public ' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' Delete' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + (SELECT CSHARPPKDECLARATIONS FROM @tblpk t3 WHERE t.TABLE_SCHEMA = t3.TABLE_SCHEMA AND t.TABLE_NAME = t3.TABLE_NAME) + ')'
					+ @crlftab + @tab + '{'
					+ @crlftab + @tab + @tab + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' dbEntry = context.' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's.Find(' + (SELECT PKCOLS FROM @tblpk t3 WHERE t.TABLE_SCHEMA = t3.TABLE_SCHEMA AND t.TABLE_NAME = t3.TABLE_NAME) + ');'
					+ @crlftab + @tab + @tab + 'if (dbEntry != null)'
					+ @crlftab + @tab + @tab + '{'
					+ @crlftab + @tab + @tab + @tab + 'context.' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's.Remove(dbEntry);'
					+ @crlftab + @tab + @tab + @tab + 'context.SaveChanges();'
					+ @crlftab + @tab + @tab + '}'
					+ @crlftab + @tab + @tab + 'return dbEntry;'
					+ @crlftab + @tab + '}' + @crlftab

					+ @crlftab + @tab + 'public void ' + 'Save' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + '(' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' ' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME) + ')'
					+ @crlftab + @tab + '{'
					+ @crlftab + @tab + @tab + 'if (' + (SELECT LTRIM(RTRIM(CSHARPPKCHECKEMPTY)) FROM @tblpk t3 WHERE t.TABLE_SCHEMA = t3.TABLE_SCHEMA AND t.TABLE_NAME = t3.TABLE_NAME) + ')'
					+ @crlftab + @tab + @tab + '{'
					+ @crlftab + @tab + @tab + @tab + 'context.' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's.Add(' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME) + ');'
					+ @crlftab + @tab + @tab + '}'
					+ @crlftab + @tab + @tab + 'else'
					+ @crlftab + @tab + @tab + '{'
					+ @crlftab + @tab + @tab + @tab + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + ' dbEntry = context.' + REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME + 's.Add(' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t.TABLE_NAME) + ');'
					+ @crlftab + @tab + @tab + @tab + 'if (dbEntry != null)'
					+ @crlftab + @tab + @tab + @tab + '{'
					+ @crlf
					+
					STUFF	
					(
						(
							SELECT @crlftab + @tab + @tab + @tab + @tab + 'dbEntry.' + REPLACE(REPLACE(REPLACE(REPLACE(t2.COLNAME, ']', ''), '[', ''), ', ', ''), ' ', '') + ' = ' + LOWER(REPLACE(t.TABLE_SCHEMA + '_', 'dbo_', '') + t2.TABLE_NAME) + '.' + REPLACE(REPLACE(REPLACE(REPLACE(t2.COLNAME, ']', ''), '[', ''), ', ', ''), ' ', '') + ';'
							FROM @t t2
							WHERE t.TABLE_SCHEMA = t2.TABLE_SCHEMA AND t.TABLE_NAME = t2.TABLE_NAME AND ISNULL(t2.ISPK, 0) = 0           
							FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
						)
						, 1, 1, ''
					) 
			
					+ @crlftab + @tab + @tab + @tab + '}'
					+ @crlftab + @tab + @tab + '}'
					+ @crlftab + @tab + @tab + 'context.SaveChanges();'
					+ @crlftab + @tab + '}'
				ELSE ''
			END

		+ @crlftab + '}' 
		+ @crlf + '}'
FROM @t t
GROUP BY t.TABLE_SCHEMA, t.TABLE_NAME

-- SELECT * FROM @t
SELECT * 
FROM @tblout1

-------------------------------- models and stored procedures S T A R T ---------------------------------------
-- get sql server version
DECLARE @ver nvarchar(128)
SET @ver = CAST(serverproperty('ProductVersion') AS nvarchar)
SET @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)

DECLARE @issqlver_2k12_orlater bit
IF @ver >= 11 SET @issqlver_2k12_orlater = 1
ELSE SET @issqlver_2k12_orlater = 0
-- SELECT @issqlver_2k12_orlater

/*
SELECT p.name, pms.name, pms.parameter_id, tp.name AS user_data_type_name, 
	system_data_type_name = 
		CASE ISNULL(tp.is_user_defined, 0)
			WHEN 1 THEN stp.name
			ELSE tp.name
		END,
	stp.is_nullable, stp.max_length, stp.precision, stp.scale, 
	-- tp.user_type_id, tp.system_type_id, tp.is_user_defined, 
	pms.has_default_value, pms.default_value, pms.is_output, pms.max_length, pms.precision, pms.scale, p.type, p.type_desc, pms.*
FROM sys.procedures AS p

LEFT OUTER JOIN sys.parameters AS pms
	ON p.object_id = pms.object_id

LEFT OUTER JOIN sys.types AS tp
	ON tp.user_type_id = pms.user_type_id

LEFT OUTER JOIN sys.types AS stp
	ON tp.system_type_id = stp.system_type_id
		AND stp.system_type_id = stp.user_type_id

ORDER BY p.name, pms.parameter_id
*/

IF @issqlver_2k12_orlater = 0
BEGIN
	-----------------------------------------------------------------------------------------------------
	-- Purpose: List column data types returned by stored procedures (that return tables) in a given database
	-- Limitations: 
	-- a) Only lists data types of first dataset returned by each stored procedure.
	-- b) Does not list scalar stored procedures (i.e., sps that do not return datasets)
	-- c) IMPORTANT: This script currently works only on all versions of SQL Server
	-- There is however an SQL Server 2012 and higher only script snippet below that was commented out.
	-----------------------------------------------------------------------------------------------------
	-- delete any existing linked servers (for versions earlier than SQL Server 2012)
	IF EXISTS(SELECT * FROM sys.servers WHERE name = N'loopback_1869_del_later')
		BEGIN
			EXEC master.sys.sp_dropserver 'loopback_1869_del_later','droplogins'
		END

	BEGIN
	
	
		-- create a new linked server
		EXEC master..sp_addlinkedserver 
			@server = 'loopback_1869_del_later',  
			@srvproduct = '',
			@provider = 'SQLNCLI',
			@datasrc = @@SERVERNAME;

		EXEC master..sp_serveroption 
			@server = 'loopback_1869_del_later', 
			@optname = 'DATA ACCESS',
			@optvalue = 'TRUE';
	
	END
END

DECLARE @sp_schema nvarchar(255), @sp_name nvarchar(255), @ssqlexec nvarchar(max)
DECLARE @ssqlopenquery nvarchar(max)
DECLARE spcur CURSOR FOR 
SELECT DISTINCT s.[name] AS sp_schema, p.[name] AS sp_name
			, ssql = 
				LTRIM(RTRIM(
				CASE pm.is_output
					WHEN 1 THEN 'DECLARE ' + CAST(pm.[name] as nvarchar(max)) + ' ' + tp.[name] + 
						CASE tp.name
							WHEN 'char' THEN '(' + CAST(pm.max_length AS varchar(20)) + ')'
							WHEN 'nchar' THEN '(' + CAST(pm.max_length AS varchar(20)) + ')'
							WHEN 'varchar' THEN '(' + CAST(pm.max_length AS varchar(20)) + ')'
							WHEN 'nvarchar' THEN '(' + CAST(pm.max_length AS varchar(20)) + ')'

							WHEN 'decimal' THEN '(' + CAST(pm.[precision] AS varchar(40)) + ', ' + CAST(pm.[scale] AS varchar(40)) + ')'
							WHEN 'numeric' THEN '(' + CAST(pm.[precision] AS varchar(40)) + ', ' + CAST(pm.[scale] AS varchar(40)) + ')'

							ELSE ''
						END
					ELSE ''
				END + ';EXEC [' + @@SERVERNAME + '].[' + DB_NAME() + '].[' + s.[name] + '].[' + p.[name] + '] ' + ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + 
						CASE pm.is_output
							WHEN 1 THEN ' ' + CAST(pm.name as nvarchar(max)) + ' OUTPUT'
							ELSE CAST(pm.name as nvarchar(max)) + ' = NULL'
						END
						
					FROM sys.all_parameters pm
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '')
			)) + ';'
	-- , pm.parameter_id, pm.is_output
	-- , pm.is_cursor_ref, pm.is_cursor_ref, pm.is_readonly, pm.is_xml_document, pm.default_value, pm.has_default_value
FROM sys.procedures as p
INNER JOIN sys.schemas AS s
	ON p.schema_id = s.schema_id
LEFT OUTER JOIN sys.parameters AS pm
	ON p.object_id = pm.object_id
LEFT OUTER JOIN sys.types AS tp
	ON pm.user_type_id = tp.user_type_id

OPEN spcur
FETCH NEXT FROM spcur
INTO @sp_schema, @sp_name, @ssqlexec

-- for versions earlier than SQL Server 2012
DECLARE @tblcnt nvarchar(20)
SET @tblcnt = 0

IF OBJECT_ID('tempdb..#tblprocreturns0') IS NOT NULL DROP TABLE #tblprocreturns0
CREATE TABLE #tblprocreturns0
(
	table_schema nvarchar(255)
	, table_name nvarchar(255)
	, sp_schema nvarchar(255)
	, sp_name nvarchar(255)
	-- , sp_sql nvarchar(max)
	, column_ordinal int
	, column_name nvarchar(255)
	, column_data_type nvarchar(255)
	, column_is_nullable bit
	, column_max_length int
	, column_precision int
	, column_scale int
)

DECLARE @tblprocreturns0 AS TABLE
(
	table_schema nvarchar(255)
	, table_name nvarchar(255)
	, sp_schema nvarchar(255)
	, sp_name nvarchar(255)
	-- , sp_sql nvarchar(max)
	, column_ordinal int
	, column_name nvarchar(255)
	, column_data_type nvarchar(255)
	, column_is_nullable bit
	, column_max_length int
	, column_precision int
	, column_scale int
)

WHILE @@FETCH_STATUS = 0
BEGIN
	-- for versions earlier than SQL Server 2012
	SET @tblcnt = @tblcnt + 1
	SET @ssqlexec = ';SET NOCOUNT ON; SET FMTONLY ON ' + @ssqlexec + ' SET FMTONLY OFF; SET NOCOUNT OFF; '
	-- PRINT @ssqlexec;

	SET @ssqlopenquery = 'SELECT * INTO #tmp FROM OPENQUERY(loopback_1869_del_later, ''' + @ssqlexec + ''');'
	
	-- s.[name] AS table_schema, t.name AS table_name, 
	
	SET @ssqlopenquery = @ssqlopenquery + 
			' INSERT INTO #tblprocreturns0 SELECT s.[name] AS table_schema, t.name AS table_name, ''' + @sp_schema + ''' AS sp_schema, ''' + @sp_name + ''' AS sp_name, c.column_id AS column_ordinal, c.name AS column_name, tp.[name] AS column_data_type, c.is_nullable AS column_is_nullable, c.max_length AS column_max_length, c.precision AS column_precision, c.scale AS column_scale
			FROM [loopback_1869_del_later].tempdb.sys.tables AS t
			INNER JOIN [loopback_1869_del_later].tempdb.sys.schemas AS s
			ON s.schema_id = t.schema_id
			INNER JOIN [loopback_1869_del_later].tempdb.sys.columns AS c
			ON t.object_id = c.object_id
			LEFT OUTER JOIN [loopback_1869_del_later].tempdb.sys.types AS tp
			ON c.user_type_id = tp.user_type_id
			WHERE t.[name] LIKE ''#tmp%''
			ORDER BY c.column_id;'
	

	-- execute the query
	BEGIN TRY
		-- PRINT 'S T A R T : ' + @ssqlopenquery
		
		IF @issqlver_2k12_orlater = 0
		BEGIN
		-- for versions earlier than SQL Server 2012
		-- Reason for abandoning this code: Could not identify the tempdb table in which records were inserted by SELECT * INTO OPENQUERY statement. 
		-- There seem to be some limitations using OPENQUERY and with linked servers.
		EXEC sp_executesql @ssqlopenquery

		/*
		-- INSERT INTO @tblprocreturns0
		SELECT s.[name] AS table_schema, t.name AS table_name, @sp_schema AS sp_schema, @sp_name AS sp_name, c.column_id AS column_ordinal, c.name AS column_name, tp.[name] AS column_data_type, c.max_length AS column_max_length, c.precision AS column_precision, c.scale AS column_scale
		FROM [loopback_1869_del_later].tempdb.sys.tables AS t
		INNER JOIN [loopback_1869_del_later].tempdb.sys.schemas AS s
		ON s.schema_id = t.schema_id
		INNER JOIN [loopback_1869_del_later].tempdb.sys.columns AS c
		ON t.object_id = c.object_id
		LEFT OUTER JOIN [loopback_1869_del_later].tempdb.sys.types AS tp
		ON c.user_type_id = tp.user_type_id
		WHERE t.[name] LIKE '#tmp%'
		ORDER BY c.column_id
		*/
		

		END
		ELSE
		BEGIN
			-- only works from SQL Server 2012 or higher
			INSERT INTO @tblprocreturns0
			SELECT 
				NULL AS table_schema, NULL AS table_name,	
				@sp_schema, @sp_name
				-- , @ssqlexec
				, T.column_ordinal, T.name AS column_name 
				-- , T.system_type_name AS column_data_type, 
				, tp.[name] AS column_data_type
				, T.is_nullable AS column_is_nullable
				, T.max_length AS column_max_length, T.precision AS column_precition, T.scale AS column_scale
				-- , T.user_type_schema
			FROM sys.dm_exec_describe_first_result_set(@ssqlexec, NULL, 1) AS T
			LEFT OUTER JOIN sys.types AS tp
						ON T.system_type_id = tp.system_type_id
				AND ISNULL(tp.is_user_defined, 0) = 0
				AND tp.system_type_id = tp.user_type_id
			WHERE ISNULL(T.is_hidden, 0) = 0;
		
		END
		-- PRINT 'S T O P'
	END TRY
	BEGIN CATCH
		PRINT 'Error: ' + CAST(ERROR_NUMBER() AS varchar(20)) + ', ' + ERROR_MESSAGE()
	END CATCH

	FETCH NEXT FROM spcur
	INTO @sp_schema, @sp_name, @ssqlexec
END

CLOSE spcur
DEALLOCATE spcur

--SELECT * 
--FROM #tblprocreturns0

--SELECT * 
--FROM @tblprocreturns0
--ORDER BY sp_schema, sp_name, column_ordinal

IF @issqlver_2k12_orlater = 0
BEGIN
	--SELECT * 
	--FROM #tblprocreturns0

	INSERT INTO @tblprocreturns0
	SELECT * 
	FROM #tblprocreturns0
	-- ORDER BY sp_schema, sp_name, column_ordinal

	-- finally delete the temp table
	IF OBJECT_ID('tempdb..#tblprocreturns0') IS NOT NULL DROP TABLE #tblprocreturns0

	/*
	SELECT * 
	FROM @tblprocreturns0
	ORDER BY sp_schema, sp_name, column_ordinal
	*/

	-- delete any existing linked servers (for versions earlier than SQL Server 2012)
	IF EXISTS(SELECT * FROM sys.servers WHERE name = N'loopback_1869_del_later')
	BEGIN
		EXEC master.sys.sp_dropserver 'loopback_1869_del_later','droplogins'
	END
END

DECLARE @tblprocdefs AS TABLE
(
	sp_schema nvarchar(255), 
	sp_name nvarchar(255), 
	sql_param_vardef nvarchar(max), 
	sql_param_var nvarchar(max),
	sql_dbtype_param nvarchar(max), 
	csharp_output_param nvarchar(max),
	csharp_param_def nvarchar(max), 
	csharp_param nvarchar(max), 	
	csharp_sp_returnmodel nvarchar(max), 
	csharp_sp_def nvarchar(max), 
	vbnet_params nvarchar(max), 
	returntype nvarchar(50)
)

INSERT INTO @tblprocdefs
SELECT DISTINCT s.[name] AS sp_schema, p.[name] AS sp_name
	, sql_param_vardef = ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + CAST(pm.name as nvarchar(max)) + ' ' + stp.name + 
						CASE 
							WHEN stp.name IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 
								CASE pm.max_length
									WHEN -1 THEN '(max)'
									ELSE '(' + CAST(pm.max_length/2 AS varchar(20)) + ')'
								END
							WHEN stp.name IN ('decimal', 'numeric') THEN '(' + CAST(pm.precision AS varchar(20)) + ', ' + CAST(pm.scale AS varchar(20)) + ')'
							ELSE ''
						END + 
						CASE ISNULL(pm.is_output, 0)
							WHEN 1 THEN ' out'
							ELSE ''
						END
						
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '')
		
		, sql_param_var = ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + CAST(pm.name + '' as nvarchar(max))
					FROM sys.all_parameters pm
					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '')

		, sqldbtype_param = ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT @crlftab + @tab + @tab + 'var ' + REPLACE(pm.name, '@', '') + 'Param = new SqlParameter { ' + 
						'ParameterName = "' + pm.name + '", SqlDbType = ' + 
						CASE stp.name
							WHEN 'bigint' THEN 'SqlDbType.BigInt'
							WHEN 'binary' THEN 'SqlDbType.VarBinary'
							WHEN 'bit' THEN 'SqlDbType.Bit'
							WHEN 'char' THEN 'SqlDbType.Char'
							WHEN 'date' THEN 'SqlDbType.Date'
							WHEN 'datetime' THEN 'SqlDbType.DateTime'
							WHEN 'datetime2' THEN 'SqlDbType.DateTime2'
							WHEN 'datetimeoffset' THEN 'SqlDbType.DateTimeOffset'
							WHEN 'decimal' THEN 'SqlDbType.Decimal'
							WHEN 'FILESTREAM attribute (varbinary(max))' THEN 'SqlDbType.VarBinary'
							WHEN 'float' THEN 'SqlDbType.Float'
							WHEN 'image' THEN 'SqlDbType.Binary'
							WHEN 'int' THEN 'SqlDbType.Int'
							WHEN 'money' THEN 'SqlDbType.Money'
							WHEN 'nchar' THEN 'SqlDbType.NChar'
							WHEN 'ntext' THEN 'SqlDbType.NText'
							WHEN 'numeric' THEN 'SqlDbType.Decimal'
							WHEN 'nvarchar' THEN 'SqlDbType.NVarChar'
							WHEN 'real' THEN 'SqlDbType.Real'
							WHEN 'rowversion' THEN 'SqlDbType.Timestamp'
							WHEN 'smalldatetime' THEN 'SqlDbType.DateTime'
							WHEN 'smallint' THEN 'SqlDbType.SmallInt'
							WHEN 'smallmoney' THEN 'SqlDbType.SmallMoney'
							WHEN 'sql_variant' THEN 'SqlDbType.Variant'
							WHEN 'text' THEN 'SqlDbType.Text'
							WHEN 'time' THEN 'SqlDbType.Time'
							WHEN 'timestamp' THEN 'SqlDbType.Timestamp'
							WHEN 'tinyint' THEN 'SqlDbType.TinyInt'
							WHEN 'uniqueidentifier' THEN 'SqlDbType.UniqueIdentifier'
							WHEN 'varbinary' THEN 'SqlDbType.VarBinary'
							WHEN 'varchar' THEN 'SqlDbType.VarChar'
							WHEN 'xml' THEN 'SqlDbType.Xml'
							ELSE 'SqlDbType.VarChar'
						END + 
						', Direction = ParameterDirection.' + 
						CASE ISNULL(pm.is_output, 0)
							WHEN 1 THEN 'Output'
							ELSE 'Input' + 
								', Value = ' + REPLACE(pm.name, '@', '') + 
								CASE 
									WHEN ISNULL(stp.is_nullable, 0) = 1 AND stp.name NOT IN ('char', 'varchar', 'nchar', 'nvarchar', 'binary', 'varbinary', 'varbinary(max)', 'image', 'rowversion', 'timestamp') THEN '.GetValueOrDefault()'
									ELSE ''
								END
						END + 						
						CASE
							WHEN stp.name IN ('char', 'varchar', 'nchar', 'nvarchar') THEN ', Size = ' + 
								CASE 
									WHEN pm.max_length = -1 THEN '-1'	-- (ex: varchar(max))
									WHEN pm.max_length > 0 THEN CAST(pm.max_length/2 AS varchar(100))
									ELSE CAST(pm.max_length AS varchar(100))
								END
							ELSE ''
						END + 
						' };'

						
					FROM sys.all_parameters pm

					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '')
		
		, csharp_output_param = 
			ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT @crlf + CAST(REPLACE(pm.name, '@', '') as nvarchar(max)) + ' = (' + 						
						CASE stp.name
							WHEN 'varchar' THEN 'string'
							WHEN 'char' THEN 'string'
							WHEN 'nvarchar' THEN 'string'
							WHEN 'nchar' THEN 'string'

							WHEN 'bigint' THEN 'long'
							WHEN 'int' THEN 'int'
							WHEN 'smallint' THEN 'short'
							WHEN 'tinyint' THEN 'byte'

							WHEN 'decimal' THEN 'decimal'
							WHEN 'numeric' THEN 'decimal'
							WHEN 'smallmoney' THEN 'decimal'
							WHEN 'money' THEN 'decimal'

							WHEN 'float' THEN 'double'
							WHEN 'real' THEN 'float'

							WHEN 'smalldatetime' THEN 'DateTime'
							WHEN 'date' THEN 'DateTime'
							WHEN 'datetime' THEN 'DateTime'
							WHEN 'datetime2' THEN 'DateTime'
							WHEN 'datetimeoffset' THEN 'DateTimeOffset'

							WHEN 'time' THEN 'TimeSpan'

							WHEN 'bit' THEN 'bool'
							WHEN 'uniqueidentifier' THEN 'Guid'
							WHEN 'image' THEN 'byte[]'
							WHEN 'binary' THEN 'byte[]'
							WHEN 'varbinary' THEN 'byte[]'
							WHEN 'varbinary(max)' THEN 'byte[]'
							WHEN 'image' THEN 'byte[]'
							ELSE 'string'
						END + 						
						') ' + CAST(REPLACE(pm.name, '@', '') as nvarchar(max)) + 'Param.Value; // output'						
						
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id AND ISNULL(pm.is_output, 0) = 1
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '')

		, csharp_param_def = 
			ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + 
						
						CASE ISNULL(pm.is_output, 0)
							WHEN 1 THEN ' out '
							ELSE ' '
						END + 
						
						CASE stp.name
							WHEN 'varchar' THEN 'string'
							WHEN 'char' THEN 'string'
							WHEN 'nvarchar' THEN 'string'
							WHEN 'nchar' THEN 'string'

							WHEN 'bigint' THEN 'long'
							WHEN 'int' THEN 'int'
							WHEN 'smallint' THEN 'short'
							WHEN 'tinyint' THEN 'byte'

							WHEN 'decimal' THEN 'decimal'
							WHEN 'numeric' THEN 'decimal'
							WHEN 'smallmoney' THEN 'decimal'
							WHEN 'money' THEN 'decimal'

							WHEN 'float' THEN 'double'
							WHEN 'real' THEN 'float'

							WHEN 'smalldatetime' THEN 'DateTime'
							WHEN 'date' THEN 'DateTime'
							WHEN 'datetime' THEN 'DateTime'
							WHEN 'datetime2' THEN 'DateTime'
							WHEN 'datetimeoffset' THEN 'DateTimeOffset'

							WHEN 'time' THEN 'TimeSpan'

							WHEN 'bit' THEN 'bool'
							WHEN 'uniqueidentifier' THEN 'Guid'
							WHEN 'image' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'binary' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'varbinary' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'varbinary(max)' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'image' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							ELSE 'string'
						END + 
						
						CASE 
							WHEN ISNULL(stp.is_nullable, 0) = 1 AND stp.name NOT IN ('char', 'nchar', 'varchar', 'nvarchar', 'binary', 'varbinary', 'varbinary(max)', 'image') THEN '? '
							ELSE ' '
						END + 

						'' + 
						
						CAST(REPLACE(pm.name, '@', '') as nvarchar(max)) + ''
						
						
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '') + 
			CASE 
				WHEN pr.table_name IS NOT NULL AND EXISTS(SELECT * FROM sys.parameters WHERE p.object_id = object_id) THEN ', out int procResult'
				WHEN pr.table_name IS NOT NULL THEN 'out int procResult'
				ELSE ''
			END
			
		, csharp_param = 
			ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + 
						
						CAST(REPLACE(pm.name + 'Param', '@', '') as nvarchar(max)) + ' '
						
						
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '') + 
			CASE 
				WHEN pr.table_name IS NOT NULL AND EXISTS(SELECT * FROM sys.parameters WHERE p.object_id = object_id) THEN ', procResultParam'
				WHEN pr.table_name IS NOT NULL THEN 'procResultParam'
				ELSE ''
			END
		
		, csharp_sp_returnmodel = 
			ISNULL(
				'public class ' + REPLACE(pr.sp_schema + '_', 'dbo_', '') + pr.sp_name + 'ReturnModel' + 
				@crlftab + '{' + @crlf + 
				ISNULL(
					LTRIM(RTRIM(STUFF(
					(
						SELECT @crlftab + @tab + 'public ' + 
							CASE pr0.column_data_type
								WHEN 'bigint' THEN 'Int64'
								WHEN 'binary' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'bit' THEN 'Boolean'
								WHEN 'char' THEN 'String'
								WHEN 'date' THEN 'DateTime'
								WHEN 'datetime' THEN 'DateTime'
								WHEN 'datetime2' THEN 'DateTime'
								WHEN 'datetimeoffset' THEN 'DateTimeOffset'
								WHEN 'decimal' THEN 'Decimal'
								WHEN 'FILESTREAM attribute (varbinary(max))' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'float' THEN 'Double'
								WHEN 'image' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'int' THEN 'Int32'
								WHEN 'money' THEN 'Decimal'
								WHEN 'nchar' THEN 'String'
								WHEN 'ntext' THEN 'String'
								WHEN 'numeric' THEN 'Decimal'
								WHEN 'nvarchar' THEN 'String'
								WHEN 'real' THEN 'Single'
								WHEN 'rowversion' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'smalldatetime' THEN 'DateTime'
								WHEN 'smallint' THEN 'Int16'
								WHEN 'smallmoney' THEN 'Decimal'
								WHEN 'sql_variant' THEN 'Object *'
								WHEN 'text' THEN 'String'
								WHEN 'time' THEN 'TimeSpan'
								WHEN 'timestamp' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'tinyint' THEN 'Byte'
								WHEN 'uniqueidentifier' THEN 'Guid'
								WHEN 'varbinary' THEN 
									CASE ISNULL(pr0.column_is_nullable, 0)
										WHEN 1 THEN 'Byte?[]'
										ELSE 'Byte[]'
									END
								WHEN 'varchar' THEN 'String'
								WHEN 'xml' THEN 'Xml'
								ELSE pr0.column_data_type
							END + 
							CASE 
								WHEN pr0.column_data_type IN ('char', 'nchar', 'varchar', 'nvarchar', 'text', 'ntext', 'binary', 'varbinary', 'varbinary(max)', 'image', 'rowversion', 'timestamp') THEN ''
								ELSE '?'
							END + ' ' + 
							pr0.column_name + ' { get; set; }'
						FROM @tblprocreturns0 AS pr0
						WHERE pr0.sp_schema = pr.sp_schema
							AND pr0.sp_name = pr.sp_name
							--AND pr0.column_name = pr.column_name
						ORDER BY pr0.sp_schema, pr0.sp_name, pr0.column_ordinal
						FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
					), 1, 1, '')))
				, '') + 
				@crlftab + '}' + @crlf
			, '')
		
		, csharp_sp_def = 
			CASE 
				WHEN pr.sp_name IS NOT NULL THEN 'List<' + REPLACE(s.[name] + '_', 'dbo_', '') + p.[name] + 'ReturnModel> '
				ELSE 'int '
			END + 
			REPLACE(s.[name] + '_', 'dbo_', '') + p.[name] + '(' + 
			ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + 
						
						CASE ISNULL(pm.is_output, 0)
							WHEN 1 THEN ' out '
							ELSE ''
						END + 
						
						CASE stp.name
							WHEN 'varchar'THEN 'string'
							WHEN 'char' THEN 'string'
							WHEN 'nvarchar' THEN 'string'
							WHEN 'nchar' THEN 'string'

							WHEN 'bigint' THEN 'long'
							WHEN 'int' THEN 'int'
							WHEN 'smallint' THEN 'short'
							WHEN 'tinyint' THEN 'byte'

							WHEN 'decimal' THEN 'decimal'
							WHEN 'numeric' THEN 'decimal'
							WHEN 'smallmoney' THEN 'decimal'
							WHEN 'money' THEN 'decimal'

							WHEN 'float' THEN 'double'
							WHEN 'real' THEN 'float'

							WHEN 'smalldatetime' THEN 'DateTime'
							WHEN 'date' THEN 'DateTime'
							WHEN 'datetime' THEN 'DateTime'
							WHEN 'datetime2' THEN 'DateTime'
							WHEN 'datetimeoffset' THEN 'DateTimeOffset'

							WHEN 'time' THEN 'TimeSpan'

							WHEN 'bit' THEN 'bool'
							WHEN 'uniqueidentifier' THEN 'Guid'
							WHEN 'image' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'binary' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'varbinary' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'varbinary(max)' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							WHEN 'image' THEN 
								CASE ISNULL(stp.is_nullable, 0)
									WHEN 1 THEN 'byte?[]'
									ELSE 'byte[]'
								END
							ELSE 'string'
						END + 
						
						CASE 
							WHEN ISNULL(stp.is_nullable, 0) = 1 AND stp.name NOT IN ('char', 'nchar', 'varchar', 'nvarchar', 'binary', 'varbinary', 'varbinary(max)', 'image') THEN '? '							
							ELSE ' '
						END + 
						'' + 
						CAST(REPLACE(pm.name, '@', '') as nvarchar(max)) + ''						
						
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '') + 
			CASE 
				WHEN pr.table_name IS NOT NULL AND EXISTS(SELECT * FROM sys.parameters WHERE p.object_id = object_id) THEN ', out int procResult'
				WHEN pr.table_name IS NOT NULL THEN 'out int procResult'
				
				WHEN pr.sp_name IS NOT NULL AND EXISTS(SELECT * FROM sys.parameters WHERE p.object_id = object_id) THEN ', out int procResult'
				WHEN pr.sp_name IS NOT NULL THEN 'out int procResult'
				
				ELSE ''
			END
			+ ');'

		, vbnet_params = 
			ISNULL(
				LTRIM(RTRIM(STUFF(
				(
					SELECT ', ' + 
						
						CASE ISNULL(pm.is_output, 0)
							WHEN 1 THEN ' ByRef'
							ELSE ''
						END + ' ' + 
						
						CAST(REPLACE(pm.name, '@', '') as nvarchar(max)) + 

						CASE 
							WHEN ISNULL(stp.is_nullable, 0) = 1 AND stp.name NOT IN ('char', 'nchar', 'varchar', 'nvarchar') THEN '?'
							ELSE ''
						END + ' As ' + 

						CASE stp.name
							WHEN 'varchar' THEN 'String'
							WHEN 'char' THEN 'String'
							WHEN 'nvarchar' THEN 'String'
							WHEN 'nchar' THEN 'String'

							WHEN 'bigint' THEN 'Long'
							WHEN 'int' THEN 'Integer'
							WHEN 'smallint' THEN 'Short'
							WHEN 'tinyint' THEN 'Byte'

							WHEN 'decimal' THEN 'Decimal'
							WHEN 'numeric' THEN 'Decimal'
							WHEN 'smallmoney' THEN 'Decimal'
							WHEN 'money' THEN 'Decimal'

							WHEN 'float' THEN 'Double'
							WHEN 'real' THEN 'Float'

							WHEN 'smalldatetime' THEN 'DateTime'
							WHEN 'date' THEN 'DateTime'
							WHEN 'datetime' THEN 'DateTime'
							WHEN 'datetime2' THEN 'DateTime'
							WHEN 'datetimeoffset' THEN 'DateTimeOffset'

							WHEN 'time' THEN 'TimeSpan'

							WHEN 'bit' THEN 'Boolean'
							WHEN 'uniqueidentifier' THEN 'Guid'
							WHEN 'image' THEN 'Byte[]'
							WHEN 'binary' THEN 'Byte[]'
							WHEN 'varbinary' THEN 'Byte[]'
							WHEN 'varbinary(max)' THEN 'Byte[]'
							WHEN 'image' THEN 'Byte[]'
							ELSE 'String'
						END + 
						' '
					FROM sys.all_parameters pm
					
					LEFT OUTER JOIN sys.types AS tp
						ON tp.user_type_id = pm.user_type_id
					
					LEFT OUTER JOIN sys.types AS stp
						ON tp.system_type_id = stp.system_type_id
							AND stp.system_type_id = stp.user_type_id

					WHERE p.object_id = pm.object_id
					ORDER BY pm.parameter_id
					FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
				), 1, 1, '')))
			, '') + 
			CASE 
				WHEN pr.table_name IS NOT NULL AND EXISTS(SELECT * FROM sys.parameters WHERE p.object_id = object_id) THEN ', ByRef procResult As Integer'
				WHEN pr.table_name IS NOT NULL THEN 'ByRef procResult As Integer'
				ELSE ''
			END
		
		, returntype = 
			CASE 
				WHEN pr.[sp_name] IS NOT NULL THEN 'table'
				ELSE 'scalar'
			END
FROM sys.procedures AS p

INNER JOIN sys.schemas AS s
	ON p.schema_id = s.schema_id

LEFT OUTER JOIN @tblprocreturns0 pr
	ON s.[name] = pr.sp_schema
		AND p.[name] = pr.sp_name
WHERE p.type = 'P' AND p.name NOT IN ('GenerateCodeExcerpts', 'GeneratePKs', 'GeneratePocoCode')
ORDER BY s.[name], p.[name]

DECLARE @tblmodel AS TABLE
(
	sp_schema nvarchar(255), 
	sp_name nvarchar(255), 
	sql_param_vardef nvarchar(max), 
	sql_param_var nvarchar(max),
	sql_dbtype_param nvarchar(max), 
	csharp_output_param nvarchar(max),
	csharp_param_def nvarchar(max), 
	csharp_param nvarchar(max), 	
	csharp_sp_returnmodel nvarchar(max), 
	csharp_sp_def nvarchar(max), 
	vbnet_params nvarchar(max), 
	returntype nvarchar(50), 
	csharp_spmodel nvarchar(max)
)

--SELECT *
--FROM @tblprocdefs AS pd
--ORDER BY pd.sp_schema, pd.sp_name

INSERT INTO @tblmodel
SELECT pd.*, 
	csharp_spmodel = 
			CASE ISNULL(pd.returntype, 'scalar')
				WHEN 'table' THEN 'public List<' + REPLACE(pd.sp_schema + '_', 'dbo_', '') + pd.sp_name + 'ReturnModel> '
				ELSE 'public int '
			END + 
				
			REPLACE(pd.sp_schema + '_', 'dbo_', '') + pd.sp_name + 
				'(' + pd.csharp_param_def + 
				
				CASE ISNULL(pd.returntype, 'scalar')
					WHEN 'table' THEN 
						CASE
							WHEN ISNULL(pd.csharp_param_def, '') <> '' THEN ', out int procResult'
							ELSE 'out int procResult'
						END
					ELSE ''
				END + 

				')' + 
				@crlftab + @tab + '{' + 
				@crlf + 
					CASE 
						WHEN ISNULL(pd.sql_dbtype_param, '') <> '' THEN pd.sql_dbtype_param + 
							@crlftab + @tab + @tab + 'var procResultParam = new SqlParameter { ParameterName = "@procResult", SqlDbType = SqlDbType.Int, Direction = ParameterDirection.Output };' + @crlftab
						ELSE '' + 
							@crlftab + @tab + @tab + 'var procResultParam = new SqlParameter { ParameterName = "@procResult", SqlDbType = SqlDbType.Int, Direction = ParameterDirection.Output };' + @crlftab
					END + 
				@crlftab + @tab + @tab + 
					CASE 
						WHEN ISNULL(pd.returntype, '') = 'table' THEN  'var procResultData = Database.SqlQuery<' + REPLACE(pd.sp_schema + '_', 'dbo_', '') + pd.sp_name + 'ReturnModel>("EXEC @procResult = [' + pd.sp_schema + '].[' + pd.sp_name + '] ' + pd.sql_param_var + 
							CASE 
								WHEN ISNULL(pd.csharp_param, '') <> '' THEN '", ' + pd.csharp_param + ').ToList();'
								ELSE '").ToList();'
							END 
						ELSE 'Database.ExecuteSqlCommand("EXEC @procResult = [' + pd.sp_schema + '].[' + pd.sp_name + '] ' + pd.sql_param_var + 
								CASE 
									WHEN ISNULL(pd.csharp_param, '') <> '' THEN '", ' + pd.csharp_param + ');'	-- .ToList()
									ELSE '");'	-- .ToList()
								END
					END + 				
				CASE 
					WHEN ISNULL(pd.csharp_output_param, '') <> '' THEN @crlftab + @tab + @tab + pd.csharp_output_param
					ELSE ''
				END + 				
				CASE 
					WHEN ISNULL(pd.returntype, '') = 'table' THEN  @crlftab + @tab + @tab + 'procResult = (int) procResultParam.Value;'
					ELSE ''
				END + ' ' + 
				@crlftab + @tab + @crlftab + @tab + @tab + 
				CASE 
					WHEN ISNULL(pd.returntype, '') = 'table' THEN  'return procResultData;' 
					ELSE 'return (int) procResultParam.Value;'
				END + 
				@crlftab + @tab + '}' + @crlf
FROM @tblprocdefs AS pd
ORDER BY pd.sp_schema, pd.sp_name

/*SELECT *
FROM @tblmodel
ORDER BY sp_schema, sp_name*/

DECLARE @tblDbSet AS TABLE
(
	type nvarchar(10), 
	table_schema nvarchar(255), 
	table_name nvarchar(255), 
	IDbSet_IDispose nvarchar(max), 
	IDbSet_DbContext nvarchar(max), 
	OnModelCreating nvarchar(max), 
	CreateModel nvarchar(max)
)

INSERT INTO @tblDbSet
SELECT t.type, s.name AS table_schema, t.name AS table_name 
	, IDbset_IDispose = 
			'IDbSet<' + REPLACE(s.name + '_', 'dbo_', '') + 			
			+ t.name + '> ' + REPLACE(s.name + '_', 'dbo_', '') + 			 
			+ t.name + 's { get; set; } // [' + s.name + '].[' + t.name + ']' 
	
	, IDbSet_DbContext = 
		'public IDbSet<' + REPLACE(s.name + '_', 'dbo_', '') + 			
			+ t.name + '> ' + REPLACE(s.name + '_', 'dbo_', '') + 
			+ t.name + 's { get; set; } // [' + s.name + '].[' + t.name + ']' 

	, OnModelCreating = 
		'modelBuilder.Configurations.Add(new ' + REPLACE(s.name + '_', 'dbo_', '') + 			
			+ t.name + 'Configuration());'

	, CreateModel = 
		'modelBuilder.Configurations.Add(new ' + REPLACE(s.name + '_', 'dbo_', '') + 			
			+ t.name + 'Configuration(schema));'
FROM sys.objects AS t
INNER JOIN sys.schemas AS s
ON t.schema_id = s.schema_id
WHERE t.type in ('U', 'V')
-- ORDER BY t.type, s.name, t.name

DECLARE @csharp_dbset_string AS nvarchar(max), @csharp_sp_returnmodel AS nvarchar(max)
SELECT 
	@csharp_dbset_string = 
		
		-- @sImportsForDbContext + @crlf + 
		-- 'namespace ' + @dbcontextname + 
		-- @crlf + '{' + 
		
		@crlftab + '// Unit of Work' + 
		@crlftab + 'public interface I' + @dbcontextname + ' : IDisposable' + 
		@crlftab + '{' + 
		@crlftab + @tab + '// Tables and Views' + @crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT @crlftab + @tab + CAST(t2.IDbSet_IDispose as nvarchar(max)) AS val
			FROM @tblDbSet t2
			ORDER BY t2.type, t2.table_schema, t2.table_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, '')))
		+ 
		@crlf + @crlftab + @tab + 'int SaveChanges();' + @crlf + 
        @crlftab + @tab + 'Task<int> SaveChangesAsync();' + @crlf + 
        @crlftab + @tab + 'Task<int> SaveChangesAsync(CancellationToken cancellationToken);' + @crlf + 
		@crlf + @crlftab + @tab + '// Stored Procedures' + @crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT --  @crlftab + @tab + '// Stored Procedure: [' + t3.sp_schema + '].[' + t3.sp_name + '](' + t3.sql_param_vardef + ');' + 
				@crlftab + @tab + CAST(t3.csharp_sp_def AS nvarchar(max)) AS val
			FROM @tblmodel t3
			ORDER BY t3.returntype, t3.sp_schema, t3.sp_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, '')))
		+ 
		@crlf + @tab + '}' + 
		
		@crlf + 
		@crlf + @tab + '// Database Context' + 
		@crlf + @tab + 'public class ' + @dbcontextname + ' : DbContext, I' + @dbcontextname + 
		@crlf + @tab + '{' + @crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT @crlftab + @tab + CAST(t2.IDbSet_DbContext as nvarchar(max)) AS val
			FROM @tblDbSet t2
			ORDER BY t2.type, t2.table_schema, t2.table_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, ''))) + 
		
		@crlftab + @tab + 
		@crlftab + @tab + 'static ' + @dbcontextname + '()' + 
		@crlftab + @tab + '{' + 
		@crlftab + @tab + @tab + 'Database.SetInitializer<' + @dbcontextname + '>(null);' + 
		@crlftab + @tab + '}' + 
		
		@crlftab + @tab + 
		@crlftab + @tab + 'public ' + @dbcontextname + '()' + 
		@crlftab + @tab + @tab + ' : base("Name = ' + @dbcontextname + '")' +  
		@crlftab + @tab + '{' + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + 'public ' + @dbcontextname + '(string connectionString)' + 
		@crlftab + @tab + @tab + ' : base(connectionString)' +  
		@crlftab + @tab + '{' + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + 'public ' + @dbcontextname + '(string connectionString, System.Data.Entity.Infrastructure.DbCompiledModel model)' + 
		@crlftab + @tab + @tab + ' : base(connectionString, model)' +  
		@crlftab + @tab + '{' + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + 'protected override void Dispose(bool disposing)' +  
		@crlftab + @tab + '{' + 
		@crlftab + @tab + @tab + 'base.Dispose(disposing);' + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + 'protected override void OnModelCreating(DbModelBuilder modelBuilder)' + 
		@crlftab + @tab + '{' + 
		@crlftab + @tab + @tab + 'base.OnModelCreating(modelBuilder);' + 
		@crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT @crlftab + @tab + @tab + CAST(t2.OnModelCreating as nvarchar(max)) AS val
			FROM @tblDbSet t2
			ORDER BY t2.type, t2.table_schema, t2.table_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, ''))) + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + 'public static DbModelBuilder CreateModel(DbModelBuilder modelBuilder, string schema)' + 
		@crlftab + @tab + '{' + @crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT @crlftab + @tab + @tab + CAST(t2.CreateModel as nvarchar(max)) AS val
			FROM @tblDbSet t2
			ORDER BY t2.type, t2.table_schema, t2.table_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, ''))) + @crlftab + @tab + @tab + 'return modelBuilder;' + 
		@crlftab + @tab + '}' + 

		@crlftab + @tab + 
		@crlftab + @tab + '// Stored Procedures' + @crlf + 
		LTRIM(RTRIM(STUFF(
		(	
			SELECT @crlftab + @tab + CAST(t2.csharp_spmodel as nvarchar(max)) AS val
			FROM @tblmodel t2
			ORDER BY t2.returntype, t2.sp_schema, t2.sp_name
			FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
		), 1, 1, ''))) + 
		
		@crlf + @tab + '}'
		-- + @crlf + '}'

		, @csharp_sp_returnmodel = 
			@tab + '// Stored Procedures Return Models' + @crlf + 
			LTRIM(RTRIM(STUFF(
			(	
				SELECT @crlftab + CAST(t2.csharp_sp_returnmodel as nvarchar(max)) AS val
				FROM @tblmodel t2
				WHERE ISNULL(t2.csharp_sp_returnmodel, '') <> ''
				ORDER BY t2.returntype, t2.sp_schema, t2.sp_name
				FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
			), 1, 1, '')))
			
-- FROM @tblDbSet
-- ORDER BY type, table_schema, table_name

-- SELECT @csharp_dbset_string AS [processing-instruction(x)] FOR XML PATH
-- SELECT @csharp_sp_returnmodel AS [processing-instruction(y)] FOR XML PATH

-- SELECT @csharp_dbset_string AS DBSetModels, @csharp_sp_returnmodel AS StoredProcsReturnModels

DECLARE @autoprops nvarchar(max)
SELECT @autoprops = 
			@crlftab + '// Entities' + @crlf + 
			LTRIM(RTRIM(STUFF(
			(	
				SELECT @crlftab + CAST(t2.AutoProps as nvarchar(max)) + @crlftab AS val
				FROM @tblout1 t2
				WHERE ISNULL(t2.AutoProps, '') <> ''
				ORDER BY t2.TableSchema, t2.TableName
				FOR XML PATH (''), TYPE).value('.', 'nvarchar(max)'
			), 1, 1, '')))

-- SELECT @autoprops AS AUTOPROPS

DECLARE @csharp_models nvarchar(max)
SELECT @csharp_models = 
	@sImportsForDbContext + @crlf + 
	'namespace ' + @entitynamespace + 
	@crlf + '{' + 
		@crlf + ISNULL(@csharp_dbset_string, '') + 
		
		@crlf + 
		
		CASE ISNULL(@IsEntitiesInSepFolder, 0)
			WHEN 1 THEN ''
			ELSE ISNULL(@autoprops, '')
		END + 
		-- @autoprops + 
		
		@crlf + ISNULL(@pococonfig, '') + 
		@crlf + ISNULL(@csharp_sp_returnmodel, '') + 
	@crlf + '}'

SELECT @csharp_models AS [processing-instruction(x)] FOR XML PATH
-------------------------------- models and stored procedures E N D -------------------------------------------


DECLARE @CSharpEFDbContext nvarchar(max), 
	@CSharpNinjectResolver nvarchar(max)

SELECT @CSharpEFDbContext = COALESCE(@CSharpEFDbContext, ' ', '') 
	+ @crlftab + @tab + 'public DbSet<' + REPLACE(TABLE_SCHEMA + '_', 'dbo_', '') + TABLE_NAME + '> ' + REPLACE(TABLE_SCHEMA + '_', 'dbo_', '') + TABLE_NAME + 's { get; set; }'
	
	, @CSharpNinjectResolver = COALESCE(@CSharpNinjectResolver, '', '') + 'kernel.Bind<I' + REPLACE(TABLE_SCHEMA + '_', 'dbo_', '') + TABLE_NAME + 'Repository>().To<EF' + REPLACE(TABLE_SCHEMA + '_', 'dbo_', '') + TABLE_NAME + 'Repository>();' + @crlftab + @tab + @tab
		
FROM @tblpk

SELECT @CSharpEFDbContext = 
	@efdbcontextimports + @crlf + 'namespace ' + @concretenamespace 
	+ @crlf + '{' + @tab + 
	+ @crlftab + 'public class EFDbContext : DbContext'
	+ @crlftab + '{'
	+ @CSharpEFDbContext
	+ @crlftab + '}'
	+ @crlf + '}'

	, @CSharpNinjectResolver = 
		@infrastructureimports + @crlf + 'namespace ' + @infrastructurenamespace 
		+ @crlf + '{' + @tab + 
		+ @crlftab + 'public class NinjectDependencyResolver : IDependencyResolver' + 
		@crlftab + '{' + 
        @crlftab + @tab + 'private IKernel kernel;' + 
		@crlftab + @tab + 'public NinjectDependencyResolver(IKernel kernelParam)' + 
        @crlftab + @tab + '{' + 
        @crlftab + @tab + @tab + 'kernel = kernelParam;' + 
        @crlftab + @tab + @tab + 'AddBindings();' + 
        @crlftab + @tab + '}' + @crlftab + 

        @crlftab + @tab + 'public object GetService(Type serviceType)' + 
        @crlftab + @tab + '{' + 
        @crlftab + @tab + @tab + 'return kernel.TryGet(serviceType);' + 
        @crlftab + @tab + '}' + @crlftab + 

        @crlftab + @tab + 'public IEnumerable<object> GetServices(Type serviceType)' + 
        @crlftab + @tab + '{' + 
        @crlftab + @tab + @tab + 'return kernel.GetAll(serviceType);' + 
        @crlftab + @tab + '}' + @crlftab + 

        @crlftab + @tab + 'public void AddBindings()' + 
        @crlftab + @tab + '{' + 
		@crlftab + @tab + @tab + '// bind from database using Entity Framework (EF)' + 
        @crlftab + @tab + @tab + @CSharpNinjectResolver + 
		@crlftab + @tab + '}' + 
		
		@crlftab + '}' + 
		@crlf + '}' 


SELECT TableSchema, TableName, ColCount, AutoProps, IRepository, Repository
FROM @tblout1
SELECT @CSharpEFDbContext, @CSharpNinjectResolver

DECLARE @TableSchema nvarchar(255), @TableName nvarchar(255), 
	@ColCount bigint, 
	-- @AutoProps nvarchar(max), 
	@IRepository nvarchar(max), 
	@Repository nvarchar(max)

DECLARE @MySpecialTempTable varchar(255)
DECLARE @Command nvarchar(4000)
DECLARE @Result int

---------------------------
-- Create Folders - START
---------------------------
-- before writing to files check if folders exist if not create folders
DECLARE @file_results table
(
	folder varchar(4000), 
	file_exists bit,
	file_is_a_directory bit,
	parent_directory_exists bit
)

DECLARE @folder varchar(4000), @file_exists bit, @file_is_a_directory bit, @parent_directory_exists bit

INSERT INTO @file_results (file_exists, file_is_a_directory, parent_directory_exists)
exec master.dbo.xp_fileexist @AutoPropsFolder
UPDATE @file_results
	SET folder = @AutoPropsFolder
WHERE folder IS NULL

INSERT INTO @file_results (file_exists, file_is_a_directory, parent_directory_exists)
exec master.dbo.xp_fileexist @IRepositoryFolder
UPDATE @file_results
	SET folder = @IRepositoryFolder
WHERE folder IS NULL

INSERT INTO @file_results (file_exists, file_is_a_directory, parent_directory_exists)
exec master.dbo.xp_fileexist @RepositoryFolder
UPDATE @file_results
	SET folder = @RepositoryFolder
WHERE folder IS NULL

INSERT INTO @file_results (file_exists, file_is_a_directory, parent_directory_exists)
exec master.dbo.xp_fileexist @InfrastructureFolder
UPDATE @file_results
	SET folder = @InfrastructureFolder
WHERE folder IS NULL

SELECT * FROM @file_results

DECLARE fc CURSOR FOR
SELECT folder, file_exists, file_is_a_directory, parent_directory_exists FROM @file_results

OPEN fc
FETCH NEXT FROM fc
INTO @folder, @file_exists, @file_is_a_directory, @parent_directory_exists

WHILE @@FETCH_STATUS = 0
BEGIN
	IF @file_is_a_directory = 0
	BEGIN
		EXECUTE master.dbo.xp_create_subdir @folder
	END

	FETCH NEXT FROM fc
	INTO @folder, @file_exists, @file_is_a_directory, @parent_directory_exists
END
-- close the cursor
CLOSE fc
DEALLOCATE fc
---------------------------
-- Create Folders - END
---------------------------

DECLARE @tmpcodegentbl AS TABLE
(
	[TableName] nvarchar(255)
    , [ColCount] int
    , [AutoProps] nvarchar(max)
    , [IRepository] nvarchar(max)
    , [Repository] nvarchar(max)
    , [EFDbContext] nvarchar(max)
    , [NInjectResolver] nvarchar(max)
	, [Models] nvarchar(max)
)

DECLARE c CURSOR FOR 
SELECT TableSchema, TableName, ColCount, AutoProps, IRepository, Repository
FROM @tblout1

OPEN c

FETCH NEXT FROM c
INTO @TableSchema, @TableName, @ColCount, @AutoProps, @IRepository, @Repository

WHILE @@FETCH_STATUS = 0
BEGIN
	-- DELETE FROM TMPCODEGEN
	-- INSERT INTO TMPCODEGEN
	-- (TableName, ColCount, AutoProps, IRepository, Repository)
	-- SELECT @TableName, @ColCount, @AutoProps, @IRepository, @Repository

	-- drop the temp table if it already exists
	IF OBJECT_ID('tempdb.dbo.SSTempCodeGen') IS NOT NULL DROP TABLE tempdb.dbo.SSTempCodeGen
	DELETE FROM @tmpcodegentbl
	INSERT INTO @tmpcodegentbl
	(TableName, ColCount, AutoProps, IRepository, Repository)
	SELECT @TableName, @ColCount, @AutoProps, @IRepository, @Repository

	SELECT * 
	INTO tempdb.dbo.SSTempCodeGen
	FROM @tmpcodegentbl	

	-- SELECT @bcpCommand = 'bcp "SELECT AutoProps FROM [' + DB_NAME() + '].[dbo].[TMPCODEGEN] WHERE AutoProps IS NOT NULL" queryout "' + @AutoPropsFolder + @TableSchema + '_' + @TableName + '.cs" -w -T -S ' + @@SERVERNAME
	IF ISNULL(@IsEntitiesInSepFolder, 0) = 1
	BEGIN
		SELECT @bcpCommand = 'bcp "SELECT AutoProps FROM [tempdb].[dbo].[SSTempCodeGen] WHERE AutoProps IS NOT NULL" queryout "' + @AutoPropsFolder + REPLACE(@TableSchema + '_', 'dbo_', '') + @TableName + '.cs" -w -T -S ' + @@SERVERNAME
		PRINT @bcpCommand
		EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT
	END

	SELECT @bcpCommand = 'bcp "SELECT IRepository FROM [tempdb].[dbo].[SSTempCodeGen] WHERE IRepository IS NOT NULL" queryout "' + @IRepositoryFolder + 'I' + REPLACE(@TableSchema + '_', 'dbo_', '') + @TableName + 'Repository.cs" -w -T -S ' + @@SERVERNAME
	PRINT @bcpCommand
	EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT

	SELECT @bcpCommand = 'bcp "SELECT Repository FROM [tempdb].[dbo].[SSTempCodeGen] WHERE Repository IS NOT NULL" queryout "' + @RepositoryFolder + 'EF' + REPLACE(@TableSchema + '_', 'dbo_', '') + @TableName + 'Repository.cs" -w -T -S ' + @@SERVERNAME
	PRINT @bcpCommand
	EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT

	FETCH NEXT FROM c
	INTO @TableSchema, @TableName, @ColCount, @AutoProps, @IRepository, @Repository
END

-- close the cursor
CLOSE c
DEALLOCATE c

UPDATE tempdb.dbo.SSTempCodeGen
	SET EFDbContext = @CSharpEFDbContext, NInjectResolver = @CSharpNinjectResolver, Models = @csharp_models

SELECT @bcpCommand = 'bcp "SELECT EFDbContext FROM [tempdb].[dbo].[SSTempCodeGen] WHERE EFDbContext IS NOT NULL" queryout "' + @RepositoryFolder + 'EFDbContext.cs" -w -T -S ' + @@SERVERNAME
PRINT @bcpCommand
EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT

SELECT @bcpCommand = 'bcp "SELECT NInjectResolver FROM [tempdb].[dbo].[SSTempCodeGen] WHERE NInjectResolver IS NOT NULL" queryout "' + @InfrastructureFolder + 'NInjectDependencyResolver.cs" -w -T -S ' + @@SERVERNAME
PRINT @bcpCommand
EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT

SELECT @bcpCommand = 'bcp "SELECT [Models] FROM [tempdb].[dbo].[SSTempCodeGen] WHERE [Models] IS NOT NULL" queryout "' + @InfrastructureFolder + 'EFModels.cs" -w -T -S ' + @@SERVERNAME
PRINT @bcpCommand
EXECUTE @Result= MASTER..xp_cmdshell @bcpCommand		-- , NO_OUTPUT

-- drop the temp table if it already exists
IF OBJECT_ID('tempdb.dbo.SSTempCodeGen') IS NOT NULL DROP TABLE tempdb.dbo.SSTempCodeGen
