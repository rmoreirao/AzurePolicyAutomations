CREATE OR ALTER PROCEDURE [dbo].[sp_UpdateRecommendationStatusAction]
    @Id BIGINT,
    @StatusAction NVARCHAR(50) = NULL,
    @StatusActionExternalId NVARCHAR(255) = NULL,
    @UpdatedBy NVARCHAR(255)
AS
BEGIN
    UPDATE [dbo].[tb_recommendation]
    SET StatusAction = @StatusAction,
        StatusActionExternalId = @StatusActionExternalId,
        UpdatedBy = @UpdatedBy,
        LastUpdateDatetime = GETUTCDATE()
    WHERE Id = @Id
END
GO
