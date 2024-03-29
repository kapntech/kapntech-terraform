
param(
    [Parameter(ParameterSetName = 'default')]
    [string]$File,    
    [Parameter(ParameterSetName = 'default')]
    [switch]$All,
    [Parameter(ParameterSetName = 'default')]
    [array]$MigratingDomains,
    [Parameter(ParameterSetName = 'default')]
    [bool]$NoDelegates = $false
)


function Test-RunAsAdministrator {
    $GetCurrentSecPrincipal = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $CheckPrincipal = New-Object System.Security.Principal.WindowsPrincipal($GetCurrentSecPrincipal)
    if ($CheckPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Output $true
    }
    else {
        Write-Output $false
    }
}

function Get-Modules {
    param (
        [Parameter(Mandatory = $false)]
        [array]$ModuleName = ("ImportExcel", "ActiveDirectory")
    )
    
    foreach ($Module in $ModuleName) {
        Import-Module $Module
        if (Get-Module -Name $Module) {
            Write-Host "Module " -ForegroundColor White -NoNewline; Write-Host "($Module) " -ForegroundColor Cyan -NoNewline; Write-Host "found" -ForegroundColor White
        }
        else {
            Write-Host "Module " -ForegroundColor White -NoNewline; Write-Host "($Module) " -ForegroundColor Cyan -NoNewline; Write-Host "not found" -ForegroundColor White
            $UserInput = Read-Host "PowerShell Module $($Module) is Required for Script to Run. Download? Enter Y for Yes, N for No to exit the script."
            switch ($UserInput) {
                'Y' {
                    $Global:ExecPolicy = Get-ExecutionPolicy
                    if ($Global:ExecPolicy -eq "RemoteSigned") {
                        Install-Module -Name $Module
                    }
                    else {
                        Write-Host 'Changing Execution Policy to RemoteSigned. To change back, run the command Set-Execution -Policy $Global:ExecPolicy'
                        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
                    }
                    Write-Host "Installing Module $($Module)"
                    Install-Module -Name $Module -Force
                    Import-Module -Name $Module
                }
                'N' {
                    Write-Host "Please install the module $($Module) and re-run the script."
                    return
                }
                Default {
                    Write-Host "Invalid Input"
                }
            }
        }
    }
}

function Test-ExServerConnection {
    $AssessmentScriptSessionChk = Get-PSSession
    if ($AssessmentScriptSessionChk.Name -notcontains "AutoAssessmentScript") {
        $ExServerToConnectTo = Read-Host "Enter Exchange Server FQDN"
        $UserCredential = Get-Credential
        $ExServerSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$($ExServerToConnectTo)/PowerShell/" -Name AutoAssessmentScript -Authentication Kerberos -Credential $UserCredential
        Import-PSSession $ExServerSession -DisableNameChecking
    }
    else {
        Write-Host Connected to Exchange -ForegroundColor Green
    }
}

function Invoke-DcDiag {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainController
    )
    $result = dcdiag /s:$DomainController | Write-Output
    $result | select-string -pattern '\. (.*) \b(passed|failed)\b test (.*)' | ForEach-Object {
        $obj = @{
            TestName   = $_.Matches.Groups[3].Value
            TestResult = $_.Matches.Groups[2].Value
            Entity     = $_.Matches.Groups[1].Value
        }
        [pscustomobject]$obj
    }
}

function New-LogEntry {
    param(
        [Parameter(Mandatory = $false)][string]$EventType,
        [Parameter(Mandatory = $false)][string]$Stage, 
        [Parameter(Mandatory = $false)][string]$Step, 
        [Parameter(Mandatory = $false)][string]$Details
    )

    $Now = Get-Date
    $LogEntry = New-Object system.object
    $LogEntry | Add-Member -NotePropertyName 'Time' -NotePropertyValue $Now.ToString()
    $LogEntry | Add-Member -NotePropertyName 'LineNumber' -NotePropertyValue $MyInvocation.ScriptLineNumber
    $LogEntry | Add-Member -NotePropertyName 'EventType' -NotePropertyValue $EventType
    $LogEntry | Add-Member -NotePropertyName 'Stage' -NotePropertyValue $Stage
    $LogEntry | Add-Member -NotePropertyName 'Step' -NotePropertyValue $Step
    $LogEntry | Add-Member -NotePropertyName 'Details' -NotePropertyValue $Details    
    $LogEntry
    
}

function New-ImportantThing {
    param(
        #[Parameter(Mandatory = $false)][string]$Item, 
        [Parameter(Mandatory = $false)][string]$Name, 
        [Parameter(Mandatory = $false)][string]$Details
    )
    $Now = Get-Date
    $ImportantThingEntry = New-Object system.object
    $ImportantThingEntry | Add-Member -NotePropertyName 'Time' -NotePropertyValue $Now.ToString()
    $ImportantThingEntry | Add-Member -NotePropertyName 'Item' -NotePropertyValue $Name
    $ImportantThingEntry | Add-Member -NotePropertyName 'Details' -NotePropertyValue $Details
    $ImportantThingEntry | Add-Member -NotePropertyName 'LineNumber' -NotePropertyValue $MyInvocation.ScriptLineNumber
    $ImportantThingEntry
}

function New-GAPRiskReportLog {
    param(
        #[Parameter(Mandatory = $false)][string]$Item, 
        [Parameter(Mandatory = $false)][string]$ProblemName, 
        [Parameter(Mandatory = $false)][string]$ResourceName,
        [Parameter(Mandatory = $false)][string]$ProblemState,
        [Parameter(Mandatory = $false)][string]$CorrectState,
        [Parameter(Mandatory = $false)][string]$Solution,
        [Parameter(Mandatory = $false)][string]$Impact,
        [Parameter(Mandatory = $false)][string]$Risk,
        [Parameter(Mandatory = $false)][string]$AssignedTo,
        [Parameter(Mandatory = $false)][string]$Notes,
        [Parameter(Mandatory = $false)][string]$Status
    )
    $Now = Get-Date
    $GAPRiskReportEntry = New-Object system.object
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Item' -NotePropertyValue $ProblemName
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Resources' -NotePropertyValue $ResourceName
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Current State' -NotePropertyValue $ProblemState
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Desired State' -NotePropertyValue $CorrectState
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Remediation' -NotePropertyValue $Solution
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Business Impact' -NotePropertyValue $Impact
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Risk' -NotePropertyValue $Risk
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'AssignedTo' -NotePropertyValue $Owner
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Notes' -NotePropertyValue $Notes
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Status' -NotePropertyValue $Status
    $GAPRiskReportEntry | Add-Member -NotePropertyName 'Time' -NotePropertyValue $Now.ToString()
    $GAPRiskReportEntry
}

$Global:LogArray = @()


$Stages = @(
    "Prerequisites"
    "AD Assessment Information",
    "Exchange Servers Assessment Information",
    "Mailbox Information",
    "Delegates Script",
    "Reports"
)

$Steps = @(
    "Prerequisites"
    "DCs Information",
    "AD Forest",
    "AD Domain",
    "DC Health Checks",
    "AD Trust",
    "AD Sync Check",
    "Exchange Server Info",
    "CAS Server Info",
    "Connectors,Rules,DLP,Certificates"
    "Database Info"
    "Exchange Features",
    "Hybrid Check",
    "Mailbox Info",
    "DG Info",
    "Public Folders",
    "Tenant Check",
    "Delegates Script",
    "Create CSV Reports",
    "Export CSV Reports",
    "Create-Export XLSX Reports"
)

if (-not(Test-RunAsAdministrator)) {
    throw "Please run as Administrator"
}
try {
    $LogLine = "Checking installed modules"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
    Get-Modules -ErrorAction Stop
    $LogLine = "Check completed"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed Modules Check: " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
}

$LogName = "AutoAssessLog" + "-" + (Get-Date -Format "M-d-yyyy-HHmmssff") + ".csv"
$LogFilePath = ".\Reports\Log"
$XMLFolderPath = ".\Reports\XMLs"
$ReportsFolderPath = ".\Reports"
$DelegatesScriptDirectoryPath = ".\Reports\Delegates"
$DelegatesScriptName = "FindDelegates.ps1"
$DelegatesScriptFullPath = "$($DelegatesScriptDirectoryPath)\$($DelegatesScriptName)"
$PreviousRunsFolderPath = ".\PreviousRuns"
$PreviousRunsPackagesFolder = "$($PreviousRunsFolderPath)\$((Get-Date).ToString('yyyy-MM-dd-HH-mm-fff'))"
$CSVsFolderPath = "$($ReportsFolderPath + "\CSVs")"
$XLSXsFolderPath = "$($ReportsFolderPath + "\XLSXs")"
$ExServerExcelReportName = "ExchangeServerAssessmentReport.xlsx"
$ADExcelReportName = "ADAssessmentReport.xlsx"
$ExMBXExcelReportName = "ExchangeMailboxAssessment.xlsx"
$ExImportantExcelReportName = "ImportantThings.xlsx"
$GAPRisksExcelReportName = "GAPSRisksReport.xlsx"

$ADForestInfoReportName = "ADForestInfoReport.csv"
$ADDomainInfoReportName = "ADDomainInfoReport.csv"
$ADHealthSummaryReportName = "ADHealthCheckReport.csv"
$ADTrustReportName = "ADTrustReport.csv"
$ExServerInfoReportName = "ExServerInfoReport.csv"
$ExDatabaseInfoReportName = "ExDatabaseInfoReport.csv"
$ExServerRecConnectorReportName = "ExServerReceiveConnectorsReport.csv"
$ExServerSendConnectorReportName = "ExServerSendConnectorsReport.csv"
$ExServerRulesReportName = "ExServerRulesReport.csv"
$ExServerJournalRulesReportName = "ExServerJournalRulesReport.csv"
$ExServerDLPPoliciesReportName = "ExServerDLPPoliciesReport.csv"
$ExServerAddressListsReportName = "ExServerAddressListsReport.csv"
$ExServerOrgRelationshipReportName = "ExServerOrgRelationshipsReport.csv"
$ExServerAcceptedDomainsReportName = "ExServerAcceptedDomainsReport.csv"
$ExEmailAddressPoliciesReportName = "ExEmailAddressPoliciesReport.csv"
$ExMailRetentionTagsReportName = "ExMailRetentionTagsReport.csv"
$ExMailRetentionPoliciesReportName = "ExMailRetentionPoliciesReport.csv"
$ActiveSyncDeviceAccessRulesReportName = "ExActiveSyncAccessRulesReport.csv"
$ActiveSyncMailboxPoliciesReportName = "ExActiveSyncMailboxPoliciesReport.csv"
$PublicFoldersReportName = "PublicFoldersReport.csv"
$PublicFoldersClientPermsReportName = "PublicFoldersClientPermissionsReport.csv"
$ExchangeCertificatesReportName = "ExchangeCertificatesReport.csv"
$ExHybridCheckReportName = "HybridExchangeCheckReport.csv"
$MailboxStatsReportName = "MailboxStatisticsReport.csv"
$DistributionGroupReportsName = "DistributionGroupReport.csv"
$DynamicDistributionGroupReportName = "DynamicDistributionGroupReport.csv"
$InternalOnlyImportantReportName = "ImportantThingsReport.csv"
$GAPRiskReportName = "GAPRisksReport.csv"

$folders = @(
    "$LogFilePath"
    "$XMLFolderPath"
    "$ReportsFolderPath"
    "$DelegatesScriptDirectoryPath"
    "$CSVsFolderPath"
    "$XLSXsFolderPath"
    "$PreviousRunsFolderPath"
)

