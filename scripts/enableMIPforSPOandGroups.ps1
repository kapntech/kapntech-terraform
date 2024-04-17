Get-MgBetaDirectorySettingTemplate

$TemplateId = (Get-MgBetaDirectorySettingTemplate | Where-Object { $_.DisplayName -eq "Group.Unified" }).Id
$Template = Get-MgBetaDirectorySettingTemplate | Where-Object -Property Id -Value $TemplateId -EQ

$params = @{
    templateId = "$TemplateId"
    values     = @(
        @{
            name  = "UsageGuidelinesUrl"
            value = "https://guideline.example.com"
        }
        @{
            name  = "EnableMIPLabels"
            value = "True"
        }
    )
}
New-MgBetaDirectorySetting -BodyParameter $params

$Setting = Get-MgBetaDirectorySetting | Where-Object { $_.DisplayName -eq "Group.Unified" }
$Setting.Values

$grpUnifiedSetting = Get-MgBetaDirectorySetting -Search DisplayName:"Group.Unified"

$params = @{
    Values = @(
        @{
            Name  = "EnableMIPLabels"
            Value = "True"
        }
    )
}

Update-MgBetaDirectorySetting -DirectorySettingId $grpUnifiedSetting.Id -BodyParameter $params


$Setting = Get-MgBetaDirectorySetting -DirectorySettingId $grpUnifiedSetting.Id
$Setting.Values