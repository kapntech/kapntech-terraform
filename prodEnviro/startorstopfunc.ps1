#function StartOrStopVM {
    param (
        [Parameter(Mandatory = $true)]$vm
    )
    Set-AzContext -Subscription '90da72fd-4e8b-4566-8304-2c234f193ea5'
    $vm = "linux-vm"
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
#}

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





$taggedVMs = @()

# Loop through each subscription
foreach ($subscription in $allEnabledSubscriptions) {
    Set-AzContext -Subscription $subscription.Id

    # Get all VMs in the subscription
    $vms = Get-AzVM

    # Loop through each VM
    foreach ($vm in $vms) {
        $tags = $vm.Tags.GetEnumerator()
        foreach ($tag in $tags) {
            if ($targetTags -contains $tag.Key) {
                $taggedVMs += CreateTaggedVMObject -vm $vm -subscription $subscription -tag $tag
            }
        }
    }
}

$timezones = Get-TimeZone -ListAvailable | Select-Object -Property Id, DisplayName, StandardName
$timezones | Export-Csv -Path ".\prodEnviro\timezones.csv" -NoTypeInformation
```