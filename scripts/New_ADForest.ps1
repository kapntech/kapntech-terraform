
Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools



$InstallADDSParams = @{
    CreateDnsDelegation           = $False
    DatabasePath                  = "C:\Windows\NTDS"
    DomainMode                    = "WinThreshold"
    DomainName                    = "server.local"
    DomainNetbiosName             = "server"
    SafeModeAdministratorPassword = (ConvertTo-SecureString -String Password -AsPlainText -Force)
    ForestMode                    = "WinThreshold"
    InstallDns                    = $True
    LogPath                       = "C:\Windows\NTDS"
    NoRebootOnCompletion          = $False
    SysvolPath                    = "C:\Windows\SYSVOL"
    Force                         = $True
}
Install-ADDSForest @InstallADDSParams

$DomainUser = "KAPNTECH\azadmin"
$DomainUserPassword = (ConvertTo-SecureString -String 'Radmin_1q2w_E$R' -AsPlainText -Force)
$DomainUserCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUser, $DomainUserPassword

$InstallDCParams = @{
    Credential          = $DomainUserCredential
    DomainName = "kapntech.com"
    NoGlobalCatalog = $False
    CreateDnsDelegation = $False
    Force = $True
}
Install-ADDSDomainController @InstallDCParams