foreach ($folder in $folders) {
    if (!(Test-Path -PathType Container $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
}
switch ($NoDelegates) {
    $true { Break }
    Default {
        if (!(Test-Path -PathType Leaf "$DelegatesScriptFullPath")) {
            $DelegateScriptUserInput = Read-Host "The script FindDelegates.ps1 could not be found in $($DelegatesScriptDirectoryPath) and will not run. If you would like to continue Press Y for Yes, or N for No."
            switch ($DelegateScriptUserInput) {
                'Y' {
                    Write-Host "Continuing script without delegates detection. Please run delegate detection independently"
                }
                'N' {
                    Write-Host "Please copy the script into the folder $($DelegatesScriptDirectoryPath). If you need to download the FindDelegates.ps1 script, a copy can be found here: https://github.com/microsoft/FastTrack/blob/master/scripts/Find-MailboxDelegates/Find-MailboxDelegates.ps1 "
                    return
                }
                Default {
                    Write-Host "Invalid Input"
                }
            } 
        }
    }
}

if (Test-Path -Path "$($XMLFolderPath)\*") {
    New-Item -ItemType Directory -Path "$($PreviousRunsPackagesFolder)\XMLs" | Out-Null
    Move-Item -Path "$($XMLFolderPath)\*.xml" -Destination "$($PreviousRunsPackagesFolder)\XMLs"
}
if (Test-Path -Path "$($CSVsFolderPath)\*") {
    New-Item -ItemType Directory -Path "$($PreviousRunsPackagesFolder)\CSVs" | Out-Null
    Move-Item -Path "$($CSVsFolderPath)\*.csv" -Destination "$($PreviousRunsPackagesFolder)\CSVs"
}
if (Test-Path -Path "$($DelegatesScriptDirectoryPath)\*") {
    New-Item -ItemType Directory -Path "$($PreviousRunsPackagesFolder)\Delegates" | Out-Null
    Move-Item -Path "$($DelegatesScriptDirectoryPath)\*.log" -Destination "$($PreviousRunsPackagesFolder)\Delegates"
    Move-Item -Path "$($DelegatesScriptDirectoryPath)\*.csv" -Destination "$($PreviousRunsPackagesFolder)\Delegates"
    Move-Item -Path "$($DelegatesScriptDirectoryPath)\*.xml" -Destination "$($PreviousRunsPackagesFolder)\Delegates"
}
if (Test-Path -Path "$($XLSXsFolderPath)\*") {
    New-Item -ItemType Directory -Path "$($PreviousRunsPackagesFolder)\XLSXs" | Out-Null
    Move-Item -Path "$($XLSXsFolderPath)\*.xlsx" -Destination "$($PreviousRunsPackagesFolder)\XLSXs"
}

try {
    $LogLine = "Testing Exchange Server shell connectivity"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
    Test-ExServerConnection -ErrorAction Stop
    $LogLine = "Connected to Exchange"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Function failed: Test-ExServerConnection " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[0] -Step $Steps[0] -Details $LogLine
}


$MaxPrimaryMBXSizeForMigration = .05
$MaxArchiveMBXSizeForMigration = .02
$MaxSharedPrimaryMBXSizeForMigration = .04
$MaxSharedArchiveBXSizeForMigration = .03
$defaultAddressLists = @(
    "All Contacts", 
    "All Distribution Lists", 
    "All Rooms", 
    "All Users", 
    "Default Global Address List", 
    "Public Folders"
)
$defaultAntiMalwareFileTypes = @(
    "ace", 
    "ani", 
    "app", 
    "docm", 
    "exe", 
    "jar", 
    "reg", 
    "scr", 
    "vbe", 
    "vbs"
)
$includedRetentionTags = @(
    "1 Month Delete", 
    "1 Week Delete", 
    "1 Year Delete", 
    "5 Year Delete", 
    "6 Month Delete", 
    "Default 2 year move to archive", 
    "Never Delete", 
    "Personal 1 year move to archive", 
    "Personal 5 year move to archive", 
    "Personal never move to archive"
)
$includedRetentionPolicies = @(
    "Default MRM Policy",
    "ArbitrationMailbox"
)

$Global:InternalOnlyImportantReport = @()
$Global:GAPRiskReport = @()
$ADHealthSummaryReport = @()
$ADForestInfoReport = @()
$ADDomainInfoReport = @()
$ADTrustReport = @()
$ExCasServers = @()
$ExServerInfoReport = @()
$ExDatabaseInfoReport = @()
$ExServerRecConnectorsReport = @()
$ExServerSendConnectorsReport = @()
$ExServerRulesReport = @()
$ExServerJournalRulesReport = @()
$ExServerDLPPoliciesReport = @()
$ExServerAddressListsReport = @()
$ExServerOrgRelationshipReport = @()
$ExAntiMalwareReport = @()
$ExServerAcceptedDomainsReport = @()
$ExEmailAddressPoliciesReport = @()
$ExMailRetentionTagsReport = @()
$ExMailRetentionPoliciesReport = @()
$ActiveSyncDeviceAccessRulesReport = @()
$ActiveSyncMailboxPoliciesReport = @()
$PublicFoldersReport = @()
$PublicFoldersClientPermissionsReport = @()
$ExchangeCertificatesReport = @()
$ExHybridCheckReport = @()
$PingSuccess = @()
$MailboxStatisticsReport = @()
$DistributionGroupReport = @()
$DynamicDistributionGroupReport = @()

$LogLine = "Beginning script"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[18] -Details $LogLine
Write-Host "Beginning AD assessment..." -ForegroundColor Yellow
Write-Host "...Getting domain controllers..." -ForegroundColor White

try {
    $LogLine = "Getting domain controllers"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[18] -Details $LogLine
    $DomainControllers = Get-ADDomainController -Filter * -ErrorAction Stop
    $LogLine = "Retrieved domain controllers successfully"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[18] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADDomainController " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[18] -Details $LogLine
}

Write-Host "...Getting AD forest information..." -ForegroundColor White
try {
    $LogLine = "Getting AD forest information"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[2] -Details $LogLine
    $ForestInfo = Get-ADForest | Select-Object Name, ForestMode, @{Name = 'Domains'; Expression = { $_.Domains -join ' , '}}, RootDomain, DomainNamingMaster, SchemaMaster, @{Name = 'GlobalCatalogs'; Expression = { $_.GlobalCatalogs -join ' , ' } }, @{Name = 'Sites'; Expression = { $_.Sites -join ' , ' } }, @{Name = 'UPNSuffixes'; Expression = { $_.UPNSuffixes -join ' , ' } } -ErrorAction Stop
    $LogLine = "Retrieved AD forest information successfully"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[2] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADForest " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[2] -Details $LogLine
}
$ADForestInfoRepObj = New-Object "PSCustomObject"
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Forest Name' -NotePropertyValue $ForestInfo.Name
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Forest Mode' -NotePropertyValue $ForestInfo.ForestMode
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Domains' -NotePropertyValue $ForestInfo.Domains
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Root Domain' -NotePropertyValue $ForestInfo.RootDomain
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Domain Naming Master' -NotePropertyValue $ForestInfo.DomainNamingMaster
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Schema Master' -NotePropertyValue $ForestInfo.SchemaMaster
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Global Catalogs' -NotePropertyValue $ForestInfo.ForestMode
$ADForestInfoRepObj | Add-Member -NotePropertyName 'Sites' -NotePropertyValue $ForestInfo.Sites
$ADForestInfoRepObj | Add-Member -NotePropertyName 'UPN Suffixes' -NotePropertyValue $ForestInfo.UPNSuffixes
$ADForestInfoReport += $ADForestInfoRepObj

Write-Host "...Getting AD domain information..." -ForegroundColor White
try {
    $LogLine = "Getting AD domain information"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
    $DomainInfo = Get-ADDomain | Select-Object Name, NetBIOSName, DomainMode, PDCEmulator, RIDMaster, InfrastructureMaster, @{Name = 'ReplicaDirectoryServers'; Expression = { $_.ReplicaDirectoryServers } }, @{Name = 'ParentDomain'; Expression = { $_.ParentDomain } }, @{Name = 'ChildDomains'; Expression = { $_.ChildDomains -join ' , ' } }
    $LogLine = "Retrieved AD domain information"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADDomain " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
}
$ADDomainInfoRepObj = New-Object "PSCustomObject"
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Domain Name' -NotePropertyValue $DomainInfo.Name
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'NetBIOS Name' -NotePropertyValue $DomainInfo.NetBIOSName
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Domain Mode' -NotePropertyValue $DomainInfo.DomainMode
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'PDC Emulator' -NotePropertyValue $DomainInfo.PDCEmulator
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'RID Master' -NotePropertyValue $DomainInfo.RIDMaster
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Infrastructure Master' -NotePropertyValue $DomainInfo.InfrastructureMaster
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Replica Servers' -NotePropertyValue ($DomainInfo.ReplicaDirectoryServers -join " , ")
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Parent Domain' -NotePropertyValue $DomainInfo.ParentDomain
$ADDomainInfoRepObj | Add-Member -NotePropertyName 'Child Domains' -NotePropertyValue $DomainInfo.ChildDomains

Write-Host "...Getting AD recycle bin status..." -ForegroundColor White
try {
    $LogLine = "Getting AD recycle bin information"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
    $ADRecycleBin = Get-ADOptionalFeature -Filter 'name -like "Recycle Bin Feature"'
    $LogLine = "Retrieved AD recycle bin information"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADOptionalFeature " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[3] -Details $LogLine
}
if ($ADRecycleBin.EnabledScopes) {
    $ADDomainInfoRepObj | Add-Member -NotePropertyName 'AD RecycleBin' -NotePropertyValue "Enabled" 
}
else {
    $ADDomainInfoRepObj | Add-Member -NotePropertyName 'AD RecycleBin' -NotePropertyValue "Disabled"
    $Global:GAPRiskReport += New-GAPRiskReportLog `
        -ProblemName "AD Recycle Bin Disabled" `
        -ResourceName "$($DomainInfo.NetBIOSName)" `
        -ProblemState "AD Recycle Bin feature is not enabled for $($DomainInfo.NetBIOSName)" `
        -CorrectState "AD Recycle Bin feature should be enabled." `
        -Solution "Enabled AD Recycle Bin" `
        -Impact "High" `
        -Risk "High" `
        -AssignedTo "IG" `
        -Notes "https://learn.microsoft.com/en-us/azure/active-directory/hybrid/connect/how-to-connect-sync-recycle-bin" `
        -Status "Reported"
}
$ADDomainInfoReport += $ADDomainInfoRepObj

Write-Host "...Beginning domain controller health checks..." -ForegroundColor White
$LogLine = "Starting DC health checks"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
foreach ($DC in $DomainControllers) {
    $ADRepObj = New-Object "PSCustomObject"
    $ADRepObj | Add-Member -NotePropertyName 'DCName' -NotePropertyValue $DC.Name
    #### Check Netlogon Service State ####
    if ( Test-Connection -ComputerName $DC.Name -Count 1 -ErrorAction SilentlyContinue ) {
        $LogLine = "Connectivity check for $($DC.Name) successful"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $ADRepObj | Add-Member -NotePropertyName 'Ping' -NotePropertyValue "Success"
        #### Check Netlogon Service State ####
        $LogLine = "Starting Netlogon service check for $($DC.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $svcName = Get-Service -ComputerName $DC.Name -Name "Netlogon" -ErrorAction SilentlyContinue
        if ($svcName.Status -like "Running") {
            $ADRepObj | Add-Member -NotePropertyName 'Netlogon' -NotePropertyValue $svcName.Status
        }
        else {
            $ADRepObj | Add-Member -NotePropertyName 'Netlogon' -NotePropertyValue $svcName.Status
            $Global:GAPRiskReport += New-GAPRiskReportLog `
                -ProblemName "DCDiag" `
                -ResourceName "Netlogon Service" `
                -ProblemState "Netlogon service is not running on $($DC.Name)" `
                -CorrectState "Netlogon service is should be running." `
                -Solution "Please investigate." `
                -Impact "High" `
                -Risk "High" `
                -AssignedTo "IG" `
                -Notes "" `
                -Status "Reported"
        }
        $LogLine = "Completed Netlogon service check for $($DC.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        #### Check NTDS Service State ####
        $LogLine = "Starting NTDS service check for $($DC.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $svcName = Get-Service -ComputerName $DC.Name -Name "NTDS" -ErrorAction SilentlyContinue
        if ($svcName.Status -like "Running") {
            $ADRepObj | Add-Member -NotePropertyName 'NTDS' -NotePropertyValue $svcName.Status
        }
        else {
            $ADRepObj | Add-Member -NotePropertyName 'NTDS' -NotePropertyValue $svcName.Status
            $Global:GAPRiskReport += New-GAPRiskReportLog `
                -ProblemName "DCDiag" `
                -ResourceName "NTDS Service" `
                -ProblemState "NTDS service is not running on $($DC.Name)" `
                -CorrectState "NTDS service is should be running." `
                -Solution "Please investigate." `
                -Impact "High" `
                -Risk "High" `
                -AssignedTo "IG" `
                -Notes "" `
                -Status "Reported"
        }
        $LogLine = "Completed NTDS service check for $($DC.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        #### Check DNS Service State ####
        $LogLine = "Starting DNS service check for $($DC.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $svcName = Get-Service -ComputerName $DC.Name -Name "DNS" -ErrorAction SilentlyContinue
        if ($svcName.Status -like "Running") {
            $ADRepObj | Add-Member -NotePropertyName 'DNS' -NotePropertyValue $svcName.Status
        }
        else {
            $ADRepObj | Add-Member -NotePropertyName 'DNS' -NotePropertyValue $svcName.Status
            $Global:GAPRiskReport += New-GAPRiskReportLog `
                -ProblemName "DCDiag" `
                -ResourceName "DNS Service" `
                -ProblemState "DNS service is not running on $($DC.Name)" `
                -CorrectState "DNS service is should be running." `
                -Solution "Please investigate." `
                -Impact "High" `
                -Risk "High" `
                -AssignedTo "IG" `
                -Notes "" `
                -Status "Reported"
        }
        $LogLine = "Completed DNS service check for $($DC.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        ### DCDiag /s Tests ###
        $LogLine = "Starting DCDiag tests for $($DC.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        try {
            $LogLine = "Beginning DCDiag"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
            $dcdiagresults = Invoke-DcDiag $DC
            $LogLine = "DCDiag ran successfully"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        }
        catch {
            Write-Host $_.Exception.Message
            $LogLine = "Failed to execute Invoke-DcDiag " + " $_"
            $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        }
        if ($dcdiagresults.TestResult -notcontains "failed") {
            $dcdiagoutcome = "Passed"
            $ADRepObj | Add-Member -NotePropertyName 'DCDiag' -NotePropertyValue $dcdiagoutcome
        }
        else {
            $dcdiagoutcome = "Failed"
            $ADRepObj | Add-Member -NotePropertyName 'DCDiag' -NotePropertyValue $dcdiagoutcome
            $Global:InternalOnlyImportantReport += New-ImportantThing -Name "DCDiag Failure" -Details "DCDiag failed a test. Investigate."
        }
        $LogLine = "Completed DCDiag tests for $($DC.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        #NIC settings
        $LogLine = "Getting NIC DNS information for $($DC.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $NICs = Get-DnsClient
        foreach ($adapter in $NICs) {
            $DCNIC = Get-DnsClientServerAddress -AddressFamily IPv4 -CimSession $DC.Name | Where-Object {$_.InterfaceAlias -clike "Ethernet*"}
            $ADRepObj | Add-Member -NotePropertyName "DNSServers" -NotePropertyValue "$($DCNIC.ServerAddresses -join ' , ')" -Force
        }
        $LogLine = "Retrieved NIC information for $($DC.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[4] -Details $LogLine
        $ADHealthSummaryReport += $ADRepObj
    }
    else {
        Write-Host $DC.Name `t $DC.Name `t Ping Failed -ForegroundColor Red
        $ADRepObj | Add-Member -NotePropertyName 'Ping' -NotePropertyValue "Failed" -Force
            $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Connectivity" `
            -ResourceName "$($DC.Name)" `
            -ProblemState "Pinged test failed for server $($DC.Name)" `
            -CorrectState "Most domain controllers should be reachable, unless ICMP is disabled by policy." `
            -Solution "Resolve connectivity issue." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "If ICMP is disabled per policy, please ignore this error." `
            -Status "Reported" 
        $ADHealthSummaryReport += $ADRepObj
    }
}
Write-Host "Finished domain controller health checks" -ForegroundColor Green
#AD Trust Info
Write-Host "...Getting AD trust info..." -ForegroundColor White
try {
    $LogLine = "Getting AD trust information"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[5] -Details $LogLine 
    $ADTrusts = Get-ADTrust -Filter *
    $LogLine = "Retreived AD trust information"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[5] -Details $LogLine
    $ADTrusts | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ADTrustReport.xml")"
    if ($null -ne $ADTrusts) {
        foreach ($ADTrust in $ADTrusts) {
            $ADTrustObj = New-Object "PSCustomObject"
            $ADTrustObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $ADTrust.Name
            $ADTrustObj | Add-Member -NotePropertyName 'Source' -NotePropertyValue $ADTrust.Source
            $ADTrustObj | Add-Member -NotePropertyName 'Target' -NotePropertyValue $ADTrust.Target
            $ADTrustObj | Add-Member -NotePropertyName 'Direction' -NotePropertyValue $ADTrust.Direction
            $ADTrustObj | Add-Member -NotePropertyName 'SelectiveAuth' -NotePropertyValue $ADTrust.SelectiveAuthentication
            $ADTrustObj | Add-Member -NotePropertyName 'ForestTransitive' -NotePropertyValue $ADTrust.ForestTransitive
            $ADTrustReport += $ADTrustObj
            $Global:InternalOnlyImportantReport += New-ImportantThing -Name "ADDS Trust/s Found" -Details "ADDS Trust/s exist. Please evaluate the impact."
        }
    } 
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADTrust " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[5] -Details $LogLine
}
#AD Check for ADSync Group
Write-Host "...Checking AD sync configuration..." -ForegroundColor White
try {
    $LogLine = "Checking AD sync configuration"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[1] -Step $Steps[6] -Details $LogLine 
    $ADSyncGroupCheck = Get-ADGroup -Filter * | Where-Object { $_.Name -eq "ADSyncAdmins" }
    $LogLine = "Retrieved AD sync configuration"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[1] -Step $Steps[6] -Details $LogLine
    if ($ADSyncGroupCheck) {
        $Global:InternalOnlyImportantReport += New-ImportantThing -Name "AD Sync Group Found" -Details "This means that Azure AD Connector or DirSync is installed or may have been in the past. Please verify and evaluate the impact."
    }
    
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ADGroup for AD sync check " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[1] -Step $Steps[6] -Details $LogLine
}
Write-Host "Finished AD assessment" -ForegroundColor Green

Write-Host "Beginning Exchange Server assessment..." -ForegroundColor Yellow
$LogLine = "Beginning to gather Exchange servers configuration information"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine
Write-Host "...Getting Exchange servers..." -ForegroundColor White
try {
    $LogLine = "Getting Exchange servers"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine
    $ExServers = Get-ExchangeServer
    $ExServers | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ExchangeServers.xml")"
    $LogLine = "Retrieved Exchange servers"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine  
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ExchangeServer " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine
}  
foreach ($ExServer in $ExServers) {
    $ExRepObj = New-Object "PSCustomObject"
    $ExRepObj | Add-Member -NotePropertyName 'Exchange Server Name' -NotePropertyValue $ExServer.Name
    #Exchange ping test
    Write-Host "...Pinging Exchange server " -ForegroundColor White -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor White
    $LogLine = "Starting Exchange servers connectivity test for $($ExServer.Name)"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine
    if ( Test-Connection -ComputerName $ExServer.Name -Count 1 -ErrorAction SilentlyContinue ) {
        $PingSuccess += $ExServer.Name
        Write-Host "...Ping " -ForegroundColor White -NoNewline; Write-Host "successful " -ForegroundColor Green -NoNewline; Write-Host "for " -ForegroundColor White -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor White
        Write-Host "...Getting server configuration for " -ForegroundColor White -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor White
        $LogLIne = "Completed Exchange servers connectivity test for $($ExServer.Name) successfully"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[7] -Details $LogLine
        $ExRepObj | Add-Member -NotePropertyName 'Ping' -NotePropertyValue "Success"
        $ExNetworkInfo = Test-Connection -ComputerName $ExServer.Name -Count 1
        $ExRepObj | Add-Member -NotePropertyName 'IP Address' -NotePropertyValue $ExNetworkInfo.Address
        $ExRepObj | Add-Member -NotePropertyName 'Role' -NotePropertyValue $ExServer.ServerRole
        $ExRepObj | Add-Member -NotePropertyName 'Edition' -NotePropertyValue $ExServer.Edition
        $ExRepObj | Add-Member -NotePropertyName 'Build Version' -NotePropertyValue $ExServer.AdminDisplayVersion
        $ExRepObj | Add-Member -NotePropertyName 'Site' -NotePropertyValue $ExServer.Site
        #$ExOSVersion = Get-WmiObject Win32_OperatingSystem -ComputerName $ExServer.Name | Select-Object Caption
        $ExOSVersion = Invoke-Command -ComputerName $ExServer.Name -ScriptBlock {
            Get-ComputerInfo | Select-Object OsName
        }
        $ExRepObj | Add-Member -NotePropertyName 'OS Name' -NotePropertyValue $ExOSVersion.OsName
        #CAS Check
        $LogLine = "Beginning CAS role check for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
        if ($ExServer.IsClientAccessServer -eq $true) {
            $ExCasServers += $ExServer.Name
            $LogLine = "Finished CAS server check for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #CAS server info
            $LogLine = "Getting CAS server information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExCASServiceInfo = Get-ClientAccessService -Identity $ExServer.Name
            $LogLine = "Retrieved CAS server information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExCASServiceInfo | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ClientAccessService_" + $($ExServer.Name) + ".xml")"  
            #ECP info
            $LogLine = "Getting ECP information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExECPUrls = Get-EcpVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved ECP information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #EWS info
            $LogLine = "Getting EWS information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExEWSUrls = Get-WebServicesVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved EWS information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #MAPI info
            $LogLine = "Getting MAPI information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExMAPIUrls = Get-MapiVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved MAPI information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #ActiveSync info
            $LogLine = "Getting ActiveSync information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExASyncUrls = Get-ActiveSyncVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved ActiveSync information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #OAB info
            $LogLine = "Getting Offline Address Book information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExOABUrls = Get-OabVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved Offline Address Book information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #OWA info
            $LogLine = "Getting OWA information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExOWAUrls = Get-OwaVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved OWA information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #PowerShell VD info
            $LogLine = "Getting PowerShell information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExPSUrls = Get-PowerShellVirtualDirectory -Server $ExServer.Name
            $LogLine = "Retrieved PowerShell information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            #OutlookAnywhere info
            $LogLine = "Getting Outlook Anywhere information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExOAUrls = Get-OutlookAnywhere -Server $ExServer.Name
            $LogLine = "Retrieved Outlook Anywhere information for $($ExServer.Name)"
            $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[8] -Details $LogLine
            $ExRepObj | Add-Member -NotePropertyName 'Client Access Server' -NotePropertyValue "Yes"
            $ExRepObj | Add-Member -NotePropertyName 'Autodiscover InternalURL' -NotePropertyValue $ExCASServiceInfo.AutoDiscoverServiceInternalUri.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'ECP InternalURL' -NotePropertyValue $ExECPUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'ECP ExternalURL' -NotePropertyValue $ExECPUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'EWS InternalURL' -NotePropertyValue $ExEWSUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'EWS ExternalURL' -NotePropertyValue $ExEWSUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'MAPI InternalURL' -NotePropertyValue $ExMAPIUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'MAPI ExternalURL' -NotePropertyValue $ExMAPIUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'ActiveSync InternalURL' -NotePropertyValue $ExASyncUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'ActiveSync ExternalURL' -NotePropertyValue $ExASyncUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'OAB InternalURL' -NotePropertyValue $ExOABUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'OAB ExternalURL' -NotePropertyValue $ExOABUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'OWA InternalURL' -NotePropertyValue $ExOWAUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'OWA ExternalURL' -NotePropertyValue $ExOWAUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'PS InternalURL' -NotePropertyValue $ExPSUrls.InternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'PS ExternalURL' -NotePropertyValue $ExPSUrls.ExternalUrl.AbsoluteUri
            $ExRepObj | Add-Member -NotePropertyName 'OA InternalURL' -NotePropertyValue $ExOAUrls.InternalHostname
            $ExRepObj | Add-Member -NotePropertyName 'OA ExternalURL' -NotePropertyValue $ExOAUrls.ExternalHostname    
        }
        else {
            $ExRepObj | Add-Member -NotePropertyName 'Client Access Server' -NotePropertyValue "No"
        }
        #Receive Connectors ####
        $LogLine = "Getting Receive Connectors information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $ReceiveConnectors = Get-ReceiveConnector
        $LogLine = "Retrieved Receive Connectors information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #Send Connectors
        $LogLine = "Getting Send Connectors information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $SendConnectors = Get-SendConnector
        $LogLine = "Retrieved Send Connectors information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #TransportRules
        $LogLine = "Getting transport rules information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $TransportRules = Get-TransportRule
        $LogLine = "Retrieved transport rules information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #Journal rules
        $LogLine = "Getting journal rules information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $JournalRules = Get-JournalRule
        $LogLine = "Retrieved journal rules information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #DLP Poliicies
        $LogLine = "Getting DLP policy information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $DLPPolicies = Get-DlpPolicy
        $LogLine = "Retrieved DLP policy information for $($ExServer.Name)"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #Certificates ####
        Write-Host "...Getting Exchange Server certificates information..." -ForegroundColor White
        $LogLine = "Getting Exchange certificate info"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        $ExchangeCertificates = Get-ExchangeCertificate -Server $ExServer.Name
        $LogLine = "Retrieved Exchange certificate info"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[9] -Details $LogLine
        #Exporting XMLs
        $ReceiveConnectors | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ReceiveConnectors_" + $($ExServer.Name) + ".xml")" 
        $SendConnectors | Export-Clixml -Path "$($XMLFolderPath + "\"  + "SendConnectors_" + $($ExServer.Name) + ".xml")"
        $SendConnectors | Export-Clixml -Path "$($XMLFolderPath + "\"  + "TransportRules_" + $($ExServer.Name) + ".xml")"
        $JournalRules | Export-Clixml -Path "$($XMLFolderPath + "\"  + "JournalRules_" + $($ExServer.Name) + ".xml")"
        $DLPPolicies | Export-Clixml -Path "$($XMLFolderPath + "\"  + "DLPPolicy_" + $($ExServer.Name) + ".xml")"
        $ExchangeCertificates | Export-Clixml -Path "$($XMLFolderPath + "\"  + "Certificates_" + $($ExServer.Name) + ".xml")"
        foreach ($ReceiveConnector in $ReceiveConnectors) {
            $ExRecConnRepObj = New-Object "PSCustomObject"
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Exchange Connector Name' -NotePropertyValue $ReceiveConnector.Identity -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $ReceiveConnector.Enabled -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Bindings' -NotePropertyValue ($ReceiveConnector.Bindings -join " , ") -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Proxy Enabled' -NotePropertyValue $ReceiveConnector.ProxyEnabled -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'FQDN' -NotePropertyValue $ReceiveConnector.Fqdn -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Transport Role' -NotePropertyValue $ReceiveConnector.TransportRole -Force
            $ExRecConnRepObj | Add-Member -NotePropertyName 'Auth' -NotePropertyValue $ReceiveConnector.AuthMechanism -Force
            $ExServerRecConnectorsReport += $ExRecConnRepObj
        }
        foreach ($SendConnector in $SendConnectors) {
            $ExSendConnRepObj = New-Object "PSCustomObject"
            $ExSendConnRepObj | Add-Member -NotePropertyName 'Exchange Send Connector Name' -NotePropertyValue $SendConnector.Name -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $SendConnector.Enabled -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'DNS Routing' -NotePropertyValue $SendConnector.DNSRoutingEnabled -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'FQDN' -NotePropertyValue $SendConnector.Fqdn -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'Port' -NotePropertyValue $SendConnector.Port -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'SourceIP' -NotePropertyValue $SendConnector.SourceIPAddress -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'SmartHosts' -NotePropertyValue $SendConnector.SmartHosts -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'SmartHostsAuth' -NotePropertyValue $SendConnector.SmartHostAuthMechanism -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'SmartHostsAuth' -NotePropertyValue $SendConnector.SmartHostAuthMechanism -Force
            $ExSendConnRepObj | Add-Member -NotePropertyName 'TLSRequired' -NotePropertyValue $SendConnector.RequireTLS -Force
            $ExServerSendConnectorsReport += $ExSendConnRepObj
        }
        foreach ($TransportRule in $TransportRules) {
            $ExRulesRepObj = New-Object "PSCustomObject"
            $ExRulesRepObj | Add-Member -NotePropertyName 'Rule Name' -NotePropertyValue $TransportRule.Identity -Force
            $ExRulesRepObj | Add-Member -NotePropertyName 'Rule Description' -NotePropertyValue $TransportRule.Description -Force
            $ExRulesRepObj | Add-Member -NotePropertyName 'Rule Priority' -NotePropertyValue $TransportRule.Priority -Force
            $ExRulesRepObj | Add-Member -NotePropertyName 'Rule State' -NotePropertyValue $TransportRule.State -Force
            $ExServerRulesReport += $ExRulesRepObj
        }
        foreach ($JournalRule in $JournalRules) {
            $ExJRulesRepObj = New-Object "PSCustomObject"
            $ExJRulesRepObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $JournalRule.Name -Force
            $ExJRulesRepObj | Add-Member -NotePropertyName 'Recipient' -NotePropertyValue $JournalRule.Recipient -Force
            $ExJRulesRepObj | Add-Member -NotePropertyName 'Recipient Address' -NotePropertyValue $JournalRule.JournalEmailAddress -Force
            $ExJRulesRepObj | Add-Member -NotePropertyName 'Scope' -NotePropertyValue $JournalRule.Scope -Force
            $ExJRulesRepObj | Add-Member -NotePropertyName 'Rule Enabled' -NotePropertyValue $JournalRule.Enabled -Force
            $ExServerJournalRulesReport += $ExJRulesRepObj
        }
        foreach ($DLPPolicy in $DLPPolicies) {
            $ExJDLPPolRepObj = New-Object "PSCustomObject"
            $ExJDLPPolRepObj | Add-Member -NotePropertyName 'Policy Name' -NotePropertyValue $DLPPolicy.Name -Force
            $ExJDLPPolRepObj | Add-Member -NotePropertyName 'Publisher Name' -NotePropertyValue $DLPPolicy.PublisherName -Force
            $ExJDLPPolRepObj | Add-Member -NotePropertyName 'Rule Recipient Address' -NotePropertyValue $DLPPolicy.Mode -Force
            $ExJDLPPolRepObj | Add-Member -NotePropertyName 'Rule Scope' -NotePropertyValue $DLPPolicy.State -Force
            $ExServerDLPPoliciesReport += $ExJDLPPolRepObj
        }
        $DLPCustomPolicyTemplate = $null
        $DLPCustomPolicyTemplate = Get-DlpPolicyTemplate | Where-Object { $_.Publisher -ne "Microsoft" }
        if ($null -ne $DLPCustomPolicyTemplate) {
            $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Non-Microsoft DLP Template" -Details "Potential Custom DLP Policy Template found. Investigate"
        }
        foreach ($ExchangeCertificate in $ExchangeCertificates) {
            $ExCertsObj = New-Object "PSCustomObject"
            $ExCertsObj | Add-Member -NotePropertyName 'Subject' -NotePropertyValue $ExchangeCertificate.Subject -Force
            $ExCertsObj | Add-Member -NotePropertyName 'DnsNameList' -NotePropertyValue ($ExchangeCertificate.DnsNameList -join " , ") -Force
            $ExCertsObj | Add-Member -NotePropertyName 'EnhancedKeyUsage' -NotePropertyValue $ExchangeCertificate.EnhancedKeyUsageList -Force
            $ExCertsObj | Add-Member -NotePropertyName 'Expiration' -NotePropertyValue $ExchangeCertificate.NotAfter -Force
            $ExCertsObj | Add-Member -NotePropertyName 'Issuer' -NotePropertyValue $ExchangeCertificate.Issuer -Force
            $ExCertsObj | Add-Member -NotePropertyName 'Thumbprint' -NotePropertyValue $ExchangeCertificate.Thumbprint -Force
            $ExCertsObj | Add-Member -NotePropertyName 'Thumbprint' -NotePropertyValue $ExServer.Name -Force
            $ExchangeCertificatesReport += $ExCertsObj
        }
        Write-Host "Finished getting configuraton for " -ForegroundColor Green -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor Green
    }
    else {
        Write-Host "Ping failed for Exchange server " -ForegroundColor Red -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor Red
        $ExRepObj | Add-Member -NotePropertyName 'Ping' -NotePropertyValue "Failed" `
            $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Connectivity" `
            -ResourceName "$($ExServer.Name)" `
            -ProblemState "Pinged test failed for server $($ExServer.Name)" `
            -CorrectState "All servers should be reachable, unless ICMP is disabled by policy." `
            -Solution "Resolve connectivity issue." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "If ICMP is disabled per policy, please ignore this error." `
            -Status "Reported" 
    }
    $ExServerInfoReport += $ExRepObj
}

