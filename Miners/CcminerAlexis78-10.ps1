using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Alexis78-10\ccminer-alexis.exe"
$Uri = "http://ccminer.org/preview/ccminer-hsr-alexis-x86-cuda8.7z"

$Commands = [PSCustomObject]@{
    #"hsr" = "" #Hsr palginnvidia better
    #"lyra2v2" = " -i 24" #Lyra2RE2 crash
    #"c11" = " -i 21" #C11
    #"x17" = " -i 21" #X17 CcminerEnemy-103 better
    #"keccak" = "" #keccak excavatornvidia2 beter
    "blake2s" = "" #blake2s
    "x11evo" = " -N 1 -i 21" #x11evo
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Name)_$(Get-Algorithm $_)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
    }
}
