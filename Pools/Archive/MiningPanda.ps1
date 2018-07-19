﻿using module ..\Include.psm1

param(
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPanda_Request = [PSCustomObject]@{}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$MiningPanda_Request = Invoke-RestMethod "https://miningpanda.site/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPanda_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$MiningPanda_Regions = "us"
$MiningPanda_Currencies = ($MiningPanda_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}

$MiningPanda_Currencies | Where-Object {$ExcludeAlgorithm -inotcontains (Get-Algorithm $MiningPanda_Request.$_.algo) -and {$MiningPanda_Request.$_.hashrate -gt 0} | ForEach-Object {
    $MiningPanda_Host = "miningpanda.site"
    $MiningPanda_Port = $MiningPanda_Request.$_.port
    $MiningPanda_Algorithm = $MiningPanda_Request.$_.algo
    $MiningPanda_Algorithm_Norm = Get-Algorithm $MiningPanda_Algorithm
    $MiningPanda_Coin = $MiningPanda_Request.$_.name
    $MiningPanda_Currency = $_
    $MiningPanda_Fee = $MiningPanda_Request.$_.fees

    $Divisor = 1000000000

    switch ($MiningPanda_Algorithm_Norm) {
        "equihash" {$Divisor /= 1000}
        "blake2s" {$Divisor *= 1000}
    }

    $MiningPanda_Fees = 1-($MiningPanda_Fee/100)
	
    $Stat = Set-Stat -Name "$($Name)_$($MiningPanda_Algorithm_Norm)_Profit" -Value ([Double]$MiningPanda_Request.$_.estimate / $Divisor  * $MiningPanda_Fees) -Duration $StatSpan -ChangeDetection $true

    $MiningPanda_Regions | ForEach-Object {
        $MiningPanda_Region = $_
        $MiningPanda_Region_Norm = Get-Region $MiningPanda_Region

        [PSCustomObject]@{
            Algorithm     = $MiningPanda_Algorithm_Norm
            CoinName      = $MiningPanda_Coin
            Price         = $Stat.Live
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $MiningPanda_Host
            Port          = $MiningPanda_Port
            User          = Get-Variable $MiningPanda_Currency -ValueOnly
            Pass          = "$Worker,c=$MiningPanda_Currency"
            Region        = $MiningPanda_Region_Norm
            SSL           = $false
            Updated       = $Stat.Updated
            PoolFee       = $MiningPanda_Fee
        }
    }
}
