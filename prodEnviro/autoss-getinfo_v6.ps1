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

function StartOrStopVM {
    param (
        [Parameter(Mandatory = $true)]$vm
    )
    if ($vm.TagName -like "*Start") {
        Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -NoWait
    }
    elseif ($vm.TagName -like "*Stop") {
        Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.VMName -Force -NoWait 
    }
    else {
        Write-Host "No Start or Stop tag found for $($vm.VMName)"
    }
}

$allEnabledSubscriptions = @()
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
                $taggedVM = [PSCustomObject]@{
                    VMName         = $vm.Name
                    SubscriptionId = $subscription.Id
                    ResourceGroupName  = $vm.ResourceGroupName
                    TagName        = $tag.Key
                    TagValue       = $tag.Value
                }
                $taggedVMs += $taggedVM
            }
        }
    }
}

foreach ($vm in $taggedVMs) {
    $currentSub = Get-AzContext
    if ($currentSub.Subscription -ne $vm.SubscriptionId) {
        Set-AzContext -Subscription $vm.SubscriptionId
    }
    StartOrStopVM -vm $vm
}













