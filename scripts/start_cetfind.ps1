param(
    [int]$StartupTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host 'CETFind local startup' -ForegroundColor Cyan
Write-Host "Project: $RepoRoot"

if (-not (Test-Path (Join-Path $RepoRoot '.env.docker-local'))) {
    throw "Missing .env.docker-local. Copy .env.docker-local.example to .env.docker-local and fill in the local values before starting CETFind."
}

# Resolve Docker CLI even when this PowerShell session has an older PATH.
$DockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if ($DockerCommand) {
    $Docker = $DockerCommand.Source
} else {
    $Docker = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
    if (-not (Test-Path $Docker)) {
        throw 'Docker CLI was not found. Install Docker Desktop, then reopen VS Code.'
    }
}

# Docker Compose may call docker-credential-desktop.exe. Add the CLI folder
# to this process PATH so the helper is found even in an older VS Code session.
$DockerBin = Split-Path -Parent $Docker
if (($env:PATH -split ';') -notcontains $DockerBin) {
    $env:PATH = "$DockerBin;$env:PATH"
}

# Start Docker Desktop automatically when it is installed but not running.
$engineReady = $false
try {
    & $Docker info --format '{{.ServerVersion}}' *> $null
    $engineReady = ($LASTEXITCODE -eq 0)
} catch {
    $engineReady = $false
}

if (-not $engineReady) {
    $DockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (Test-Path $DockerDesktop) {
        Write-Host 'Starting Docker Desktop...'
        Start-Process -FilePath $DockerDesktop
    } else {
        throw 'Docker Engine is unavailable and Docker Desktop could not be found. Install/start Docker Desktop, then retry.'
    }

    $engineDeadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    do {
        Start-Sleep -Seconds 3
        try {
            & $Docker info --format '{{.ServerVersion}}' *> $null
            $engineReady = ($LASTEXITCODE -eq 0)
        } catch {
            $engineReady = $false
        }
    } while (-not $engineReady -and (Get-Date) -lt $engineDeadline)

    if (-not $engineReady) {
        throw "Docker Desktop did not become ready within $StartupTimeoutSeconds seconds. Check Docker Desktop / WSL status and retry."
    }
}

Write-Host 'Starting PostgreSQL, FastAPI and the local website...'
& $Docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml up -d --build
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Compose failed. Review the error above; no browser was launched.'
}

# Wait for both the backend health endpoint and the static frontend.
$checks = @(
    @{ Name = 'Backend API'; Url = 'http://127.0.0.1:8000/healthz' },
    @{ Name = 'Frontend'; Url = 'http://127.0.0.1:8080/' }
)
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
foreach ($check in $checks) {
    $ready = $false
    do {
        try {
            $response = Invoke-WebRequest -Uri $check.Url -UseBasicParsing -TimeoutSec 5
            $ready = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
        } catch {
            Start-Sleep -Seconds 2
        }
    } while (-not $ready -and (Get-Date) -lt $deadline)

    if (-not $ready) {
        & $Docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml ps
        throw "$($check.Name) did not become ready at $($check.Url). Check the container status above."
    }
    Write-Host "$($check.Name): ready ($($check.Url))" -ForegroundColor Green
}

Write-Host 'CETFind is ready. VS Code can now open the browser.' -ForegroundColor Green
