#Requires -Version 5.1
# =========================================================
#  OpenCode + OmO (oh-my-openagent) - Instalador automatico
#
#  Requisitos:
#    - Windows 10/11
#    - Node.js + npm instalados y en PATH
#    - OpenCode Desktop instalado
#    - GitHub Copilot configurado como proveedor en OpenCode
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File install-omo.ps1
#
#  Que hace:
#    1. Valida prerequisitos
#    2. Instala oh-my-opencode via npm
#    3. Ejecuta el instalador de OmO (copilot-only)
#    4. Crea perfil aislado (no toca la instalacion principal)
#    5. Distribuye la config de agentes/modelos
#    6. Aplica el parche ZWSP (bug conocido en agent names)
#    7. Crea launcher en Desktop + script de re-parcheo
# =========================================================

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ---- Rutas dinamicas basadas en el usuario actual ----
$UserHome        = $env:USERPROFILE
$ConfigDir       = Join-Path $UserHome ".config\opencode"
$OmoProfileDir   = Join-Path $UserHome ".config\opencode-omo"
$CacheDir        = Join-Path $UserHome ".cache\opencode\packages\oh-my-openagent@latest\node_modules\oh-my-openagent"
$AppData         = $env:APPDATA
$AppDataOC       = Join-Path $AppData "opencode"
$DataDir         = Join-Path $UserHome ".local\share\opencode-omo"
$DesktopDir      = [Environment]::GetFolderPath("Desktop")
$ScriptRoot      = $PSScriptRoot
$Timestamp       = Get-Date -Format "yyyy-MM-dd_HHmmss"
$LogFile         = Join-Path $ScriptRoot "install-omo_$Timestamp.log"

# ---- Iniciar transcripcion (log de resultados) ----
Start-Transcript -Path $LogFile -Force | Out-Null

# ---- Detectar OpenCode Desktop ----
$OpenCodePaths = @(
    (Join-Path $env:LOCALAPPDATA "OpenCode\OpenCode.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\OpenCode\OpenCode.exe"),
    (Join-Path ${env:ProgramFiles} "OpenCode\OpenCode.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "OpenCode\OpenCode.exe")
)
$OpenCodeExe = $null
foreach ($p in $OpenCodePaths) {
    if (Test-Path $p) { $OpenCodeExe = $p; break }
}

# =========================================================
#  Funciones auxiliares
# =========================================================

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "    OK: $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "    WARN: $msg" -ForegroundColor Yellow
}

