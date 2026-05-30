#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function ok($msg)   { Write-Host "  [+]  $msg" -ForegroundColor Green }
function fail($msg) { Write-Host "  [x]  $msg" -ForegroundColor Red; exit 1 }
function log($msg)  { Write-Host "  >>  $msg" -ForegroundColor Cyan }
function info($msg) { Write-Host "       $msg" -ForegroundColor DarkGray }
function warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function hr()       { Write-Host ("  " + ("-" * 57)) -ForegroundColor DarkGray }

$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT_DIR

# -- Args ----------------------------------------------------------------------
$USE_PROD      = $false
$USE_WEB       = $false
$EMULATOR_ONLY = $false

foreach ($arg in $args) {
    switch ($arg) {
        '--prod'          { $USE_PROD      = $true }
        '--web'           { $USE_WEB       = $true }
        '--emulator-only' { $EMULATOR_ONLY = $true }
        { $_ -in '--help', '-h' } {
            Write-Host ""
            Write-Host "  Usage: .\dev.ps1 [--prod] [--web] [--emulator-only]" -ForegroundColor White
            Write-Host ""
            Write-Host "  --prod           Connect to live Firebase instead of local emulators"
            Write-Host "  --web            Run on Chrome instead of Android"
            Write-Host "  --emulator-only  Start Firebase emulators only -- no Flutter (for integration tests)"
            Write-Host ""
            Write-Host "  Without flags: emulator mode, Flutter will ask which device" -ForegroundColor DarkGray
            Write-Host ""
            exit 0
        }
        default { fail "Unknown argument: $arg  (try --help)" }
    }
}

if ($EMULATOR_ONLY -and $USE_PROD) {
    fail "--emulator-only and --prod are mutually exclusive"
}

# -- Header --------------------------------------------------------------------
Write-Host ""
Write-Host "  CozyTalk  -  dev runner" -ForegroundColor Magenta
hr
Write-Host ""

$PLATFORM = if ($EMULATOR_ONLY) { "none (emulator-only)" }
            elseif ($USE_WEB)   { "Chrome" }
            else                { "auto-detect" }
$BACKEND  = if ($USE_PROD) { "Production Firebase" } else { "Local emulators" }

Write-Host "  Platform  $PLATFORM"
Write-Host "  Backend   $BACKEND"
Write-Host ""

if ($USE_PROD) {
    warn "You are connecting to live Firebase -- real data, real users."
    Write-Host ""
}

# -- Vertex AI credentials check -----------------------------------------------
if (-not $USE_PROD) {
    $adcFile = Join-Path $env:APPDATA 'gcloud\application_default_credentials.json'
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue) -or -not (Test-Path $adcFile)) {
        warn "Vertex AI ADC not found -- interest matching degrades to random matching."
        info "Run once: gcloud auth application-default login"
        Write-Host ""
    } else {
        ok "Vertex AI ADC ready -- interest matching enabled"
        Write-Host ""
    }
}

# -- Helpers -------------------------------------------------------------------
function Stop-ProcessOnPort([int]$Port) {
    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
}

function Test-Port([int]$Port) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try   { $tcp.Connect('127.0.0.1', $Port); $true  }
    catch { $false }
    finally { $tcp.Dispose() }
}

function Test-EmulatorsUp {
    foreach ($port in @(9099, 8080, 9000, 5001, 8085)) {
        if (-not (Test-Port $port)) { return $false }
    }
    return $true
}

# -- Emulator state ------------------------------------------------------------
$EmulatorProcess    = $null
$LogFile            = $null
$script:ExitCode    = 0
$script:SilentAbort = $false  # set before throwing so catch doesn't double-print

function Stop-Emulators {
    if ($null -ne $EmulatorProcess -and -not $EmulatorProcess.HasExited) {
        Write-Host ""
        Write-Host "  Stopping emulators..." -ForegroundColor DarkGray
        # /T kills the whole process tree (cmd.exe + firebase child).
        & taskkill /F /T /PID $EmulatorProcess.Id 2>$null
        try { $EmulatorProcess.WaitForExit(5000) | Out-Null } catch {}
    } elseif ($EMULATOR_ONLY) {
        Write-Host ""
        Write-Host "  Stopping emulators..." -ForegroundColor DarkGray
        foreach ($port in @(9099, 8080, 9000, 5001, 8085, 4000, 4400, 4500)) {
            Stop-ProcessOnPort $port
        }
    }
    if ($null -ne $LogFile) {
        Write-Host "  Session log saved -> $LogFile" -ForegroundColor DarkGray
        Write-Host "  Run .\logs.sh to view." -ForegroundColor DarkGray
    }
    Write-Host "  Done." -ForegroundColor DarkGray
    Write-Host ""
}

function Show-EmulatorTail {
    if ($null -ne $LogFile -and (Test-Path $LogFile)) {
        Get-Content $LogFile -ErrorAction SilentlyContinue |
            Select-Object -Last 20 |
            ForEach-Object { Write-Host "    $_" }
    }
}

