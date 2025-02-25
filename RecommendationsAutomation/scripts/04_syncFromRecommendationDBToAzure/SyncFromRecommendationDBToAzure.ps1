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

    if (-not $recommendation.SubscriptionId) {
        throw "SubscriptionId is missing in recommendation object."
    }

    # Build full identifiers
    $recommendationId = $recommendation.ExternalId  # now holds only the recommendation id
    $suppressName = "HardcodedSuppressName"

    # Construct the URI per the API documentation:
    # DELETE https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Advisor/recommendations/{recommendationId}/suppressions/{suppressionId}?api-version=2023-01-01
    $uri = "https://management.azure.com$($recommendationId)/suppressions/$($suppressName)?api-version=2023-01-01"

    # Build the request body
    $body = @{
        properties = @{
            suppressionId = "" 
            ttl = ""
        }
    } | ConvertTo-Json -Depth 4

    $response = Invoke-RestMethod -Uri $uri -Method Put -Headers @{ Authorization = "Bearer $token" } -Body $body -ContentType "application/json"
    ## Retrieve the response -> properties -> suppressionId and return it
    return $response.properties.suppressionId

}

function Update-RecommendationStatusAction {
    param (
        [string]$recommendationId,
        [string]$suppressId
    )

    $query = @"
        EXEC [dbo].[sp_UpdateRecommendationStatusAction]
            @Id = $($recommendationId),
            @StatusAction = 'SOURCE_UPDATED',
            @StatusActionExternalId = '$($suppressId)',
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
            Write-Host "Syncing recommendation: $($recommendation.Id)"

            $suppressId = Dismiss-RecommendationOnAzure -recommendation $recommendation

            Write-Host "Successfully dismissed recommendation: $($recommendation.Id) on Azure"

            # Update recommendation status action in the database
            Update-RecommendationStatusAction -recommendationId $recommendation.Id -suppressId $suppressId

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
