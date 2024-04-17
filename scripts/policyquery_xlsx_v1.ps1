function Write-ColorfulMessage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Module,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "Module " -ForegroundColor White -NoNewline
    Write-Host "($Module) " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Get-Modules {
    param (
        [Parameter(Mandatory = $false)]
        [array]$ModuleName = ("ImportExcel")
    )

    foreach ($Module in $ModuleName) {
        Import-Module $Module
        if (Get-Module -Name $Module) {
            Write-ColorfulMessage -Module $Module -Message "found"
        }
        else {
            Write-ColorfulMessage -Module $Module -Message "not found"
            $UserInput = Read-Host "PowerShell Module $($Module) is Required for Script to Run. Download? Enter Y for Yes, N for No to exit the script."
            switch ($UserInput) {
                'Y' {
                    $Global:ExecPolicy = Get-ExecutionPolicy
                    if ($Global:ExecPolicy -ne "RemoteSigned") {
                        Write-Host 'Changing Execution Policy to RemoteSigned. To change back, run the command Set-Execution -Policy $Global:ExecPolicy'
                        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
                    }
                    Write-Host "Installing Module $($Module)"
                    Install-Module -Name $Module -Force
                    Import-Module -Name $Module
                }
                'N' {
                    Write-Host "Please install the module $($Module) and re-run the script."
                    return
                }
                Default {
                    Write-Host "Invalid Input"
                }
            }
        }
    }
}

function New-LogEntry {
    param(
        [Parameter(Mandatory = $false)][string]$EventType,
        [Parameter(Mandatory = $false)][string]$Stage, 
        [Parameter(Mandatory = $false)][string]$Step, 
        [Parameter(Mandatory = $false)][string]$Details
    )

    $Now = Get-Date

    # Create a PSCustomObject with properties for each aspect of the log entry
    $LogEntry = New-Object -TypeName PSObject -Property @{
        "Time" = $Now.ToString()
        "LineNumber" = $MyInvocation.ScriptLineNumber
        "EventType" = $EventType
        "Stage" = $Stage
        "Step" = $Step
        "Details" = $Details
    }

    $LogEntry
}

Get-Modules
# Get the current date and time in the format "yyyyMMdd_HHmmss"
$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"

# Create a report name by appending the date and time to the base name
$xlsxReportName = "FinOpsAssignments_$dateTime.xlsx"
$reportName = "FinOpsComplianceReport_$dateTime.csv"
$assignmentReportName = "FinOpsAssignments_$dateTime.csv"

# Define the path where the report will be saved
$xlsxReportPath = ".\$xlsxReportName"
$reportPath = ".\$reportName"

# Get all FinOps policies by filtering on the category metadata
$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }

# Evaluate resources by getting the policy assignments and states for each FinOps policy
$ResourceCompliance = $FinOpsDefinitions | ForEach-Object {
    Get-AzPolicyAssignment -PolicyDefinitionId $_.PolicyDefinitionId
} | ForEach-Object {
    Get-AzPolicyState -PolicyAssignmentName $_.Name
}

$assigndefsarray = @()
foreach($def in $FinOpsDefinitions){
    $assignDefs = Get-AzPolicyAssignment -PolicyDefinitionId $def.PolicyDefinitionId
    $assigndefsarray += $assignDefs
}


$resComp = @()
foreach($assignmentdefs in $assigndefsarray){
    $state = Get-AzPolicyState -PolicyAssignmentName $assignmentdefs.Name
    $resComp += $state
}

foreach($i in 0..($assigndefsarray.Count -1)){
    $sheetName = $assigndefsarray[$i].Name
    $sheetName = $resComp | Where-Object { $_.PolicyAssignmentName -eq $assigndefsarray[$i].Name }
    $assignmentResComp[$i] | Export-Excel -Path "$xlsxReportName" -WorksheetName $sheetName
}


Get-AzPolicyState -PolicyAssignmentName 6197c70d4e254a5c98189d60

$assignments = @()
foreach ($definition in $FinOpsDefinitions){
    $assignments += Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId
}

$baseName = "assign"
foreach ($i in 0..($assignments.Count - 1)){
    $sheetName = $assignments[$i].Name
    $assignmentdefs = Get-AzPolicyState -PolicyAssignmentName $assignments[$i].Name
    Get-AzPolicyState -PolicyAssignmentName 6197c70d4e254a5c98189d60
   #$assignments[$i] | Export-Excel -Path "$xlsxReportName" -WorksheetName $sheetName
}


# Create a compliance report by creating a custom object for each resource
$ComplianceReport = $ResourceCompliance | ForEach-Object {
    # Split the resource ID on '/' and get the last part as the resource name
    $resourceIdParts = $_.resourceId.Split('/')
    $resourceName = $resourceIdParts[-1]

    # Create a PSCustomObject with properties for each aspect of the resource
    New-Object -TypeName PSObject -Property @{
        "AssignmentName" = $_.PolicyAssignmentName
        "DefinitionName" = $_.PolicyDefinitionName
        "ResourceType" = $_.ResourceType
        "ResourceName" = $resourceName
        "SubscriptionID" = $_.SubscriptionID
        "ComplianceState" = $_.ComplianceState
    }
}

# Export the compliance report to a CSV file at the defined path
$ComplianceReport | Export-Csv -Path $reportPath -NoTypeInformation