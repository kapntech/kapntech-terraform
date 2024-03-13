$tagSheet = Import-Csv -Path ".\prodEnviro\accepted_tags.csv"
$appropriateTags = @()
foreach ($tag in $tagSheet) {
    Set-TimeZone -Id $tag.TimeZone
    Write-Host "Setting TimeZone to $($tag.TimeZone)"
    $time = Get-Date -Format "H:mm"
    Write-Host "Current Time: $time"
    [int]$t0 = $tag.TagValue
    $t1 = [int]$t0 + 1
    if ($time -ge $tag.TagValue -and $time -lt $t1) {
        Write-Host "Time is within range"
        $appropriateTags += $tag.TagName
    }else {
        Write-Host "Time for $($tag.TagName) is not within range"
    }
}
$appropriateTags


function Get-TargetTags {
    param (
        [Parameter(Mandatory = $true)][string]$acceptedTagsList
    )
    $acceptedTagsList = ".\prodEnviro\accepted_tags.csv"
    $tagSheet = Import-Csv -Path $acceptedTagsList
    $appropriateTags = @()
    foreach ($tag in $tagSheet) {
        Set-TimeZone -Id $tag.TimeZone
        $time = Get-Date -Format "HH:mm"
        $tag.TagValue = 09
        [int]$t0 = $tag.TagValue
        $t1 = [int]$t0 + 1
        if ($time -ge $tag.TagValue -and $time -lt $t1) {
            Write-Host "True"
            $appropriateTags += $tag.TagName
        }else {
            Write-Host "False"
        }
    }
    return $appropriateTags
}

$targetTags = Get-TargetTags -acceptedTagsList ".\prodEnviro\accepted_tags.csv"
$targetTags