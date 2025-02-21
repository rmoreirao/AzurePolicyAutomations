# Import required modules
Import-Module Az.Resources
Import-Module SqlServer

# Configuration
$sqlServerName = "serverrecommendations.database.windows.net"
$databaseName = "db_recommendation"

function Get-RecommendationsToSync {
    param (
        [string]$connectionString
    )

    $query = @"
        EXEC [dbo].[sp_GetRecommendations]
            @StatusAction = 'TO_SYNC_WITH_SOURCE',
            @Source = 'AZURE',
            @Status = 'Dismissed'
"@

    $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
    $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
    $recommendations = Invoke-Sqlcmd -Query $query -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken -ErrorAction Stop

    return $recommendations
}

function Dismiss-RecommendationOnAzure {
    param (
        [PSObject]$recommendation
    )

    $token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token
    $uri = "https://management.azure.com{$recommendation.ExternalId}/suppressions/{guid}?api-version=2023-01-01"
    $body = @{
        properties = @{
            ttl = "PT1H"
        }
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $uri -Method Put -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"

    return $response
}

function Update-RecommendationStatusAction {
    param (
        [PSObject]$recommendation
    )

    $query = @"
        EXEC [dbo].[sp_UpdateRecommendationStatusAction]
            @Id = $($recommendation.Id),
            @StatusAction = 'SOURCE_UPDATED',
            @StatusActionExternalId = 'TODO - Azure Suppress ID',
            @UpdatedBy = 'System'
"@

    $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
    $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
    Invoke-Sqlcmd -Query $query -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken -ErrorAction Stop
}

# Main execution
try {
    # Get recommendations to sync
    $recommendations = Get-RecommendationsToSync -connectionString $connectionString

    foreach ($recommendation in $recommendations) {
        try {
            # Dismiss recommendation on Azure
            Dismiss-RecommendationOnAzure -recommendation $recommendation

            # Update recommendation status action in the database
            Update-RecommendationStatusAction -recommendation $recommendation

            Write-Host "Successfully synced recommendation: $($recommendation.Id)"
        }
        catch {
            Write-Error "Failed to sync recommendation $($recommendation.Id): $_"
        }
    }

    Write-Host "Sync process completed."
}
catch {
    Write-Error "Error during execution: $_"
}
