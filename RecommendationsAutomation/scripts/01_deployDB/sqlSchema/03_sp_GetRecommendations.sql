CREATE OR ALTER PROCEDURE [dbo].[sp_GetRecommendations]
    @TenantId NVARCHAR(255) = NULL,
    @SubscriptionId NVARCHAR(255) = NULL,
    @SubscriptionName NVARCHAR(100) = NULL,
    @Status NVARCHAR(20) = NULL,
    @Category NVARCHAR(50) = NULL,
    @Impact NVARCHAR(10) = NULL,
    @Source NVARCHAR(10) = NULL,
    @StatusAction NVARCHAR(50) = NULL
AS
BEGIN
    SELECT Id, ExternalId, Source, CloudProvider, TenantId, SubscriptionId, SubscriptionName, Category, ShortDescription, 
           Description, PotentialBenefits, Impact, Status, StatusAction,StatusActionExternalId, StatusHistoryJson, 
           CreatedBy, CreationDatetime, UpdatedBy, LastUpdateDatetime, ArchivedBy, ArchiveDatetime, 
           ImplementationExternalLink, DocumentationLink, ResourceType, ResourceName, ResourceId, 
           Region, CostPotentialSavingsAmount, CostPotentialSavingsCcy, 
           CostPotentialSavingsLookbackPeriodDays, CostPotentialSavingsTerm, DetailsJson, ProposedETA
    FROM [dbo].[tb_recommendation]
    WHERE (@TenantId IS NULL OR TenantId = @TenantId)
        AND (@SubscriptionId IS NULL OR SubscriptionId = @SubscriptionId)
        AND (@SubscriptionName IS NULL OR SubscriptionName = @SubscriptionName)
        AND (@Status IS NULL OR Status = @Status)
        AND (@Category IS NULL OR Category = @Category)
        AND (@Impact IS NULL OR Impact = @Impact)
        AND (@Source IS NULL OR Source = @Source)
        AND (@StatusAction IS NULL OR StatusAction = @StatusAction)
        AND ArchivedBy IS NULL
    ORDER BY CreationDatetime DESC
END
GO
