﻿using module ..\Include.psm1

$Path = ".\Bin\ZEnemy-NVIDIA-109a\z-enemy.exe"
$Uri = "https://mega.nz/#!CP5giJSb!p4mtA2Ullr4V4Ocd-siNAaxZYHXmDhGQvC0ztYgTuQE"

$Commands = [PSCustomObject]@{
    "bitcore" = " -N 3" #Bitcore
    "phi" = " -N 1" #Phi
    "vit" = "" #Vitalium
    "x16s" = " -N 3" #Pigeon
    "x16r" = " -N 3" #Raven
    "x17" = " -N 1" #X17
    "xevan" = "" #Xevan
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week * 0.99}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}