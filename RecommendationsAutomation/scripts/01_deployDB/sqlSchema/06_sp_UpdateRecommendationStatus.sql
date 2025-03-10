CREATE OR ALTER PROCEDURE [dbo].[sp_UpdateRecommendationStatus]
    @Id BIGINT,
    @User NVARCHAR(255),
    @UserComments NVARCHAR(MAX),
    @Status NVARCHAR(20)
AS
BEGIN
    DECLARE @CurrentSource NVARCHAR(10);
    DECLARE @CurrentStatusHistoryJson NVARCHAR(MAX);
    DECLARE @CurrentStatusAction NVARCHAR(50);
    DECLARE @NewStatusHistoryJson NVARCHAR(MAX);
    DECLARE @StateUpdateDatetime DATETIME2 = GETUTCDATE();
    DECLARE @NewStatusAction NVARCHAR(50) = NULL;

    -- Get current Source, StatusHistoryJson, and StatusAction
    SELECT 
        @CurrentSource = Source, 
        @CurrentStatusHistoryJson = StatusHistoryJson,
        @CurrentStatusAction = StatusAction
    FROM [dbo].[tb_recommendation]
    WHERE Id = @Id;

    -- If StatusAction is not empty, throw an exception
    IF ISNULL(@CurrentStatusAction, '') = 'TO_SYNC_WITH_SOURCE'
    BEGIN
        RAISERROR('Cannot update status of recommendation because there is a pending action: "%s".', 16, 1, @CurrentStatusAction);
        RETURN;
    END

    -- Set StatusAction if conditions are met
    -- This scenario is where user is dismissing a recommendation that was synced from Azure
    -- In this case, the recommendation should be marked for syncing with the source
    IF @Status = 'DISMISSED' AND @CurrentSource = 'Azure' AND @User != 'System'
    BEGIN
        SET @NewStatusAction = 'TO_SYNC_WITH_SOURCE';
    END

    -- Create new status history entry
    DECLARE @NewStatusEntry NVARCHAR(MAX) = (
        SELECT 
            @StateUpdateDatetime AS StateUpdateDatetime,
            @Status AS State,
            @UserComments AS UserComments
        FOR JSON PATH
    );

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
        END;

    -- Update the recommendation status, history, and StatusAction in a single update
    UPDATE [dbo].[tb_recommendation]
    SET Status = @Status,
        UpdatedBy = @User,
        LastUpdateDatetime = @StateUpdateDatetime,
        StatusHistoryJson = @NewStatusHistoryJson,
        StatusAction = @NewStatusAction
    WHERE Id = @Id;
END
GO
