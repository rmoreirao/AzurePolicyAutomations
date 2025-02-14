DROP TABLE [dbo].[tb_recommendation]
GO
CREATE TABLE [dbo].[tb_recommendation]
(
    [Id] BIGINT IDENTITY(1,1) PRIMARY KEY,
    [ExternalId] NVARCHAR(255),
    [Source] NVARCHAR(10) NOT NULL CHECK ([Source] IN ('Custom', 'Azure', 'AWS')),
    [CloudProvider] NVARCHAR(100),
    [TenantId] NVARCHAR(255),
    [SubscriptionId] NVARCHAR(255),
    [SubscriptionName] NVARCHAR(255),
    [Category] NVARCHAR(50) NOT NULL CHECK ([Category] IN ('Cost', 'Security', 'Reliability', 'Operational Excellence', 'Performance')),
    [ShortDescription] NVARCHAR(500) NOT NULL,
    [Description] NVARCHAR(MAX),
    [PotentialBenefits] NVARCHAR(1000),
    [Impact] NVARCHAR(10) NOT NULL CHECK ([Impact] IN ('High', 'Medium', 'Low')),
    [Status] NVARCHAR(20) NOT NULL CHECK ([Status] IN ('New', 'Dismissed', 'InProgress', 'Implemented')),
    [StatusAction] NVARCHAR(50) CHECK ([StatusAction] IN ('SYNC_WITH_SOURCE')),
    [StatusHistoryJson] NVARCHAR(MAX),
    [CreatedBy] NVARCHAR(255) NOT NULL,
    [CreationDatetime] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    [UpdatedBy] NVARCHAR(255),
    [LastUpdateDatetime] DATETIME2,
    [ArchivedBy] NVARCHAR(255),
    [ArchiveDatetime] DATETIME2,
    [ImplementationExternalLink] NVARCHAR(2000),
    [DocumentationLink] NVARCHAR(2000),
    [ResourceType] NVARCHAR(255),
    [ResourceName] NVARCHAR(255),
    [ResourceId] NVARCHAR(1000),
    [Region] NVARCHAR(100),
    [CostPotentialSavingsAmount] DECIMAL(18,2),
    [CostPotentialSavingsCcy] NVARCHAR(3),
    [CostPotentialSavingsLookbackPeriodDays] INT,
    [CostPotentialSavingsTerm] NVARCHAR(10),
    [DetailsJson] NVARCHAR(MAX),
    [ProposedETA] DATETIME2
);

-- Create indexes for commonly queried columns
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_recommendation_TenantId' AND object_id = OBJECT_ID('dbo.tb_recommendation'))
BEGIN
    CREATE INDEX IX_recommendation_TenantId ON [dbo].[tb_recommendation] ([TenantId]);
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_recommendation_SubscriptionId' AND object_id = OBJECT_ID('dbo.tb_recommendation'))
BEGIN
    CREATE INDEX IX_recommendation_SubscriptionId ON [dbo].[tb_recommendation] ([SubscriptionId]);
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_recommendation_Status' AND object_id = OBJECT_ID('dbo.tb_recommendation'))
BEGIN
    CREATE INDEX IX_recommendation_Status ON [dbo].[tb_recommendation] ([Status]);
END