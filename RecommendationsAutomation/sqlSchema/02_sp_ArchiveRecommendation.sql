CREATE OR ALTER PROCEDURE [dbo].[sp_ArchiveRecommendation]
    @Id BIGINT,
    @ArchivedBy NVARCHAR(255)
AS
BEGIN
    UPDATE [dbo].[tb_recommendation]
    SET ArchivedBy = @ArchivedBy,
        ArchiveDatetime = GETUTCDATE()
    WHERE Id = @Id
END
GO