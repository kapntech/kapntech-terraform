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
        if (-not (Get-Module -ListAvailable -Name $Module)) {
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
        Import-Module $Module
        Write-ColorfulMessage -Module $Module -Message "found"
    }
}

function CreateCustomObject {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Properties
    )

    $customObject = New-Object "PSCustomObject"
    foreach ($property in $Properties.GetEnumerator()) {
        $customObject | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
    }

    return $customObject
}

$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"
$xlsxReportName = "FinOpsAssignments_$dateTime.xlsx"
$xlsxReportPath = ".\$xlsxReportName"

Get-Modules

$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }
$FinOpsDefinitionsArray = @()
foreach ($definition in $FinOpsDefinitions) {
    $definitionDisplayName = $definition | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty DisplayName
    $FinOpsDefinitionsArray += CreateCustomObject @{
        "DisplayName"        = $definitionDisplayName
        "Name"               = $definition.Name
        "ResourceId"         = $definition.ResourceId
        "ResourceName"       = $definition.ResourceName
        "ResourceType"       = $definition.ResourceType
        "SubscriptionId"     = $definition.SubscriptionId
        "PolicyDefinitionId" = $definition.PolicyDefinitionId
    }
}

$FinOpsAssignments = @()
foreach ($definition in $FinOpsDefinitionsArray) {
    $AssignedDefinitions = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId
    $FinOpsAssignments += $AssignedDefinitions
}

$FinOpsAssignmentsArray = @{}
foreach ($fAssignment in $FinOpsAssignments) {
    $FinOpsAssignmentDefName = $fAssignment | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty DisplayName
    $FinOpsAssignmentsArray[$fAssignment.Name] = CreateCustomObject @{
        "DefinitionDisplayName"        = $FinOpsAssignmentDefName
        "AssignmentName"               = $fAssignment.Name
        "AssignmentResourceId"         = $fAssignment.ResourceId
        "AssignmentResourceName"       = $fAssignment.ResourceName
        "AssignmentResourceGroupName"  = $fAssignment.ResourceGroupName
        "AssignmentResourceType"       = $fAssignment.ResourceType
        "AssignmentSubscriptionId"     = $fAssignment.SubscriptionId
        "AssignmentPolicyAssignmentId" = $fAssignment.PolicyAssignmentId
    }
}

$ResourceCompliance = Get-AzPolicyState
foreach ($Resource in $ResourceCompliance) {
    $resourceIdParts = $Resource.resourceId.Split('/')
    $resourceName = $resourceIdParts[-1]
    $assignment = $FinOpsAssignmentsArray[$Resource.PolicyAssignmentName]
    if ($assignment) {
        $ResourceReport = CreateCustomObject @{
            "DefinitionDisplayName" = $assignment.DefinitionDisplayName
            "PolicyAssignmentName"  = $Resource.PolicyAssignmentName
            "DefinitionName"        = $Resource.PolicyDefinitionName
            "ResourceType"          = $Resource.ResourceType
            "ResourceName"          = $resourceName
            "SubscriptionID"        = $Resource.SubscriptionId
            "ComplianceState"       = $Resource.ComplianceState
        }
        $ResourceReport | Export-Excel -Path $xlsxReportPath -WorksheetName $assignment.AssignmentName
    }
}