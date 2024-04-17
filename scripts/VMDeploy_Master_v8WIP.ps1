<#
        .SYNOPSIS
            This script wil be used to provision following Azure Resources based on the input file:
                1. Virtual Network with multiple Address Space specified in the 'vNet' Sheet.
                2. Multiple Subnet with Address Space specified in the 'Subnet' Sheet. This Subnets will use the Virtual Networks created in the step 1.
                3. Network Security Groups will be created and assigned to their respective Subnets as specified in the sheet 'NSG'.
                4. Bastion will be created as specified in the sheet 'Bastion'. If Bastion subnet is not available, it will be created as well.
                5. Virtual machines will be created as specified in the sheet 'VM'

        .DESCRIPTION
            If you're not already logged in your Azure Subscription using PowerShell, please change $LoginRequired value to $true:
                Example:
                        $LoginRequired = $True

        .NOTES
            Following PowerShell Modules are required for the script to run successfully:
                1. Import-Excel:PowerShell module to import/export Excel spreadsheets, without Excel. Please run following command in PowerShell to install this module:
                        Install-Module -Name ImportExcel
                2. Install the Az PowerShell module
                        Install-Module -Name Az -AllowClobber

        .LINK
            Following are the links which you can refer to if you need more information about:
                1. https://www.powershellgallery.com/packages/ImportExcel/7.0.1
                2. https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-3.5.0
    #>

    Param
    (
        # Input file Path
    [Parameter()]
    [String] $InputFilePath,

    [Parameter()]
    [String] $LogFilePath,

    $Allinputs = @{}
    )

    #************  Fill in desired values.  ****************

    # Specify '$true' if you are not already logged into the Azure subscription :

    $LoginRequired = $false

    $Global:InputFilePath = 'C:\Users\jonat\OneDrive - Infogain India Private Limited\Projects\NAC\Script\NAC_VMDeployment_v1.1.xlsx'

    $Global:LogFilePath = 'C:\!repos\JKDev\PowerShell Library\VMDeploy\Master\log.txt'

    $DiskInitializeScriptPath = 'C:\!repos\JKDev\PowerShell Library\VMDeploy\Master\DiskInitialize.ps1'

    #*******************  Constants  ***********************

    #*************  Initializing Variables  ****************
    
    $Hash = @{}
    $Hash.VirtualNetwork = @{}
    $Hash.Bastion = @{}
    $Hash.VM = @{}
    $Hash.LB = @{}

    $Allinputs.Vnet = Import-Excel -Path $Global:InputFilePath -WorksheetName 'vNet'
    $AllInputs.Subnet = Import-Excel -Path $Global:InputFilePath -WorksheetName 'Subnet'
    $Allinputs.Bastion = Import-Excel -Path $Global:InputFilePath -WorksheetName 'Bastion'
    $Allinputs.NSG = Import-Excel -Path $Global:InputFilePath -WorksheetName 'NSG'
    $Allinputs.RT = Import-Excel -Path $Global:InputFilePath -WorksheetName 'RouteTables'
    $Allinputs.VM = Import-Excel -Path $Global:InputFilePath -WorksheetName 'VM'
    $Allinputs.LBRules = Import-Excel -Path $Global:InputFilePath -WorksheetName 'LB-Rules'
    $Allinputs.NATRules = Import-Excel -Path $Global:InputFilePath -WorksheetName 'LB-NATRules'


    #*******************  Functions  ***********************

    Function Select-Subscription
    {
    Try
    {
        Write-host 'Login to your Azure Account'
        Login-AzAccount
        Get-AzSubscription | Out-GridView -PassThru | Select-AzSubscription
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        $LogLine = 'Erro Logging to the subscription. Error' + $ErrorMessage
        Write-Log $logLine
    }
    }

    Function Write-Log
    {
    Param
    (
        [Parameter ()]
        [ValidateNotNull()]
        [String] $LogContent
    )
    Try
    {
        $logLine = "$(Get-Date)", $LogContent
        Add-Content $LogFilePath -Value $logLine
    }
    Catch
    {
        Write-Output 'Error writing to the log file'
    }
    }

    Function Clear-log
    {
        Try
        {
            IF (Test-Path $LogFilePath)
            {
                Remove-Item $LogFilePath
            }
        }
        Catch
        {
            Write-Log 'Error deleting old log File'
        }
    }

    Function Test-AzureResource ([String] $ResourceType, [String] $ResourceName)
    {
        Try
        {
            IF ($null -eq (Get-AzResource -ResourceType $ResourceType -Name $ResourceName))
            {
                Return $true
            }
            Else
            {
                Return $false
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $ResourceName
            $logLine = "Error in function Test-AzureResource for Resource (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $logLine
            throw
        }
    }

    Function New-ResourceGroup ([String] $RGName, [String] $RGLocation)
    {
        Try
        {
            IF ($null -eq (Get-AzResourceGroup -Name $RGName -Location $RGLocation -ErrorAction SilentlyContinue))
            {
                Write-host 'Creating Resource Group' $RGName 'in' $RGLocation
                New-AzResourceGroup -Name $RGName -Location $RGLocation
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $RGName
            $LogLine = "Error in Function New-ResourceGroup (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-NetworkSecurityGroup ($vNet, $Subnet, $NSG)
    {
        Try
        {
            IF (Test-AzureResource -ResourceType 'Microsoft.Network/networkSecurityGroups' -ResourceName $NSG)
            {
                IF ($Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).Keys.Count -gt 0)
                {
                    $Rules = @()
                    Foreach ($Rule in $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).keys)
                    {
                        $Rules += New-AzNetworkSecurityRuleConfig -Name $Rule -Description $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).Description `
                                    -Direction $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).Direction `
                                    -Access $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).Action -Protocol $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).Protocol `
                                    -Priority $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).Priority -SourceAddressPrefix $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).SourceAddressPrefix `
                                    -SourcePortRange $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).SourcePortRange `
                                    -DestinationAddressPrefix $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).DestinationAddressPrefix `
                                    -DestinationPortRange $Hash.VirtualNetwork.($vnet).Subnet.($Subnet).NSG.($NSG).($Rule).DestinationPortRange
                    }
                    $NSGConfig = New-AzNetworkSecurityGroup -Name $NSG -ResourceGroupName $Hash.VirtualNetwork.($vNet).Raw.ResourceGroup -Location $Hash.VirtualNetwork.($vNet).Raw.Location -SecurityRules $Rules
                }
                Else
                {
                    $NSGConfig = New-AzNetworkSecurityGroup -Name $NSG -ResourceGroupName $Hash.VirtualNetwork.($vNet).Raw.ResourceGroup -Location $Hash.VirtualNetwork.($vNet).Raw.Location
                }
            }
            Else
            {
                $NSGConfig = Get-AzNetworkSecurityGroup -Name $NSG -ResourceGroupName $Hash.VirtualNetwork.($vNet).Raw.ResourceGroup
            }
            Return $NSGConfig
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $NSG
            $LogLine = "Error Provision Network Security Group (" + $failedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-RouteTable($vNet, $Subnet, $RouteTable)
    {
        Try
        {
            IF (Test-AzureResource -ResourceType 'Microsoft.Network/RouteTables' -ResourceName $RouteTable)
            {
                $Routes = @()
                Foreach ($Route in $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.($RouteTable).Keys)
                {
                    $Routes += New-AzRouteConfig -Name $Route -AddressPrefix $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.($RouteTable).($Route).AddressPrefix `
                                -NextHopType $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.($RouteTable).($Route).NextHop `
                                -NextHopIpAddress $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.($RouteTable).($Route).NextHopAddress
                }
                $RouteConfig = New-AzRouteTable -Name $RouteTable -ResourceGroupName $Hash.VirtualNetwork.($vNet).Raw.ResourceGroup -Location $Hash.VirtualNetwork.($vNet).Raw.Location -Route $Routes
            }
            Else
            {
                $RouteConfig = Get-AzRouteTable -Name $RouteTable -ResourceGroupName $Hash.VirtualNetwork.($vNet).Raw.ResourceGroup
            }
            Return $RouteConfig
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $RouteTable
            $LogLine = "Error Provision Route Table (" + $failedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-VirtualNetwork ($vNet)
    {
        Try
        {
            IF (Test-AzureResource -ResourceType 'Microsoft.Network/virtualNetworks' -ResourceName $Hash.virtualNetwork.($vNet).raw.VNetName)
            {
                New-ResourceGroup -RGName $Hash.virtualNetwork.($vNet).raw.ResourceGroup -RGLocation $Hash.virtualNetwork.($vNet).raw.Location

                $SubnetConfig = @()

                foreach ($Subnet in $Hash.virtualNetwork.($vNet).Subnet.Keys)
                {
                    IF ($null -ne $Hash.VirtualNetwork.($vnet).Subnet.($subnet).NSG.Keys)
                    {
                        Foreach ($NSG in $Hash.VirtualNetwork.($vnet).Subnet.($subnet).NSG.keys)
                        {
                            $NSGConfig = New-NetworkSecurityGroup -vNet $vNet -Subnet $Subnet -NSG $NSG
                        }
                    }
                    Else
                    {
                        $NSGConfig = $null
                    }

                    IF ($null -ne $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.Keys)
                    {
                        Foreach ($RouteTable in $Hash.VirtualNetwork.($vNet).Subnet.($Subnet).RT.Keys)
                        {
                            $RouteConfig = New-RouteTable -vNet $vnet -Subnet $Subnet -Route $RouteTable
                        }
                    }
                    Else
                    {
                        $RouteConfig = $null
                    }
                    $Subnetconfig += New-AzVirtualNetworkSubnetConfig -Name $Hash.virtualNetwork.($vNet).Subnet.($subnet).raw.SubnetName -AddressPrefix $Hash.virtualNetwork.($vNet).Subnet.($subnet).raw.SubnetAddrRange -NetworkSecurityGroup $NSGConfig -RouteTable $RouteConfig
                }
                New-AzVirtualNetwork -Name $Hash.virtualNetwork.($vNet).raw.VNetName -ResourceGroupName $Hash.virtualNetwork.($vNet).raw.ResourceGroup -Location $Hash.virtualNetwork.($vNet).raw.Location -AddressPrefix $Hash.virtualNetwork.($vNet).AddressPrefix -Subnet $SubnetConfig
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $vnet.VNetName
            $LogLine = "Error Provision Virtual Network (" + $failedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-Bastion ($Bastion)
    {
        Try
        {
            New-ResourceGroup -RGName $Hash.Bastion.($Bastion).raw.BastionRG -RGLocation $Hash.Bastion.($Bastion).Raw.Location
            IF (Test-AzureResource -ResourceType 'Microsoft.Network/bastionHosts' -ResourceName $Bastion)
            {
                $VirtualNetwork = Get-AzVirtualNetwork -Name $Hash.Bastion.($Bastion).Raw.VNetName
                IF ($null -ne $VirtualNetwork )
                {
                IF (($virtualnetwork.Subnets | Where-Object 'Name' -eq 'AzureBastionSubnet') -eq $null)
                        {
                                Add-AzVirtualNetworkSubnetConfig -Name $Hash.Bastion.($Bastion).Raw.BastionSubnetName -AddressPrefix $Hash.Bastion.($Bastion).Raw.BastionSubnetAddressPrefix -VirtualNetwork $VirtualNetwork
                                $VirtualNetwork | Set-AzVirtualNetwork
                                $VirtualNetwork = Get-AzVirtualNetwork -Name $Hash.Bastion.($Bastion).Raw.VNetName
                        }
                    
                #$RG = New-ResourceGroup -RGName $Hash.Bastion.($Bastion).Raw.BastionRG -RGLocation $Hash.Bastion.($Bastion).Raw.Location
                $BastionPIPName = $Bastion + '-PIP'
                $BastionPIP = New-AzPublicIpAddress -ResourceGroupName $Hash.Bastion.($Bastion).Raw.BastionRG -Name $BastionPIPName -Location $Hash.Bastion.($Bastion).Raw.Location -AllocationMethod Static -Sku Standard
                New-AzBastion -ResourceGroupName $Hash.Bastion.($Bastion).raw.BastionRG -Name $Bastion -PublicIpAddress $BastionPIP -VirtualNetwork $VirtualNetwork
                }
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $Bastion
            $LogLine = "Error Provision Bastion (" + $failedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    } 


    Function Add-Disk ($Disk_Name, $Disk_Size, $VM, $VM_Config, $Lun)
    {
        Try
        {
            $DiskConfig = New-AzDiskConfig -Location $Hash.VM.($VM).Raw.Location -AccountType $Hash.VM.($VM).Raw.Disk_Type -CreateOption Empty -DiskSizeGB $Disk_Size
            $DataDisk = New-AzDisk -DiskName $Disk_Name -Disk $DiskConfig -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name
            Add-AzVMDataDisk -VM $VM_Config -Name $Disk_Name -CreateOption Attach -ManagedDiskId $DataDisk.Id -Lun $Lun
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $VM.VM_Name
            $LogLine = "Error provisioning data disk for VM (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function Add-VMDataDisk ($VM, $VMConfig)
    {
        Try
        {
            IF ($null -ne $Hash.VM.($VM).Raw.Disk1)
            {
                $DataDiskName = 'Disk-' + $Hash.VM.($VM).Raw.VM_Name + '-DataDisk-01'
                Add-Disk -Disk_Name $DataDiskName -VM $VM -Disk_Size $Hash.VM.($VM).Raw.Disk1 -VM_Config $VM_Config -Lun 1
            }
            IF ($null -ne $Hash.VM.($VM).Raw.Disk2)
            {
                $DataDiskName = 'Disk-' + $Hash.VM.($VM).Raw.VM_Name + '-DataDisk-02'
                Add-Disk -Disk_Name $DataDiskName -VM $VM -Disk_Size $Hash.VM.($VM).Raw.Disk2 -VM_Config $VM_Config -Lun 2
            }
            IF ($null -ne $Hash.VM.($VM).Raw.Disk3)
            {
                $DataDiskName = 'Disk-' + $Hash.VM.($VM).Raw.VM_Name + '-DataDisk-03'
                Add-Disk -Disk_Name $DataDiskName -VM $VM -Disk_Size $Hash.VM.($VM).Raw.Disk3 -VM_Config $VM_Config -Lun 3
            }
            IF ($null -ne $Hash.VM.($VM).Raw.Disk4)
            {
                $DataDiskName = 'Disk-' + $Hash.VM.($VM).Raw.VM_Name + '-DataDisk-04'
                Add-Disk -Disk_Name $DataDiskName -VM $VM -Disk_Size $Hash.VM.($VM).Raw.Disk4 -VM_Config $VM_Config -Lun 4
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $VM.VM_Name
            $LogLine = "Error provisioning data disk for VM (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-BackupVault ($VM)
    {
        Try
        {
            IF (Test-AzureResource -ResourceType 'Microsoft.RecoveryServices/vaults' -ResourceName $Hash.VM.($VM).Raw.BackupVaultName)
            {
                New-ResourceGroup -RGName $Hash.VM.($VM).Raw.BackupVaultRG -RGLocation $Hash.VM.($VM).Raw.Location
                $BackupVault = New-AzRecoveryServicesVault -Name $Hash.VM.($VM).Raw.BackupVaultName -ResourceGroupName $Hash.VM.($VM).Raw.BackupVaultRG -Location $Hash.VM.($VM).Raw.Location
                $BackupVault | Set-AzRecoveryServicesVaultContext
                $SchPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM"
                $SchPol.ScheduleRunTimes.Clear()
                $Time = $Hash.VM.($VM).Raw.BackupStartTime
                $UtcTime = [datetime]::Parse($Time)
                $UtcTime = $UtcTime.ToUniversalTime()
                $SchPol.ScheduleRunTimes.Add($UtcTime)
                $RetPol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM"
                $RetPol.DailySchedule.DurationCountInDays = $Hash.VM.($VM).Raw.DailyRetention
                $RetPol.WeeklySchedule.DurationCountInWeeks = $Hash.VM.($VM).Raw.WeeklyRetention
                $RetPol.MonthlySchedule.DurationCountInMonths = $Hash.VM.($VM).Raw.MonthlyRetention
                $RetPol.YearlySchedule.DurationCountInYears = $Hash.VM.($VM).Raw.YearlyRetention
                $BackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy -Name $Hash.VM.($VM).Raw.BackupPolicyName -WorkloadType AzureVM -RetentionPolicy $RetPol -SchedulePolicy $SchPol
                $VMState = Get-AzVM -Name $VM
                While ($VMState.ProvisioningState -ne 'Succeeded')
                {
                    Start-Sleep -Seconds 5
                    $VMState = Get-AzVM -Name $VM
                }
                Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $VM -Policy $BackupPolicy
            }
            Else
            {
                $BackupVault = Get-AzRecoveryServicesVault -Name $Hash.VM.($VM).Raw.BackupVaultName -ResourceGroupName $Hash.VM.($VM).Raw.BackupVaultRG
                $BackupVault | Set-AzRecoveryServicesVaultContext
                IF ($null -eq (Get-AzRecoveryServicesBackupProtectionPolicy -Name $Hash.VM.($VM).Raw.BackupPolicyName -ErrorAction SilentlyContinue))
                {
                    $SchPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM"
                    $SchPol.ScheduleRunTimes.Clear()
                    $Time = $Hash.VM.($VM).Raw.BackupStartTime
                    $UtcTime = [datetime]::Parse($Time)
                    $UtcTime = $UtcTime.ToUniversalTime()
                    $SchPol.ScheduleRunTimes.Add($UtcTime)
                    $RetPol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM"
                    $RetPol.DailySchedule.DurationCountInDays = $Hash.VM.($VM).Raw.DailyRetention
                    $RetPol.WeeklySchedule.DurationCountInWeeks = $Hash.VM.($VM).Raw.WeeklyRetention
                    $RetPol.MonthlySchedule.DurationCountInMonths = $Hash.VM.($VM).Raw.MonthlyRetention
                    $RetPol.YearlySchedule.DurationCountInYears = $Hash.VM.($VM).Raw.YearlyRetention
                    $BackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy -Name $Hash.VM.($VM).Raw.BackupPolicyName -WorkloadType AzureVM -RetentionPolicy $RetPol -SchedulePolicy $SchPol
                    $VMState = Get-AzVM -Name $VM
                    While ($VMState.ProvisioningState -ne 'Succeeded')
                    {
                        Start-Sleep -Seconds 5
                        $VMState = Get-AzVM -Name $VM
                    }
                    Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $VM -Policy $BackupPolicy
                }
                Else
                {
                    $BackupPolicy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $Hash.VM.($VM).Raw.BackupPolicyName -VaultId $BackupVault.ID
                    $VMState = Get-AzVM -Name $VM
                    While ($VMState.ProvisioningState -ne 'Succeeded')
                    {
                        Start-Sleep -Seconds 5
                        $VMState = Get-AzVM -Name $VM
                    }
                    Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $VM -Policy $BackupPolicy
                }
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $Hash.VM.($VM).Raw.BackupVaultName
            $LogLine = "Error provisioning Backup Vault (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function Enable-DiskEncryption ($VM)
    {
        Try
        {
            IF (Test-AzureResource -ResourceType 'Microsoft.KeyVault/Vaults' -ResourceName $Hash.VM.($VM).Raw.KVault_Name)
            {
                New-ResourceGroup -RGName $Hash.VM.($VM).Raw.KVault_RG_Name -RGLocation $Hash.VM.($VM).Raw.Location
                $KeyVault = New-AzKeyVault -Name $Hash.VM.($VM).Raw.KVault_Name `
                            -ResourceGroupName $Hash.VM.($VM).Raw.KVault_RG_Name `
                            -Location $Hash.VM.($VM).Raw.Location -EnabledForDiskEncryption -EnableSoftDelete

                Set-AzVMDiskEncryptionExtension -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name `
                            -VMName $VM -DiskEncryptionKeyVaultUrl $KeyVault.VaultUri `
                            -DiskEncryptionKeyVaultId $KeyVault.ResourceId -VolumeType All -Force

                $LogLine = 'Disk Encryption configured successfully for VM (' + $VM + ').'
                write-log $LogLine
            }
            Else
            {
                $KeyVault = Get-AzKeyVault -VaultName $Hash.VM.($VM).Raw.KVault_Name -ResourceGroupName $Hash.VM.($VM).Raw.KVault_RG_Name
                Set-AzVMDiskEncryptionExtension -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name`
                            -VMName $VM -DiskEncryptionKeyVaultUrl $KeyVault.VaultUri `
                            -DiskEncryptionKeyVaultId $KeyVault.ResourceId -VolumeType All -Force

                $LogLine = 'Disk Encryption configured successfully for VM (' + $Hash.VM.($VM).Raw.VM_Name + ').'
                write-log $LogLine
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $VM
            $LogLine = "Error during disk encryption for VM  (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-VM ($VM)
    {
        Try
        {
            # Check if VM Exist
            IF (Test-AzureResource -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceName $VM)
            {
                New-ResourceGroup -RGName $Hash.VM.($VM).Raw.RG_Name -RGLocation $Hash.VM.($VM).Raw.Location

                # Form VM Credentials
                $SecurePwd = ConvertTo-SecureString -String $Hash.VM.($VM).Raw.VM_Admin_Pwd -AsPlainText -Force
                $VM_Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Hash.VM.($VM).Raw.VM_Admin_Name, $SecurePwd

                # Get Virtual Network Details
                $VM_Vnet = Get-AzVirtualNetwork -Name $Hash.VM.($VM).Raw.VNet_Name -ResourceGroupName $Hash.VM.($VM).Raw.VNet_RG_Name

                # Get Subnet Configuration
                $VM_Subnet = Get-AzVirtualNetworkSubnetConfig -Name $Hash.VM.($VM).Raw.Subnet_Name -VirtualNetwork $VM_Vnet

                IF ($Hash.VM.($VM).Raw.PIP -ne 'No' -and $null -ne $Hash.VM.($VM).Raw.PIP_Name)
                {
                    IF (Test-AzureResource -ResourceType 'Microsoft.Network/publicIPAddresses' -ResourceName $Hash.VM.($VM).Raw.PIP_Name)
                    {
                        New-AzPublicIpAddress -Name $Hash.VM.($VM).Raw.PIP_Name -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Location $Hash.VM.($VM).Raw.Location -AllocationMethod Static
                    }
                    $VM_PIP = Get-AzPublicIpAddress -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $Hash.VM.($VM).Raw.PIP_Name
                }

                # Virtual machine network interface
                IF (Test-AzureResource -ResourceType 'Microsoft.Network/networkInterfaces' -ResourceName $Hash.VM.($VM).Raw.Nic_Name)
                {
                    IF ($null -eq $VM_PIP)
                    {
                        $VM_Nic = New-AzNetworkInterface -Name $Hash.VM.($VM).Raw.Nic_Name -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Location $Hash.VM.($VM).Raw.Location -SubnetId $VM_Subnet.Id
                    }
                    Else
                    {
                        $VM_Nic = New-AzNetworkInterface -Name $Hash.VM.($VM).Raw.Nic_Name -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Location $Hash.VM.($VM).Raw.Location -PublicIpAddressId $VM_PIP.Id -SubnetId $VM_Subnet.Id
                    }
                    $VM_Nic = Get-AzNetworkInterface -Name $Hash.VM.($VM).Raw.Nic_Name -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name
                }
                Else
                {
                    $VM_Nic = Get-AzNetworkInterface -Name $Hash.VM.($VM).Raw.Nic_Name -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name
                }

                # Virtual Machine Availability Set & Create VM Configuration
                IF ($null -eq $Hash.VM.($VM).Raw.Availability_Set_Name)
                {
                    $VM_Config = New-AzVMConfig -VMName $Hash.VM.($VM).Raw.VM_Name -VMSize $Hash.VM.($VM).Raw.VM_Size
                }
                Else
                {
                    If(Test-AzureResource -ResourceType 'Microsoft.Compute/availabilitySets' -ResourceName $Hash.VM.($VM).Raw.Availability_Set_Name)
                    {
                        $VM_AvailabilitySet = New-AzAvailabilitySet -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $Hash.VM.($VM).Raw.Availability_Set_Name -Location $Hash.VM.($VM).Raw.Location -PlatformUpdateDomainCount 2 -PlatformFaultDomainCount 2 -Sku Aligned
                        $VM_Config = New-AzVMConfig -VMName $Hash.VM.($VM).Raw.VM_Name -VMSize $Hash.VM.($VM).Raw.VM_Size -AvailabilitySetId $VM_AvailabilitySet.Id
                    }
                    Else
                    {
                        $VM_AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Name $Hash.VM.($VM).Raw.Availability_Set_Name
                        $VM_Config = New-AzVMConfig -VMName $Hash.VM.($VM).Raw.VM_Name -VMSize $Hash.VM.($VM).Raw.VM_Size -AvailabilitySetId $VM_AvailabilitySet.Id
                    }
                }

                Switch ($Hash.VM.($VM).Raw.ImageSource)
                {
                    'Gallery'
                        {
                            $VM_Config = $VM_Config | Set-AzVMOperatingSystem -Windows -ComputerName $Hash.VM.($VM).Raw.VM_Name -Credential $VM_Credentials -TimeZone $Hash.VM.($VM).Raw.Time_Zone -ProvisionVMAgent | Add-AzVMNetworkInterface -id $VM_Nic.Id
                            Set-AzVMSourceImage -VM $VM_Config -PublisherName $Hash.VM.($VM).Raw.Publisher -Offer $Hash.VM.($VM).Raw.Offer -Skus $Hash.VM.($VM).Raw.SKU -Version latest
                        }
                    'Custom'
                        {
                            $SourceImage = Get-AzImage -ResourceGroupName $Hash.VM.($VM).Raw.SourceImageRG -ImageName $Hash.VM.($VM).Raw.SourceImageName
                            $VM_Config = $VM_Config | Set-AzVMOperatingSystem -Windows -ComputerName $Hash.VM.($VM).Raw.VM_Name -Credential $VM_Credentials -TimeZone $Hash.VM.($VM).Raw.Time_Zone -ProvisionVMAgent | Add-AzVMNetworkInterface -id $VM_Nic.Id
                            Set-AzVMSourceImage -VM $VM_Config -Id $SourceImage.Id
                        }
                    'SharedImage'
                        {
                            $SharedImageVersionId = Get-AzGalleryImageVersion -ResourceGroupName $Hash.VM.($VM).Raw.SharedImageDefinitionRG -GalleryName $Hash.VM.($VM).Raw.SharedImageGalleryName -GalleryImageDefinitionName $Hash.VM.($VM).Raw.SharedImageDefinitionName -Name $Hash.VM.($VM).Raw.SharedImageDefinitionVersion
                            $VM_Config = $VM_Config | Set-AzVMOperatingSystem -Windows -ComputerName $Hash.VM.($VM).Raw.VM_Name -Credential $VM_Credentials -TimeZone $Hash.VM.($VM).Raw.Time_Zone -ProvisionVMAgent | Add-AzVMNetworkInterface -id $VM_Nic.Id
                            Set-AzVMSourceImage -VM $VM_Config -Id $SharedImageVersionId.Id
                        }
                }
                # Create and Configure VM OS Disk
                $VM_OS_Disk = 'disk-' + $Hash.VM.($VM).Raw.VM_Name + '-os'
                Set-AzVMOSDisk -VM $VM_Config -Name $VM_OS_Disk -Caching ReadWrite -StorageAccountType $Hash.VM.($VM).Raw.Disk_Type -CreateOption FromImage

                IF (Test-AzureResource -ResourceType 'Microsoft.Storage/storageAccounts' -ResourceName $Hash.VM.($VM).Raw.Diag_Storage_Name)
                {
                    New-ResourceGroup -RGName $Hash.VM.($VM).Raw.Diag_Storage_RG -RGLocation $Hash.VM.($VM).Raw.Location
                    New-AzStorageAccount -Name $Hash.VM.($VM).Raw.Diag_Storage_Name -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -SkuName 'Standard_LRS' -Location $Hash.VM.($VM).Raw.Location
                }

                # Configure VM boot Diagnostics
                Set-AzVMBootDiagnostic -VM $VM_Config -Enable -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -StorageAccountName $Hash.VM.($VM).Raw.Diag_Storage_Name

                # Create and Attach Disks
                Add-VMDataDisk -VM $Hash.VM.($VM).Raw.VM_Name -VMConfig $VM_Config

                # Get Hybrid License info and provision VM
                IF ($Hash.VM.($VM).Raw.Hybrid_Benefits -eq 'Yes')
                {
                    $VM_Hybrid_License = 'Windows_Server'
                    New-AzVM -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Location $Hash.VM.($VM).Raw.Location -VM $VM_Config -LicenseType $VM_Hybrid_License
                }
                Else
                {
                $VM_Hybrid_License = ''
                    New-AzVM -ResourceGroupName $Hash.VM.($VM).Raw.RG_Name -Location $Hash.VM.($VM).Raw.Location -VM $VM_Config
                }

                $LogLine = 'Provisioning successfully started for VM (' + $Hash.VM.($VM).Raw.VM_Name + ').'
                Write-Log $LogLine

                IF ($null -ne ($Hash.VM.($VM).Raw.BackupVaultName))
                {
                    New-BackupVault $VM
                }

                Initialize-DataDisks $VM

                IF ($null -ne ($Hash.VM.($VM).Raw.KVault_Name))
                {
                    Enable-DiskEncryption $VM
                }
            }
            Else
            {
                $LogLine = 'Already provisioned VM (' + $Hash.VM.($VM).Raw.VM_Name + ').'
                Write-Log $LogLine
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $VM
            $LogLine = "Error provisioning VM (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    Function New-AZLBFEPool ($LB)
    {
            Switch ($Hash.LB.($LB).Design.LBType)
            {
                Internal {
                    $FEPools = @()
                    Foreach ($FEPool in $Hash.LB.($LB).FEPool.Keys)
                    {
                        $vnet = Get-AzVirtualNetwork -Name $Hash.LB.($LB).FEPool.($FEPool).Design.vNetName
                        $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $Hash.LB.($LB).FEPool.($FEPool).Design.SubnetName -VirtualNetwork $vnet
                        $FEPools += New-AzLoadBalancerFrontendIpConfig -Name $FEPool -PrivateIpAddress $Hash.LB.($LB).FEPool.($FEPool).Design.FEPrivateIP -SubnetId $Subnet.Id
                    }
                }
                Public {
                    $FEPools = @()
                    Foreach ($FEPool in $Hash.LB.($LB).FEPool.Keys)
                    {
                        IF (Test-AzureResource -ResourceType 'Microsoft.Network/publicIPAddresses' -ResourceName $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPName)
                        {
                            $FEPIP = New-AzPublicIpAddress -Name $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPName `
                                -ResourceGroupName $Hash.LB.($LB).FEPool.($FEPool).Design.LBRG `
                                -Location $Hash.LB.($LB).FEPool.($FEPool).Design.Location `
                                -AllocationMethod $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPAllocationMethod `
                                -Sku $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPSku
                            $FEPools += New-AzLoadBalancerFrontendIpConfig -Name $FEPool -PublicIpAddress $FEPIP
                        }
                        Else
                        {
                            $PIP = Get-AzPublicIpAddress -Name $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPName
                            IF ($null -eq $PIP.IpConfiguration -and $PIP.Sku.Name -eq $Hash.LB.($LB).FEPool.($FEPool).Design.PublicIPSku)
                            {
                                $FEPIP = $PIP
                                $FEPools += New-AzLoadBalancerFrontendIpConfig -Name $FEPool -PublicIpAddress $FEPIP
                            }
                        }
                    }
                }
            }
        Return $FEPools
    }

    Function New-AZLBProbe ($LB)
    {
        $Probes = @()
        Foreach ($Probekey in $Hash.LB.($LB).Probe.Keys)
        {
            $Probes += New-AzLoadBalancerProbeConfig -Name $Probekey -Protocol $Hash.LB.($LB).Probe.($Probekey).HealthProbeProtocol `
                        -RequestPath $Hash.LB.($LB).Probe.($Probekey).HealthProbePath `
                        -Port $Hash.LB.($LB).Probe.($Probekey).HealthProbePort `
                        -IntervalInSeconds $Hash.LB.($LB).Probe.($Probekey).HealthProbeInterval `
                        -ProbeCount $Hash.LB.($LB).Probe.($Probekey).HealthProbeCount
        }
        Return $Probes
    }

    Function New-AZLBBEPool ($LB)
    {
        $BEPools = @()
        Foreach ($BEKey in $Hash.LB.($LB).BEPool.keys)
        {
            $BEPools += New-AzLoadBalancerBackendAddressPoolConfig -Name $BEKey
        }
        Return $BEPools
    }

    Function New-AZLBRule ($LB)
    {
    $LBRules = @()
        Foreach ($LBRule in $Hash.LB.($LB).LBRules.Keys)
        {
            $FEConfig = $FEpools | Where-Object Name -EQ $Hash.LB.($LB).LBRules.($LBRule).Design.FrontendPoolName
            $BEConfig = $BEPools | Where-Object Name -EQ $Hash.LB.($LB).LBRules.($LBRule).Design.BackendPoolName
            $ProbeConfig = $Probes | Where-Object Name -EQ $Hash.LB.($LB).LBRules.($LBRule).Design.HealthProbeName
            $LBRules += New-AzLoadBalancerRuleConfig -Name $LBRule -FrontendIpConfiguration $FEConfig `
                                    -BackendAddressPool $BEConfig -Probe $ProbeConfig -Protocol $Hash.LB.($LB).LBRules.($LBRule).Design.LBProtocol `
                                    -FrontendPort $Hash.LB.($LB).LBRules.($LBRule).Design.LBFrontendPort -BackendPort $Hash.LB.($LB).LBRules.($LBRule).Design.LBBackendPort
        }
        Return $LBRules
    }

    Function New-AZNATRule ($LB)
    {
        $NATRules = @()
        Foreach ($NATRule in $Hash.LB.($LB).NATRules.Keys)
        {
            $FEConfig = $FEpools | Where-Object Name -EQ $Hash.LB.($LB).NATRules.($NATRule).Design.FrontendPoolName
            $NATRules += New-AzLoadBalancerInboundNatRuleConfig -Name $NATRule -FrontendIpConfiguration $FEConfig `
                                    -Protocol $Hash.LB.($LB).NATRules.($NATRule).Design.NATProtocol `
                                    -FrontendPort $Hash.LB.($LB).NATRules.($NATRule).Design.NATFrontendPort `
                                    -BackendPort $Hash.LB.($LB).NATRules.($NATRule).Design.NATBackendPort
        }
        Return $NATRules
    }

    Function Get-AzNICIPConfig ($VMName, $IPaddress)
    {
        $AZVM = Get-AzVM -Name $VMName
        $Found = $false
        Foreach ($NIC in $AZVM.NetworkProfile.NetworkInterfaces)
        {
            $NICID = $NIC.id.Split('/')
            $NICName = $NICID[$NICID.Count -1]
            $NICConfig = Get-AzNetworkInterface -Name $NICName
            $IPConfig = Get-AzNetworkInterfaceIpConfig -NetworkInterface $NICConfig | Where-Object 'PrivateIPAddress' -EQ $IPaddress
            IF ($IPConfig.PrivateIpAddress -eq $IPaddress)
            {
                $Found = $true
                Return $NICConfig
            }
        }
    }

    Function Add-AZLBBEVMs ($LB)
    {
        Foreach($BEVM in $Hash.LB.($LB).BEVMs.Keys)
        {
            $LBConfig = Get-AzLoadBalancer -Name $LB
            $BEPools = Get-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $LBConfig
            $BEConfig = $BEPools | Where-Object Name -EQ $Hash.LB.($LB).BEVMs.($BEVM).Design.BackendPoolName
            $NICConfig = Get-AzNICIPConfig -VMName $BEVM -IPaddress $Hash.LB.($LB).BEVMs.($BEVM).Design.LBBackEndIP
            $IPConfig = Get-AzNetworkInterfaceIpConfig -NetworkInterface $NICConfig | Where-Object 'PrivateIPAddress' -EQ $Hash.LB.($LB).BEVMs.($BEVM).Design.LBBackEndIP
            $IPConfig.LoadBalancerBackendAddressPools = $BEConfig
            Set-AzNetworkInterface -NetworkInterface $NICConfig
        }
    }

    Function New-AZLB ($LB)
    {
        IF (Test-AzureResource -ResourceType 'Microsoft.Network/loadBalancers' -ResourceName $LB)
        {
            New-ResourceGroup -RGName $Hash.LB.($LB).Design.LBRG -RGLocation $Hash.LB.($LB).Design.Location

            $FEPools =  New-AZLBFEPool -LB $LB
            $BEPools = New-AZLBBEPool -LB $LB
            $Probes = New-AZLBProbe -LB $LB
            $LBRules = New-AZLBRule -LB $LB
            $NATRules = New-AZNATRule -LB $LB
            New-AzLoadBalancer -Name $LB -ResourceGroupName $Hash.LB.($LB).Design.LBRG `
                            -Location $Hash.LB.($LB).Design.Location `
                            -Sku $Hash.LB.($LB).Design.LBSKU `
                            -FrontendIpConfiguration $FEPools `
                            -BackendAddressPool $BEPools `
                            -Probe $Probes `
                            -LoadBalancingRule $LBRules `
                            -InboundNatRule $NATRules
            Add-AZLBBEVMs -LB $LB
        }
    }

    Function Initialize-DataDisks ($VM)
    {
        Try
        {
            IF ($null -ne ($Hash.VM.($VM).Raw.Diag_Storage_Name))
            {
                $NewDiskInitContainer = "diskinitialize"
                $DiskContainerCheck = Get-AzStorageAccount -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -Name $Hash.VM.($VM).Raw.Diag_Storage_Name | Get-AzStorageContainer
                If($DiskContainerCheck.Name -notcontains $NewDiskInitContainer)
                {
                    $NewStorageContainer = Get-AzStorageAccount -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -Name $Hash.VM.($VM).Raw.Diag_Storage_Name | New-AzStorageContainer -Name $NewDiskInitContainer
                    $uploadscript = @{
                        'File' = $DiskInitializeScriptPath
                        'Container' = $NewDiskInitContainer
                        'BlobType' = 'Block'
                        'Blob' = 'DiskInitialize.ps1'
                    }
                    $NewStorageContainer | Set-AzStorageBlobContent @uploadscript
                    $SAKey = (Get-AzStorageAccountKey -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -Name $Hash.VM.($VM).Raw.Diag_Storage_Name) | Where-Object {$_.KeyName -eq "key1"}
                    $scriptextparams = @{
                        'ResourceGroupName' = $Hash.VM.($VM).Raw.RG_Name
                        'VMName' = $Hash.VM.$VM.Raw.VM_Name
                        'Name' = 'DiskInitialize.ps1'
                        'Location' = $Hash.VM.($VM).Raw.Location
                        'StorageAccountName' = $Hash.VM.($VM).Raw.Diag_Storage_Name
                        'StorageAccountKey' = $SAKey.Value
                        'FileName' = 'DiskInitialize.ps1'
                        'ContainerName' = $NewDiskInitContainer
                        'Run' = 'DiskInitialize.ps1'
                    }
                    Set-AzVMCustomScriptExtension @scriptextparams
                }
                Else
                {
                    $Strgkey= (Get-AzureRmStorageAccountKey -ResourceGroupName $Hash.vm.($VM).raw.Diag_Storage_RG -name $Hash.vm.($VM).raw.Diag_Storage_Name -ErrorAction Stop)[0].value
                    $StrgContext = New-AzureStorageContext -StorageAccountName $Hash.vm.($VM).raw.Diag_Storage_Name -StorageAccountKey $Strgkey -ErrorAction Stop
                    $blob = Get-AzureStorageBlob -Blob 'DiskInitialize.ps1' -Container "diskinitialize" -Context $StrgContext -ErrorAction Ignore
                    If ($blob -eq $null) 
                    {
                        $NewStorageContainer = Get-AzStorageAccount -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -Name $Hash.VM.($VM).Raw.Diag_Storage_Name | Get-AzStorageContainer
                        $uploadscript = @{
                            'File' = $DiskInitializeScriptPath
                            'Container' = $NewDiskInitContainer
                            'BlobType' = 'Block'
                            'Blob' = 'DiskInitialize.ps1'
                        }
                    
                        $NewStorageContainer | Set-AzStorageBlobContent @uploadscript
                    }
                    $SAKey = (Get-AzStorageAccountKey -ResourceGroupName $Hash.VM.($VM).Raw.Diag_Storage_RG -Name $Hash.VM.($VM).Raw.Diag_Storage_Name) | Where-Object {$_.KeyName -eq "key1"}
                    $scriptextparams = @{
                        'ResourceGroupName' = $Hash.VM.($VM).Raw.RG_Name
                        'VMName' = $Hash.VM.$VM.Raw.VM_Name
                        'Name' = 'DiskInitialize.ps1'
                        'Location' = $Hash.VM.($VM).Raw.Location
                        'StorageAccountName' = $Hash.VM.($VM).Raw.Diag_Storage_Name
                        'StorageAccountKey' = $SAKey.Value
                        'FileName' = 'DiskInitialize.ps1'
                        'ContainerName' = $NewDiskInitContainer
                        'Run' = 'DiskInitialize.ps1'
                    }
                    Set-AzVMCustomScriptExtension @scriptextparams
                }
            }
        }
        Catch
        {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $VM
            $LogLine = "Error during disk encryption for VM  (" + $FailedItem + "). Error: " + $ErrorMessage
            Write-Log $LogLine
            throw
        }
    }

    #**************  Building Hash for the Deployment'  *****************

    Foreach ($vnetInput in $Allinputs.Vnet)
    {
        IF ($null -ne $vnetInput.VNetName)
        {
            Write-Host 'Building vNet Hash'
            IF ($Hash.VirtualNetwork.keys -notcontains $vnetInput.VNetName)
            {
                $Hash.VirtualNetwork.($vnetInput.VNetName) = @{}
                $Hash.VirtualNetwork.($vnetInput.VNetName).Raw = $vnetInput
                $Hash.virtualNetwork.($vnetInput.VNetName).Subnet = @{}
                $Hash.virtualNetwork.($vnetInput.VNetName).AddressPrefix = @()
            }
            IF ($Hash.virtualNetwork.($vnetInput.VNetName).AddressPrefix -notcontains $vnetInput.AddressSpace)
            {
                $Hash.virtualNetwork.($vnetInput.VNetName).AddressPrefix += $vnetInput.AddressSpace
            }
        }
    }

    Foreach ($SubnetInput in $Allinputs.Subnet)
    {
        IF ($null -ne $SubnetInput.SubnetName)
        {
            Write-Host 'Building Subnet Hash'
            IF ($Hash.virtualNetwork.($subnetInput.VNetName).Subnet.keys -notcontains $SubnetInput.SubnetName)
            {
                $Hash.virtualNetwork.($subnetInput.VNetName).Subnet.($SubnetInput.Subnetname) = @{}
                $Hash.virtualNetwork.($subnetInput.VNetName).Subnet.($SubnetInput.Subnetname).Raw = $SubnetInput
                $Hash.virtualNetwork.($subnetInput.VNetName).Subnet.($SubnetInput.Subnetname).NSG = @{}
                $Hash.virtualNetwork.($subnetInput.VNetName).Subnet.($SubnetInput.Subnetname).RT = @{}
            }
        }
    }

    Foreach ($NSGInput in $Allinputs.NSG)
    {
        IF ($null -ne $NSGInput.NSGName)
        {
            Write-Host 'Building NSG Hash'
            IF ($Hash.VirtualNetwork.($NSGInput.vNetName).Subnet.($NSGInput.SubnetName).NSG.Keys -notcontains $NSGInput.NSGName)
            {
                $Hash.VirtualNetwork.($NSGInput.vNetName).Subnet.($NSGInput.SubnetName).NSG.($NSGInput.NSGName) = @{}
            }
            IF ($null -ne $NSGInput.RuleName)
            {
                IF ($Hash.VirtualNetwork.($NSGInput.vNetName).Subnet.($NSGInput.SubnetName).NSG.($NSGInput.NSGName) -notcontains $NSGInput.RuleName)
                {
                    $Hash.VirtualNetwork.($NSGInput.vNetName).Subnet.($NSGInput.SubnetName).NSG.($NSGInput.NSGName).($NSGInput.RuleName) = $NSGInput
                }
            }
        }
    }

    Foreach ($RTInput in $Allinputs.RT)
    {
        IF ($null -ne $RTInput.RouteTableName)
        {
            Write-Host 'Building RouteTable Hash'
            IF ($Hash.VirtualNetwork.($RTInput.vNetName).Subnet.($RTInput.Subnet).RT.keys -notcontains $RTInput.RouteTableName)
            {
                $Hash.VirtualNetwork.($RTInput.vNetName).Subnet.($RTInput.Subnet).RT.($RTInput.RouteTableName) = @{}
            }
            IF ($Hash.VirtualNetwork.($RTInput.vNetName).Subnet.($RTInput.Subnet).RT.($RTInput.RouteTableName).keys -notcontains $RTInput.RouteName)
            {
                $Hash.VirtualNetwork.($RTInput.vNetName).Subnet.($RTInput.Subnet).RT.($RTInput.RouteTableName).($RTInput.RouteName) = $RTInput
            }
        }
    }

    Foreach ($BastionInput in $Allinputs.Bastion)
    {
        IF ($null -ne $BastionInput.BastionName)
        {
            Write-Host 'Building Bsation Hash'
            IF ($Hash.Bastion.keys -notcontains $BastionInput.BastionName)
            {
                $Hash.Bastion.($BastionInput.BastionName) = @{}
                $Hash.Bastion.($BastionInput.BastionName).Raw = $BastionInput
            }
        }
    }

    Foreach ($VMInput in $Allinputs.VM)
    {
        IF ($null -ne $VMInput.VM_Name)
        {
            Write-Host 'Building VM Hash'
            IF ($Hash.VM.Keys -notcontains $VMInput.VM_Name)
            {
                $Hash.VM.($VMInput.VM_Name) = @{}
                $Hash.VM.($VMInput.VM_Name).Raw = $VMInput
            }
        }
    }

    Foreach ($LBinput in $AllInputs.LBRules)
    {
        IF ($null -ne $LBinput.LBName)
        {
            IF ($Hash.LB.Keys -notcontains $LBinput.LBName)
            {
                $Hash.LB.($LBinput.LBName) = @{}
                $Hash.LB.($LBinput.LBName).Design = $LBinput
                $Hash.LB.($LBinput.LBName).FEPool = @{}
                $Hash.LB.($LBinput.LBName).BEPool = @{}
                $Hash.LB.($LBinput.LBName).BEVMs = @{}
                $Hash.LB.($LBinput.LBName).Probe = @{}
                $Hash.LB.($LBinput.LBName).LBRules = @{}
                $Hash.LB.($LBinput.LBName).NATRules = @{}
            }
            IF ($Hash.LB.($LBinput.LBName).FEPool.Keys -notcontains $LBinput.FrontendPoolName)
            {
                $Hash.LB.($LBinput.LBName).FEPool.($LBinput.FrontendPoolName) = @{}
                $Hash.LB.($LBinput.LBName).FEPool.($LBinput.FrontendPoolName).Design = $LBinput
            }
            IF ($Hash.LB.($LBinput.LBName).BEPool.Keys -notcontains $LBinput.BackendPoolName)
            {
                $Hash.LB.($LBinput.LBName).BEPool.($LBinput.BackendPoolName) = @{}
                $Hash.LB.($LBinput.LBName).BEPool.($LBinput.BackendPoolName).Design = $LBinput
            }
            IF ($Hash.LB.($LBinput.LBName).BEVMs.keys -notcontains $LBinput.LBBackEndVM)
            {
                $Hash.LB.($LBinput.LBName).BEVMs.($LBinput.LBBackEndVM) = @{}
                $Hash.LB.($LBinput.LBName).BEVMs.($LBinput.LBBackEndVM).Design = $LBinput
            }
            IF ($Hash.LB.($LBinput.LBName).Probe.Keys -notcontains $LBinput.HealthProbeName)
            {
                $Hash.LB.($LBinput.LBName).Probe.($LBinput.HealthProbeName) = @{}
                $Hash.LB.($LBinput.LBName).Probe.($LBinput.HealthProbeName) = $LBinput
            }
            IF ($Hash.LB.($LBinput.LBName).LBRules.Keys -notcontains $LBinput.LBRuleName)
            {
                $Hash.LB.($LBinput.LBName).LBRules.($LBinput.LBRuleName) = @{}
                $Hash.LB.($LBinput.LBName).LBRules.($LBinput.LBRuleName).Design = $LBinput
            }
        }
    }

    Foreach ($NATInput in $Allinputs.NATRules)
    {
        IF($null -ne $NATInput.LBName)
        {
            IF ($Hash.LB.($NATInput.LBName).NATRules.Keys -notcontains $NATInput.NATRuleName)
            {
            $Hash.LB.($NATInput.LBName).NATRules.($NATInput.NATRuleName) = @{}
            $Hash.LB.($NATInput.LBName).NATRules.($NATInput.NATRuleName).Design = $NATInput
            }
        }
    }

    #**************  Start Script Actions  *****************
    Clear-log
    
    IF ($LoginRequired -eq $true)
    {
        Write-Host 'Signing into the Azure Subscription'
        Select-Subscription
    }
    Else
    {
        Write-Host 'Accessing the Azure Subscription'
        Get-AzSubscription | Out-GridView -PassThru | Select-AzSubscription
    }

    #**************  Deploying Azure Resources  *****************
    
    Foreach ($vNet in $Hash.VirtualNetwork.keys)
    {
        Write-Host 'potato'
        IF ($Hash.VirtualNetwork.($vNet).raw.Provision -eq 'Yes')
        {
            New-VirtualNetwork ($vNet)
            Write-Host 'Deploying Virtual Network' $vNet
        }
    }

    Foreach ($Bastion in $Hash.Bastion.Keys)
    {
        IF ($Hash.Bastion.($Bastion).Raw.Provision -eq 'Yes')
        {
            New-Bastion $Bastion
            Write-Host 'Deploying Virtual Network' $Bastion
        }
    }

    Foreach ($VM in $Hash.VM.keys)
    {
    IF ($Hash.VM.($VM).Raw.Provision -eq 'Yes')
    {
        New-VM $VM
        Write-Host 'Deploying VM' $VM
    }
    }

    Foreach ($LB in $Hash.lb.Keys)
    {
        $HealthProbes = @()
        IF ($Hash.LB.($LB).Design.Provision -eq 'Yes')
        {
            New-AZLB -LB $LB
        }
    }