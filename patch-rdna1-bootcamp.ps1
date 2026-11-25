[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DriverRoot
)
$ErrorActionPreference = 'Stop'
$InfName = 'u0206089.inf'
$ExpectedDriverVersion = '32.0.21045.29003'
$PciId = 'PCI\VEN_1002&DEV_7340&SUBSYS_0210106B&REV_43'
$DeviceLine = '"AMD Radeon Pro 5300M (Apple Boot Camp)" = ati2mtag_Navi14, ' + $PciId
$FalconSection = @'
[falcon_navi]
HKR,,DalDPSkipPowerOff,%REG_DWORD%,1
HKR,,DalFeatureBacklightControl,%REG_DWORD%,0
HKR,,DALNonStandardModesBCD1,%REG_BINARY%,20,48,12,80,00,00,00,60,19,20,12,00,00,00,00,60,23,04,14,40,00,00,00,60,17,92,11,20,00,00,00,60,37,58,22,40,00,00,00,60
HKR,,DalPSRFeatureEnable,%REG_DWORD%,0
HKR,,DisableWorkstation,%REG_DWORD%,1
HKR,,KMD_BootCampPlatform,%REG_DWORD%,1
HKR,,KMD_EnableBrightnessInterface2,%REG_DWORD%,0
HKR,,PP_Apple_Bootcamp_Enable,%REG_DWORD%,1
HKR,,PP_EnableLoadFalconSmcFirmware,%REG_DWORD%,1
HKR,,PP_Falcon_QuickTransition_Enable,%REG_DWORD%,1
HKR,,PP_VariBrightFeatureEnable,%REG_DWORD%,0
'@
if (-not $DriverRoot) {
    $DriverRoot = Read-Host 'Enter the path to the extracted AMD Adrenalin 26.11.2 folder'
}
if (-not (Test-Path -LiteralPath $DriverRoot -PathType Container)) {
    throw "Folder not found: $DriverRoot"
}
$matches = @(Get-ChildItem -LiteralPath $DriverRoot -Filter $InfName -File -Recurse)
if ($matches.Count -ne 1) {
    throw "Expected exactly one $InfName under '$DriverRoot'; found $($matches.Count). Extract the AMD 26.11.2 package first and point to its root folder."
}
$InfPath = $matches[0].FullName
# Preserve the INF's existing encoding.
$bytes = [System.IO.File]::ReadAllBytes($InfPath)
if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $encoding = [System.Text.Encoding]::Unicode
} elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    $encoding = [System.Text.Encoding]::BigEndianUnicode
} elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $encoding = New-Object System.Text.UTF8Encoding($true)
} else {
    $encoding = [System.Text.Encoding]::Default
}
$content = $encoding.GetString($bytes)
if ($content -notmatch "(?im)^DriverVer\s*=\s*[^,\r\n]+,\s*$([regex]::Escape($ExpectedDriverVersion))\s*$") {
    throw "Wrong driver INF. Expected DriverVer $ExpectedDriverVersion (Adrenalin 26.11.2 RDNA1 package); found a different version."
}
if ($content -notmatch '(?im)^CatalogFile\s*=\s*u0206089\.cat\s*$') {
    throw "The INF does not reference u0206089.cat. Refusing to patch an unexpected package."
}
function Update-InfSection {
    param([string]$Text, [string]$SectionName, [scriptblock]$Editor)
    $headerPattern = "(?im)^\[$([regex]::Escape($SectionName))\][ \t]*\r?$"
    $header = [regex]::Match($Text, $headerPattern)
    if (-not $header.Success) {
        throw "Required INF section [$SectionName] was not found. The AMD INF layout may have changed."
    }
    $bodyStart = $header.Index + $header.Length
    $remaining = $Text.Substring($bodyStart)
    $nextHeader = [regex]::Match($remaining, '(?m)^\[[^\r\n]+\][ \t]*\r?$')
    if ($nextHeader.Success) {
        $sectionEnd = $bodyStart + $nextHeader.Index
    } else {
        $sectionEnd = $Text.Length
    }
    $sectionText = $Text.Substring($header.Index, $sectionEnd - $header.Index)
    $editedSection = & $Editor $sectionText
    return $Text.Substring(0, $header.Index) + $editedSection + $Text.Substring($sectionEnd)
}
$content = Update-InfSection -Text $content -SectionName 'ATI.Mfg.NTamd64.10.0.1..19044' -Editor {
    param($section)
    if ($section -match [regex]::Escape($PciId)) {
        if ($section -notmatch '(?im)^\s*"[^"]+"\s*=\s*ati2mtag_Navi14,\s*PCI\\VEN_1002&DEV_7340&SUBSYS_0210106B&REV_43\s*$') {
            throw 'The Apple PCI ID already exists with an unexpected mapping. Manual review required.'
        }
    } else {
        $firstLine = [regex]::Match($section, '(?m)^\[[^\r\n]+\]\s*\r?\n')
        if (-not $firstLine.Success) { throw 'Could not locate the manufacturer section header.' }
        $section = $section.Insert($firstLine.Length, $DeviceLine + "\`r\`n")
    }
    return $section
}
$content = Update-InfSection -Text $content -SectionName 'ati2mtag_Navi14' -Editor {
    param($section)
    $section = [regex]::Replace(
        $section,
        '(?im)^[ \t]*ExcludeID[ \t]*=[ \t]*PCI\\VEN_1002&DEV_7340&SUBSYS_0210106B(?:&REV_[0-9A-F]+)?[^\r\n]*(?:\r?\n|$)',
        ''
    )
    if ($section -notmatch '(?im)^\s*AddReg\s*=\s*falcon_navi\s*$') {
        $delReg = [regex]::Match($section, '(?im)^[ \t]*DelReg[ \t]*=[ \t]*ati2mtag_RemoveDeviceSettings[ \t]*$')
        if (-not $delReg.Success) { throw 'Could not find the DelReg anchor inside [ati2mtag_Navi14].' }
        $section = $section.Insert($delReg.Index, "AddReg = falcon_navi\`r\`n")
    }
    return $section
}
if ($content -match '(?im)^\[falcon_navi\][ \t]*\r?$') {
    $content = Update-InfSection -Text $content -SectionName 'falcon_navi' -Editor {
        param($section)
        return $FalconSection + "\`r\`n"
    }
} else {
    $content = $content.TrimEnd() + "\`r\`n\`r\`n" + $FalconSection + "\`r\`n"
}
$backup = "$InfPath.pre-bootcamp.bak"
if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $InfPath -Destination $backup
}
[System.IO.File]::WriteAllText($InfPath, $content, $encoding)
$verify = [System.IO.File]::ReadAllText($InfPath, $encoding)
$checks = @(
    $verify -match [regex]::Escape($PciId),
    $verify -match '(?im)^\[ati2mtag_Navi14\]',
    $verify -match '(?im)^\[falcon_navi\]',
    $verify -match '(?im)^\s*AddReg\s*=\s*falcon_navi\s*$',
    $verify -match '(?im)^\s*HKR,,DalPSRFeatureEnable,%REG_DWORD%,0\s*$',
    $verify -match '(?im)^\s*HKR,,KMD_BootCampPlatform,%REG_DWORD%,1\s*$',
    $verify -match '(?im)^\s*HKR,,PP_Apple_Bootcamp_Enable,%REG_DWORD%,1\s*$'
)
if ($checks -contains $false) {
    throw 'Post-patch verification failed. Restore the .pre-bootcamp.bak file and inspect the INF manually.'
}
Write-Host ''
Write-Host 'Patch applied successfully:' -ForegroundColor Green
Write-Host "  INF:     $InfPath"
Write-Host "  Backup:  $backup"
Write-Host "  PCI ID:  $PciId"
Write-Host ''
Write-Warning 'Editing the INF invalidates the original AMD catalog signature. This script does NOT sign or install the driver.'
Write-Warning 'Do not install this modified package until its catalog has been regenerated and signed for your Windows test/signing configuration.'
