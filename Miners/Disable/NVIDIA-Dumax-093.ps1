﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

if (-not $Devices.NVIDIA) {return} # No NVIDIA mining device present in system

$DriverVersion = (Get-Devices).NVIDIA.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.1.00"
if ($DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers to 390.77 or newer. "
    return
}

$Type = "NVIDIA"
$Path = ".\Bin\NVIDIA-Dumax-093\ccminer.exe"
$API  = "Ccminer"
$Uri  = "https://github.com/DumaxFr/ccminer/releases/download/dumax-0.9.3/ccminer-dumax-0.9.3-win64.zip"
$Port = Get-FreeTcpPort -DefaultPort 4068
$Fee  = 0

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{Algorithm = "phi"; Params = ""; Zpool = ""; ZergpoolCoins = ""} #phi NVIDIA-TRex-051
    #[PSCustomObject]@{Algorithm = "phi2"; Params = ""; Zpool = ""; ZergpoolCoins = ""} #phi2 NVIDIA-ZEnemy-112av2
    [PSCustomObject]@{Algorithm = "x16r"; Params = ""; Zpool = ""; ZergpoolCoins = ""} #x16r
    [PSCustomObject]@{Algorithm = "x16s"; Params = ""; Zpool = ""; ZergpoolCoins = ""} #x16s
    #[PSCustomObject]@{Algorithm = "x17"; Params = ""; Zpool = ""; ZergpoolCoins = ""} #x17 NVIDIA-Alexis78-12b1
}

$CommonCommands = "" #eg. " -d 0,1,8,9"

$DeviceIDs = (Get-DeviceIDs -Config $Config -Devices $Devices -Type NVIDIA -DeviceTypeModel $($Devices.NVIDIA) -DeviceIdBase 10 -DeviceIdOffset 0)."$(if ($Type -EQ "NVIDIA"){"All"}else{$Type})"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Where-Object {$Pools.(Get-Algorithm $_.Algorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_.Algorithm
	
    $StaticDiff = $_."$($Pools.$Algorithm_Norm.Name)"

    Switch ($Algorithm_Norm) {
        "allium"        {$ExtendInterval = 3}
        "CryptoNightV7" {$ExtendInterval = 3}
        "hmq1725"       {$ExtendInterval = 3}
        "Lyra2RE2"      {$ExtendInterval = 3}
        "phi"           {$ExtendInterval = 3}
        "phi2"          {$ExtendInterval = 3}
        "tribus"        {$ExtendInterval = 3}
        "X16R"          {$ExtendInterval = 4}
        "X16S"          {$ExtendInterval = 4}
        "X17"           {$ExtendInterval = 3}
        "Xevan"         {$ExtendInterval = 3}
        default         {$ExtendInterval = 0}
    }
	
    Switch ($Algorithm_Norm) {
        "Lyra2RE2" {$Average = 1}
        "lyra2z"   {$Average = 1}
        "phi"      {$Average = 1}
        "tribus"   {$Average = 1}
        "Xevan"    {$Average = 1}
        default    {$Average = 3}
    }

    $HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week * (1 - $Fee / 100)

    [PSCustomObject]@{
        Type           = $Type
        Path           = $Path
        Arguments      = "-q -b $($Port) -a $($_.Algorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($StaticDiff)$($_.Params)$($CommonCommands) -N $($Average) --submit-stale -d $($DeviceIDs -join ',')"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API            = $API
        Port           = $Port
        URI            = $Uri
        MinerFee       = @($Fee)
        ExtendInterval = $ExtendInterval
    }
}
