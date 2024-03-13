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