#Database Info ####
Write-Host "...Getting database information for Exchange server " -ForegroundColor White -NoNewline; Write-Host "$($ExServer.Name)" -ForegroundColor Cyan -NoNewline; Write-Host "..." -ForegroundColor White
foreach ($Success in $PingSuccess) {
    $LogLine = "Getting Exchange database information"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[10] -Details $LogLine
    $mailboxDatabases = Get-MailboxDatabase -Status
    $LogLine = "Retreived Exchange database information"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[10] -Details $LogLine
    $mailboxDatabases | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ExchangeDatabases.xml")" 
    foreach ($mailboxDatabase in $mailboxDatabases) {
        $ExDBObj = New-Object "PSCustomObject"
        $ExDBObj | Add-Member -NotePropertyName 'ServerName' -NotePropertyValue $mailboxDatabase.Server -Force
        $ExDBObj | Add-Member -NotePropertyName 'DBName' -NotePropertyValue $mailboxDatabase.Name -Force
        $ExDBObj | Add-Member -NotePropertyName 'DBSize' -NotePropertyValue $mailboxDatabase.DatabaseSize -Force
        $ExDBObj | Add-Member -NotePropertyName 'AvailableNewMBSize' -NotePropertyValue $mailboxDatabase.AvailableNewMailboxSpace -Force
        $ExDBObj | Add-Member -NotePropertyName 'IsPublicFolderDatabase' -NotePropertyValue $mailboxDatabase.IsPublicFolderDatabase -Force
        $ExDBObj | Add-Member -NotePropertyName 'IndexEnabled' -NotePropertyValue $mailboxDatabase.IndexEnabled -Force
        $ExDBObj | Add-Member -NotePropertyName 'CircularLoggingEnabled' -NotePropertyValue $mailboxDatabase.CircularLoggingEnabled -Force
        $ExDBObj | Add-Member -NotePropertyName 'ProhibitSRQuota' -NotePropertyValue $mailboxDatabase.ProhibitSendReceiveQuota -Force
        $ExDBObj | Add-Member -NotePropertyName 'ProhibitSQuota' -NotePropertyValue $mailboxDatabase.ProhibitSendQuota -Force
        $ExDBObj | Add-Member -NotePropertyName 'RecoverableItemsQuota' -NotePropertyValue $mailboxDatabase.RecoverableItemsQuota -Force
        $ExDBObj | Add-Member -NotePropertyName 'RecoverableItemsWarn' -NotePropertyValue $mailboxDatabase.RecoverableItemsWarningQuota -Force
        $ExDBObj | Add-Member -NotePropertyName 'MBXRetention' -NotePropertyValue $mailboxDatabase.MailboxRetention -Force
        $ExDBObj | Add-Member -NotePropertyName 'DeletedItemsRetention' -NotePropertyValue $mailboxDatabase.DeletedItemRetention -Force
        $ExDatabaseInfoReport += $ExDBObj
    }
}
Write-Host "Finished getting database information" -ForegroundColor Green

