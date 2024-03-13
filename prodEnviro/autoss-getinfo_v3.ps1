#region functions

#endregion functions
function Get-DecimalTime {
    $time = Get-Date -Format "HH:mm"
    return [int]$time.Substring(0, 2) + [int]($time.Substring(3, 2)) / 100
}

function Get-TargetTags {
    param (
        [Parameter(Mandatory = $true)][string]$acceptedTagsList
    )
    $tagSheet = Import-Csv -Path $acceptedTagsList
    $appropriateTags = @()
    foreach ($tag in $tagSheet) {
        Set-TimeZone -Id $tag.TimeZone
        Write-Host "Setting TimeZone to $($tag.TimeZone)"
        $decimalTime = Get-DecimalTime
        Write-Host "Current Time: $decimalTime"
        [int]$t0 = $tag.TagValue
        [int]$t1 = [int]$t0 + 1
        Write-Host "Target time is $([int]$t0)"
        Write-Host "Target time + 1 is $t1"
        if ($decimalTime -ge $tag.TagValue -and $decimalTime -lt [int]$t1) {
            Write-Host "True"
            $appropriateTags += $tag.TagName
        }
        else {
            Write-Host "False"
        }
        Start-Sleep -Seconds 2
    }
    return $appropriateTags
}

#region Runbook Connect
#param (
#    [Parameter(Mandatory = $false)][string]$UAMI,
#    [Parameter(Mandatory = $false)][string]$Method,
#    [Parameter(Mandatory = $false)][string]$automationAccount,
#    [Parameter(Mandatory = $false)][string]$ResourceGroup,
#    [Parameter(Mandatory = $false)][string]$reportName
#)



#Import-Module Az.Accounts
#Import-Module Az.Automation
#Import-Module Az.Compute
# Ensures you do not inherit an AzContext in your runbook
#null = Disable-AzContextAutosave -Scope Process
#
# Connect using a Managed Service Identity
#ry {
#   $AzureConnection = (Connect-AzAccount -Identity).context
#
#atch {
#   Write-Output "There is no system-assigned user identity. Aborting." 
#   exit
#
#
# set and store context
#AzureContext = Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
#
#f ($Method -eq "SA") {
#   Write-Output "Using system-assigned managed identity"
#
#lseif ($Method -eq "UA") {
#   Write-Output "Using user-assigned managed identity"
#
#   # Connects using the Managed Service Identity of the named user-assigned managed identity
#   $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroup -Name $UAMI -DefaultProfile $AzureContext
#
#   # validates assignment only, not perms
#   $AzAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $automationAccount -DefaultProfile $AzureContext
#   if ($AzAutomationAccount.Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
#       $AzureConnection = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context
#
#       # set and store context
#       $AzureContext = Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
#   }
#   else {
#       Write-Output "Invalid or unassigned user-assigned managed identity"
#       exit
#   }
#
#lse {
#   Write-Output "Invalid method. Choose UA or SA."
#   exit
#endregion Runbook Connect

#region Testing
Connect-AzAccount
$UAMI = "mitestUAMI"
$Method = "UA"
$automationAccount = "autoss-runbook-aa"
$ResourceGroup = "rg"
$reportFolder = $env:TEMP
$reportName = "vmsEnabled.csv"
$reportPath = "$reportFolder" + "\" + "$reportName"
$allEnabledSubscriptions = "90da72fd-4e8b-4566-8304-2c234f193ea5"
#endregion Testing

#Write-Output "Connected to $($AzureConnection.Subscription)"

#$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })
Write-Output $allEnabledSubscriptions
$vmScheduled = @()
$vmTags = @()

$targetTags = Get-TargetTags -acceptedTagsList ".\prodEnviro\accepted_tags.csv"

foreach ($subscription in $allEnabledSubscriptions) {
    Set-AzContext -Subscription $subscription
    Write-Output "Connected to $($subscription)"
    $vms = Get-AzVM
    if ($null -ne $vms) {
        Write-Output "Null not eq VMS"
        foreach ($vm in $vms) {
            $vm.Tags.Keys | ForEach-Object {
                $vmTags += $_
            }
            $targetVMs = @()
            $vmTags | ForEach-Object {
                if ($targetTags -contains $_) {
                    $targetVMsArray = New-Object "PSCustomObject"
                    $targetVMsArray | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
                    $targetVMsArray | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value $subscription.Id
                    $targetVMsArray | Add-Member -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
                    Write-Output "True"
                    $targetVMs += $targetVMsArray
            }else {
                Write-Output "False"
            }
        }
            if ($vm.Tags.Keys[3] -in $targetTags) {
                    $vmTagRepObj = New-Object "PSCustomObject"
                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value $subscription.Id
                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "Schedule" -Value ($vm.Tags.Keys | Where-Object {$_ -eq $targetTags})
                }
            }
            $vmScheduled += $vmTagRepObj
        }
    }
}
$vmScheduled | Export-Csv -Path $reportPath -NoTypeInformation



#foreach ($subscription in $allEnabledSubscriptions) {
#    Set-AzContext -Subscription $subscription
#    Write-Output "Connected to $($subscription)"
#    $vms = Get-AzVM
#    if ($null -ne $vms) {
#        Write-Output "Null not eq VMS"
#        foreach ($vm in $vms) {
#            if ($vm.Tags.Keys -contains $targetTags) {
#                if ($ssScheduleEnabled -ne "false") {
#                    $vmTagRepObj = New-Object "PSCustomObject"
#                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
#                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value $subscription.Id
#                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "ResourceGroup" -Value $vm.ResourceGroupName
#                    $vmTagRepObj | Add-Member -MemberType NoteProperty -Name "Schedule" -Value $vm.Tags.ssScheduleUse
#                }
#            }
#            $vmScheduled += $vmTagRepObj
#        }
#    }
#} 
#$vmScheduled | Export-Csv -Path $reportPath -NoTypeInformation
$context = New-AzStorageContext -StorageAccountName "storaccount1ansjhxiu" -StorageAccountKey "PC5THg/rJ9iCbRrneeV64gXWlMhETP2qKgRVernsO49W1jkBSkkdqDPXe9r5Sy1OEAD/eDKIxTqN+AStugh23A=="
Set-AzStorageBlobContent -Context $context -Container "csvs" -File $reportPath -Blob "vmsEnabled.csv" -Force

Write-Output $vmScheduled