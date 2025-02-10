CREATE OR ALTER PROCEDURE [dbo].[sp_InsertRecommendation]
    @ExternalId NVARCHAR(255),
    @Source NVARCHAR(10),
    @TenantId NVARCHAR(255),
    @SubscriptionId NVARCHAR(255),
    @Category NVARCHAR(50),
    @ShortDescription NVARCHAR(500),
    @Description NVARCHAR(MAX),
    @PortentialBenefits NVARCHAR(1000),
    @Impact NVARCHAR(10),
    @Status NVARCHAR(20),
    @StatusAction NVARCHAR(50) = NULL,
    @StatusHistoryJson NVARCHAR(MAX) = NULL,
    @CreatedBy NVARCHAR(255),
    @ImplementationExternalLink NVARCHAR(2000) = NULL,
    @DocumentationLink NVARCHAR(2000) = NULL,
    @ResourceType NVARCHAR(255) = NULL,
    @ResourceName NVARCHAR(255) = NULL,
    @ResourceId NVARCHAR(1000) = NULL,
    @Region NVARCHAR(100) = NULL,
    @CostPotentialSavingsAmount DECIMAL(18,2) = NULL,
    @CostPotentialSavingsCcy NVARCHAR(3) = NULL,
    @CostPotentialSavingsLookbackPeriodDays INT = NULL,
    @CostPotentialSavingsTerm NVARCHAR(10) = NULL,
    @DetailsJson NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO [dbo].[tb_recommendation]
    (ExternalId, Source, TenantId, SubscriptionId, Category, ShortDescription, 
     Description, PortentialBenefits, Impact, Status, StatusAction, StatusHistoryJson, 
     CreatedBy, ImplementationExternalLink, DocumentationLink, 
     ResourceType, ResourceName, ResourceId, Region, CostPotentialSavingsAmount, 
     CostPotentialSavingsCcy, CostPotentialSavingsLookbackPeriodDays, CostPotentialSavingsTerm, 
     DetailsJson)
    VALUES
    (@ExternalId, @Source, @TenantId, @SubscriptionId, @Category, @ShortDescription,
     @Description, @PortentialBenefits, @Impact, @Status, @StatusAction, @StatusHistoryJson,
     @CreatedBy, @ImplementationExternalLink, @DocumentationLink,
     @ResourceType, @ResourceName, @ResourceId, @Region, @CostPotentialSavingsAmount,
     @CostPotentialSavingsCcy, @CostPotentialSavingsLookbackPeriodDays, @CostPotentialSavingsTerm,
     @DetailsJson)

    SELECT SCOPE_IDENTITY() as NewId
END
GO
