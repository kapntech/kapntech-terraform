#region Function for connecting with Managed Identity
# Function for connecting with Managed Identity
#function SetAndStoreContext {
#    param (
#        [Parameter(Mandatory = $true)]$AzureConnection
#    )
#    return Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
#}
#endregion Function for connecting with Managed Identity

# Function to get the current time in decimal format
function Get-DecimalTime {
    $time = Get-Date -Format "HH:mm"
    return [int]$time.Substring(0, 2) + [int]($time.Substring(3, 2)) / 100
}

# Function to get the appropriate tags based on the current time
function Get-TargetTags {
    param (
        [Parameter(Mandatory = $true)][string]$taggedVMs
    )
    $targetVMs = @()
    #$appropriateTags = @()
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


function Get-TargetTags2 {
    param (
        [Parameter(Mandatory = $true)][string]$acceptedTagsList = ".\prodEnviro\accepted_tags_v2.csv"
    )
    $tagSheet = Import-Csv -Path $acceptedTagsList | Where-Object { $_.Active -eq "true" }

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


# Function to start or stop a VM based on its tag
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

# Function to create a tagged VM object
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

#region Connect with Managed Identity
#try {
#    $AzureConnection = (Connect-AzAccount -Identity).context
#    $AzureContext = SetAndStoreContext -AzureConnection $AzureConnection
#}
#catch {
#    Write-Output "There is no system-assigned user identity. Aborting." 
#    exit
#}
#
#if ($AzAutomationAccount.Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
#    $AzureConnection = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context
#    $AzureContext = SetAndStoreContext -AzureConnection $AzureConnection
#}
#endregion Connect with Managed Identity

# Get all enabled subscriptions
$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })

# Get the target tags based on the current time
$targetTags = Get-TargetTags -acceptedTagsList ".\prodEnviro\accepted_tags.csv"

# Array to store tagged VMs
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

# Loop through the tagged VMs and start or stop them
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












$acceptedTagsList = ".\prodEnviro\accepted_tags_v2.csv"

$tagSheet = Import-Csv -Path $acceptedTagsList | Where-Object { $_.Active -eq "true" }

$appropriateTags = @()

$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })

$taggedVMs = @()

foreach ($subscription in $allEnabledSubscriptions) {
    Set-AzContext -Subscription '90da72fd-4e8b-4566-8304-2c234f193ea5' #$subscription.Id

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

$finalVMs = @()

foreach($taggedVM in $taggedVMs){
        Set-TimeZone -Id (get-timezone -name * | Where-Object { $_.DisplayName -eq $tzdisplayname } | select -expand "Id")
        $decimalTime = Get-DecimalTime
        [int]$t0 = $taggedVM.TagValue
        [int]$t1 = [int]$t0 + 1
        if ($decimalTime -ge $taggedVM.TagValue -and $decimalTime -lt [int]$t1) {
            $finalVMs += $taggedVM
        }
        Start-Sleep -Seconds 2
}


get-timezone -name * | where-property {.DisplayName -eq Display_Name_in_CSV }

$taggedVMs 

Get-TimeZone -ListAvailable


$tzdisplayname = "(UTC+14:00) Kiritimati Island"

$timezone = get-timezone -name * | Where-Object { $_.DisplayName -eq $tzdisplayname }

Set-TimeZone -Id $timezone.Id

Set-TimeZone -Id (get-timezone -name * | Where-Object { $_.DisplayName -eq $tzdisplayname } | select -expand "Id")




az vm list --show-details --query '[].{Name:name, Tags:tags}'




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

# Import the CSV containing tag names and corresponding time zones
$tagSheet = Import-Csv -Path "C:\!repos\kapntech-terraform\prodEnviro\accepted_tags_v2.csv"

# Get all enabled subscriptions
$allEnabledSubscriptions = @(Get-AzSubscription | Where-Object { $_.State -eq "Enabled" })

# Array to store tagged VMs
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
            # Check if the tag name is in the tag sheet
            $matchingTag = $tagSheet | Where-Object { $_.TagName -eq $tag.Key }
            if ($matchingTag) {
                # Set the local time to the corresponding time zone
                Set-TimeZone -Id $matchingTag.TimeZone

                # Get the current time in decimal format
                $decimalTime = Get-DecimalTime

                # Check if the tag value is within 1 hour of the decimal time
                [int]$t0 = $matchingTag.TagValue
                [int]$t1 = [int]$t0 + 1
                if ($decimalTime -ge $matchingTag.TagValue -and $decimalTime -lt [int]$t1) {
                    # Create a tagged VM object and add it to the array
                    $taggedVMs += CreateTaggedVMObject -vm $vm -subscription $subscription -tag $tag
                }
            }
        }
    }
}

# $taggedVMs now contains all virtual machines that match the criteria