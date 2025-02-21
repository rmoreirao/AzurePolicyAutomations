# Import required modules
Import-Module SqlServer

# Configuration
$sqlServerName = "serverrecommendations.database.windows.net"
$databaseName = "db_recommendation"
$sqlSchemaPath = Join-Path -Path $PSScriptRoot -ChildPath "sqlSchema"

# Function to execute SQL file on the database
function Execute-SqlFile {
    param (
        [string]$filePath,
        [string]$connectionString
    )

    try {
        $sqlQuery = Get-Content -Path $filePath -Raw
        $secureStringAccessToken = (Get-AzAccessToken -ResourceUrl 'https://database.windows.net' -AsSecureString).Token
        # Remove next line when SqlServer module adds support for Access Token as SecureString
        $accessToken = ConvertFrom-SecureString -SecureString $secureStringAccessToken -AsPlainText
        Invoke-Sqlcmd -Query $sqlQuery -ServerInstance $sqlServerName -Database $databaseName -AccessToken $accessToken -ErrorAction Stop
        Write-Host "Successfully executed file: $filePath"
    }
    catch {
        Write-Error "Failed to execute file $($filePath): $($_)"
    }
}

# Main execution
try {
    # Get all SQL files in the sqlSchema folder, ordered by filename
    $sqlFiles = Get-ChildItem -Path $sqlSchemaPath -Filter *.sql | Sort-Object Name

    # Initialize counters
    $totalExecuted = 0

    # Execute each SQL file 
    foreach ($file in $sqlFiles) {
        $filePath = $file.FullName
        Execute-SqlFile -filePath $filePath -connectionString $connectionString
        $totalExecuted++
    }

    Write-Host "Deployment process completed."
    Write-Host "Total Files Executed: $totalExecuted"
}
catch {
    Write-Error "Error during execution: $_"
}