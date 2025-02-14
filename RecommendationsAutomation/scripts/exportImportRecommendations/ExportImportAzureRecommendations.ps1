# Import required modules
Import-Module Az.Resources
Import-Module SqlServer

# Configuration
$kqlQueryPath = Join-Path -Path $PSScriptRoot -ChildPath "advisorRecommendations.kql"
$sqlServerName = "serverrecommendations.database.windows.net"
$databaseName = "db_recommendation"

function Get-AzureAdvisorRecommendations {
    param (
        [string]$kqlQueryPath
    )

    $kqlQuery = Get-Content -Path $kqlQueryPath -Raw
    $batchSize = 1000
    $skipResult = 0
    
    [System.Collections.Generic.List[PSObject]]$recommendations = New-Object 'System.Collections.Generic.List[PSObject]'

    while ($true) {
        if ($skipResult -gt 0) {
            Write-Host "Processing next batch of $batchSize recommendations. Current total: $($recommendations.Count)"
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken -UseTenantScope
        } else {
            Write-Host "Processing first batch of $batchSize recommendations"
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -UseTenantScope
        }

        $recommendations.AddRange($graphResult.data)

        if ($graphResult.data.Count -lt $batchSize) {
            break
        }
        $skipResult += $batchSize
    }

    Write-Host "Total recommendations retrieved: $($recommendations.Count)"
    return $recommendations
}

function Filter-Recommendations {
    param (
        [System.Collections.Generic.List[PSObject]]$recommendations
    )

    $filteredRecommendations = $recommendations | Where-Object { $_.impact -ne "Low" }
    Write-Host "Filtered recommendations count: $($filteredRecommendations.Count)"
    return $filteredRecommendations
}

function Import-RecommendationToSql {
    param (
        [PSObject]$recommendation,
        [string]$connectionString
    )

    try {
        # Safe string handling for SQL parameters
        $externalId = $recommendation.id.Replace("'", "''")
        $tenantId = $recommendation.tenantId.Replace("'", "''")
        $subscriptionId = $recommendation.subscriptionId.Replace("'", "''")
        $subscriptionName = $recommendation.subscriptionName.Replace("'", "''")
        $category = $recommendation.category.Replace("'", "''")
        $shortDesc = $recommendation.problem.Replace("'", "''")
        $resourceId = if ($recommendation.resourceId) { $recommendation.resourceId.Replace("'", "''") } else { $null }
        $resourceName = if ($recommendation.ResourceName) { $recommendation.ResourceName.Replace("'", "''") } else { $null }
        $region = if ($recommendation.region) { $recommendation.region.Replace("'", "''") } else { $null }

        # Create JSON details
        $detailsJson = $recommendation | ConvertTo-Json -Depth 10 -Compress
        $detailsJson = $detailsJson.Replace("'", "''")
    

        # if category == 'highavailability' then set category = 'reliability'
        if ($category.ToLower() -eq 'highavailability') {
            $category = 'reliability'
        }

        # Build implementation link
        $implLink = switch ($category.ToLower()) {
            "cost" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/Cost" }
            "security" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/Security" }
            "reliability" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/Reliability" }
            "operational excellence" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/OperationalExcellence" }
            "performance" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/Performance" }
            # "highavailability" { "https://portal.azure.com/#view/Microsoft_Azure_Expert/AdvisorMenuBlade/~/HighAvailability" }
            default { 
                throw "Unknown recommendation category: $($category)"
            }
        }

        # Build the query with proper NULL handling
        $query = @"
            EXEC [dbo].[sp_ImportRecommendation] 
                @ExternalId = '$externalId',
                @CloudProvider = 'Azure',
                @Source = 'Azure',
                @TenantId = '$tenantId',
                @SubscriptionId = '$subscriptionId',
                @SubscriptionName = '$subscriptionName',
                @Category = '$category',
                @ShortDescription = '$shortDesc',
                @Description = '$shortDesc',
                @PortentialBenefits = 'TODO - PortentialBenefits',
                @Impact = '$($recommendation.impact)',
                @Status = 'NEW',
                @CreatedBy = 'System',
                @ImplementationExternalLink = $(if ($implLink) { "'$implLink'" } else { "NULL" }),
                @ResourceType = NULL,
                @ResourceName = $(if ($resourceName) { "'$resourceName'" } else { "NULL" }),
                @ResourceId = $(if ($resourceId) { "'$resourceId'" } else { "NULL" }),
                @Region = $(if ($region) { "'$region'" } else { "NULL" }),
                @CostPotentialSavingsAmount = $(if ($recommendation.annualSavingsAmount) { $recommendation.annualSavingsAmount } else { "NULL" }),
                @CostPotentialSavingsCcy = $(if ($recommendation.savingsCurrency) { "'$($recommendation.savingsCurrency)'" } else { "NULL" }),
                @DetailsJson = $(if ($detailsJson) { "'$detailsJson'" } else { "NULL" })
"@

        Write-Debug "Executing query: $query"
        $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
# Remove next line when SqlServer module adds support for Access Token as SecureString
        $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
        # $testQuery = "SELECT TOP 5 * FROM [dbo].[tb_recommendation]"
        Invoke-Sqlcmd -Query $query -ServerInstance $sqlServerName -database $databaseName -AccessToken $accessToken -ErrorAction Stop

        # Invoke-Sqlcmd -Query $query -ConnectionString $connectionString
        Write-Host "Successfully imported recommendation: $($recommendation.id)"
        return $true
    }
    catch {
        Write-Error "Failed to import recommendation $($recommendation.id): $_"
        Write-Error "Failed query: $query"
        return $false
    }
}