# Prints an error and signals the outer catch to exit 1 without double-printing.
function Abort([string]$msg) {
    Write-Host ""
    Write-Host "  [x]  $msg" -ForegroundColor Red
    Write-Host ""
    $script:SilentAbort = $true
    throw $msg
}

$mobileDir    = Join-Path (Join-Path $ROOT_DIR 'apps') 'mobile'
$functionsDir = Join-Path $ROOT_DIR 'functions'

# -- Load .env from apps/mobile ------------------------------------------------
$envFile     = Join-Path $mobileDir '.env'
$envExample  = Join-Path $mobileDir '.env.example'

if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
        warn "apps/mobile/.env not found -- created from .env.example"
        info "Open apps/mobile/.env and set your GIPHY_API_KEY, then re-run."
        Write-Host ""
    }
}

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)\s*$') {
            $k = $Matches[1]; $v = $Matches[2].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
            }
        }
    }
}

if (-not $env:GIPHY_API_KEY) {
    warn "GIPHY_API_KEY is not set -- GIF picker will be disabled."
    info "Get a key at https://developers.giphy.com/ and add it to apps/mobile/.env"
    Write-Host ""
}

# -- Build Flutter args --------------------------------------------------------
$FLUTTER_ARGS = @()
if ($USE_WEB)  { $FLUTTER_ARGS += '-d', 'chrome' }
if ($USE_PROD) { $FLUTTER_ARGS += '--dart-define=USE_EMULATOR=false' }
if ($env:GIPHY_API_KEY) { $FLUTTER_ARGS += "--dart-define=GIPHY_API_KEY=$env:GIPHY_API_KEY" }

