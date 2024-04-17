
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

Get-Modules


$xlsxReportName = "FinOpsAssignments_$dateTime.xlsx"
$xlsxReportPath = ".\$xlsxReportName"
$reportPath = ".\$reportName"


#Get all policy definitions with the category 'FinOps'
$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }
$FinOpsDefinitionsArray = @()
foreach($definition in $FinOpsDefinitions){
    $definitionRepObj = New-Object "PSCustomObject"
    $definitionDisplayName = $definition | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty DisplayName
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $definitionDisplayName
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "Name" -Value $definition.Name
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "ResourceId" -Value $definition.ResourceId
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "ResourceName" -Value $definition.ResourceName
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $definition.ResourceType
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value $definition.SubscriptionId
    $definitionRepObj | Add-Member -MemberType NoteProperty -Name "PolicyDefinitionId" -Value $definition.PolicyDefinitionId
    $FinOpsDefinitionsArray += $definitionRepObj 
}

$FinOpsAssignments = @()
foreach($definition in $FinOpsDefinitionsArray){
    $AssignedDefinitions = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId
    $FinOpsAssignments += $AssignedDefinitions
}

$FinOpsAssignmentsArray = @()
foreach($fAssignment in $FinOpsAssignments){
    $FinOpsAssignmentArrObj = New-Object "PSCustomObject"
    $FinOpsAssignmentDefName = $fAssignment | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty DisplayName
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "DefinitionDisplayName" -Value $FinOpsAssignmentDefName
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentName" -Value $fAssignment.Name
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentResourceId" -Value $fAssignment.ResourceId
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentResourceName" -Value $fAssignment.ResourceName
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentResourceGroupName" -Value $fAssignment.ResourceGroupName
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentResourceType" -Value $fAssignment.ResourceType
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentSubscriptionId" -Value $fAssignment.SubscriptionId
    $FinOpsAssignmentArrObj | Add-Member -MemberType NoteProperty -Name "AssignmentPolicyAssignmentId" -Value $fAssignment.PolicyAssignmentId
    #$FinOpsAssignmentsArray += $FinOpsAssignmentObj
    $FinOpsAssignmentsArray += $FinOpsAssignmentArrObj
} 

foreach ($i in 0..($FinOpsAssignmentsArray.Count - 1)) {
    #$WorkSheetName = $FinOpsAssignments[$i].Name
    $ResourceCompliance = Get-AzPolicyState -PolicyAssignmentName $FinOpsAssignmentsArray[$i].AssignmentName
    $ResourceReport = @()
    foreach($Resource in $ResourceCompliance){
        $resourceIdParts = $Resource.resourceId.Split('/')
        $resourceName = $resourceIdParts[-1]
        $ResourceRepObj = New-Object "PSCustomObject"
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "DefinitionDisplayName" -Value $FinOpsAssignmentsArray[$i].DefinitionDisplayName
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "PolicyAssignmentName" -Value $Resource.PolicyAssignmentName
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "DefinitionName" -Value $Resource.PolicyDefinitionName
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $Resource.ResourceType
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "ResourceName" -Value $resourceName
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $Resource.SubscriptionId
        $ResourceRepObj | Add-Member -MemberType NoteProperty -Name "ComplianceState" -Value $Resource.ComplianceState
        $ResourceReport += $ResourceRepObj
    }
    $ResourceReport | Export-Excel -Path "$xlsxReportName" -WorksheetName $FinOpsAssignmentsArray[$i].AssignmentName
}


$ComplianceReport = $ResourceCompliance | ForEach-Object {
    # Split the resource ID on '/' and get the last part as the resource name
    $resourceIdParts = $_.resourceId.Split('/')
    $resourceName = $resourceIdParts[-1]

    # Create a PSCustomObject with properties for each aspect of the resource
    New-Object -TypeName PSObject -Property @{
        "AssignmentName"  = $_.PolicyAssignmentName
        "DefinitionName"  = $_.PolicyDefinitionName
        "ResourceType"    = $_.ResourceType
        "ResourceName"    = $resourceName
        "SubscriptionID"  = $_.SubscriptionID
        "ComplianceState" = $_.ComplianceState
    }
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