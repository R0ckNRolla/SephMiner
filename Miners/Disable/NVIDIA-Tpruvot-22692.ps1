﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

if (-not $Devices.NVIDIA) {return} # No NVIDIA mining device present in system

$DriverVersion = (Get-Devices).NVIDIA.Platform.Version -replace ".*CUDA ",""
$RequiredVersion = "9.2.00"
if ($DriverVersion -lt $RequiredVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredVersion) or above (installed version is $($DriverVersion)). Please update your Nvidia drivers to 397.93 or newer. "
    return
}

$Type = "NVIDIA"
$Path = ".\Bin\NVIDIA-TPruvot-22692\ccminer.exe"
$API  = "Ccminer"
$Uri  = "http://semitest.000webhostapp.com/binary/CCMiner%202.2.6R2.7z"
$Port = Get-FreeTcpPort -DefaultPort 4068
$Fee  = 0

$Commands = [PSCustomObject]@{
    #"allium"     = "" #allium CcminerTpruvot-23
    #"bitcore"     = ""#bitcore CcminerZEnemy-111v3
    #"blake2s"     = "" #Blake2s
    "bmw"         = "" #bmw
    #"c11"         = "" #C11 CcminerZEnemy-111v3
    "deep"        = "" #deep
    "dmd-gr"      = "" #dmd-gr
    "fresh"       = "" #fresh
    "fugue256"    = "" #fugue256
    "heavy"       = "" #heavy
    #"hsr"         = " -N 3" #hsr
    #"hmq1725"     = " -N 3" #hmq1725 crash
    "jha"         = "" #JHA
    #"keccak"      = " -m 2" #Keccak
    #"keccakc"     = "" #keccakc CcminerAlexis78-12
    "luffa"       = "" #luffa
    "lyra2"       = "" #lyra2
    #"lyra2v2"     = "" #Lyra2RE2
    #"lyra2z"      = "" #Lyra2z
    "mjollnir"    = "" #mjollnir
    #"neoscrypt"   = "" #NeoScrypt PalginNvidiaFork-45ee8fa
    "penta"       = "" #penta
    #"phi"         = "" #phi CcminerZEnemy-111v3
    #"phi2"         = "" #phi2 CcminerTpruvot-226
    "polytimos"   = "" #polytimos
    "scrypt-jane" = "" #scrypt-jane
    "s3"          = "" #s3
    #"sha256t"     = "" #sha256t NVIDIA-Tpruvot-22691
    "skein2"      = "" #Skein2
    #"skunk"       = "" #Skunk CcminerZEnemy-111v3
    #"timetravel"  = "" #Timetravel CcminerZEnemy-111v3
    #"tribus"      = "" #Tribus CcminerZEnemy-111v3
	#"x11evo"      = "" #X11evo CcminerAlexis78-12
    "x12"         = "" #X12
    #"x16r"        = "" #X16r
    #"x16s"        = "" #X16s
    #"x17"         = "" #X17 CcminerZEnemy-111v3
    "whirlpool"   = "" #whirlpool
    "wildkeccak"  = "" #wildkeccak
    "zr5"         = "" #zr5
}

$CommonCommands = "" #eg. " -d 0,1,8,9"

$DeviceIDs = (Get-DeviceIDs -Config $Config -Devices $Devices -Type NVIDIA -DeviceTypeModel $($Devices.NVIDIA) -DeviceIdBase 10 -DeviceIdOffset 0)."$(if ($Type -EQ "NVIDIA"){"All"}else{$Type})"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_
	
    Switch ($Algorithm_Norm) {
        "allium"        {$ExtendInterval = 2}
        "CryptoNightV7" {$ExtendInterval = 2}
        "Lyra2RE2"      {$ExtendInterval = 2}
        "phi"           {$ExtendInterval = 2}
        "phi2"          {$ExtendInterval = 2}
        "tribus"        {$ExtendInterval = 2}
        "X16R"          {$ExtendInterval = 3}
        "X16S"          {$ExtendInterval = 3}
        "X17"           {$ExtendInterval = 2}
        "Xevan"         {$ExtendInterval = 2}
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
        Arguments      = "-q -b $($Port) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)$($CommonCommands) -N $($Average) --submit-stale -d $($DeviceIDs -join ',')"
        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
        API            = $API
        Port           = $Port
        URI            = $Uri
        MinerFee       = @($Fee)
        ExtendInterval = $ExtendInterval
    }
}
