param(
    [int]$Port = 27016,
    [int]$ServerPort = 27015
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$serverProject = Join-Path $projectRoot 'server\CyrodiilMP.Server\CyrodiilMP.Server.csproj'
$serverDll = Join-Path $projectRoot 'server\CyrodiilMP.Server\bin\Debug\net10.0\CyrodiilMP.Server.dll'
$logDir = Join-Path $projectRoot '.cyrodiilmp'
$serverOut = Join-Path $logDir 'udp-sidecar-smoke.out.log'
$serverErr = Join-Path $logDir 'udp-sidecar-smoke.err.log'

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Remove-Item $serverOut, $serverErr -ErrorAction SilentlyContinue

$env:DOTNET_CLI_HOME = Join-Path $projectRoot '.dotnet-home'
$env:APPDATA = Join-Path $projectRoot '.dotnet-home\AppData\Roaming'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null

function Send-UdpText {
    param(
        [System.Net.Sockets.UdpClient]$Client,
        [System.Net.IPEndPoint]$EndPoint,
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    [void]$Client.Send($bytes, $bytes.Length, $EndPoint)
}

function Receive-UdpText {
    param(
        [System.Net.Sockets.UdpClient]$Client,
        [string]$Label,
        [int]$TimeoutMilliseconds = 500
    )

    $remote = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
    $Client.Client.ReceiveTimeout = $TimeoutMilliseconds
    try {
        $bytes = $Client.Receive([ref]$remote)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        return $null
    }
}

function Send-UntilUdpMatch {
    param(
        [System.Net.Sockets.UdpClient]$SendClient,
        [System.Net.Sockets.UdpClient]$ReceiveClient,
        [System.Net.IPEndPoint]$EndPoint,
        [string]$Text,
        [string]$Label,
        [string]$Pattern,
        [int]$TimeoutMilliseconds = 5000
    )

    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        Send-UdpText $SendClient $EndPoint $Text
        $response = Receive-UdpText $ReceiveClient $Label 400
        if ($response -and $response -match $Pattern) {
            return $response
        }
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw "Timed out waiting for $Label"
}

function Wait-ForTimedOutPlayer {
    param(
        [System.Net.Sockets.UdpClient]$HeartbeatClient,
        [System.Net.Sockets.UdpClient]$ReceiveClient,
        [System.Net.IPEndPoint]$EndPoint,
        [int]$TimeoutMilliseconds = 8000
    )

    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    $tick = 10
    do {
        $tick += 1
        Send-UdpText $HeartbeatClient $EndPoint "transform player=1 tick=$tick x=1.00 y=2.00 z=3.00 yaw=90.00"
        $response = Receive-UdpText $ReceiveClient 'timeout player-left' 500
        if ($response -and $response -match '^player-left ' -and $response -match 'reason=timeout') {
            return $response
        }
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    throw 'Timed out waiting for timeout player-left'
}

function New-LoopbackUdpClient {
    $client = [System.Net.Sockets.UdpClient]::new([System.Net.Sockets.AddressFamily]::InterNetwork)
    $client.Client.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback, 0))
    return $client
}

dotnet build $serverProject -c Debug --nologo | Out-Host

$serverProcess = Start-Process -FilePath 'dotnet' `
    -ArgumentList @($serverDll, '--port', $ServerPort.ToString(), '--native-port', $Port.ToString()) `
    -WorkingDirectory $projectRoot `
    -RedirectStandardOutput $serverOut `
    -RedirectStandardError $serverErr `
    -PassThru `
    -WindowStyle Hidden

$smokeFailed = $false
try {
    Start-Sleep -Seconds 2
    if ($serverProcess.HasExited) {
        $out = Get-Content $serverOut -Raw -ErrorAction SilentlyContinue
        $err = Get-Content $serverErr -Raw -ErrorAction SilentlyContinue
        throw "CyrodiilMP server exited before smoke test. stdout=[$out] stderr=[$err]"
    }

    $endpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $Port)
    $clientA = New-LoopbackUdpClient
    $clientB = New-LoopbackUdpClient
    $clientC = New-LoopbackUdpClient

    $welcomeA = Send-UntilUdpMatch $clientA $clientA $endpoint 'hello protocol=0 name=SmokeA' 'client A welcome' '^server-welcome '
    $welcomeB = Send-UntilUdpMatch $clientB $clientB $endpoint 'hello protocol=0 name=SmokeB' 'client B welcome' '^server-welcome '

    $remoteForB = Send-UntilUdpMatch $clientA $clientB $endpoint 'transform player=1 tick=1 x=1.00 y=2.00 z=3.00 yaw=90.00' 'remote transform for B' '^remote-transform '

    $remoteForA = Send-UntilUdpMatch $clientB $clientA $endpoint 'transform player=2 tick=1 x=4.00 y=5.00 z=6.00 yaw=180.00' 'remote transform for A' '^remote-transform '

    $leftForA = Send-UntilUdpMatch $clientB $clientA $endpoint 'disconnect player=2' 'player-left for A' '^player-left '
    $welcomeC = Send-UntilUdpMatch $clientC $clientC $endpoint 'hello protocol=0 name=SmokeC' 'client C welcome' '^server-welcome '
    $timeoutForA = Wait-ForTimedOutPlayer $clientA $clientA $endpoint

    Write-Host 'UDP sidecar smoke test passed.'
}
catch {
    $smokeFailed = $true
    throw
}
finally {
    if ($clientA) { $clientA.Dispose() }
    if ($clientB) { $clientB.Dispose() }
    if ($clientC) { $clientC.Dispose() }
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
    }

    if ($smokeFailed) {
        Write-Host '--- UDP smoke server stdout ---'
        Get-Content $serverOut -ErrorAction SilentlyContinue
        Write-Host '--- UDP smoke server stderr ---'
        Get-Content $serverErr -ErrorAction SilentlyContinue
    }
}
