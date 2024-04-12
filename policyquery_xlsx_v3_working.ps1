
#function Get-Modules {
#    param (
#        [Parameter(Mandatory = $false)]
#        [array]$ModuleName = ("ImportExcel")
#    )
#
#    foreach ($Module in $ModuleName) {
#        Import-Module $Module
#        if (Get-Module -Name $Module) {
#            Write-ColorfulMessage -Module $Module -Message "found"
#        }
#        else {
#            Write-ColorfulMessage -Module $Module -Message "not found"
#            $UserInput = Read-Host "PowerShell Module $($Module) is Required for Script to Run. Download? Enter Y for Yes, N for No to exit the script."
#            switch ($UserInput) {
#                'Y' {
#                    $Global:ExecPolicy = Get-ExecutionPolicy
#                    if ($Global:ExecPolicy -ne "RemoteSigned") {
#                        Write-Host 'Changing Execution Policy to RemoteSigned. To change back, run the command Set-Execution -Policy $Global:ExecPolicy'
#                        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
#                    }
#                    Write-Host "Installing Module $($Module)"
#                    Install-Module -Name $Module -Force
#                    Import-Module -Name $Module
#                }
#                'N' {
#                    Write-Host "Please install the module $($Module) and re-run the script."
#                    return
#                }
#                Default {
#                    Write-Host "Invalid Input"
#                }
#            }
#        }
#    }
#}

$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"
$xlsxReportName = "FinOpsAssignments_$dateTime.xlsx"
$xlsxReportPath = ".\$xlsxReportName"

#Get-Modules

<#$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }
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
}#>


$FinOpsDefinitionsArray = @()
$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }
foreach ($definition in $FinOpsDefinitions) {
    $definitionRepObj = New-Object "PSCustomObject" -Property @{
        DisplayName        = $definition | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty DisplayName
        Name               = $definition.Name
        ResourceId         = $definition.ResourceId
        ResourceName       = $definition.ResourceName
        ResourceType       = $definition.ResourceType
        SubscriptionId     = $definition.SubscriptionId
        PolicyDefinitionId = $definition.PolicyDefinitionId
    }
    $FinOpsDefinitionsArray += $definitionRepObj
}   





$FinOpsAssignmentsArray = @()
foreach($definition in $FinOpsDefinitionsArray){
    $AssignedDefinitions = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId | Select-Object -ExpandProperty Properties
    foreach($AssignedDefinition in $AssignedDefinitions){
        $FinOpsAssignmentsArrObj = New-Object "PSCustomObject" @{
            DefinitionDisplayName        = $definition.DisplayName
            Name                         = $AssignedDefinitions.DisplayName
            AssignmentResourceId         = $AssignedDefinitions.ResourceId
            AssignmentResourceName       = $AssignedDefinitions.ResourceName
            AssignmentResourceGroupName  = $AssignedDefinitions.ResourceGroupName
            AssignmentResourceType       = $AssignedDefinitions.ResourceType
            AssignmentSubscriptionId     = $AssignedDefinitions.SubscriptionId
            AssignmentPolicyAssignmentId = $AssignedDefinitions.PolicyAssignmentId
        }
    }
    $FinOpsAssignmentsArray += $FinOpsAssignmentsArrObj
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
    $FinOpsAssignmentsArray += $FinOpsAssignmentArrObj
} 

foreach ($i in 0..($FinOpsAssignmentsArray.Count - 1)) {
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
    $ResourceReport | Export-Excel -Path $xlsxReportPath -WorksheetName $FinOpsAssignmentsArray[$i].AssignmentName
}