# ReversePocoCodeGen
<b>Purpose:</b> Generates .NET reverse poco classes for a given Micrsoft SQL Server (ver. 2005 or later) database

<b>Requirements:</b>
  	<b><i>For code generation:</b></i> Microsoft SQL Server version 2005 or later<br />
  	<b><i>For using the generated code:</b></i> C#, Entity Framework 6.0 or later, NInject (for dependency injection)
  
<b>How to use:</b> 
	Simply copy stored procedures:<br /> 
			<ul>
			  <li><code>[GeneratePocoCode]</code> and </li> 
			  <li><code>[GeneratePKs]</code> </li>
			</ul></ br>
	<p>to your Microsoft SQL Server (version >= 2005) database and then run this stored procedure.
	1. Open SQL Server Query Analyser, 
	2. Select New Query and select the database from drop-down list  from toolbar that needs code generation
	3. Execute below stored produre like below:</p><br />
	
	Ex:
	exec GeneratePocoCode 
			'MyDb',				-- name of your application
			'C:\MyTest\Domain'		-- root folder where your reverse poco classes need to be generated
	Optionally you may also specify individual folders for entities, interfaces, interface implementations etc.,

What does it do?
	Running this stored procedure generates the .NET reverse Poco classes in C# (VB.NET generation may be added later)
	under four different folders: Entities, Abstract, Concrete and Infrastructure respectevily
