function Get-DecimalTime {
    $time = Get-Date -Format "HH:mm"
    return [int]$time.Substring(0, 2) + [int]($time.Substring(3, 2)) / 100
}

function CreateTaggedVMObject {
    param (
        [Parameter(Mandatory = $true)]$vm,
        [Parameter(Mandatory = $true)]$subscription,
        [Parameter(Mandatory = $true)]$tag
    )
    return [PSCustomObject]@{
        VMName            = $vm.Name
        SubscriptionId    = $subscription.Id
        ResourceGroupName = $vm.ResourceGroupName
        TagName           = $tag.Key
        TagValue          = $tag.Value
    }
}

$acceptedTagsList = ".\prodEnviro\accepted_tags_v2.csv"
$acceptedTagsListActive = import-csv -Path $acceptedTagsList | Where-Object { $_.Active -eq "true" }
$targetTags = @()

foreach ($tagEntry in $acceptedTagsListActive) {
    Get-TimeZone -Name * | Where-Object { $_.DisplayName -eq $tagEntry.DisplayName } | Set-TimeZone
    Write-Host "Timezone set to: $($tagEntry.DisplayName)"
    $decimalTime = Get-DecimalTime
    $decimalTime = [math]::Floor($decimalTime)
    $upperTime = $decimalTime + 1
    Write-Host "Current time in decimal format: $decimalTime"
    $decimalTimeValue = [PSCustomObject]@{
        "TagName" = $tagEntry.TagName
        "DisplayName" = $tagEntry.DisplayName
        "TargetTagValue" = $decimalTime
        "UpperTimeValue" = $upperTime
    }
    $targetTags += $decimalTimeValue
}

$devManagementGroupsId = @( "DEV-Subscriptions", "kptmgid001", "Production-Subscriptions", "disabledsubs" )
$targetSubs = @()
foreach ($mg in $devManagementGroupsId){
    $subs = Get-AzManagementGroupSubscription -GroupId $mg
    $targetSubs += $subs
}

$taggedVMs = @()
foreach ($sub in $targetSubs) {
    Set-AzContext -Subscription $sub.DisplayName

    # Get all VMs in the subscription
    $vms = Get-AzVM

    # Loop through each VM
    foreach ($vm in $vms) {
        $tags = $vm.Tags.GetEnumerator()
        foreach ($tag in $tags) {
            $matchingTag = $targetTags | Where-Object { $_.TagName -eq $tag.Key }
            if ($matchingTag.TargetTagValue -and $tag.Value -lt $matchingTag.UpperTimeValue) {
                $taggedVMs += CreateTaggedVMObject -vm $vm -subscription $sub.DisplayName -tag $tag
            }
        }
    }
}