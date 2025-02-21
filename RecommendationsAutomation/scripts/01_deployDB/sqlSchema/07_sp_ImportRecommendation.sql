CREATE OR ALTER PROCEDURE [dbo].[sp_ImportRecommendation]
    @ExternalId NVARCHAR(255),
    @Source NVARCHAR(10),
    @CloudProvider NVARCHAR(100),
    @TenantId NVARCHAR(255),
    @SubscriptionId NVARCHAR(255),
    @SubscriptionName NVARCHAR(255),
    @Category NVARCHAR(50),
    @ShortDescription NVARCHAR(500),
    @Description NVARCHAR(MAX),
    @PotentialBenefits NVARCHAR(1000),
    @Impact NVARCHAR(10),
    @Status NVARCHAR(20),
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
    DECLARE @ExistingId BIGINT
    DECLARE @CurrentStatusHistoryJson NVARCHAR(MAX)
    DECLARE @StateUpdateDatetime DATETIME2 = GETUTCDATE()
    DECLARE @NewStatusHistoryJson NVARCHAR(MAX)

    -- Check if recommendation exists
    SELECT @ExistingId = Id, @CurrentStatusHistoryJson = StatusHistoryJson
    FROM [dbo].[tb_recommendation]
    WHERE ExternalId = @ExternalId AND Source = @Source

    -- Create new status history entry
    DECLARE @NewStatusEntry NVARCHAR(MAX) = (
        SELECT 
            @StateUpdateDatetime AS StateUpdateDatetime,
            @Status AS State,
            'Imported from ' + @Source AS UserComments
        FOR JSON PATH
    )

    -- Handle JSON array creation/append
    SET @NewStatusHistoryJson = 
        CASE 
            WHEN ISJSON(@CurrentStatusHistoryJson) = 1 AND @CurrentStatusHistoryJson IS NOT NULL
            THEN (
                SELECT *
                FROM (
                    SELECT * FROM OPENJSON(@CurrentStatusHistoryJson)
                    WITH (
                        StateUpdateDatetime datetime2,
                        State nvarchar(20),
                        UserComments nvarchar(max)
                    )
                    UNION ALL
                    SELECT * FROM OPENJSON(@NewStatusEntry)
                    WITH (
                        StateUpdateDatetime datetime2,
                        State nvarchar(20),
                        UserComments nvarchar(max)
                    )
                ) AS combined
                FOR JSON PATH
            )
            ELSE @NewStatusEntry
        END

    IF @ExistingId IS NULL
    BEGIN
        
        -- Calculate @ProposedETA: if Impact == 'High' then @ProposedETA = GETUTCDATE() + 90 days, else @ProposedETA = NULL
        DECLARE @ProposedETA DATETIME2 = 
            CASE 
                WHEN @Impact = 'High' THEN DATEADD(DAY, 90, GETUTCDATE())
                ELSE NULL
            END


        -- Insert new recommendation
        INSERT INTO [dbo].[tb_recommendation]
        (ExternalId, Source, CloudProvider, TenantId, SubscriptionId, SubscriptionName, Category, ShortDescription, 
         Description, PotentialBenefits, Impact, Status, StatusAction, StatusHistoryJson, 
         CreatedBy, CreationDatetime, LastUpdateDatetime,
         ImplementationExternalLink, DocumentationLink, ResourceType, ResourceName, 
         ResourceId, Region, CostPotentialSavingsAmount, CostPotentialSavingsCcy, 
         CostPotentialSavingsLookbackPeriodDays, CostPotentialSavingsTerm, DetailsJson, ProposedETA)
        VALUES
        (@ExternalId, @Source, @CloudProvider, @TenantId, @SubscriptionId, @SubscriptionName, @Category, @ShortDescription,
         @Description, @PotentialBenefits, @Impact, @Status, NULL, @NewStatusEntry,
         @CreatedBy, @StateUpdateDatetime, @StateUpdateDatetime,
         @ImplementationExternalLink, @DocumentationLink, @ResourceType, @ResourceName,
         @ResourceId, @Region, @CostPotentialSavingsAmount, @CostPotentialSavingsCcy,
         @CostPotentialSavingsLookbackPeriodDays, @CostPotentialSavingsTerm, @DetailsJson, @ProposedETA)

        SELECT SCOPE_IDENTITY() as NewId
    END
    ELSE
    BEGIN
        -- Update existing recommendation
        UPDATE [dbo].[tb_recommendation]
        SET CloudProvider = @CloudProvider,
            TenantId = @TenantId,
            SubscriptionId = @SubscriptionId,
            SubscriptionName = @SubscriptionName,
            Category = @Category,
            ShortDescription = @ShortDescription,
            Description = @Description,
            PotentialBenefits = @PotentialBenefits,
            Impact = @Impact,
            Status = @Status,
            StatusAction = NULL,
            StatusActionExternalId = NULL,
            StatusHistoryJson = @NewStatusHistoryJson,
            LastUpdateDatetime = @StateUpdateDatetime,
            ImplementationExternalLink = @ImplementationExternalLink,
            DocumentationLink = @DocumentationLink,
            ResourceType = @ResourceType,
            ResourceName = @ResourceName,
            ResourceId = @ResourceId,
            Region = @Region,
            CostPotentialSavingsAmount = @CostPotentialSavingsAmount,
            CostPotentialSavingsCcy = @CostPotentialSavingsCcy,
            CostPotentialSavingsLookbackPeriodDays = @CostPotentialSavingsLookbackPeriodDays,
            CostPotentialSavingsTerm = @CostPotentialSavingsTerm,
            DetailsJson = @DetailsJson,
            ArchivedBy = NULL,
            ArchiveDatetime = NULL
        WHERE Id = @ExistingId

        SELECT @ExistingId as NewId
    END
END
GO