Write-Host "Beginning Exchange feature configurations assessment..." -ForegroundColor Yellow
#Address Lists ####
Write-Host "...Getting Address Lists information..." -ForegroundColor White
try {
    $LogLine = "Getting Address List info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $LogLine = "Current Address Lists array is + $($defaultAddressLists)"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $AddressLists = Get-AddressList
    $LogLine = "Retreived Address List info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details "Gathered Address List Info successfully"
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-AddressList " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$AddressLists | Export-Clixml -Path "$($XMLFolderPath + "\"  + "AddressLists.xml")"
foreach ($AddressList in $AddressLists) {
    $ExALObj = New-Object "PSCustomObject"
    $ExALObj | Add-Member -NotePropertyName 'Identity' -NotePropertyValue $AddressList.Identity -Force
    $ExALObj | Add-Member -NotePropertyName 'DisplayName' -NotePropertyValue $AddressList.DisplayName -Force
    $ExALObj | Add-Member -NotePropertyName 'RecipientFilter' -NotePropertyValue $AddressList.RecipientFilter -Force
    $ExALObj | Add-Member -NotePropertyName 'LdapRecipientFilter' -NotePropertyValue $AddressList.LdapRecipientFilter -Force
    $ExALObj | Add-Member -NotePropertyName 'RecipientFilterApplied' -NotePropertyValue $AddressList.RecipientFilterApplied -Force
    $ExALObj | Add-Member -NotePropertyName 'OriginatingServer' -NotePropertyValue $AddressList.OriginatingServer -Force
    $ExServerAddressListsReport += $ExALObj
    if ($AddressList.DisplayName -notin $defaultAddressLists) {
        $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Custom Address List" -Details "Potential Custom Address List found. Investigate"
    }
}
#Org Relationship ####
Write-Host "...Getting Organizational Relationship information..." -ForegroundColor White
try {
    $LogLine = "Getting Org Relationship info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $OrgRelationships = Get-OrganizationRelationship
    $LogLine = "Retreived Org Relationship info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-OrganizationRelationship " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$OrgRelationships | Export-Clixml -Path "$($XMLFolderPath + "\"  + "OrgRelationships.xml")"
foreach ($OrgRelationship in $OrgRelationships) {
    $ExOrgObj = New-Object "PSCustomObject"
    $ExOrgObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $OrgRelationship.Name -Force
    $ExOrgObj | Add-Member -NotePropertyName 'Domain Names' -NotePropertyValue $OrgRelationship.DomainNames -Force
    $ExOrgObj | Add-Member -NotePropertyName 'Free Busy Enabled' -NotePropertyValue $OrgRelationship.FreeBusyAccessEnabled -Force
    $ExOrgObj | Add-Member -NotePropertyName 'FreeBusy Access Lvl' -NotePropertyValue $OrgRelationship.FreeBusyAccessLevel -Force
    $ExOrgObj | Add-Member -NotePropertyName 'FreeBusy Access Scope' -NotePropertyValue $OrgRelationship.FreeBusyAccessScope -Force
    $ExOrgObj | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $OrgRelationship.Enabled -Force
    $ExServerOrgRelationshipReport += $ExOrgObj
}
#Anti-malware file types ####
Write-Host "...Getting anti-malware file types..." -ForegroundColor White
try {
    $LogLine = "Getting anti-malware file type info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $LogLine = "Default anti-malware file types are $($defaultAntiMalwareFileTypes)"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $MalwarePolicies = Get-MalwareFilterPolicy
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-MalwareFilterPolicy " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
#Anti-malware policies ####
Write-Host "...Getting anti-malware policies..." -ForegroundColor White
try {
    $LogLine = "Getting anti-malware policy info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $MalwarePolicies = Get-MalwareFilterPolicy
    $LogLine = "Retrieved anti-malware policy info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine 
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-MalwareFilterPolicy " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$MalwarePolicies | Export-Clixml -Path "$($XMLFolderPath + "\"  + "MalwareFilterPolicies.xml")"
foreach ($MalwarePolicie in $MalwarePolicies) {
    $ExMalwareObj = New-Object "PSCustomObject"
    $ExMalwareObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $MalwarePolicies.Identity -Force
    $ExMalwareObj | Add-Member -NotePropertyName 'Default Policy' -NotePropertyValue $MalwarePolicies.IsDefault -Force
    $ExMalwareObj | Add-Member -NotePropertyName 'Action' -NotePropertyValue $MalwarePolicies.Action -Force
    $filetypesreport = @()
    foreach ($filetype in $MalwarePolicies.FileTypes) {
        if ($filetype -notin $defaultAntiMalwareFileTypes) {
            $filetypesreport += $filetype
            $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Anti-Malware" -Details "Non-default Anti-malware file type included in policy. Investigate"
        }
    }
    $ExMalwareObj | Add-Member -NotePropertyName 'File Types' -NotePropertyValue $filetypesreport -Force
    $ExMalwareObj | Add-Member -NotePropertyName 'FreeBusy Access Scope' -NotePropertyValue $OrgRelationship.FreeBusyAccessScope -Force
    $ExMalwareObj | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $OrgRelationship.Enabled -Force
    $ExAntiMalwareReport += $ExMalwareObj
}
#Accepted Domains ####
Write-Host "...Getting accepted domains information..." -ForegroundColor White
try {
    $LogLine = "Getting accepted domains info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $AcceptedDomains = Get-AcceptedDomain
    $LogLine = "Retrieve accepted domain info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-AcceptedDomain " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$AcceptedDomains | Export-Clixml -Path "$($XMLFolderPath + "\"  + "AcceptedDomains.xml")"
foreach ($AcceptedDomain in $AcceptedDomains) {
    $ExDomainsObj = New-Object "PSCustomObject"
    $ExDomainsObj | Add-Member -NotePropertyName 'Domain Name' -NotePropertyValue $AcceptedDomain.DomainName -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'Domain Type' -NotePropertyValue $AcceptedDomain.DomainType -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'Address Book Enabled' -NotePropertyValue $AcceptedDomain.AddressBookEnabled -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'CoexistenceDomain' -NotePropertyValue $AcceptedDomain.IsCoexistenceDomain -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'Default Federated Domain' -NotePropertyValue $AcceptedDomain.IsDefaultFederatedDomain -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'Initial Domain' -NotePropertyValue $AcceptedDomain.InitialDomain -Force
    $ExDomainsObj | Add-Member -NotePropertyName 'Server' -NotePropertyValue $AcceptedDomain.OriginatingServer -Force
    $ExServerAcceptedDomainsReport += $ExDomainsObj
}
#Email Address Policies ####
Write-Host "...Getting email address policies information..." -ForegroundColor White
try {
    $LogLine = "Get email address policy info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $EmailAddressPolicies = Get-EmailAddressPolicy
    $LogLine = "Retrieved email address policy info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-EmailAddressPolicy " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$EmailAddressPolicies | Export-Clixml -Path "$($XMLFolderPath + "\"  + "EmailAddressPolicies.xml")"
foreach ($EmailAddressPolicy in $EmailAddressPolicies) {
    $ExEmailAddPolicyObj = New-Object "PSCustomObject"
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Policy Name' -NotePropertyValue $EmailAddressPolicy.Name -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Priority' -NotePropertyValue $EmailAddressPolicy.Priority -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Included Recipients' -NotePropertyValue $EmailAddressPolicy.IncludedRecipients -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Has Email Address Setting' -NotePropertyValue $EmailAddressPolicy.HasEmailAddressSetting -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Recipient Filter Type' -NotePropertyValue $EmailAddressPolicy.RecipientFilterType -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'EnabledPrimarySMTPAddressTemplate' -NotePropertyValue $EmailAddressPolicy.EnabledPrimarySMTPAddressTemplate -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'EnabledEmailAddressTemplates' -NotePropertyValue $EmailAddressPolicy.EnabledEmailAddressTemplates -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Recipient Filter' -NotePropertyValue $EmailAddressPolicy.RecipientFilter -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Ldap Recipient Filter' -NotePropertyValue $EmailAddressPolicy.LdapRecipientFilter -Force
    $ExEmailAddPolicyObj | Add-Member -NotePropertyName 'Recipient Filter Applied' -NotePropertyValue $EmailAddressPolicy.RecipientFilterApplied -Force
    $ExEmailAddressPoliciesReport += $ExEmailAddPolicyObj
}
#Retention Tags ####
Write-Host "...Getting retention tags information..." -ForegroundColor White
try {
    $LogLine = "Get retention tag info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $MailRetentionTagInformation = Get-RetentionPolicyTag
    $LogLine = "Retrieved retention tag info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-RetentionPolicyTag " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$MailRetentionTagInformation | Export-Clixml -Path "$($XMLFolderPath + "\"  + "MailRetentionPolicyTags.xml")"
#Retention Policies ####
Write-Host "...Getting retention policies information..." -ForegroundColor White
try {
    $LogLine = "Get retention policy info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $MailRetentionPolicyInformation = Get-RetentionPolicy
    $LogLine = "Retrieved retention policy info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-RetentionPolicy " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$MailRetentionTagInformation | Export-Clixml -Path "$($XMLFolderPath + "\"  + "MailRetentionPolicy.xml")"
foreach ($MailRetentionTag in $MailRetentionTagInformation) {
    $ExMailRetentionTagObj = New-Object "PSCustomObject"
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'TagName' -NotePropertyValue $MailRetentionTag.Name -Force
    if ($MailRetentionTag.Name -notin $includedRetentionTags) {
        $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Retention Tags" -Details "Non-included Retention Tag name found. Investigate"
    }
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Enabled' -NotePropertyValue $MailRetentionTag.RetentionEnabled -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Type' -NotePropertyValue $MailRetentionTag.Type -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Action' -NotePropertyValue $MailRetentionTag.RetentionAction -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'After' -NotePropertyValue $MailRetentionTag.AgeLimitForRetention -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Apply To' -NotePropertyValue $MailRetentionTag.MessageClassDisplayName -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Destination Folder' -NotePropertyValue $MailRetentionTag.MoveToDestinationFolder -Force
    $ExMailRetentionTagObj | Add-Member -NotePropertyName 'Trigger When' -NotePropertyValue $MailRetentionTag.TriggerForRetention -Force
    $ExMailRetentionTagsReport += $ExMailRetentionTagObj
}
foreach ($MailRetentionPolicy in $MailRetentionPolicyInformation) {
    $ExMailRetentionObj = New-Object "PSCustomObject"
    $ExMailRetentionObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $MailRetentionPolicy.Name -Force
    if ($MailRetentionPolicy.Name -notin $includedRetentionPolicies) {
        $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Retention Policies" -Details "Non-included Retention Policy name found. Investigate"
    }
    $ExMailRetentionObj | Add-Member -NotePropertyName 'Tag Links' -NotePropertyValue ($MailRetentionPolicy.RetentionPolicyTagLinks -join " , ") -Force
    $ExMailRetentionObj | Add-Member -NotePropertyName 'Default' -NotePropertyValue $MailRetentionPolicy.IsDefault -Force
    $ExMailRetentionPoliciesReport += $ExMailRetentionObj
}
#Active Sync device info####
Write-Host "...Getting active sync device information..." -ForegroundColor White
try {
    $LogLine = "Getting Active Sync device info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $ActiveSyncDeviceAccessRules = Get-ActiveSyncDeviceAccessRule
    $LogLine = "Retrieved Active Sync device info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-ActiveSyncDeviceAccessRule" + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$ActiveSyncDeviceAccessRules | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ActiveSyncDeviceAccessRules.xml")"
foreach ($ActiveSyncDeviceAccessRule in $ActiveSyncDeviceAccessRules) {
    $ExActSyncAccRuleObj = New-Object "PSCustomObject"
    $ExActSyncAccRuleObj | Add-Member -NotePropertyName 'Rule Name' -NotePropertyValue $ActiveSyncDeviceAccessRule.Name -Force
    $ExActSyncAccRuleObj | Add-Member -NotePropertyName 'Query String' -NotePropertyValue $ActiveSyncDeviceAccessRule.QueryString -Force
    $ExActSyncAccRuleObj | Add-Member -NotePropertyName 'Characteristic' -NotePropertyValue $ActiveSyncDeviceAccessRule.Characteristic -Force
    $ExActSyncAccRuleObj | Add-Member -NotePropertyName 'Access Level' -NotePropertyValue $ActiveSyncDeviceAccessRule.AccessLevel -Force
    $ActiveSyncDeviceAccessRulesReport += $ExActSyncAccRuleObj
}
#Active Sync mailbox info####
Write-Host "...Getting active sync mailbox information..." -ForegroundColor White
try {
    $LogLine = "Getting Active Sync mailbox info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
    $ActiveSyncMailboxPolicies = Get-MobileDeviceMailboxPolicy
    $LogLine = "Retrieved Active Sync mailbox info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-MobileDeviceMailboxPolicy" + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[11] -Details $LogLine
}
$ActiveSyncMailboxPolicies | Export-Clixml -Path "$($XMLFolderPath + "\"  + "ActiveSyncMailboxPolicies.xml")"
foreach ($ActiveSyncMailboxPolicy in $ActiveSyncMailboxPolicies) {
    $ExActSyncMbxPolObj = New-Object "PSCustomObject"
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $ActiveSyncMailboxPolicy.Name -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'IsDefault' -NotePropertyValue $ActiveSyncMailboxPolicy.IsDefault -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'PasswordEnabled' -NotePropertyValue $ActiveSyncMailboxPolicy.PasswordEnabled -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'SimplePassAllowed' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowSimplePassword -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AlphaNumPassReq' -NotePropertyValue $ActiveSyncMailboxPolicy.AlphanumericPasswordRequired -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MinComplexChar' -NotePropertyValue $ActiveSyncMailboxPolicy.MinPasswordComplexCharacters -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MinPassLength' -NotePropertyValue $ActiveSyncMailboxPolicy.MinPasswordLength -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'PassExpiration' -NotePropertyValue $ActiveSyncMailboxPolicy.PasswordExpiration -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'PassHistory' -NotePropertyValue $ActiveSyncMailboxPolicy.PasswordHistory -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MaxFailedAttempts' -NotePropertyValue $ActiveSyncMailboxPolicy.MaxPasswordFailedAttempts -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MaxInactiveLock' -NotePropertyValue $ActiveSyncMailboxPolicy.MaxInactivityTimeLock -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'PassRecoveryEnabled' -NotePropertyValue $ActiveSyncMailboxPolicy.PasswordRecoveryEnabled -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'EncyptionEnabled' -NotePropertyValue $ActiveSyncMailboxPolicy.DeviceEncryptionEnabled -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'PolicyRefreshInt' -NotePropertyValue $ActiveSyncMailboxPolicy.DevicePolicyRefreshInterval -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MaxAttach' -NotePropertyValue $ActiveSyncMailboxPolicy.MaxAttachmentSize -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowApplePush' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowApplePushNotifications -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'EncryptionReq' -NotePropertyValue $ActiveSyncMailboxPolicy.RequireDeviceEncryption -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowWiFi' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowWiFi -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowTxt' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowTextMessaging -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowPOPIMAP' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowPOPIMAPEmail -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowBrowser' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowBrowser -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowConsumerEmail' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowConsumerEmail -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllRDP' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowRemoteDesktop -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowInternetSharing' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowInternetSharing -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowBTooth' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowBluetooth -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MaxCalendarAgeFilter' -NotePropertyValue $ActiveSyncMailboxPolicy.MaxCalendarAgeFilter -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'MaxEmailAgeFilter' -NotePropertyValue $ActiveSyncMailboxPolicy.MaxEmailAgeFilter -Force
    $ExActSyncMbxPolObj | Add-Member -NotePropertyName 'AllowOTA' -NotePropertyValue $ActiveSyncMailboxPolicy.AllowMobileOTAUpdate -Force
    $ActiveSyncMailboxPoliciesReport += $ExActSyncMbxPolObj
}

Write-Host "...Checking for hybrid configuration..." -ForegroundColor White
try {
    $LogLine = "Checking for Hybrid Config"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
    $ExHybridCheck = Get-HybridConfiguration
    $LogLine = "Retrieved Hybrid Config info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-HybridConfiguration" + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
}
try {
    $LogLine = "Getting ACL sync info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
    $ExHybridACL = Get-OrganizationConfig | Select-Object ACLableSyncedObjectEnabled
    $LogLine = "Retreived ACL sync info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-OrganizationConfig" + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[2] -Step $Steps[12] -Details $LogLine
}
if ($null -ne $ExHybridCheck) {
    foreach ($ExHybrid in $ExHybridCheck) {
        $ExHybridCheck | Export-Clixml -Path "$($XMLFolderPath + "\"  + "HybridConfig.xml")"
        $HybExObj = New-Object "PSCustomObject"
        $HybExObj | Add-Member -NotePropertyName 'HybridDomains' -NotePropertyValue ($ExHybrid.Domains -join ',')
        $HybExObj | Add-Member -NotePropertyName 'ReceivingServers' -NotePropertyValue ($ExHybrid.ReceivingTransportServers -join ',')
        $HybExObj | Add-Member -NotePropertyName 'SendingServers' -NotePropertyValue ($ExHybrid.SendingTransportServers -join ',')
        $HybExObj | Add-Member -NotePropertyName 'Features' -NotePropertyValue ($ExHybrid.Features -join ',')
        $HybExObj | Add-Member -NotePropertyName 'Identity' -NotePropertyValue $ExHybrid.Identity
        $HybExObj | Add-Member -NotePropertyName 'Server' -NotePropertyValue $ExHybrid.OriginatingServer
        if ($ExHybridACL.ACLableSyncedObjectEnabled -eq "True") {
            $HybExObj | Add-Member -NotePropertyName 'ACLSyncEnalbed' -NotePropertyValue 'TRUE'
        }
        else {
            $HybExObj | Add-Member -NotePropertyName 'ACLSyncEnalbed' -NotePropertyValue 'FALSE'
            $Global:InternalOnlyImportantReport += New-ImportantThing -Name "ACLable Object Sync not enabled" -Details "Consult the table: https://learn.microsoft.com/en-us/exchange/hybrid-deployment/set-up-delegated-mailbox-permissions for when to enable ACLable object syncrhonization."
        }
        $HybExObj | Add-Member -NotePropertyName 'DN' -NotePropertyValue $ExHybrid.DistinguishedName
        $HybExObj | Add-Member -NotePropertyName 'WhenCreated' -NotePropertyValue $ExHybrid.WhenCreated
        $ExHybridCheckReport += $HybExObj
        $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Hybrid Config" -Details "Hybrid Config Found. Investigate"
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Exchange Hybrid" `
            -ResourceName "On-premises Exchange" `
            -ProblemState "Hybrid Exchange configuration found." `
            -CorrectState "No Hybrid Exchange configuration expected." `
            -Solution "Additional discussion and or assessment required." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "If existing Hybrid configuration is expected, please ignore." `
            -Status "Reported"
    }
}
else {
    Write-Host "No Hybrid Config Detected"
}
Write-Host "Finished getting Exchange feature configurations" -ForegroundColor Green
#end#region -- Exchange Server Feature Info ####

#region -- Mailbox Info
if ($all) {
    try {
        Write-Host "Getting mailbox information..." -ForegroundColor Yellow -NoNewline; Write-Host "All " -ForegroundColor Cyan -NoNewline; Write-Host "switch specified" -ForegroundColor Yellow
        $LogLine = "All switch specificed, getting all mailbox info"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -IgnoreDefaultScope
        $LogLine = "Retrieved all mailbox info"
        $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
    }
    catch {
        Write-Host $_.Exception.Message
        $LogLine = "Failed to execute Get-Mailbox with All switch" + " $_"
        $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
    }
}
if ($file) {
    try {
        Write-Host "Getting mailbox information..." -ForegroundColor Yellow -NoNewline; Write-Host "File " -ForegroundColor Cyan -NoNewline; Write-Host "switch specified" -ForegroundColor Yellow
        $LogLine = "File switch specificed, getting mailbox info based off input file"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
        $CustomerInput = Import-Csv $File
        $LogLine = "Retrieved input file mailbox info"
        $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
    }
    catch {
        Write-Host $_.Exception.Message
        $LogLine = "Failed to execute Import-Csv $($File) " + " $_"
        $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[13] -Details $LogLine
    }
    $CustomerInputArray = @()
    foreach ($item in $CustomerInput) {
        $CustomerInputObj = New-Object PSObject
        $CustomerInputObj | Add-Member NoteProperty -Name samAccountName -Value $item.samAccountName 
        $CustomerInputObj | Add-Member NoteProperty -Name UserPrincipalName -Value $item.UserPrincipalName
        $CustomerInputObj | Add-Member NoteProperty -Name PrimarySMTPAddress -Value $item.PrimarySMTPAddress
        $CustomerInputObj | Add-Member NoteProperty -Name Type -Value $item.Type
        $CustomerInputObj | Add-Member NoteProperty -Name License -Value $item.License 
        $CustomerInputArray += $CustomerInputObj
    }
    $Mailboxes = $CustomerInputArray
}
$MailboxCount = $Mailboxes.count
$i = 0
$MailboxDatabases = @(Get-MailboxDatabase)
foreach ($Mailbox in $Mailboxes) {
    $i = $i + 1
    $pct = $i / $MailboxCount * 100
    $MailboxStats = Get-Mailbox -Identity $Mailbox.samAccountName
    Write-Progress -Activity "Collecting mailbox details" -Status "Processing mailbox $i of $MailboxCount - $Mailbox" -PercentComplete $pct
    $Stats = $Mailbox.samAccountName | Get-MailboxStatistics | Select-Object @{label = "Total Item Size (GB)"; expression = { [math]::Round(($_.TotalItemSize.value.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }, @{label = "Total Deleted Item Size (GB)"; expression = { [math]::Round(($_.TotalDeletedItemSize.value.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 4) } }, ItemCount, LastLogonTime, LastLoggedOnUserAccount
    $InboxStats = Get-MailboxFolderStatistics $MailboxStats.Alias -FolderScope Inbox | Where-Object { $_.FolderPath -eq "/Inbox" } | Select-Object @{label = "Inbox Folder and SubFolder Size (GB)"; expression = { [math]::Round(($_.FolderAndSubfolderSize.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }, ItemsInFolder
    $SentItemStats = Get-MailboxFolderStatistics $MailboxStats.Alias -FolderScope SentItems | Where-Object { $_.FolderPath -eq "/Sent Items" } | Select-Object @{label = "Sent Items Folder and SubFolder Size (GB)"; expression = { [math]::Round(($_.FolderAndSubfolderSize.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }
    $DeletedItemStats = Get-MailboxFolderStatistics $MailboxStats.Alias -FolderScope DeletedItems | Where-Object { $_.FolderPath -eq "/Deleted Items" } | Select-Object @{label = "Deleted Items Folder and SubFolder Size (GB)"; expression = { [math]::Round(($_.FolderAndSubfolderSize.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }
    $LastLogon = $Stats.LastLogonTime
    $User = Get-User $MailboxStats.Alias
    $ADUser = Get-ADUser $MailboxStats.samaccountname -Properties Enabled, AccountExpirationDate
    $PrimaryDB = $MailboxDatabases | Where-Object { $_.Name -eq $MailboxStats.Database }
    $ArchiveDB = $MailboxDatabases | Where-Object { $_.Name -eq $MailboxStats.ArchiveDatabase }
    if ($MailboxStats.ArchiveDatabase) {
        $ArchiveStats = $MailboxStats.Alias | Get-MailboxStatistics -Archive | Select-Object @{label = "Archive Total Item Size (GB)"; expression = { [math]::Round(($_.TotalItemSize.value.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }, @{label = "Archive Total Deleted Item Size (GB)"; expression = { [math]::Round(($_.TotalDeletedItemSize.value.ToString().Split("(")[1].Split(" ")[0].Replace(",", "") / 1024MB), 2) } }, ItemCount
    }
    else {
        $ArchiveStats = "n/a"
    }
    $mbxUserObj = New-Object PSObject
    $mbxUserObj | Add-Member NoteProperty -Name "DisplayName" -Value $MailboxStats.DisplayName
    $mbxUserObj | Add-Member NoteProperty -Name "Primary Email Address" -Value $MailboxStats.PrimarySMTPAddress
    $mbxUserObj | Add-Member NoteProperty -Name "Mailbox Type" -Value $MailboxStats.RecipientTypeDetails
    $mbxUserObj | Add-Member NoteProperty -Name "Title" -Value $User.Title
    $mbxUserObj | Add-Member NoteProperty -Name "Department" -Value $User.Department
    $mbxUserObj | Add-Member NoteProperty -Name "Office" -Value $User.Office
    $mbxUserObj | Add-Member NoteProperty -Name "Total Mailbox Size (GB)" -Value ($Stats.'Total Item Size (GB)' + $Stats.'Total Deleted Item Size (GB)')
    if (($MailboxStats.RecipientTypeDetails -eq "UserMailbox" -and $Stats.'Total Item Size (GB)' -ge $MaxPrimaryMBXSizeForMigration)) {
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Mailbox Size" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Primary Mailbox is beyond recommended size limit for successful migration." `
            -CorrectState "$($MailboxStats.SamAccountName) Primary Mailbox should be less than $($MaxPrimaryMBXSizeForMigration)." `
            -Solution "Work with the user to reduce the mailbox size before attempting migration to Exchange Online." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Complete"
    }
    elseif ($MailboxStats.RecipientTypeDetails -eq "Shared Mailbox" -and $Stats.'Total Item Size (GB)' -ge $MaxSharedPrimaryMBXSizeForMigration) {
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName " Shared Mailbox Size" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Shared Primary Mailbox is beyond recommended size limit for successful migration." `
            -CorrectState "$($MailboxStats.SamAccountName) Shared Primary Mailbox should be less than $($MaxSharedPrimaryMBXSizeForMigration)." `
            -Solution "Work with the users to reduce the mailbox size before attempting migration to Exchange Online." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Complete"
    }
    <#Licensing/Size logic
    if(($Mailbox.License -eq "M365 E3" -and $MailboxStats.RecipientTypeDetails -eq "UserMailbox" -and $Stats.'Total Item Size (GB)' -ge $MaxPrimaryMBXSizeForMigration)){
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Mailbox Size" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Primary Mailbox is beyond recommended size limit for successful migration." `
            -CorrectState "$($MailboxStats.SamAccountName) Primary Mailbox should be less than $($MaxPrimaryMBXSizeForMigration)." `
            -Solution "Work with the user to reduce the mailbox size before attempting migration to Exchange Online." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Complete"
    }elseif ($Mailbox.License -eq "None" -and $MailboxStats.RecipientTypeDetails -eq "Shared Mailbox" -and $Stats.'Total Item Size (GB)' -ge $MaxSharedPrimaryMBXSizeForMigration) {
        $Global:GAPRiskReport += New-GAPRiskReportLog `
        -ProblemName " Shared Mailbox Size" `
        -ResourceName $MailboxStats.PrimarySMTPAddress `
        -ProblemState "$($MailboxStats.SamAccountName) Shared Primary Mailbox is beyond recommended size limit for successful migration." `
        -CorrectState "$($MailboxStats.SamAccountName) Shared Primary Mailbox should be less than $($MaxSharedPrimaryMBXSizeForMigration)." `
        -Solution "Work with the users to reduce the mailbox size before attempting migration to Exchange Online." `
        -Impact "High" `
        -Risk "High" `
        -AssignedTo "IG" `
        -Notes "None" `
        -Status "Complete"
    }
    #>
    $mbxUserObj | Add-Member NoteProperty -Name "Mailbox Size (GB)" -Value $Stats.'Total Item Size (GB)'
    $mbxUserObj | Add-Member NoteProperty -Name "Mailbox Recoverable Item Size (GB)" -Value $Stats.'Total Item Size (GB)'
    $mbxUserObj | Add-Member NoteProperty -Name "Mailbox Items" -Value $Stats.ItemCount
    $mbxUserObj | Add-Member NoteProperty -Name "Inbox Folder Size (GB)" -Value $InboxStats.'Inbox Folder and SubFolder Size (GB)'
    $mbxUserObj | Add-Member NoteProperty -Name "Sent Items Folder Size (GB)" -Value $SentItemStats.'Sent Items Folder and SubFolder Size (GB)'
    $mbxUserObj | Add-Member NoteProperty -Name "Deleted Items Folder Size (GB)" -Value $DeletedItemStats.'Deleted Items Folder and SubFolder Size (GB)'
    if ($ArchiveStats -eq "n/a") {
        $mbxUserObj | Add-Member NoteProperty -Name "Total Archive Size (GB)" -Value "n/a"
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Size (GB)" -Value "n/a"
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Deleted Item Size (GB)" -Value "n/a"
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Items" -Value "n/a"
    }
    else {
        $mbxUserObj | Add-Member NoteProperty -Name "Total Archive Size (GB)" -Value ($ArchiveStats.'Archive Total Item Size (GB)' + $ArchiveStats.'Archive Total Deleted Item Size (GB)')
        if ($MailboxStats.RecipientTypeDetails -eq "UserMailbox" -and $ArchiveStats.'Archive Total Item Size (GB)' -ge $MaxArchiveMBXSizeForMigration) {
            $Global:GAPRiskReport += New-GAPRiskReportLog `
                -ProblemName "Archive Mailbox Size" `
                -ResourceName $MailboxStats.PrimarySMTPAddress `
                -ProblemState "$($MailboxStats.SamAccountName) Archive Mailbox is beyond recommended size limit for successful migration." `
                -CorrectState "$($MailboxStats.SamAccountName) Archive Mailbox should be less than $($MaxArchiveMBXSizeForMigration)." `
                -Solution "Work with the user to reduce the mailbox size before attempting migration to Exchange Online." `
                -Impact "High" `
                -Risk "High" `
                -AssignedTo "IG" `
                -Notes "None" `
                -Status "Reported"
        }
        elseif ($MailboxStats.RecipientTypeDetails -eq "Shared Mailbox" -and $ArchiveStats.'Archive Total Item Size (GB)' -ge $MaxSharedArchiveBXSizeForMigration) {
            $Global:GAPRiskReport += New-GAPRiskReportLog `
                -ProblemName "Shared Archive Mailbox Size" `
                -ResourceName $MailboxStats.PrimarySMTPAddress `
                -ProblemState "$($MailboxStats.SamAccountName) Shared Archive Mailbox is beyond recommended size limit for successful migration." `
                -CorrectState "$($MailboxStats.SamAccountName) Shared Archive Mailbox should be less than $($MaxArchiveMBXSizeForMigration)." `
                -Solution "Work with the users to reduce the mailbox size before attempting migration to Exchange Online." `
                -Impact "High" `
                -Risk "High" `
                -AssignedTo "IG" `
                -Notes "Shared Mailboxes with Archives require an Exchange license in M365." `
                -Status "Reported"
        }
        <#License/Size Logic
        if($Mailbox.License -eq "M365 E3" -and $MailboxStats.RecipientTypeDetails -eq "UserMailbox" -and $ArchiveStats.'Archive Total Item Size (GB)' -ge $MaxArchiveMBXSizeForMigration){
            $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Archive Mailbox Size" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Archive Mailbox is beyond recommended size limit for successful migration." `
            -CorrectState "$($MailboxStats.SamAccountName) Archive Mailbox should be less than $($MaxArchiveMBXSizeForMigration)." `
            -Solution "Work with the user to reduce the mailbox size before attempting migration to Exchange Online." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Complete"
        }elseif ($Mailbox.License -eq "None" -and $MailboxStats.RecipientTypeDetails -eq "Shared Mailbox" -and $ArchiveStats.'Archive Total Item Size (GB)' -ge $MaxSharedArchiveBXSizeForMigration) {
            $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Shared Archive Mailbox Size" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Shared Archive Mailbox is beyond recommended size limit for successful migration." `
            -CorrectState "$($MailboxStats.SamAccountName) Shared Archive Mailbox should be less than $($MaxArchiveMBXSizeForMigration)." `
            -Solution "Work with the users to reduce the mailbox size before attempting migration to Exchange Online." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Complete"
        }#>
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Size (GB)" -Value $ArchiveStats.'Archive Total Item Size (GB)'
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Deleted Item Size (GB)" -Value $ArchiveStats.'Archive Total Deleted Item Size (GB)'
        $mbxUserObj | Add-Member NoteProperty -Name "Archive Items" -Value $ArchiveStats.ItemCount
    }
    $mbxUserObj | Add-Member NoteProperty -Name "Audit Enabled" -Value $MailboxStats.AuditEnabled
    $mbxUserObj | Add-Member NoteProperty -Name "Email Address Policy Enabled" -Value $MailboxStats.EmailAddressPolicyEnabled
    $mbxUserObj | Add-Member NoteProperty -Name "Hidden From Address Lists" -Value $MailboxStats.HiddenFromAddressListsEnabled
    $mbxUserObj | Add-Member NoteProperty -Name "Use Database Quota Defaults" -Value $MailboxStats.UseDatabaseQuotaDefaults
    if ($MailboxStats.UseDatabaseQuotaDefaults -eq $true) {
        $mbxUserObj | Add-Member NoteProperty -Name "Issue Warning Quota" -Value $PrimaryDB.IssueWarningQuota
        $mbxUserObj | Add-Member NoteProperty -Name "Prohibit Send Quota" -Value $PrimaryDB.ProhibitSendQuota
        $mbxUserObj | Add-Member NoteProperty -Name "Prohibit Send Receive Quota" -Value $PrimaryDB.ProhibitSendReceiveQuota
    }
    elseif ($MailboxStats.UseDatabaseQuotaDefaults -eq $false) {
        $mbxUserObj | Add-Member NoteProperty -Name "Issue Warning Quota" -Value $MailboxStats.IssueWarningQuota
        $mbxUserObj | Add-Member NoteProperty -Name "Prohibit Send Quota" -Value $MailboxStats.ProhibitSendQuota
        $mbxUserObj | Add-Member NoteProperty -Name "Prohibit Send Receive Quota" -Value $MailboxStats.ProhibitSendReceiveQuota
    }
    $mbxUserObj | Add-Member NoteProperty -Name "Account Enabled" -Value $aduser.Enabled
    $mbxUserObj | Add-Member NoteProperty -Name "Account Expires" -Value $aduser.AccountExpirationDate
    $mbxUserObj | Add-Member NoteProperty -Name "Last Mailbox Logon" -Value $LastLogon
    if ($null -ne $LastLogon) {
        $StartDate = (Get-Date)
        $EndDate = $LastLogon
        $lastlogonInDays = New-TimeSpan -Start $EndDate -End $StartDate
        $mbxUserObj | Add-Member NoteProperty -Name "Last Mailbox Logon Days Ago" -Value $lastlogonInDays.Days
    }
    elseif ($null -eq $LastLogon) {
        $mbxUserObj | Add-Member NoteProperty -Name "Last Mailbox Logon Days Ago" -Value 'n/a'
    }
    $mbxUserObj | Add-Member NoteProperty -Name "Last Logon By" -Value $Stats.LastLoggedOnUserAccount
    $mbxUserObj | Add-Member NoteProperty -Name "Primary Mailbox Database" -Value $MailboxStats.Database
    $mbxUserObj | Add-Member NoteProperty -Name "Retention Policy" -Value $MailboxStats.RetentionPolicy
    $mbxUserObj | Add-Member NoteProperty -Name "Forwarding Enabled" -Value $MailboxStats.ForwardingAddress
    if ($null -eq $MailboxStats.ForwardingAddress) {
        $mbxUserObj | Add-Member NoteProperty -Name "Forward and Copy" -Value "n/a" -Force
    }
    elseif ($null -ne $MailboxStats.ForwardingAddress) {
        $mbxUserObj | Add-Member NoteProperty -Name "Forward and Copy" -Value $MailboxStats.DeliverToMailboxAndForward
    }
    $mbxUserObj | Add-Member NoteProperty -Name "External Forwarding Enabled" -Value $MailboxStats.ForwardingSmtpAddress -Force #Warn
    if ($null -eq $MailboxStats.ForwardingSmtpAddress) {
        $mbxUserObj | Add-Member NoteProperty -Name "Forward and Copy" -Value "n/a" -Force
    }
    elseif ($null -ne $Mailbox.ForwardingSmtpAddress) {
        $mbxUserObj | Add-Member NoteProperty -Name "Forward and Copy" -Value $MailboxStats.DeliverToMailboxAndForward -Force #Warn
    }
    $mbxUserObj | Add-Member NoteProperty -Name "Litigation Hold" -Value $MailboxStats.LitigationHoldEnabled #Warn
    $mbxUserObj | Add-Member NoteProperty -Name "Retention Hold" -Value $MailboxStats.RetentionHoldEnabled #Warn
    $mbxUserObj | Add-Member NoteProperty -Name "Address Book Policy" -Value $MailboxStats.AddressBookPolicy #Warn
    $mbxUserObj | Add-Member NoteProperty -Name "Unified Mailbox" -Value $MailboxStats.UnifiedMailbox 
    if ($MailboxStats.UnifiedMailbox) {
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Unified Messaging" `
            -ResourceName $MailboxStats.PrimarySMTPAddress `
            -ProblemState "$($MailboxStats.SamAccountName) Has Unified Messaging components associated with the mailbox." `
            -CorrectState "$($MailboxStats.SamAccountName) UM migrations are out of scope" `
            -Solution "UM migration is out of scope, please remove feature associations, or understand that these will no longer work post-migration." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Reported"
    }
    $mbxUserObj | Add-Member NoteProperty -Name "InPlaceHolds" -Value $MailboxStats.InPlaceHolds 
    $mbxUserObj | Add-Member NoteProperty -Name "Primary Server/DAG" -Value $PrimaryDB.MasterServerOrAvailabilityGroup
    $mbxUserObj | Add-Member NoteProperty -Name "Archive Mailbox Database" -Value $MailboxStats.ArchiveDatabase
    $mbxUserObj | Add-Member NoteProperty -Name "Archive Server/DAG" -Value $ArchiveDB.MasterServerOrAvailabilityGroup
    $mbxUserObj | Add-Member NoteProperty -Name "Organizational Unit" -Value $User.OrganizationalUnit
    $mbxUserObj | Add-Member NoteProperty -Name "License" -Value $MailboxStats.License
    $MailboxStatisticsReport += $mbxUserObj
}
Write-Host "Finished getting mailbox information" -ForegroundColor Green
#endregion -- Mailbox Info

#region Group Info
#distribution groups
Write-Host "...Getting distribution group information..." -ForegroundColor White
try {
    $LogLine = "Getting DG info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[14] -Details "Getting DG Info"
    $DistributionGroups = Get-DistributionGroup -ResultSize Unlimited
    $LogLine = "Received DG info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[3] -Step $Steps[14] -Details "Retrieved DG Info successfully"
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-DistributionGroup " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[14] -Details $LogLine
}
$DistributionGroups | Export-Clixml -Path "$($XMLFolderPath + "\"  + "DistributionGroups.xml")"
foreach ($DistributionGroup in $DistributionGroups) {
    $DGsObj = New-Object "PSCustomObject"
    $DGsObj | Add-Member NoteProperty -Name "DisplayName" -Value $DistributionGroup.DisplayName
    $DGsObj | Add-Member NoteProperty -Name "PrimarySmtpAddress" -Value $DistributionGroup.PrimarySmtpAddress
    $SecondarySmtpAddress = $DistributionGroup.EmailAddresses | Where-Object { $_.DistributionGroup.EmailAddresses -clike "*" } | ForEach-Object { $_.DistributionGroup.EmailAddresses -replace "smtp:", "" }
    $DGsObj | Add-Member NoteProperty -Name "SecondaryEmailAddresses" -Value ($SecondarySmtpAddress -join ',')
    $DGsObj | Add-Member NoteProperty -Name "GroupType" -Value $DistributionGroup.GroupType
    $DGsObj | Add-Member NoteProperty -Name "RecipientType" -Value $DistributionGroup.RecipientType
    $GroupMembers = Get-DistributionGroupMember $DistributionGroup.DistinguishedName -ResultSize Unlimited
    $DGsObj | Add-Member NoteProperty -Name "GroupMembers" -Value ($GroupMembers.Name -join ',')
    $DGsObj | Add-Member NoteProperty -Name "GroupMembersPrimarySmtpAddress" -Value ($GroupMembers.PrimarySmtpAddress -join ',')
    $NestedDG = $null
    foreach ($GroupMember in $GroupMembers) {
        if($NestedDG = $GroupMember | Where-Object { $_.RecipientType -like "*Group*" }){
            $NestedDG = $true
        }
    }
    if ($NestedDG -eq $true) {
        $DGsObj | Add-Member NoteProperty -Name "NestedDG" -Value 'TRUE' -Force
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Nested DGs" `
            -ResourceName "$($DistributionGroup.DisplayName)" `
            -ProblemState "$($DistributionGroup.DisplayName) contains nested distribution groups. Azure AD Connect does not support nested distribution groups." `
            -CorrectState "$($DistributionGroup.DisplayName) should not contain nested distribution groups." `
            -Solution "If distribution groups are to be migrated, a solution needs to be determined for proper group membership." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Reported"
    }
    else {
        $DGsObj | Add-Member NoteProperty -Name "NestedDG" -Value 'FALSE' -Force
    }
    $DGsObj | Add-Member NoteProperty -Name "ManagedBy" -Value ($DistributionGroup.ManagedBy -join ',')
    $DGsObj | Add-Member NoteProperty -Name "Alias" -Value $DistributionGroup.Alias
    $DGsObj | Add-Member NoteProperty -Name "HiddenfromGAL" -Value $DistributionGroup.HiddenFromAddressListsEnabled
    $DGsObj | Add-Member NoteProperty -Name "JoinRestriction" -Value $DistributionGroup.MemberJoinRestriction
    $DGsObj | Add-Member NoteProperty -Name "LeaveRestriction" -Value $DistributionGroup.MemberDepartRestriction
    $DGsObj | Add-Member NoteProperty -Name "SenderAuthRequired" -Value $DistributionGroup.RequireSenderAuthenticationEnabled
    $DGsObj | Add-Member NoteProperty -Name "AcceptFromOnly" -Value $DistributionGroup.AcceptMessagesOnlyFrom
    $DGsObj | Add-Member NoteProperty -Name "GrantSendOnBehalfTo" -Value $DistributionGroup.GrantSendOnBehalfTo
    $DGsObj | Add-Member NoteProperty -Name "DistinguishedName" -Value $DistributionGroup.DistinguishedName
    $DistributionGroupReport += $DGsObj
}
#Dynamic Distribution Group Script
Write-Host "...Getting dynamic distribution group information..." -ForegroundColor White
try {
    $LogLine = "Getting Dynamic DG info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[14] -Details "Getting Dynamic DG Info"
    $DynamicDistributionGroups = Get-DynamicDistributionGroup -ResultSize Unlimited
    $LogLine = "Retrieved Dynamic DG info"
    $Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[3] -Step $Steps[14] -Details "Retrieved Dynamic DG Info successfully"
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-DynamicDistributionGroup " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[14] -Details $LogLine
}
$DynamicDistributionGroups | Export-Clixml -Path "$($XMLFolderPath + "\"  + "DynamicDistributionGroups.xml")"
foreach ($DynamicDistributionGroup in $DynamicDistributionGroups) {
    $DynDGsObj = New-Object "PSCustomObject"
    $DynDGsObj | Add-Member NoteProperty -Name "DisplayName" -Value $DynamicDistributionGroup.DisplayName
    $DynDGsObj | Add-Member NoteProperty -Name "PrimarySmtpAddress" -Value $DynamicDistributionGroup.PrimarySmtpAddress
    $SecondarySmtpAddress = $DynamicDistributionGroup.EmailAddresses | Where-Object { $_.EmailAddresses -clike "smtp*" } | ForEach-Object { $_.EmailAddresses -replace "smtp:", "" }
    $DynDGsObj | Add-Member NoteProperty -Name "SecondaryEmailAddresses" -Value ($SecondarySmtpAddress -join ',')
    $DynDGsObj | Add-Member NoteProperty -Name "RecipientType" -Value $DynamicDistributionGroup.RecipientType
    $NestedDynDG = $null
    foreach ($GroupMember in $GroupMembers) {
        $NestedDynDG = $GroupMember | Where-Object { $_.RecipientType -like "*Group*" }
        $NestedDynDG = $true
    }
    if ($NestedDynDG -eq $true) {
        $DynDGsObj | Add-Member NoteProperty -Name "NestedDDG" -Value 'TRUE' -Force
        $Global:GAPRiskReport += New-GAPRiskReportLog `
            -ProblemName "Nested Dynamic DGs" `
            -ResourceName "$($DynamicDistributionGroup.Name)" `
            -ProblemState "$($DynamicDistributionGroup.Name) contains nested dynamic distribution groups. Azure AD Connect does not support nested distribution groups." `
            -CorrectState "$($DynamicDistributionGroup.Name) should not contain nested distribution groups." `
            -Solution "If dynamic distribution groups are to be migrated, a solution needs to be determined for proper group membership." `
            -Impact "High" `
            -Risk "High" `
            -AssignedTo "IG" `
            -Notes "None" `
            -Status "Reported"
    }
    else {
        $DynDGsObj | Add-Member NoteProperty -Name "NestedDG" -Value 'FALSE' -Force
    }
    $DynDGsObj | Add-Member NoteProperty -Name "ManagedBy" -Value ($DynamicDistributionGroup.ManagedBy -join ',')
    $DynDGsObj | Add-Member NoteProperty -Name "Alias" -Value $DynamicDistributionGroup.Alias
    $DynDGsObj | Add-Member NoteProperty -Name "HiddenfromGAL" -Value $DynamicDistributionGroup.HiddenFromAddressListsEnabled
    $DynDGsObj | Add-Member NoteProperty -Name "SenderAuthRequired" -Value $DynamicDistributionGroup.RequireSenderAuthenticationEnabled
    $DynDGsObj | Add-Member NoteProperty -Name "AcceptFromOnly" -Value $DynamicDistributionGroup.AcceptMessagesOnlyFromDLMembers
    $DynDGsObj | Add-Member NoteProperty -Name "GrantSendOnBehalfTo" -Value $DynamicDistributionGroup.GrantSendOnBehalfTo
    $DynDGsObj | Add-Member NoteProperty -Name "DistinguishedName" -Value $DynamicDistributionGroup.DistinguishedName
    $DynamicDistributionGroupReport += $DynDGsObj
}
Write-Host "Finished getting mail information" -ForegroundColor Green
#endregion Group Info

#region Public Folders info ####
Write-Host "...Getting Public Folders information..." -ForegroundColor White
try {
    $LogLine = "Getting Public Folder info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
    $PublicFolders = Get-PublicFolder -Recurse -ResultSize Unlimited
    $LogLine = "Retrieved Public Folder info"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to execute Get-PublicFolder" + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
}
$PublicFolders | Export-Clixml -Path "$($XMLFolderPath + "\"  + "PublicFolders.xml")"
if ($null -ne $PublicFolders) {
    foreach ($PublicFolder in $PublicFolders) {
        $PFStats = $PublicFolder | Get-PublicFolderStatistics
        $ExPublicFoldersObj = New-Object "PSCustomObject"
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Name' -NotePropertyValue $PublicFolder.Name -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'MailEnabled' -NotePropertyValue $PublicFolder.MailEnabled -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'ParentPath' -NotePropertyValue $PublicFolder.ParentPath -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Content MBX Name' -NotePropertyValue $PublicFolder.ContentMailboxName -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Folder Size' -NotePropertyValue $PublicFolder.FolderSize -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Item Count' -NotePropertyValue $PFStats.ItemCount -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Total Item Size' -NotePropertyValue $PFStats.TotalAssociatedItemSize -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Total Deleted Item Size' -NotePropertyValue $PFStats.TotalDeletedItemSize -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Total Item Size' -NotePropertyValue $PFStats.TotalItemSize -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Contact Count' -NotePropertyValue $PFStats.ContactCount-Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'MBX Owner ID' -NotePropertyValue $PublicFolder.MailboxOwnerId -Force
        $ExPublicFoldersObj | Add-Member -NotePropertyName 'Mail Recipient GUID' -NotePropertyValue $PublicFolder.MailRecipientGuid -Force
        $PublicFoldersReport += $ExPublicFoldersObj
        try {
            $LogLine = "Getting Public Folder permissions info"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
            $PublicFoldersClientPermissions = Get-PublicFolderClientPermission -Identity $PublicFolder.Identity
            $LogLine = "Retrieved Public Folder permissions info"
            $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
        }
        catch {
            Write-Host $_.Exception.Message
            $LogLine = "Failed to execute Get-PublicFolderClientPermission" + " $_"
            $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[15] -Details $LogLine
        }
        foreach ($PublicFoldersClientPermission in $PublicFoldersClientPermissions) {
            $PublicFolders | Export-Clixml -Path "$($XMLFolderPath + "\"  + "PublicFoldersClientPermissions_$($PublicFoldersClientPermission.FolderName).xml")"
            $ExPublicFolderClientPermsObj = New-Object "PSCustomObject"
            $ExPublicFolderClientPermsObj | Add-Member -NotePropertyName 'FolderName' -NotePropertyValue $PublicFoldersClientPermission.FolderName -Force
            $ExPublicFolderClientPermsObj | Add-Member -NotePropertyName 'User' -NotePropertyValue $PublicFoldersClientPermission.User -Force
            $ExPublicFolderClientPermsObj | Add-Member -NotePropertyName 'AccessRights' -NotePropertyValue $PublicFoldersClientPermission.AccessRights -Force
            $PublicFoldersClientPermissionsReport += $ExPublicFolderClientPermsObj
        }
    }
    $Global:GAPRiskReport += New-GAPRiskReportLog `
        -ProblemName "Public Folders Found" `
        -ResourceName "Public Folders" `
        -ProblemState "Public Folder migration is not in scope." `
        -CorrectState "" `
        -Solution "Check with project manager to determine if Public Folder migration is feasible." `
        -Impact "High" `
        -Risk "High" `
        -AssignedTo "IG" `
        -Notes "" `
        -Status "Reported"
}
#endregion Public Folders info ####

#region -- Tenant Availability Check
Write-Host "...Checking for tenant availability..." -ForegroundColor White
try {
    $LogLine = "Checking tenant availability"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[16] -Details $LogLine
    if ($MigratingDomains) {
        foreach ($MigratingDomain in $MigratingDomains) {
            $uri = "https://login.microsoftonline.com/$($MigratingDomain)/.well-known/openid-configuration"
            $rest = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $uri
            if ($rest.authorization_endpoint) {
                $result = $(($rest.authorization_endpoint | Select-String '\w{8}-\w{4}-\w{4}-\w{4}-\w{12}').Matches.Value)
                if ([guid]::Parse($result)) {
                    $Global:InternalOnlyImportantReport += New-ImportantThing -Name "Domain $($MigratingDomain) returned tenant id $($result.ToString())" -Details "Ask client if the domain has been added to an existing Azure AD tenant. If required, have client work with Microsoft to remove the domain from the current tenant."
                    $Global:GAPRiskReport += New-GAPRiskReportLog `
                        -ProblemName "FQDN Availability Check" `
                        -ResourceName "$($MigratingDomain)" `
                        -ProblemState "$($MigratingDomain) could already exist on a Azure AD tenant." `
                        -CorrectState "$($MigratingDomain) should not exist on any tenant." `
                        -Solution "Perform a manual check by attempting to Add (NOT VERIFY) the FQDN to the target tenant. If it exists in another tenant, contact Microsoft." `
                        -Impact "High" `
                        -Risk "High" `
                        -AssignedTo "IG" `
                        -Notes "A domain can only exist in 1 Azure AD tenant at a time." `
                        -Status "Reported"
                }
            }
        }
    }
    $LogLine = "Retrieved tenant availability"
    $Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[3] -Step $Steps[16] -Details $LogLine
}
catch {
    Write-Host $_.Exception.Message
    $LogLine = "Failed to check tenant availability " + " $_"
    $Global:LogArray += New-LogEntry -EventType "Error" -Stage $Stages[3] -Step $Steps[16] -Details $LogLine
}
Write-Host "Finished checking for tenant availability" -ForegroundColor Green
#endregion -- Tenant Availability Check

#region -- Find Delegates Script
$LogLine = "Starting delegates script, if selected"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[4] -Step $Steps[17] -Details $LogLine
Write-Host -ForegroundColor Yellow "Launching Find Delegates Script"
switch ($NoDelegates) {
    $true { Break }
    Default {
        if ($all) {
            & "$($DelegatesScriptDirectoryPath)\FindDelegates.ps1" -FullAccess -SendOnBehalfTo -SendAs
            If ($LASTEXITCODE -ne 1) {
                Write-Host -ForegroundColor Green "Delegate Script Ran Successfully"
            }
            else {
                Write-Host -ForegroundColor Red "Delegate Script Failed"
            } 
        }
        if ($file) {
            & "$($DelegatesScriptDirectoryPath)\FindDelegates.ps1" -FullAccess -SendOnBehalfTo -SendAs -InputMailboxesCSV $file
            If ($LASTEXITCODE -ne 1) {
                Write-Host -ForegroundColor Green "Delegate Script Ran Successfully"
            }
            else {
                Write-Host -ForegroundColor Red "Delegate Script Failed"
            }
        }
    }
}
$LogLine = "Finished delegates script, if selected"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[4] -Step $Steps[17] -Details $LogLine
#endregion -- Find Delegates Script

#region -- Reports Export
Write-Host "Assessment Finished" -ForegroundColor Green

#Report Paths 
Write-Host "Beginning Report Exports..." -ForegroundColor Yellow
$ADForestInfoReportPath = "$($CSVsFolderPath)\$($ADForestInfoReportName)"
$ADDomainInfoReportPath = "$($CSVsFolderPath)\$($ADDomainInfoReportName)"
$ADHealthSummaryReportPath = "$($CSVsFolderPath)\$($ADHealthSummaryReportName)"
$ADTrustReportPath = "$($CSVsFolderPath)\$($ADTrustReportName)"
$ExServerInfoReportPath = "$($CSVsFolderPath)\$($ExServerInfoReportName)"
$ExDatabaseInfoReportPath = "$($CSVsFolderPath)\$($ExDatabaseInfoReportName)"
$ExServerRecConnectorsReportPath = "$($CSVsFolderPath)\$($ExServerRecConnectorReportName)"
$ExServerSendConnectorsReportPath = "$($CSVsFolderPath)\$($ExServerSendConnectorReportName)"
$ExServerRulesReportPath = "$($CSVsFolderPath)\$($ExServerRulesReportName)"
$ExServerJournalRulesReportPath = "$($CSVsFolderPath)\$($ExServerJournalRulesReportName)"
$ExServerDLPPoliciesReportPath = "$($CSVsFolderPath)\$($ExServerDLPPoliciesReportName)"
$ExServerAddressListsReportPath = "$($CSVsFolderPath)\$($ExServerAddressListsReportName)"
$ExServerOrgRelationshipReportPath = "$($CSVsFolderPath)\$($ExServerOrgRelationshipReportName)"
$ExServerAcceptedDomainsReportPath = "$($CSVsFolderPath)\$($ExServerAcceptedDomainsReportName)"
$ExEmailAddressPoliciesReportPath = "$($CSVsFolderPath)\$($ExEmailAddressPoliciesReportName)"
$ExMailRetentionTagsReportPath = "$($CSVsFolderPath)\$($ExMailRetentionTagsReportName)"
$ExMailRetentionPoliciesReportPath = "$($CSVsFolderPath)\$($ExMailRetentionPoliciesReportName)"
$ActiveSyncDeviceAccessRulesReportPath = "$($CSVsFolderPath)\$($ActiveSyncDeviceAccessRulesReportName)"
$ActiveSyncMailboxPoliciesReportPath = "$($CSVsFolderPath)\$($ActiveSyncMailboxPoliciesReportName)"
$PublicFoldersReportPath = "$($CSVsFolderPath)\$($PublicFoldersReportName)"
$PublicFoldersClientPermissionsReportPath = "$($CSVsFolderPath)\$($PublicFoldersClientPermsReportName)"
$ExchangeCertificatesReportPath = "$($CSVsFolderPath)\$($ExchangeCertificatesReportName)"
$ExHybridCheckReportPath = "$($CSVsFolderPath)\$($ExHybridCheckReportName)"
$MailboxStatisticsReportPath = "$($CSVsFolderPath)\$($MailboxStatsReportName)"
$DistributionGroupReportPath = "$($CSVsFolderPath)\$($DistributionGroupReportsName)"
$DynamicDistributionGroupReportPath = "$($CSVsFolderPath)\$($DynamicDistributionGroupReportName)"
$InternalOnlyImportantReportPath = "$($CSVsFolderPath)\$($InternalOnlyImportantReportName)"
$Global:GAPRiskReportPath = "$($CSVsFolderPath)\$($GAPRiskReportName)"
$ScriptLog = "$($LogFilePath)\$($LogName)"

#Export CSV reports
#AD forest report
$LogLine = "Exporting AD forest report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ADForestInfoReport | Export-Csv $ADForestInfoReportPath -NoTypeInformation
$LogLine = "Success - Exporting AD forest report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#AD Domain report
$LogLine = "Exporting AD domain report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ADDomainInfoReport | Export-Csv $ADDomainInfoReportPath -NoTypeInformation
$LogLine = "Success - Exporting AD domain report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#AD health summary report
$LogLine = "Exporting AD health summary report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ADHealthSummaryReport | Export-Csv $ADHealthSummaryReportPath -NoTypeInformation
$LogLine = "Success - Exporting AD health summary report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#AD trust report
$LogLine = "Exporting AD trust report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ADTrustReport | Export-Csv $ADTrustReportPath -NoTypeInformation
$LogLine = "Success - Exporting AD trust report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server info report
$LogLine = "Exporting Exchange Server info report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerInfoReport | Export-Csv $ExServerInfoReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server info report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server database report
$LogLine = "Exporting Exchange Server database report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExDatabaseInfoReport | Export-Csv $ExDatabaseInfoReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server database report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server recieve connector report
$LogLine = "Exporting Exchange Server recieve connector report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerRecConnectorsReport | Export-Csv $ExServerRecConnectorsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server receive connector report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server send connector report
$LogLine = "Exporting Exchange Server send connector report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerSendConnectorsReport | Export-Csv $ExServerSendConnectorsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server send connector report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server rules report
$LogLine = "Exporting Exchange Server rules report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerRulesReport | Export-Csv $ExServerRulesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server rules report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server journal rules report
$LogLine = "Exporting Exchange Server journal rules report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerJournalRulesReport | Export-Csv $ExServerJournalRulesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server journal rules report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server DLP report
$LogLine = "Exporting Exchange Server DLP report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerDLPPoliciesReport | Export-Csv $ExServerDLPPoliciesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server DLP report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server address list report
$LogLine = "Exporting Exchange Server address list report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerAddressListsReport | Export-Csv $ExServerAddressListsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server address list report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server address list report
$LogLine = "Exporting Exchange Server address list report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerOrgRelationshipReport | Export-Csv $ExServerOrgRelationshipReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server address list report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server accepted domains report
$LogLine = "Exporting Exchange Server accepted domains report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExServerAcceptedDomainsReport | Export-Csv $ExServerAcceptedDomainsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server accepted domains report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server email address policies report
$LogLine = "Exporting Exchange Server email address policies report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExEmailAddressPoliciesReport | Export-Csv $ExEmailAddressPoliciesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server email address policies report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server email retention tags report
$LogLine = "Exporting Exchange Server email retention tags report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExMailRetentionTagsReport | Export-Csv $ExMailRetentionTagsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server email retention tags report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server email retention policies report"
$LogLine = "Exporting Exchange Server email retention policies report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExMailRetentionPoliciesReport | Export-Csv $ExMailRetentionPoliciesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server email retention policies report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server Active Sync device report
$LogLine = "Exporting Exchange Server Active Sync device report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ActiveSyncDeviceAccessRulesReport | Export-Csv $ActiveSyncDeviceAccessRulesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server Active Sync device report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server Active Sync mailbox report
$LogLine = "Exporting Exchange Server Active Sync mailbox report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ActiveSyncMailboxPoliciesReport | Export-Csv $ActiveSyncMailboxPoliciesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server Active Sync mailbox report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server Public Folders report
$LogLine = "Exporting Exchange Server Public Folders report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$PublicFoldersReport | Export-Csv $PublicFoldersReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server Public Folders report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server Public Folders permissions report
$LogLine = "Exporting Exchange Server Public Folders permissions report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$PublicFoldersClientPermissionsReport | Export-Csv $PublicFoldersClientPermissionsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server Public Folders permissions report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server certificates report
$LogLine = "Exporting Exchange Server certificates report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExchangeCertificatesReport | Export-Csv $ExchangeCertificatesReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server certificates report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server hybrid check report
$LogLine = "Exporting Exchange Server hybrid check report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$ExHybridCheckReport | Export-Csv $ExHybridCheckReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server hybrid check report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server hybrid check report
$LogLine = "Exporting Exchange Server hybrid check report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$MailboxStatisticsReport | Export-Csv $MailboxStatisticsReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server hybrid check report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server distribution group report
$LogLine = "Exporting Exchange Server distribution group report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$DistributionGroupReport | Export-Csv $DistributionGroupReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server distribution group report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Exchange Server dynamic distribution group report
$LogLine = "Exporting Exchange Server dynamic distribution group report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$DynamicDistributionGroupReport | Export-Csv $DynamicDistributionGroupReportPath -NoTypeInformation
$LogLine = "Success - Exporting Exchange Server dynamic distribution group report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#Internal Important report
$LogLine = "Exporting Internal Important report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$Global:InternalOnlyImportantReport | Export-Csv $InternalOnlyImportantReportPath -NoTypeInformation
$LogLine = "Success - Exporting Internal Important report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
#GAP Risk report
$LogLine = "Exporting GAP Risk report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
$Global:GAPRiskReport | Export-Csv $Global:GAPRiskReportPath -NoTypeInformation
$LogLine = "Success - Exporting GAP Risk report"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[18] -Details $LogLine
## - XLSX Reports
$LogLine = "Exporting XLSX reports"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[19] -Details $LogLine
$ADForestInfoReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ADExcelReportName)" -Append -WorksheetName ADForest
$ADDomainInfoReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ADExcelReportName)" -Append -WorksheetName ADDomain
$ADHealthSummaryReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ADExcelReportName)" -Append -WorksheetName ADHealth -ConditionalText $(
    New-ConditionalText -ConditionalType Equal Failed -BackgroundColor Red -ConditionalTextColor White
    New-ConditionalText -ConditionalType Equal Success -BackgroundColor Green -ConditionalTextColor White
    New-ConditionalText -ConditionalType Equal Running -BackgroundColor Green -ConditionalTextColor White)
$ADTrustReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ADExcelReportName)" -Append -WorksheetName ADTrust 
$ExServerInfoReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExServerInfo 
$ExDatabaseInfoReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExDBInfo
$ExServerRecConnectorsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExRecConn
$ExServerSendConnectorsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExSendConn
$ExServerRulesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExRules
$ExServerJournalRulesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExJournRules
$ExServerDLPPoliciesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExDLPPols
$ExServerAddressListsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExAddrList
$ExServerOrgRelationshipReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExOrgRel
$ExServerAcceptedDomainsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExAccDomains
$ExEmailAddressPoliciesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExAddrPols
$ExMailRetentionTagsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExRetTags
$ExMailRetentionPoliciesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExRetPols
$ActiveSyncDeviceAccessRulesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExASDevAccess
$ActiveSyncMailboxPoliciesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExASMbxPols
$PublicFoldersReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExPFs
$PublicFoldersClientPermissionsReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExPFsPerms
$ExchangeCertificatesReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName ExCerts
$ExHybridCheckReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExServerExcelReportName)" -Append -WorksheetName Hybrid
$DistributionGroupReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExMBXExcelReportName)" -Append -WorksheetName DGReport
$DynamicDistributionGroupReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExMBXExcelReportName)" -Append -WorksheetName DynDGReport
$Global:InternalOnlyImportantReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $ExImportantExcelReportName)" -Append -WorksheetName Important
$Global:GAPRiskReport | Export-Excel -Path "$($XLSXsFolderPath + "\" + $GAPRisksExcelReportName)" -Append -WorksheetName Important
$LogLine = "Finished exporting XLSX reports"
$Global:LogArray += New-LogEntry -EventType "Informational" -Stage $Stages[5] -Step $Steps[19] -Details $LogLine
#endregion -- Reports Export
Write-Host "Script Complete" -ForegroundColor Green
$LogLine = "Script Complete"
$Global:LogArray += New-LogEntry -EventType "Success" -Stage $Stages[5] -Step $Steps[19] -Details $LogLine
#Export Log
$Global:LogArray | Export-Csv $ScriptLog -NoTypeInformation