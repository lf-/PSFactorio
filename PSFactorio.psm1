function Get-FactorioToken {
    <#
    .NAME
    Get-FactorioToken

    .SYNOPSIS
    Gets a factorio.com authentication token

    .PARAMETER credential
    PSCredential containing factorio.com credentials

    .EXAMPLE
    PS C:\> Get-FactorioToken (Get-Credential)
    202cb962ac59075b964b07152d234b70
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [pscredential]$credential
    )
    $api = 'https://auth.factorio.com/api-login'
    $body = @{
        username = $credential.UserName;
        password = $credential.GetNetworkCredential().Password;
        apiVersion = 2
    }
    (Invoke-RestMethod -Uri $api -Body $body -Method Post)[0]
}

function Get-FactorioMod {
    <#
    .NAME
    Get-FactorioMod

    .SYNOPSIS
    Gets an object with the mod database information of a given mod

    .PARAMETER modName
    Name of the mod to get details on

    .EXAMPLE
    PS C:\> Get-FactorioMod FARL
    name summary                    owner    LatestVersion
    ---- -------                    -----    -------------
    FARL Fully automated rail-layer Choumiko 0.6.0
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$modName
    )
    $ErrorActionPreference = 'Stop'


    $api = 'https://mods.factorio.com/api/mods'
    $queryparams = '?page_size=max&order=alpha'

    if ($modName) {
        $api += '/' + $modName
    }

    $api += $queryparams
    Write-Verbose "Calling ${api}"
    $result = Invoke-RestMethod -Uri $api
    
    if ($modName) {
        $mods = $result
        $result.pstypenames.insert(0, 'PSFactorio.FactorioMod')
    } else {
        $mods = $result.results
        foreach ($m in $mods) {
            $m.pstypenames.Insert(0,'PSFactorio.FactorioMod')
        }
    }
    
    $mods
}

Update-TypeData -TypeName PSFactorio.FactorioMod -MemberType ScriptProperty -MemberName LatestVersion -Value {$this.releases[0].version} -Force
Update-TypeData -TypeName PSFactorio.FactorioMod -DefaultDisplayPropertySet name,summary,owner,LatestVersion -Force

function Install-FactorioMod {
    <#
    .NAME
    Install-FactorioMod

    .SYNOPSIS
    Installs a mod from mods.factorio.com given credentials and the name

    .PARAMETER mod
    Name or Mod object to install

    .PARAMETER username
    factorio.com username

    .PARAMETER authToken
    Authentication token to use. Can be left blank, in which case the cmdlet will prompt for credentials.

    .PARAMETER modsPath
    Path to the mods folder

    .EXAMPLE
    PS C:\> # Will install FARL into %appdata%\factorio\mods
    PS C:\> Install-FactorioMod FARL -username johnsmith -authToken 202cb962ac59075b964b07152d234b70
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateScript({$_ -is [string] -or 'PSFactorio.FactorioMod' -in $_.pstypenames})]
        [object]$mod,

        [Parameter(Mandatory=$true)]
        [string]$username,
        
        [Parameter(Mandatory=$false)]
        [string]$authToken,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$modsPath = $(Join-Path $env:APPDATA "Factorio\mods")
    )

    # TODO: figure out if parameter handling can be improved; this isn't ideal
    if ($mod -is [string]) {
        $mod = Get-FactorioMod $mod
    }

    if (-not $authToken) {
        Write-Verbose 'Auth token not supplied, getting one'
        Write-Host 'Enter your factorio.com credentials'
        $authToken = Get-FactorioToken
    }

    # TODO: allow installation of arbitrary releases
    $url = "https://mods.factorio.com$($mod.releases[0].download_url)?username=${username}&token=${authToken}"
    Invoke-WebRequest $url -OutFile (Join-Path $modsPath (Split-Path -Leaf $mod.releases[0].file_name))
}