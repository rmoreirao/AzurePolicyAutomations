
function ResourceGraphQueryAndExportToCsv {
    param (
        [string]$kqlQuery,
        [string]$csvFilePath
    )

    $batchSize = 1000
    $skipResult = 0

    [System.Collections.Generic.List[PSObject]]$kqlResult = New-Object 'System.Collections.Generic.List[PSObject]'

    while ($true) {
        if ($skipResult -gt 0) {
            Write-Host "Processing next batch of $batchSize records"
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -SkipToken $graphResult.SkipToken -UseTenantScope
        } else {
            Write-Host "Processing first batch of $batchSize records"
            $graphResult = Search-AzGraph -Query $kqlQuery -First $batchSize -UseTenantScope
        }

        $kqlResult.AddRange($graphResult.data)

        if ($graphResult.data.Count -lt $batchSize) {
            break
        }
        $skipResult += $batchSize
    }

    Write-Host "Total records processed: $($kqlResult.Count)"


    # Flatten any array/complex properties so Export-Csv produces a usable table
    $flattened = $kqlResult | ForEach-Object {
        $obj = [ordered]@{}
        foreach ($prop in $_.PSObject.Properties) {
            if ($prop.Value -is [System.Collections.IEnumerable] -and $prop.Value -notlike '*[System.*]*' -and $prop.Value -isnot [string]) {
                $obj[$prop.Name] = $prop.Value -join '; '
            } else {
                $obj[$prop.Name] = $prop.Value
            }
        }
        [PSCustomObject]$obj
    }

    $flattened | Export-Csv -Path $csvFilePath -NoTypeInformation -Force
}

# Array of .kql filenames
$kqlFiles = @(
    "kustoQueries/policyAssignments.kql"
    "kustoQueries/initiativePolicies.kql"
    "kustoQueries/policyAssignmentCompliancyState.kql",
    "kustoQueries/policyDefinitions.kql",
    "kustoQueries/managementGroups.kql"
)

# Iterate over each .kql file and execute the export method
foreach ($kqlFile in $kqlFiles) {
    Write-Host "Processing file $kqlFile..."
    $kqlQuery = Get-Content -Path $kqlFile -Raw
    $csvFilePath = "output/" + [System.IO.Path]::GetFileNameWithoutExtension($kqlFile) + ".csv"
    ResourceGraphQueryAndExportToCsv -kqlQuery $kqlQuery -csvFilePath $csvFilePath
}