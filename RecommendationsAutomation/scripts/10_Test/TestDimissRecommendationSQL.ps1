param (
    [Parameter(Mandatory = $true)]
    [int]$RecommendationId
)

# Import required modules
Import-Module Az.Resources
Import-Module SqlServer

# Configuration
$sqlServerName = "serverrecommendations.database.windows.net"
$databaseName = "db_recommendation"

function Dismiss-Recommendation {
    param (
        [int]$RecommendationId
    )

    try {
        $query = @"
            EXEC [dbo].[sp_UpdateRecommendationStatus]
                @Id = $RecommendationId,
                @User = 'TestUser',
                @UserComments = 'Dismissed for PoC',
                @Status = 'DISMISSED'
"@

        Write-Debug "Executing query: $query"
        $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
        # Remove next line when SqlServer module adds support for Access Token as SecureString
        $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
        Invoke-Sqlcmd -Query $query -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken -ErrorAction Stop

        Write-Host "Successfully dismissed recommendation: $RecommendationId"
        return $true
    }
    catch {
        Write-Error "Failed to dismiss recommendation $($RecommendationId): $_"
        return $false
    }
}

# Main execution
try {
    $success = Dismiss-Recommendation -RecommendationId $RecommendationId
    if ($success) {
        Write-Host "Recommendation dismissed successfully."
    } else {
        Write-Host "Failed to dismiss recommendation."
    }
}
catch {
    Write-Error "Error during execution: $_"
}