function Write-Fail($msg) {
    Write-Host "    FAIL: $msg" -ForegroundColor Red
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Copy-ConfigFile($name, $dest) {
    $src = Join-Path $ScriptRoot "config\$name"
    if (-not (Test-Path $src)) {
        Write-Fail "Archivo de config no encontrado: $src"
        throw "Missing config file: $src"
    }
    Ensure-Dir (Split-Path $dest -Parent)
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "$name -> $dest"
}

# =========================================================
#  PASO 0: Validar prerequisitos
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  OpenCode + OmO (oh-my-openagent) - Instalador" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

Write-Step "Validando prerequisitos..."

# Node.js
try {
    $nodeVersion = & node --version 2>&1
    Write-Ok "Node.js $nodeVersion"
} catch {
    Write-Fail "Node.js no encontrado en PATH. Instalalo desde https://nodejs.org"
    exit 1
}

# npm
try {
    $npmVersion = & npm --version 2>&1
    Write-Ok "npm $npmVersion"
} catch {
    Write-Fail "npm no encontrado en PATH."
    exit 1
}

# OpenCode Desktop
if ($OpenCodeExe) {
    Write-Ok "OpenCode Desktop: $OpenCodeExe"
} else {
    Write-Fail "OpenCode Desktop no encontrado. Rutas buscadas:"
    foreach ($p in $OpenCodePaths) { Write-Host "      - $p" }
    exit 1
}

# Config files in repo
$requiredConfigs = @("opencode.json", "oh-my-openagent.json")
foreach ($f in $requiredConfigs) {
    $fp = Join-Path $ScriptRoot "config\$f"
    if (Test-Path $fp) {
        Write-Ok "Config: $f"
    } else {
        Write-Fail "Falta config\$f en el repositorio"
        exit 1
    }
}

# =========================================================
#  PASO 1: Instalar oh-my-opencode via npm
# =========================================================

Write-Step "Instalando oh-my-opencode via npm..."

Ensure-Dir $ConfigDir

# Crear package.json si no existe
$pkgJson = Join-Path $ConfigDir "package.json"
if (-not (Test-Path $pkgJson)) {
    $pkgContent = '{"private": true, "dependencies": {}}'
    [System.IO.File]::WriteAllText($pkgJson, $pkgContent)
    Write-Ok "package.json creado en $ConfigDir"
}

Push-Location $ConfigDir
try {
    & npm install oh-my-opencode@latest 2>&1 | Out-Null
    Write-Ok "oh-my-opencode instalado en $ConfigDir\node_modules"
} catch {
    Write-Warn "npm install fallo: $_. Continuando (el plugin se descargara via cache)..."
} finally {
    Pop-Location
}

# =========================================================
#  PASO 2: Ejecutar instalador de OmO
# =========================================================

Write-Step 'Ejecutando instalador de OmO (--copilot=yes)...'

Push-Location $ConfigDir
try {
    & npx oh-my-opencode install --no-tui --claude=no --openai=no --gemini=no --copilot=yes --skip-auth 2>&1 | Out-Null
    Write-Ok "Instalador OmO completado"
} catch {
    Write-Warn "El instalador OmO reporto un error: $_. Continuando con setup manual..."
} finally {
    Pop-Location
}

# =========================================================
#  PASO 3: Crear perfil aislado
# =========================================================

Write-Step "Creando perfil aislado OmO..."

Ensure-Dir $OmoProfileDir
Copy-ConfigFile "opencode.json" (Join-Path $OmoProfileDir "opencode.json")

# Asegurar que NO quede opencode.json en el config global (perfil limpio)
$globalOC = Join-Path $ConfigDir "opencode.json"
if (Test-Path $globalOC) {
    # El instalador OmO puede haber creado uno aqui - moverlo
    $backupPath = Join-Path $ConfigDir "opencode.json.bak-omo"
    Move-Item -Path $globalOC -Destination $backupPath -Force
    Write-Warn "opencode.json existente movido a $backupPath (perfil global limpio)"
}

# =========================================================
#  PASO 4: Distribuir config de agentes
# =========================================================

Write-Step "Distribuyendo oh-my-openagent.json..."

# Ruta principal (donde OmO lo busca primero)
Copy-ConfigFile "oh-my-openagent.json" (Join-Path $ConfigDir "oh-my-openagent.json")

# Copia en %APPDATA%\opencode (ruta alternativa de busqueda)
Ensure-Dir $AppDataOC
Copy-ConfigFile "oh-my-openagent.json" (Join-Path $AppDataOC "oh-my-openagent.json")

# Copia de referencia en el perfil aislado
Copy-ConfigFile "oh-my-openagent.json" (Join-Path $OmoProfileDir "oh-my-openagent.json")

# =========================================================
#  PASO 5: Aplicar parche ZWSP
# =========================================================

Write-Step "Aplicando parche ZWSP (Zero-Width Space)..."

# Bug: OmO prefixa nombres de agentes con U+200B para ordenar en la UI.
# Esto causa que los lookups fallen (nombre registrado != nombre buscado).
# Fix: reemplazar los valores ZWSP por strings vacios en AGENT_LIST_SORT_PREFIXES.

$patchTargets = @(
    (Join-Path $CacheDir "dist\index.js"),
    (Join-Path $ConfigDir "node_modules\oh-my-opencode\dist\index.js")
)

$zwspChar = [char]0x200B
$patchedCount = 0

foreach ($target in $patchTargets) {
    $shortName = $target.Replace($UserHome, "~")

    if (-not (Test-Path $target)) {
        Write-Warn "No encontrado: $shortName (se parcheara cuando OmO se descargue)"
        continue
    }

    $content = [System.IO.File]::ReadAllText($target)

    if (-not $content.Contains($zwspChar)) {
        Write-Ok "Ya parcheado: $shortName"
        continue
    }

    $pattern = '(?s)(AGENT_LIST_SORT_PREFIXES\s*=\s*\{)(.*?)(\})'
    $match = [regex]::Match($content, $pattern)

    if ($match.Success) {
        $originalBlock = $match.Value
        $cleanedBlock = $originalBlock.Replace([string]$zwspChar, '')

        if ($originalBlock -ne $cleanedBlock) {
            $content = $content.Remove($match.Index, $match.Length).Insert($match.Index, $cleanedBlock)
            [System.IO.File]::WriteAllText($target, $content)
            Write-Ok "Parcheado: $shortName"
            $patchedCount++
        }
    } else {
        # Fallback: remover ZWSP globalmente
        $cleaned = $content.Replace([string]$zwspChar, '')
        [System.IO.File]::WriteAllText($target, $cleaned)
        Write-Ok "Parcheado (global): $shortName"
        $patchedCount++
    }
}

if ($patchedCount -eq 0) {
    Write-Ok "No se requirio parcheo (ya limpio o upstream arreglado)"
}

# =========================================================
#  PASO 6: Crear directorio de datos separado (Electron)
# =========================================================

Write-Step "Creando directorio de datos para instancia OmO..."

Ensure-Dir $DataDir
Write-Ok $DataDir

# =========================================================
#  PASO 7: Crear launcher en Desktop
# =========================================================

Write-Step "Creando launcher en Desktop..."

$launcherPath = Join-Path $DesktopDir "OpenCode-OmO.bat"
$launcherContent = @"
@echo off
REM =========================================================
REM  OpenCode Desktop - Perfil OmO (oh-my-openagent)
REM  Lanza OpenCode Desktop con el plugin OmO activado
REM  Perfil aislado: no afecta la instalacion principal
REM =========================================================

REM Registrar el plugin OmO mediante OPENCODE_CONFIG
set "OPENCODE_CONFIG=$OmoProfileDir\opencode.json"

REM Desactivar telemetria anonima de OmO
set "OMO_SEND_ANONYMOUS_TELEMETRY=0"
set "OMO_DISABLE_POSTHOG=1"

REM Lanzar OpenCode Desktop con user-data-dir separado
REM (permite ejecutar simultaneamente la instancia normal y la OmO)
start "" "$OpenCodeExe" --user-data-dir="$DataDir"
"@

[System.IO.File]::WriteAllText($launcherPath, $launcherContent)
Write-Ok "Launcher: $launcherPath"

# =========================================================
#  PASO 8: Copiar script de re-parcheo a Desktop
# =========================================================

Write-Step "Copiando script de re-parcheo a Desktop..."

$repatchSrc = Join-Path $ScriptRoot "repatch-zwsp.ps1"
$repatchDst = Join-Path $DesktopDir "OmO-repatch-ZWSP.ps1"

if (Test-Path $repatchSrc) {
    Copy-Item -Path $repatchSrc -Destination $repatchDst -Force
    Write-Ok "Re-patch script: $repatchDst"
} else {
    Write-Warn "repatch-zwsp.ps1 no encontrado en el repo. Copia manualmente si lo necesitas."
}

# =========================================================
#  Resumen final
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Instalacion completada" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  Perfil OmO:     $OmoProfileDir" -ForegroundColor Gray
Write-Host "  Config agentes:  $(Join-Path $ConfigDir 'oh-my-openagent.json')" -ForegroundColor Gray
Write-Host "  Launcher:        $launcherPath" -ForegroundColor Gray
Write-Host "  Re-patch script: $repatchDst" -ForegroundColor Gray
Write-Host ""
Write-Host "  Siguiente paso: doble clic en 'OpenCode-OmO.bat' en el Escritorio" -ForegroundColor Yellow
Write-Host "  El agente por defecto sera 'Sisyphus - Ultraworker'" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Despues de actualizaciones de OmO:" -ForegroundColor Yellow
Write-Host "  -> Click derecho en 'OmO-repatch-ZWSP.ps1' > Ejecutar con PowerShell" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Log de resultados: $LogFile" -ForegroundColor Gray
Write-Host ""

# ---- Detener transcripcion ----
Stop-Transcript | Out-Null

Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
