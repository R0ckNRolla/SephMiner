using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-FireIceJK-244\xmr-stak.exe"
$Uri = "https://semitest.000webhostapp.com/binary/xmr-stak-JK_2.4.4.zip"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3334
$Fee = 0

$Commands = [PSCustomObject]@{
    "cryptonight_heavy"       = "" #CryptoNightHeavy --nvidia cnheavy.txt
    "cryptonight_lite_v7"     = "" #CryptoNightLiteV7 --nvidia cnlitev7.txt
    "cryptonight_lite_v7_xor" = "" #CryptoNightLiteV7xor --nvidia cnlitev7xor.txt
    "cryptonight_V7"          = "" #CryptoNightV7 --nvidia cn7.txt
    "cryptonight_V7_stellite" = "" #CryptoNightV7stellite --nvidia cn7stellite.txt
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

$Algorithm_Norm = Get-Algorithm $_

$HashRate = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week * (1 - $Fee / 100)

([PSCustomObject]@{
        pool_list       = @([PSCustomObject]@{
                pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                wallet_address  = "$($Pools.$Algorithm_Norm.User)"
                pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
                rig_id = ""
                use_nicehash    = $true
                use_tls         = $Pools.$Algorithm_Norm.SSL
                tls_fingerprint = ""
                pool_weight     = 1
            }
        )
        currency        = "$_"
        call_timeout    = 10
        retry_time      = 10
        giveup_limit    = 0
        verbose_level   = 3
        print_motd      = $true
        h_print_time    = 60
        aes_override    = $null
        use_slow_memory = "warn"
        tls_secure_algo = $true
        daemon_mode     = $false
        flush_stdout    = $false
        output_file     = ""
        httpd_port      = $Port
        http_login      = ""
        http_pass       = ""
        prefer_ipv4     = $true
    } | ConvertTo-Json -Depth 10
) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_Cpu.txt" -Force -ErrorAction SilentlyContinue

	[PSCustomObject]@{
    Type      = "CPU"
    Path      = $Path
    Arguments = "-C $($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_Cpu.txt -c $($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_Cpu.txt --noUAC --noAMD --noNVIDIA $($Commands.$_)"
    HashRates = [PSCustomObject]@{$Algorithm_Norm = $HashRate}
    API       = "XMRig"
    Port      = $Port
    URI       = $Uri
    MinerFee  = @($Fee)
	}
}