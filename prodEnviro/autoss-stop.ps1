$UAMI = "mitestUAMI"
$Method = "UA"
$automationAccount = "autoss-runbook-aa"
$ResourceGroup = "rg"
$reportFolder = $env:TEMP
$reportName = "vmsEnabled.csv"
$reportPath = "$reportFolder" + "\" + "$reportName"
$context = New-AzStorageContext -StorageAccountName "storaccount1ansjhxiu" -StorageAccountKey "PC5THg/rJ9iCbRrneeV64gXWlMhETP2qKgRVernsO49W1jkBSkkdqDPXe9r5Sy1OEAD/eDKIxTqN+AStugh23A=="
$containerName = "csvs"
$reportblob = @{
    Blob        = $reportName
    Container   = $containerName
    Destination = $reportFolder
    Context     = $context
}

#Import-Module Az.Accounts
#Import-Module Az.Automation
#Import-Module Az.Compute
# Ensures you do not inherit an AzContext in your runbook
$null = Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
    $AzureConnection = (Connect-AzAccount -Identity).context
}
catch {
    Write-Output "There is no system-assigned user identity. Aborting." 
    exit
}

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection

if ($Method -eq "SA") {
    Write-Output "Using system-assigned managed identity"
}
elseif ($Method -eq "UA") {
    Write-Output "Using user-assigned managed identity"

    # Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroup -Name $UAMI -DefaultProfile $AzureContext

    # validates assignment only, not perms
    $AzAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $automationAccount -DefaultProfile $AzureContext
    if ($AzAutomationAccount.Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
        $AzureConnection = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

        # set and store context
        $AzureContext = Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
    }
    else {
        Write-Output "Invalid or unassigned user-assigned managed identity"
        exit
    }
}
else {
    Write-Output "Invalid method. Choose UA or SA."
    exit
}

Get-AzStorageBlobContent @reportblob
$vmSSList = Import-Csv -Path $reportPath

$weekends = @("Monday", "Friday", "Saturday", "Sunday")
$timeZone = "IST"
$stopTime = "12:00:00"
$currentTime = (Get-Date).TimeOfDay.ToString()

foreach ($entry in $vmSSList) {
    $context = Get-AzContext
    if ($entry.SubscriptionId -eq $context.Subscription) {
        Write-Output "Subscription is the same"
        $vmStatus = (Get-AzVM -ResourceGroupName $entry.ResourceGroup -Name $entry.VMName -Status).Statuses[1].DisplayStatus
        Write-Output $vmStatus
        if ($vmStatus -ne "VM deallocated" -and $weekends -contains (Get-Date).DayOfWeek -and $currentTime -ge $stopTime) {
            Write-Output "Stopping VM"
            try {
                Stop-AzVM -ResourceGroupName $entry.ResourceGroup -Name $entry.VMName -Force
                Write-Output "VM is stopped"
            }
            catch {
                Write-Output "VM could not be stopped"
            }
        }
        elseif ($vmStatus -eq "VM deallocated") {
            Write-Output "VM is already stopped"
        }
    }
    else {
        Write-Output "Subscription is different"
        Set-AzContext -Subscription $entry.SubscriptionId
        $vmStatus = (Get-AzVM -ResourceGroupName $entry.ResourceGroup -Name $entry.VMName -Status).Statuses[1].DisplayStatus
        Write-Host $vmStatus
        if ($vmStatus -ne "VM deallocated" -and $weekends -contains (Get-Date).DayOfWeek -and $currentTime -ge $stopTime) {
            Write-Output "Stopping VM"
            try {
                Stop-AzVM -ResourceGroupName $entry.ResourceGroup -Name $entry.VMName -Force
                Write-Output "VM is stopped"
            }
            catch {
                Write-Output "VM could not be stopped"
            }
        }
        elseif ($vmStatus -eq "VM deallocated") {
            Write-Output "VM is already stopped"
        }
    }
}



