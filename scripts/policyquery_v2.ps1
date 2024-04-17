$FinOpsAssignments = @()
$ResourceCompliance = @()
$ComplianceReport = @()

#Get all FinOps policies
$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object {$_.Properties.metadata.category -eq 'FinOps'}
foreach ($definition in $FinOpsDefinitions) {
    $FinOpsDefAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $definition.PolicyDefinitionId
    $FinOpsAssignments += $FinOpsDefAssignment
}

#Evaluate resources
foreach($FinOpsAssignment in $FinOpsAssignments){
    $AssignmentResourceComp = Get-AzPolicyState -PolicyAssignmentName $FinOpsAssignment.Name
    $ResourceCompliance += $AssignmentResourceComp
}

foreach ($resource in $ResourceCompliance) {
    $ComplianceReportObj = New-Object "PSCustomObject"
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "AssignmentName" -Value $resource.PolicyAssignmentName
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "DefinitionName" -Value $resource.PolicyDefinitionName
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $resource.ResourceType
    $resourceIdParts = $resource.resourceId.Split('/')
    $resourceName = $resourceIdParts[-1]
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "ResourceName" -Value $resourceName
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $resource.SubscriptionID
    $ComplianceReportObj | Add-Member -MemberType NoteProperty -Name "ComplianceState" -Value $resource.ComplianceState
    $ComplianceReport += $ComplianceReportObj
}


foreach($assignment in $finopspolicies){
    $compsumsum = Get-AzPolicyStateSummary -filter "(policyAssignmentId eq '$finop.PolicyAssignmentId')"
    $compsums2 += $compsumsum
}





$noncomp = Get-AzPolicyStateSummary -SubscriptionId "90da72fd-4e8b-4566-8304-2c234f193ea5" -filter "(policyAssignmentId eq '/subscriptions/90da72fd-4e8b-4566-8304-2c234f193ea5/providers/Microsoft.Authorization/policyAssignments/ec6c767bc0224467ae78b115')"