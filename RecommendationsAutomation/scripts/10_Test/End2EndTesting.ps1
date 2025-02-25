Write-Host "1) Redeploying the database schema..."
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "../01_deployDB/DeployDBSchema.ps1"
& $scriptPath

Read-Host -Prompt "Press Enter to continue"

Write-Host "2) Syncing recommendations from Azure to SQL..."
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "../02_exportImportRecommendations/ExportAzureImportSqlRecommendations.ps1"
& $scriptPath

Read-Host -Prompt "Press Enter to continue"

Write-Host "3) Generating Recommendations Digest Emails..."
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "../03_recommendationsEmail/recommendationsSummaryEmail.py"
python $scriptPath

Read-Host -Prompt "Press Enter to continue"

$recommendationId = Read-Host -Prompt "Enter the ID of the recommendation to be dismissed on SQL (press Enter to skip)"
if ([string]::IsNullOrWhiteSpace($recommendationId)) {
    Write-Host "Skipping recommendation dismissal step..."
} else {
    Write-Host "Dismissing recommendation with ID: $recommendationId"
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "TestDimissRecommendationSQL.ps1"
    & $scriptPath -RecommendationId $recommendationId
}

Read-Host -Prompt "Press Enter to continue"

Write-Host "4) Syncing the Dismissed Recommendation with Azure..."
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "../04_syncFromRecommendationDBToAzure/SyncFromRecommendationDBToAzure.ps1"
& $scriptPath

Read-Host -Prompt "Press Enter to continue"

Write-Host "5) Syncing recommendations from Azure to SQL again to make sure that Recommendation is Dismissed on the Source..."
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "../02_exportImportRecommendations/ExportAzureImportSqlRecommendations.ps1"
& $scriptPath

Read-Host -Prompt "Press Enter to finish"