﻿using module ..\Include.psm1

param(
    [alias("UserName")]
    [String]$User, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$MiningPoolHub_Request = [PSCustomObject]@{}

try {
    $MiningPoolHub_Request = Invoke-RestMethod "http://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($MiningPoolHub_Request.return | Measure-Object).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

try {
    $MiningPoolHub_Variance = Invoke-RestMethod "https://semitest.000webhostapp.com/variance/mph.variance.txt" -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
}
catch {
    Write-Log -Level Warn "Pool Variance ($Name) has failed. Mining Without variance in calcualtion."
}

$MiningPoolHub_Regions = "europe", "us-east", "asia"

$MiningPoolHub_Request.return | Where-Object {$ExcludeAlgorithm -inotcontains (Get-Algorithm $_.algo)} | Where-Object {$ExcludeCoin -inotcontains $_.current_mining_coin -and ($Coin.count -eq 0 -or $Coin -icontains $_.current_mining_coin)} | ForEach-Object {
    $MiningPoolHub_Hosts = $_.all_host_list.split(";")
    $MiningPoolHub_Port = $_.algo_switch_port
    $MiningPoolHub_Algorithm = $_.algo
    $MiningPoolHub_Algorithm_Norm = Get-Algorithm $MiningPoolHub_Algorithm
    $MiningPoolHub_Coin = (Get-Culture).TextInfo.ToTitleCase(($_.current_mining_coin -replace "-", " " -replace "_", " ")) -replace " "
    $MiningPoolHub_Fee = 0.9

    $Divisor = 1000000000
	
	if($MiningPoolHub_Coin -eq "Ethereum") {$MiningPoolHub_Fee = 0} #valid until 180630
    $MiningPoolHub_Fees = 1-($MiningPoolHub_Fee/100)
	
    $Variance = 1 - $MiningPoolHub_Variance.$MiningPoolHub_Algorithm_Norm
	
    if ($Variance -ne 0){$Variance -= 0.01}
	
    $Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Algorithm_Norm)_Profit" -Value ([Double]$_.profit / $Divisor) -Duration $StatSpan -ChangeDetection $true
	
    $Stat.Live = $Stat.Live * $MiningPoolHub_Fees * $Variance
    $Stat.Week = $Stat.Week * $MiningPoolHub_Fees * $Variance
    $Stat.Week_Fluctuation = $Stat.Week_Fluctuation * $MiningPoolHub_Fees * $Variance
	
    $MiningPoolHub_Regions | ForEach-Object {
        $MiningPoolHub_Region = $_
        $MiningPoolHub_Region_Norm = Get-Region ($MiningPoolHub_Region -replace "^us-east$", "us")

        if ($User) {
            [PSCustomObject]@{
                Algorithm     = $MiningPoolHub_Algorithm_Norm
                CoinName      = $MiningPoolHub_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                Port          = $MiningPoolHub_Port
                User          = "$User.$Worker"
                Pass          = "x"
                Region        = $MiningPoolHub_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
                PoolFee       = $MiningPoolHub_Fee
                Variance      = $Variance
            }
            
                if ($MiningPoolHub_Algorithm_Norm -eq "Equihash") {
                    [PSCustomObject]@{
                        Algorithm     = $MiningPoolHub_Algorithm_Norm
                        CoinName      = $MiningPoolHub_Coin
                        Price         = $Stat.Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+ssl"
                        Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$MiningPoolHub_Region*"} | Select-Object -First 1
                        Port          = $MiningPoolHub_Port
                        User          = "$User.$Worker"
                        Pass          = "x"
                        Region        = $MiningPoolHub_Region_Norm
                        SSL           = $true
                        Updated       = $Stat.Updated
                        PoolFee       = $MiningPoolHub_Fee
                        Variance      = $Variance
                    }
                }
        }
    }
}