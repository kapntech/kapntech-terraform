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


$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })
$targetTags = Get-TargetTags -acceptedTagsList ".\prodEnviro\accepted_tags.csv"
$targetVMs = @()

foreach ($subscription in $allEnabledSubscriptions) {
    Set-AzContext -Subscription $subscription.Id

    $vms = Get-AzVM

    foreach ($vm in $vms) {
        $tags = $vm.Tags.Keys

        foreach ($tag in $tags) {
            if ($targetTags -contains $tag) {
                $targetVMsArray = New-Object "PSCustomObject"
                $targetVMsArray | Add-Member -MemberType NoteProperty -Name "VMName" -Value $vm.Name
                $targetVMsArray | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value $subscription.Id
                $targetVMsArray | Add-Member -MemberType NoteProperty -Name "ResourceGroupName" -Value $vm.ResourceGroupName
                $targetVMsArray | Add-Member -MemberType NoteProperty -Name "TagName" -Value $tag
                $targetVMs += $targetVMsArray
                break
            }
        }
    }
}

foreach ($vm in $targetVMs) {
    $currentSub = Get-AzContext
    if ($currentSub.Subscription -ne $vm.SubscriptionId) {
        Set-AzContext -Subscription $vm.SubscriptionId
    }
    StartOrStopVM -vm $vm
}
