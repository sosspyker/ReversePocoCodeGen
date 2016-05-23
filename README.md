# ReversePocoCodeGen
Generates .NET reverse poco classes for a given Micrsoft SQL Server (ver. 2005 or later) database


#### Requirements:

###### For code generation: 
_Microsoft SQL Server version 2005 or later_
###### For using the generated code: 
_C#, Entity Framework 6.0 or later, NInject (for dependency injection)_

#### How to use: 

Simply copy below stored procedures: 
    
        [GeneratePocoCode]
	    [GeneratePKs] 
to your Microsoft SQL Server (version >= 2005) database for which you need to generate the C# code.

1. Open SQL Server Query Analyser, 
2. Select New Query and select the database from drop-down list  from toolbar that needs code generation
3. Execute stored procedure ``` [GeneratePocoCode]```

###### Using ``` [GeneratePocoCode] ```:
```sql
USE [MyDb]
GO

DECLARE @RC int
DECLARE @appname nvarchar(500)              /* name of application */
    @RootFolder varchar(1000)               /* root folder where reverse poco code is generated */
    @AutoPropsFolder varchar(1000)          /* optional path (relative to root) for entity classes - default: '\Entities\' */
    @IRepositoryFolder varchar(1000)        /* optional path (relative to root) for repository interfaces - default: '\Abstract\' */
    @RepositoryFolder varchar(1000)         /* optional path (relative to root) for repository classes - default: '\Concrete\' */
    @InfrastructureFolder varchar(1000)     /* optional path (relative to root) for views, view-models, dbcotext, NInject classes - default: '\Infrastructure\' */
    @IsEntitiesInSepFolder bit              /* 0 => All entity classes in a single file in @InfrastructureFolder, 1 => Each entity written to a separate file in @AutoPropsFolder */

-- Set parameter values here.

EXECUTE @RC = [dbo].[GeneratePocoCode] 
   @appname
  ,@RootFolder
  ,@AutoPropsFolder
  ,@IRepositoryFolder
  ,@RepositoryFolder
  ,@InfrastructureFolder
  ,@IsEntitiesInSepFolder
GO
```

Ex: 
```sql
exec GeneratePocoCode 
		'MyDb',					-- name of your application
		'C:\MyTest\Domain'	    -- root folder where your reverse poco classes need to be generated)
```


#### What does it do?

Running this stored procedure generates the .NET reverse Poco classes in C# (VB.NET generation may be added later) under four different folders if defaults are used: 
* Entities
* Abstract
* Concrete and
* Infrastructure
