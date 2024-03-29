# Get the current date and time in the format "yyyyMMdd_HHmmss"
$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"

# Create a report name by appending the date and time to the base name
$reportName = "FinOpsComplianceReport_$dateTime.csv"

# Define the path where the report will be saved
$reportPath = ".\$reportName"

# Get all FinOps policies by filtering on the category metadata
$FinOpsDefinitions = Get-AzPolicyDefinition | Where-Object { $_.Properties.metadata.category -eq 'FinOps' }
$FinOpsDefAssignments = @()
# Evaluate resources by getting the policy assignments and states for each FinOps policy
$FinOpsDefAssignments = $FinOpsDefinitions | ForEach-Object {
    Get-AzPolicyAssignment -PolicyDefinitionId $_.PolicyDefinitionId
}



$ResourceCompliance = $FinOpsDefinitions | ForEach-Object {
    Get-AzPolicyAssignment -PolicyDefinitionId $_.PolicyDefinitionId
} | ForEach-Object {
    Get-AzPolicyState -PolicyAssignmentName $_.Name
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
        "TagValue" = $_.TagValue
    }
}

# Export the compliance report to a CSV file at the defined path
$ComplianceReport | Export-Csv -Path $reportPath -NoTypeInformation



# Create a compliance report for each FinOps policy assignment
$ComplianceReport = $FinOpsDefAssignments | ForEach-Object {
    $policyAssignmentId = $_.PolicyAssignmentId

    # Get the policy state for the current policy assignment
    $policyState = Get-AzPolicyState -PolicyAssignmentId $policyAssignmentId

    # Split the resource ID on '/' and get the last part as the resource name
    $resourceIdParts = $policyState.resourceId.Split('/')
    $resourceName = $resourceIdParts[-1]

    # Create a PSCustomObject with properties for each aspect of the resource
    $report = New-Object -TypeName PSObject -Property @{
        "AssignmentName" = $_.Name
        "DefinitionName" = $_.PolicyDefinitionName
        "ResourceType" = $policyState.ResourceType
        "ResourceName" = $resourceName
        "SubscriptionID" = $policyState.SubscriptionID
        "ComplianceState" = $policyState.ComplianceState
        "TagValue" = $policyState.TagValue
    }

    # Export the compliance report to a CSV file with a unique name
    $report | Export-Csv -Path ".\FinOpsComplianceReport_$policyAssignmentId.csv" -NoTypeInformation
}



foreach ($FinOpsDefAssignment in $FinOpsAssignments){
    $policyState = Get-AzPolicyState -PolicyAssignmentName $FinOpsDefAssignment.Name

}