try {
    # -- Emulator startup ------------------------------------------------------
    if (-not $USE_PROD) {
        if (Test-EmulatorsUp) {
            # Another terminal already owns the emulators -- just connect.
            ok "Emulators already running -- attaching"
            info "Emulator UI -> http://127.0.0.1:4000"
            Write-Host ""
            hr
        } else {
            # No emulators detected -- this terminal will start and own them.
            foreach ($port in @(9099, 8080, 9000, 5001, 8085, 4000, 4400, 4500)) {
                Stop-ProcessOnPort $port
            }

            $logsDir = Join-Path $ROOT_DIR 'logs'
            if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
            $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
            $LogFile   = Join-Path $logsDir "emulator-$timestamp.log"

            # Rotate: keep last 10 emulator session logs.
            Get-ChildItem -Path $logsDir -Filter 'emulator-20*.log' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 10 |
                Remove-Item -Force -ErrorAction SilentlyContinue

            log "Building Cloud Functions..."
            $buildOut      = & npm --prefix $functionsDir run build 2>&1
            $buildExitCode = $LASTEXITCODE
            $buildOut | Out-File -FilePath $LogFile -Encoding utf8
            if ($buildExitCode -ne 0) {
                Write-Host ""
                Write-Host "  [x]  Build failed. Last log:" -ForegroundColor Red
                Write-Host ""
                Show-EmulatorTail
                Abort "Build failed"
            }
            ok "Functions built"

            log "Starting Firebase emulators..."
            info "Session log -> $LogFile"
            info "Emulator UI -> http://127.0.0.1:4000  (Logs tab = real-time function output)"
            info "Tip         -> .\logs.sh -f  to follow logs in another terminal"
            Write-Host ""

            # cmd.exe runs synchronously (no & / start), so it stays alive until
            # firebase exits -- HasExited on $EmulatorProcess stays meaningful.
            $emulatorCmd = "firebase emulators:start --only functions,auth,firestore,database,pubsub >> `"$LogFile`" 2>&1"
            $EmulatorProcess = Start-Process -FilePath 'cmd.exe' `
                -ArgumentList '/c', $emulatorCmd `
                -WorkingDirectory $ROOT_DIR `
                -PassThru -NoNewWindow

            $MAX_WAIT = 90

            function Wait-ForPort([string]$Name, [int]$Port) {
                $elapsed = 0
                Write-Host -NoNewline "  Waiting for $Name emulator on :$Port" -ForegroundColor DarkGray
                while (-not (Test-Port $Port)) {
                    Write-Host -NoNewline "." -ForegroundColor DarkGray
                    Start-Sleep -Seconds 1
                    $elapsed++
                    if ($elapsed -ge $MAX_WAIT) {
                        Write-Host ""
                        Write-Host "  [x]  $Name emulator didn't respond after ${MAX_WAIT}s." -ForegroundColor Red
                        Write-Host "  Last log lines:" -ForegroundColor DarkGray
                        Write-Host ""
                        Show-EmulatorTail
                        Abort "$Name emulator timed out"
                    }
                    $EmulatorProcess.Refresh()
                    if ($EmulatorProcess.HasExited) {
                        Write-Host ""
                        Write-Host "  [x]  Emulator process exited unexpectedly." -ForegroundColor Red
                        Write-Host "  Last log lines:" -ForegroundColor DarkGray
                        Write-Host ""
                        Show-EmulatorTail
                        Abort "Emulator process exited unexpectedly"
                    }
                }
                Write-Host " ready" -ForegroundColor Green
            }

            Wait-ForPort "auth"      9099
            Wait-ForPort "database"  9000
            Wait-ForPort "firestore" 8080
            Wait-ForPort "functions" 5001
            Wait-ForPort "pubsub"    8085
            ok "Emulator UI -> http://127.0.0.1:4000"
            Write-Host ""
            hr
        }
    }

    # -- Emulator-only mode ----------------------------------------------------
    if ($EMULATOR_ONLY) {
        Write-Host ""
        ok "Emulators ready"
        info "Example: cd functions; npm test"
        Write-Host ""
        hr
        Write-Host ""
        Write-Host "  Press Ctrl+C to stop emulators." -ForegroundColor DarkGray
        Write-Host ""
        while ($true) { Start-Sleep -Seconds 1 }
    }

    # -- Java compatibility guard (Android/Gradle only) ------------------------
    # Kotlin 2.1.0 (bundled in Gradle 8.x) can't parse Java 22+ version strings.
    # If the active JDK is too new, find the highest installed version that's <= 21.
    if (-not $USE_WEB -and -not $EMULATOR_ONLY) {
        $javaVer = $null
        try {
            # Select-Object -First 1 + ToString() ensures a scalar string in both
            # PS 5.1 (returns ErrorRecord objects) and PS 7 (returns strings).
            # -match on an array filters elements instead of setting $Matches.
            $javaLine = (& java -version 2>&1 | Select-Object -First 1).ToString()
            if ($javaLine -match '"(\d+)[\.\d]*"') {
                $major = [int]$Matches[1]
                if ($major -eq 1 -and $javaLine -match '"1\.(\d+)') { $major = [int]$Matches[1] }
                $javaVer = $major
            }
        } catch {}

        if ($null -ne $javaVer -and $javaVer -gt 21) {
            $jCandidate = $null

            # 1. Check registry (covers Oracle, Adoptium, Microsoft, Corretto installers)
            $regPath = 'HKLM:\SOFTWARE\JavaSoft\JDK'
            if (Test-Path $regPath) {
                $jCandidate = Get-ChildItem $regPath -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        # -as [int] returns $null instead of throwing on non-numeric key names
                        $v = ($_.PSChildName -split '\.')[0] -as [int]
                        $h = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).JavaHome
                        if ($null -ne $v -and $v -ge 11 -and $v -le 21 -and $h -and (Test-Path "$h\bin\java.exe")) {
                            [PSCustomObject]@{ Version = $v; Home = $h }
                        }
                    } | Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty Home
            }

            # 2. Fall back to scanning common install dirs
            if (-not $jCandidate) {
                $jCandidate = @(
                    'C:\Program Files\Java',
                    'C:\Program Files\Eclipse Adoptium',
                    'C:\Program Files\Microsoft',
                    'C:\Program Files\BellSoft',
                    'C:\Program Files\Amazon Corretto'
                ) | Where-Object { Test-Path $_ } |
                    ForEach-Object { Get-ChildItem -Path $_ -Directory -ErrorAction SilentlyContinue } |
                    ForEach-Object {
                        $v = ($_.Name -replace '[^\d].*', '') -as [int]
                        if ($null -ne $v -and $v -ge 11 -and $v -le 21 -and (Test-Path "$($_.FullName)\bin\java.exe")) {
                            [PSCustomObject]@{ Version = $v; Home = $_.FullName }
                        }
                    } | Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty Home
            }

            if (-not $jCandidate) {
                Abort "Java $javaVer is not supported by the Kotlin Gradle plugin (max: 21).`nInstall any JDK between 11 and 21 and re-run, or set JAVA_HOME manually."
            }

            $env:JAVA_HOME = $jCandidate
            warn "Java $javaVer detected -- using $jCandidate for Gradle"
            Write-Host ""
        }
    }

    # -- Flutter ---------------------------------------------------------------
    Write-Host ""
    $webSuffix = if ($USE_WEB) { " on Chrome" } else { "" }
    log "Starting Flutter$webSuffix..."
    Write-Host ""
    hr
    Write-Host ""

    Push-Location $mobileDir
    try {
        & flutter run @FLUTTER_ARGS
    } finally {
        Pop-Location
    }
} catch {
    if (-not $script:SilentAbort) {
        Write-Host "  [x]  $_" -ForegroundColor Red
    }
    $script:ExitCode = 1
} finally {
    if (-not $USE_PROD) { Stop-Emulators }
}
exit $script:ExitCode
