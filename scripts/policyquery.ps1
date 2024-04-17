
# Import the Az module
Import-Module Az

# Set the Azure subscription context
Connect-AzAccount

# Define the Azure policy name
$policyName = "TestTF - Deny OS Disk Detach"

# Get the non-compliant resources for the specified policy
$nonCompliantResources = Get-AzPolicyState -PolicyDefinitionName $policyName | Where-Object { $_.ComplianceState -ne "Compliant" }

# Create a CSV file to store the non-compliant resources
$csvFilePath = ".\nonCompliantResources.csv"
$nonCompliantResources | Export-Csv -Path $csvFilePath -NoTypeInformation

# Output the path of the CSV file
Write-Host "CSV file of non-compliant resources has been generated: $csvFilePath"




get-azpolicystatesummary -subscription "90da72fd-4e8b-4566-8304-2c234f193ea" -filter "(policyAssignmentId eq '/subscriptions/90da72fd-4e8b-4566-8304-2c234f193ea5/providers/Microsoft.Authorization/policyAssignments/ec6c767bc0224467ae78b115')"


$noncomp = Get-AzPolicyStateSummary -SubscriptionId "90da72fd-4e8b-4566-8304-2c234f193ea5" -filter "(policyAssignmentId eq '/subscriptions/90da72fd-4e8b-4566-8304-2c234f193ea5/providers/Microsoft.Authorization/policyAssignments/ec6c767bc0224467ae78b115')"


Get-AzPolicyState -SubscriptionId "90da72fd-4e8b-4566-8304-2c234f193ea5" -PolicyAssignmentName "ec6c767bc0224467ae78b115"

Get-AzPolicyState -ManagementGroup "Kapntech-Root" | Where-Object { $_.PolicyDefinitionCategory -eq 'Tags'}



$finopspolicies = @()
$compsums = @()
$compsums2 = @()

#Get all FinOps policies
$finops = Get-AzPolicyDefinition | Where-Object {$_.Properties.metadata.category -eq 'FinOps'}
foreach ($finop in $finops) {
    $assignments = Get-AzPolicyAssignment -PolicyDefinitionId $finop.PolicyDefinitionId
    $finopspolicies += $assignments
}

#Evaluate resources
foreach($assignment in $finopspolicies){
    $compsum = Get-AzPolicyState -PolicyAssignmentName $assignment.Name
    $compsums += $compsum
}

foreach($assignment in $finopspolicies){
    $compsumsum = Get-AzPolicyStateSummary -filter "(policyAssignmentId eq '$finop.PolicyAssignmentId')"
    $compsums2 += $compsumsum
}