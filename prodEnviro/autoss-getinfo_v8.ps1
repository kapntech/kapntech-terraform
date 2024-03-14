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
        $decimalTime = Get-DecimalTime
        [int]$t0 = $tag.TagValue
        [int]$t1 = [int]$t0 + 1
        if ($decimalTime -ge $tag.TagValue -and $decimalTime -lt [int]$t1) {
            $appropriateTags += $tag.TagName
        }
        Start-Sleep -Seconds 2
    }
    return $appropriateTags
    Write-Host "Appropriate Tags: $appropriateTags"
}

function StartOrStopVM {
    param (
        [Parameter(Mandatory = $true)]$vm
    )
    $vmStatusArray = @()
    if ($vm.TagName -like "*Start") {
        $vmStatus = (Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -Status).Statuses[1].DisplayStatus
        $vmStatusArray += [PSCustomObject]@{
            VMName = $vm.VMName
            Status = $vmStatus
        }
        if ($vmStatus -eq 'VM running') {
            Write-Host "$($vm.VMName) is already running"
        }
        else {
            Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -NoWait
            Write-Host "Starting $($vm.VMName)"
        }
    }
    elseif ($vm.TagName -like "*Stop") {
        $vmStatus = (Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -Status).Statuses[1].DisplayStatus
        $vmStatusArray += [PSCustomObject]@{
            VMName = $vm.VMName
            Status = $vmStatus
        }
        if ($vmStatus -eq 'VM stopped') {
            Write-Host "$($vm.VMName) is already stopped"
        }
        else {
            Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -Force -NoWait 
            Write-Host "Stopping $($vm.VMName)"
        }
    }
    else {
        Write-Host "No Start or Stop tag found for $($vm.VMName)"
    }
    return $vmStatusArray
}

function CreateTaggedVMObject {
    param (
        [Parameter(Mandatory = $true)]$vm,
        [Parameter(Mandatory = $true)]$subscription,
        [Parameter(Mandatory = $true)]$tag
    )
    return [PSCustomObject]@{
        VMName         = $vm.Name
        SubscriptionId = $subscription.Id
        ResourceGroupName  = $vm.ResourceGroupName
        TagName        = $tag.Key
        TagValue       = $tag.Value
    }
}

$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })
$targetTags = Get-TargetTags -acceptedTagsList ".\prodEnviro\accepted_tags.csv"
$taggedVMs = @()

foreach ($subscription in $allEnabledSubscriptions) {
    Set-AzContext -Subscription $subscription.Id

    $vms = Get-AzVM

    foreach ($vm in $vms) {
        $tags = $vm.Tags.GetEnumerator()
        foreach ($tag in $tags) {
            if ($targetTags -contains $tag.Key) {
                $taggedVMs += CreateTaggedVMObject -vm $vm -subscription $subscription -tag $tag
            }
        }
    }
}

for ($i = 1; $i -le 3; $i++) {
    foreach ($vm in $taggedVMs) {
        $currentSub = Get-AzContext
        if ($currentSub.Subscription -ne $vm.SubscriptionId) {
            Set-AzContext -Subscription $vm.SubscriptionId
        }
        $vmStatus = (Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -Status).Statuses[1].DisplayStatus
        if ($vmStatus -eq 'VM running' -or $vmStatus -eq 'VM stopped') {
            $taggedVMs = $taggedVMs | Where-Object { $_ -ne $vm }
        }
        else {
            StartOrStopVM -vm $vm
        }
    }
}
$vmResults















function SetAndStoreContext {
    param (
        [Parameter(Mandatory = $true)]$AzureConnection
    )
    return Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
}

# ... rest of your code ...

try {
    $AzureConnection = (Connect-AzAccount -Identity).context
    $AzureContext = SetAndStoreContext -AzureConnection $AzureConnection
}
catch {
    Write-Output "There is no system-assigned user identity. Aborting." 
    exit
}

# ... rest of your code ...

if ($AzAutomationAccount.Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
    $AzureConnection = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context
    $AzureContext = SetAndStoreContext -AzureConnection $AzureConnection
}