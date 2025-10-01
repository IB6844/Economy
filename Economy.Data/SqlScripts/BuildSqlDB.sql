-------------------------------------------------
--<<<<<<<<<<<<<<<***************>>>>>>>>>>>>>>>--

DECLARE @DatabaseName sysname = 'Economy';

--<<<<<<<<<<<<<<<***************>>>>>>>>>>>>>>>--

-- WARNING!!!!     WARNING!!!!     WARNING!!!!

-- setting of 1 will DROP the databasee and
-- recrearte all data will be lost in the database

DECLARE @DropAndRebuild int = 1;			-- 1 = true; 0 = false

--<<<<<<<<<<<<<<<***************>>>>>>>>>>>>>>>--
-------------------------------------------------

-- version: Major.Minor.Release.Revision
-- Major = 1 - Generations Number (non changing)
-- Minor = 0 - feature changes/breaking changes (non resetting per major)
-- Release = 0 - Publish (non resetting per major)
-- Revision = {x} - Commit/Build (non resetting per major)

DECLARE @VerMajor int = 1;
DECLARE @VerMinor int = 0;
DECLARE @VerRelease int = 0;
DECLARE @VerRevision int = 0;

-- SUPPORT VARIABLES

DECLARE @cmd nvarchar(max);
DECLARE @ParmDefinition nvarchar(max);
DECLARE @retval int;

-- DROP AND REBUILD DATABASE

