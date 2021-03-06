using module ..\Include.psm1

class BMiner : Miner {
    [PSCustomObject]GetMinerData ([String[]]$Algorithm, [Bool]$Safe = $false) {
        if ($_.Status -NE "Running"){return @()}
        $Server = "localhost"
        $Timeout = 10 #seconds

        $Delta = 0.05
        $Interval = 5
        $HashRates = @()

        $PowerDraws = @()
        $ComputeUsages = @()
        
        if ($this.index -eq $null -or $this.index -le 0) {
            
            # Supports max. 20 cards
            $Index = @()
            for ($i = 0; $i -le 20; $i++) {$Index += $i}               
        }
        else {
            $Index = $this.index
        }

        $URI = "http://$($Server):$($this.Port)/api/status"

        do {
            $HashRates += $HashRate = [PSCustomObject]@{}

            try {
                $Response = Invoke-WebRequest $URI -UseBasicParsing -TimeoutSec $Timeout -ErrorAction Stop
                $Data = $Response | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Write-Log -Level "Error" "$($this.API) API failed to connect to miner ($($this.Name)). Could not read hash rates from miner."
                break
            }
            
            $HashRate_Value = 0
            $Index | Where  {$Data.miners.$_.solver} | ForEach {
                $HashRate_Value += [Double]$Data.miners.$_.solver.solution_rate
            }

            $HashRate_Name = [String]$Algorithm[0]
            if ($Algorithm[0] -match ".+NiceHash") {
                $HashRate_Name = "$($HashRate_Name)Nicehash"
            }

            if ($HashRate_Name -and ($Algorithm -like (Get-Algorithm $HashRate_Name)).Count -eq 1) {
                $HashRate | Add-Member @{(Get-Algorithm $HashRate_Name) = [Int64]$HashRate_Value}
            }

            $Algorithm | Where-Object {-not $HashRate.$_} | ForEach-Object {break}

            if (-not $Safe) {break}

            Start-Sleep $Interval
        } while ($HashRates.Count -lt 6)

        $HashRate = [PSCustomObject]@{}
        $Algorithm | ForEach-Object {$HashRate | Add-Member @{$_ = [Int64]($HashRates.$_ | Measure-Object -Maximum -Minimum -Average | Where-Object {$_.Maximum - $_.Minimum -le $_.Average * $Delta}).Maximum}}
        $Algorithm | Where-Object {-not $HashRate.$_} | Select-Object -First 1 | ForEach-Object {$Algorithm | ForEach-Object {$HashRate.$_ = [Int]0}}

        return [PSCustomObject]@{
            HashRate = $HashRate
        }
    }
}