function Update-ObsoleteRecommendations {
    param (
        [string]$importStartTime
    )

    $findObsoleteQuery = @"
        SELECT Id
        FROM [dbo].[tb_recommendation]
        WHERE Source = 'Azure'
        AND LastUpdateDatetime < '$importStartTime'
        AND Status != 'IMPLEMENTED'
        AND ArchivedBy IS NULL
"@

    Write-Host "Checking for obsolete Azure recommendations..."
    $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
    # Remove next line when SqlServer module adds support for Access Token as SecureString
    $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
    $obsoleteRecommendations = Invoke-Sqlcmd -Query $findObsoleteQuery -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken  -ErrorAction Stop

    $totalUpdated = 0
    foreach ($obsoleteRecommendation in $obsoleteRecommendations) {
        try {
            $updateQuery = @"
                EXEC [dbo].[sp_UpdateRecommendationStatus]
                    @Id = $($obsoleteRecommendation.Id),
                    @User = 'System',
                    @UserComments = 'Automatically marked as implemented - no longer reported by Azure',
                    @Status = 'IMPLEMENTED'
"@

            
            Invoke-Sqlcmd -Query $updateQuery -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken -ErrorAction Stop
            $totalUpdated++
        }
        catch {
            Write-Error "Failed to update recommendation $($recommendation.Id): $_"
        }
    }

    Write-Host "Total obsolete recommendations marked as implemented: $totalUpdated"
    return $totalUpdated
}

# Main execution
try {
    # Get timestamp before starting the import
    $importStartTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    
    # Get recommendations from Azure
    $recommendations = Get-AzureAdvisorRecommendations -kqlQueryPath $kqlQueryPath

    # Filter recommendations
    $filteredRecommendations = Filter-Recommendations -recommendations $recommendations

    # Initialize counters
    $totalImported = 0
    $totalFailed = 0

    # Import recommendations to SQL
    foreach ($recommendation in $filteredRecommendations) {
        $success = Import-RecommendationToSql -recommendation $recommendation -connectionString $connectionString
        if ($success) {
            Write-Host "Recommendation imported successfully."
            $totalImported++
        } else {
            Write-Host "Failed to import recommendation."
            $totalFailed++
        }
    }

    Write-Host "Import process completed."
    Write-Host "Total Recommendations Imported: $totalImported"
    Write-Host "Total Recommendations Failed: $totalFailed"

    # Only update obsolete recommendations if there were no failures during import
    if ($totalFailed -eq 0) {
        Write-Host "No import failures detected. Proceeding with obsolete recommendations update..."
        $totalUpdated = Update-ObsoleteRecommendations -importStartTime $importStartTime
    } else {
        throw "Skipping obsolete recommendations update due to import failures."
    }
}
catch {
    Write-Error "Error during execution: $_"
}