IF (@DropAndRebuild = 1)
BEGIN
	IF (EXISTS (SELECT 1 FROM sys.Databases WHERE [Name] = @DatabaseName))
	BEGIN
		PRINT 'DROP DATABASE ' + @DatabaseName

		USE [master];

		SET @cmd = N'EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N''' + @DatabaseName + N''';';
		EXECUTE sp_executesql @cmd

		SET @cmd = N'ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
		EXECUTE sp_executesql @cmd

		SET @cmd = N'DROP DATABASE ['+ @DatabaseName +'];';
		EXECUTE sp_executesql @cmd

		PRINT 'CREATE DATABASE ' + @DatabaseName

		SET @cmd = N'CREATE DATABASE [' + @DatabaseName + '];';
		EXECUTE sp_executesql @cmd
	END

	USE [Economy]


	IF (DB_NAME() <> @DatabaseName)
	BEGIN
		PRINT 'DATABASE NOT SET TO THE SAME DATABASE NAME IN THE TWO (2) REQUIRED PLACES';

		RETURN;
	END

	-- Database Management Schema
	IF (NOT EXISTS (SELECT 1
		FROM INFORMATION_SCHEMA.SCHEMATA
		WHERE SCHEMA_NAME = 'DBM'))
	BEGIN
		PRINT 'CREATE SCHEMA DBM';

		EXEC sp_executesql N'CREATE SCHEMA DBM AUTHORIZATION db_owner;';
	END

	-- Control Schema
	IF (NOT EXISTS (SELECT 1
		FROM INFORMATION_SCHEMA.SCHEMATA
		WHERE SCHEMA_NAME = 'CTL'))
	BEGIN
		PRINT 'CREATE SCHEMA CTL';

		EXEC sp_executesql N'CREATE SCHEMA CTL AUTHORIZATION db_owner;';
	END

	-- Economy Schema
	IF (NOT EXISTS (SELECT 1
		FROM INFORMATION_SCHEMA.SCHEMATA
		WHERE SCHEMA_NAME = 'eco'))
	BEGIN
		PRINT 'CREATE SCHEMA eco';

		EXEC sp_executesql N'CREATE SCHEMA eco AUTHORIZATION db_owner;';
	END

	-- Organization Schema
	IF (NOT EXISTS (SELECT 1
		FROM INFORMATION_SCHEMA.SCHEMATA
		WHERE SCHEMA_NAME = 'org'))
	BEGIN
		PRINT 'CREATE SCHEMA org';

		EXEC sp_executesql N'CREATE SCHEMA org AUTHORIZATION db_owner;';
	END

	-- ADD DBM.DbPrint STORED PROCEDURE
	IF (NOT EXISTS ( SELECT 1
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE Specific_schema = 'DBM'
			AND specific_name = 'DbPrint'
			AND Routine_Type = 'PROCEDURE'))
	BEGIN
		PRINT 'CREATE PROCEDURE [DBM].[DbPrint]';

		EXEC sp_executesql N'
			CREATE PROCEDURE [DBM].[DbPrint]
				@Message nvarchar(max)
			AS
			BEGIN
				RAISERROR(@Message, 0, 1) WITH NOWAIT;
			END';
	END

	--ADD DbExec STORED PROCEDURE

	IF (NOT EXISTS ( SELECT 1
				FROM INFORMATION_SCHEMA.ROUTINES
				WHERE Specific_schema = 'DBM'
						AND specific_name = 'DbExec'
						AND Routine_Type = 'PROCEDURE'))
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE PROCEDURE [DBM].[DbExec]'

		EXEC sp_executesql N'
			CREATE PROCEDURE [DBM].[DbExec]
				@database sysname,
				@SqlCommand nvarchar(max)
			AS
			BEGIN
				DECLARE @SqlCommandExtended nvarchar(max) = (''USE [ + @database + ];'' + @SqlCommand);
				EXEC sp_executesql @SqlCommandExtended;
			END;';
	END

	--ADD DbHasFunction FUNCTION

	IF (NOT EXISTS ( SELECT 1
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE Specific_schema = 'DBM'
			AND specific_name = 'DbHasFunction'
			AND Routine_Type = 'FUNCTION'))
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE FUNCTION [DBM].[DbHasFunction]'

		EXEC sp_executesql N'
		CREATE FUNCTION [DBM].[DbHasFunction] (@schema sysname, @name sysname)
			RETURNS BIT
			AS
			BEGIN
				RETURN IIF( EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES
				WHERE Specific_schema = @schema
					AND specific_name = @name
					AND Routine_Type = ''FUNCTION''), 1, 0);
			END;';
	END


	--ADD DbHasSP FUNCTION

	IF (NOT EXISTS ( SELECT 1 
		FROM INFORMATION_SCHEMA.ROUTINES
		WHERE Specific_schema = 'DBM'
			AND specific_name = 'DbHasSP'
			AND Routine_Type = 'FUNCTION'))
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE PROCEDURE [DBM].[DbHasSP]'

		EXEC sp_executesql N'
		CREATE FUNCTION [DBM].[DbHasSP] (@schema sysname, @name sysname)
			RETURNS BIT
			AS
			BEGIN
				RETURN IIF( EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES
				WHERE Specific_schema = @schema
					AND specific_name = @name
					AND Routine_Type = ''PROCEDURE''), 1, 0);
			END;'; 
	END


	--ADD DbHasTable FUNCTION

	IF (DBM.DBHasFunction('DBM', 'DbHasTable') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE FUNCTION [DBM].[DbHasTable]';
	
		EXEC sp_executesql N'
			CREATE FUNCTION [DBM].[DbHasTable] (@schema sysname, @name sysname)
				RETURNS BIT
				AS
				BEGIN
					RETURN IIF( EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES
					WHERE Specific_schema = @schema
						AND specific_name = @name
						AND Routine_Type = ''TABLE''), 1, 0);
				END;';
	END

	-- ADD Version Table used for SQL script management

	IF (DBM.DBHasTable('DBM', 'DbVersion') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE TABLE [DBM].[DbVersion]';

		EXEC sp_executesql N'
			CREATE TABLE [DBM].[DbVersion](
				[Id] [int] IDENTITY(1,1) NOT NULL,
				[Major] [int] NOT NULL,
				[Minor] [int] NOT NULL,
				[Release] [int] NOT NULL,
				[Revision] [int] NOT NULL,
			 CONSTRAINT [PK_DbVersion] PRIMARY KEY CLUSTERED 
			(
				[Id] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];

			ALTER TABLE [DBM].[DbVersion]  WITH CHECK ADD  CONSTRAINT [CK_DbVersion_Id] CHECK  (([Id]=(1)));

			ALTER TABLE [DBM].[DbVersion] CHECK CONSTRAINT [CK_DbVersion_Id];';

		EXEC [DBM].[DbPrint] 'LOAD [DBM].[DbVersion]'

		SET @cmd = N'INSERT INTO [DBM].[DbVersion] VALUES (' + CONVERT(nvarchar, @VerMajor) + ', ' + CONVERT(nvarchar, @VerMinor) + ', ' + CONVERT(nvarchar, @VerRelease) + ', ' + CONVERT(nvarchar, @VerRevision) + ');';
		EXECUTE sp_executesql @cmd;
	END


	-- ADD db_executer role

	 IF DATABASE_PRINCIPAL_ID('db_executor') IS NULL
	BEGIN
		PRINT 'CREATE ROLE db_executor';

		EXEC sp_executesql N'CREATE ROLE db_executor;';
		EXEC sp_executesql N'GRANT EXECUTE TO db_executor;';
	END

	
-------------------------------------------------
--<<<<<<<<<<<<<<<***************>>>>>>>>>>>>>>>--

-- BUILD DATA TABLES

--<<<<<<<<<<<<<<<***************>>>>>>>>>>>>>>>--
-------------------------------------------------

-- ADD Hub Table

IF (DBM.DBHasTable('CTL', 'User') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [CTL].[User]'
		
		EXEC sp_executesql N'
			CREATE TABLE [CTL].[User]
			(
				[Id] INT IDENTITY(1,1) NOT NULL,
				[GoogleId] VARCHAR(64) UNIQUE NOT NULL,
				[Email] VARCHAR(255) NOT NULL,
				[Name] VARCHAR(255) NOT NULL,
				[CreatedAt] DATETIME2 DEFAULT (SYSDATETIME()) NOT NULL,
				[LastLogin] DATETIME2 DEFAULT (SYSDATETIME()) NOT NULL,
				CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];';

	END -- IF (DBM.DBHasTable('CTL', 'User') = 0)

	IF (DBM.DBHasTable('eco', 'Hub') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [eco].[Hub]'
		
		EXEC sp_executesql N'
			CREATE TABLE [eco].[Hub]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[OwnerId] int NOT NULL,
				CONSTRAINT [PK_Hub] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
			) ON [PRIMARY];
			
			ALTER TABLE [eco].[Hub] WITH NOCHECK ADD CONSTRAINT [FK_Hub_User_UserId] FOREIGN KEY([OwnerId])
				REFERENCES [CTL].[User] ([Id]);

			ALTER TABLE [eco].[Hub] CHECK CONSTRAINT [FK_Hub_User_UserId];';

	END -- IF (DBM.DBHasTable('eco', 'Hub') = 0)

	IF (DBM.DBHasTable('eco', 'Member') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [eco].[Member]'
		
		EXEC sp_executesql N'
			CREATE TABLE [eco].[Member]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[UserId] int NOT NULL,
				[HubId] int NOT NULL,
				[Wallet] decimal(19,4) NOT NULL
				CONSTRAINT [PK_Member] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
				
				UNIQUE NONCLUSTERED ([UserId] ASC, [HubId] ASC) 
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
			) ON [PRIMARY];
			
			ALTER TABLE [eco].[Member] WITH NOCHECK ADD CONSTRAINT [FK_Member_User_UserId] FOREIGN KEY([UserId])
				REFERENCES [CTL].[User] ([Id]);

			ALTER TABLE [eco].[Member] CHECK CONSTRAINT [FK_Member_User_UserId];
			
			ALTER TABLE [eco].[Member] WITH NOCHECK ADD CONSTRAINT [FK_Member_Hub_HubId] FOREIGN KEY([HubId])
				REFERENCES [eco].[Hub] ([Id]);

			ALTER TABLE [eco].[Member] CHECK CONSTRAINT [FK_Member_Hub_HubId];';

	END -- IF (DBM.DBHasTable('eco', 'Member') = 0)

	IF (DBM.DBHasTable('org', 'Organization') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [org].[Organization]'
		
		EXEC sp_executesql N'
			CREATE TABLE [org].[Organization]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[OwnerId] int NOT NULL,
				CONSTRAINT [PK_Organization] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];
			
			ALTER TABLE [org].[Organization] WITH NOCHECK ADD CONSTRAINT [FK_Organization_Member_MemberId] FOREIGN KEY([OwnerId])
				REFERENCES [eco].[Member] ([Id]);

			ALTER TABLE [org].[Organization] CHECK CONSTRAINT [FK_Organization_Member_MemberId];';

	END -- IF (DBM.DBHasTable('org', 'Organization') = 0)

	IF (DBM.DBHasTable('org', 'OrgRole') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [org].[OrgRole]'
		
		EXEC sp_executesql N'
			CREATE TABLE [org].[OrgRole]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[OrgId] int NOT NULL, 
				CONSTRAINT [PK_OrgRole] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];
			
			ALTER TABLE [org].[OrgRole] WITH NOCHECK ADD CONSTRAINT [FK_OrgRole_Organization_OrgId] FOREIGN KEY([OrgId])
				REFERENCES [org].[Organization] ([Id]);

			ALTER TABLE [org].[OrgRole] CHECK CONSTRAINT [FK_OrgRole_Organization_OrgId];';

	END -- IF (DBM.DBHasTable('org', 'OrgRole') = 0)

	IF (DBM.DBHasTable('eco', 'Vault') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [eco].[Vault]'
		
		EXEC sp_executesql N'
			CREATE TABLE [eco].[Vault]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[OrgId] int NOT NULL,
				[Balance] decimal(19,4) NOT NULL,
				CONSTRAINT [PK_Vault] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];
			
			ALTER TABLE [eco].[Vault] WITH NOCHECK ADD CONSTRAINT [FK_Vault_Organization_OrgId] FOREIGN KEY([OrgId])
				REFERENCES [org].[Organization] ([Id]);

			ALTER TABLE [eco].[Vault] CHECK CONSTRAINT [FK_Vault_Organization_OrgId];';

	END -- IF (DBM.DBHasTable('eco', 'Vault') = 0)

	
	IF (DBM.DBHasTable('org', 'VaultPermission') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [org].[VaultPermission]'
		
		EXEC sp_executesql N'
			CREATE TABLE [org].[VaultPermission]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[Name] nvarchar(64) NOT NULL,
				[Description] nvarchar(512) NOT NULL,
				CONSTRAINT [PK_VaultPermission] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
			) ON [PRIMARY];';

	END -- IF (DBM.DBHasTable('org', 'VaultPermission') = 0)

	IF (DBM.DBHasTable('org', 'LinkVaultPermission') = 0)
	BEGIN
		EXEC [DBM].[DbPrint] 'CREATE [org].[LinkVaultPermission]'
		
		EXEC sp_executesql N'
			CREATE TABLE [org].[LinkVaultPermission]
			(
				[Id] int IDENTITY(1,1) NOT NULL,
				[RefId] uniqueIdentifier NOT NULL,
				[VaultId] int NOT NULL,
				[RoleId] int NOT NULL,
				[PermissionId] int NOT NULL,
				CONSTRAINT [PK_LinkVaultPermission] PRIMARY KEY CLUSTERED ([Id] ASC)
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
				
				UNIQUE NONCLUSTERED ([VaultId] ASC, [RoleId] ASC, [PermissionId] ASC) 
					WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, 
					ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
			) ON [PRIMARY];
			
			ALTER TABLE [org].[LinkVaultPermission] WITH NOCHECK ADD CONSTRAINT [FK_Link_Vault_VaultId] FOREIGN KEY([VaultId])
				REFERENCES [eco].[Vault] ([Id]);

			ALTER TABLE [org].[LinkVaultPermission] CHECK CONSTRAINT [FK_Link_Vault_VaultId];
			
			ALTER TABLE [org].[LinkVaultPermission] WITH NOCHECK ADD CONSTRAINT [FK_Link_Role_RoleId] FOREIGN KEY([RoleId])
				REFERENCES [org].[OrgRole] ([Id]);

			ALTER TABLE [org].[LinkVaultPermission] CHECK CONSTRAINT [FK_Link_Role_RoleId]
			
			ALTER TABLE [org].[LinkVaultPermission] WITH NOCHECK ADD CONSTRAINT [FK_Link_Permission_PermissionId] FOREIGN KEY([PermissionId])
				REFERENCES [org].[VaultPermission] ([Id]);

			ALTER TABLE [org].[LinkVaultPermission] CHECK CONSTRAINT [FK_Link_Permission_PermissionId];';

	END -- IF (DBM.DBHasTable('org', 'LinkVaultPermission') = 0)
END 