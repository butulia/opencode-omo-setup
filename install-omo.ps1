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
$requiredConfigs = @("opencode.json")
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
#  PASO 2: Seleccionar suscripciones y ejecutar instalador
# =========================================================

Write-Step "Selecciona las suscripciones que tienes disponibles..."
Write-Host ""
Write-Host "    Proveedores nativos:" -ForegroundColor DarkGray
Write-Host "    [1] Claude (Anthropic)       - anthropic/ models (Opus, Sonnet, Haiku)" -ForegroundColor White
Write-Host "    [2] OpenAI / ChatGPT         - openai/ models (GPT-5.4 for Oracle)" -ForegroundColor White
Write-Host "    [3] Gemini (Google)           - google/ models (Gemini 3.1 Pro, Flash)" -ForegroundColor White
Write-Host ""
Write-Host "    Proveedores proxy:" -ForegroundColor DarkGray
Write-Host "    [4] GitHub Copilot           - github-copilot/ models (fallback)" -ForegroundColor White
Write-Host "    [5] OpenCode Zen             - opencode/ models (opencode/claude-opus-4-6, etc.)" -ForegroundColor White
Write-Host "    [6] Z.ai Coding Plan         - zai-coding-plan/glm-5 (visual-engineering fallback)" -ForegroundColor White
Write-Host "    [7] Kimi For Coding          - kimi-for-coding/k2p5 (Sisyphus/Prometheus fallback)" -ForegroundColor White
Write-Host "    [8] OpenCode Go              - opencode/ models" -ForegroundColor White
Write-Host "    [9] Vercel AI Gateway        - vercel/ models (universal proxy, always last fallback)" -ForegroundColor White
Write-Host ""
Write-Host "    Prioridad de modelos: Nativo > Copilot > OpenCode Zen > Z.ai > Kimi > Vercel" -ForegroundColor DarkGray
Write-Host ""
$selection = Read-Host "    Introduce los numeros separados por comas (ej: 1,4)"

# Nota: Claude acepta 'yes' o 'max20'; el resto solo 'yes'/'no'
$claudeFlag     = "no"
$openaiFlag     = "no"
$geminiFlag     = "no"
$copilotFlag    = "no"
$zenFlag        = "no"
$zaiFlag        = "no"
$kimiFlag       = "no"
$goFlag         = "no"
$vercelFlag     = "no"

$choices = $selection -split ',' | ForEach-Object { $_.Trim() }
foreach ($c in $choices) {
    switch ($c) {
        "1" { $claudeFlag  = "yes" }
        "2" { $openaiFlag  = "yes" }
        "3" { $geminiFlag  = "yes" }
        "4" { $copilotFlag = "yes" }
        "5" { $zenFlag     = "yes" }
        "6" { $zaiFlag     = "yes" }
        "7" { $kimiFlag    = "yes" }
        "8" { $goFlag      = "yes" }
        "9" { $vercelFlag  = "yes" }
    }
}

# Si eligio Claude, preguntar si tiene plan max20
if ($claudeFlag -eq "yes") {
    Write-Host ""
    $claudeTier = Read-Host "    Tienes el plan Claude Max 20 msgs/day? (s/N)"
    if ($claudeTier -eq "s" -or $claudeTier -eq "S") {
        $claudeFlag = "max20"
        Write-Ok "Claude: max20"
    } else {
        Write-Ok "Claude: yes"
    }
}

$enabled = @()
if ($claudeFlag  -ne "no") { $enabled += "Claude=$claudeFlag" }
if ($openaiFlag  -eq "yes") { $enabled += "OpenAI" }
if ($geminiFlag  -eq "yes") { $enabled += "Gemini" }
if ($copilotFlag -eq "yes") { $enabled += "GitHub Copilot" }
if ($zenFlag     -eq "yes") { $enabled += "OpenCode Zen" }
if ($zaiFlag     -eq "yes") { $enabled += "Z.ai" }
if ($kimiFlag    -eq "yes") { $enabled += "Kimi" }
if ($goFlag      -eq "yes") { $enabled += "OpenCode Go" }
if ($vercelFlag  -eq "yes") { $enabled += "Vercel" }

if ($enabled.Count -eq 0) {
    Write-Fail "No se selecciono ninguna suscripcion. Abortando."
    Stop-Transcript | Out-Null
    exit 1
}

Write-Ok "Suscripciones: $($enabled -join ', ')"

# Preguntar por --skip-auth
Write-Host ""
$skipAuth = Read-Host "    Omitir instrucciones de autenticacion? (s/N)"
$skipAuthFlag = ""
if ($skipAuth -eq "s" -or $skipAuth -eq "S") {
    $skipAuthFlag = "--skip-auth"
    Write-Ok "Skip auth: si"
} else {
    Write-Ok "Skip auth: no"
}

Write-Step "Ejecutando instalador de OmO..."

$installArgs = @(
    "oh-my-opencode", "install", "--no-tui",
    "--claude=$claudeFlag",
    "--openai=$openaiFlag",
    "--gemini=$geminiFlag",
    "--copilot=$copilotFlag",
    "--opencode-zen=$zenFlag",
    "--zai-coding-plan=$zaiFlag",
    "--kimi-for-coding=$kimiFlag",
    "--opencode-go=$goFlag",
    "--vercel-ai-gateway=$vercelFlag"
)
if ($skipAuthFlag -ne "") { $installArgs += $skipAuthFlag }

Push-Location $ConfigDir
try {
    & npx @installArgs 2>&1 | Out-Null
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
#  PASO 4: Parchear variants de Claude y distribuir config
# =========================================================

Write-Step "Parcheando oh-my-openagent.json generado por OmO..."

$omoConfig = Join-Path $ConfigDir "oh-my-openagent.json"

if (-not (Test-Path $omoConfig)) {
    # OmO podria haberlo dejado en AppData
    $altConfig = Join-Path $AppDataOC "oh-my-openagent.json"
    if (Test-Path $altConfig) {
        Ensure-Dir $ConfigDir
        Copy-Item -Path $altConfig -Destination $omoConfig -Force
        Write-Ok "Config encontrado en AppData, copiado a $ConfigDir"
    } else {
        Write-Fail "OmO no genero oh-my-openagent.json. Revisa la instalacion manualmente."
        Write-Fail "Docs: https://ohmyopenagent.com/docs"
        Stop-Transcript | Out-Null
        exit 1
    }
}

# Leer y parsear el config generado por OmO
$jsonRaw = [System.IO.File]::ReadAllText($omoConfig)
$config = $jsonRaw | ConvertFrom-Json

# Parchear variants de modelos Claude via github-copilot/ proxy
# El proxy de Copilot no soporta effort "max", solo low/medium/high
$claudeMaxPatched = 0

function Patch-ClaudeVariants($obj) {
    if ($null -eq $obj) { return }

    # Parchear modelo principal
    if ($obj.PSObject.Properties.Name -contains 'model' -and
        $obj.PSObject.Properties.Name -contains 'variant') {
        if ($obj.model -match '^github-copilot/claude' -and $obj.variant -eq 'max') {
            $obj.variant = 'high'
            $script:claudeMaxPatched++
        }
    }

    # Parchear fallback_models
    if ($obj.PSObject.Properties.Name -contains 'fallback_models' -and $null -ne $obj.fallback_models) {
        foreach ($fb in $obj.fallback_models) {
            if ($fb.PSObject.Properties.Name -contains 'model' -and
                $fb.PSObject.Properties.Name -contains 'variant') {
                if ($fb.model -match '^github-copilot/claude' -and $fb.variant -eq 'max') {
                    $fb.variant = 'high'
                    $script:claudeMaxPatched++
                }
            }
        }
    }
}

# Parchear agents
if ($config.PSObject.Properties.Name -contains 'agents') {
    foreach ($prop in $config.agents.PSObject.Properties) {
        Patch-ClaudeVariants $prop.Value
    }
}

# Parchear categories
if ($config.PSObject.Properties.Name -contains 'categories') {
    foreach ($prop in $config.categories.PSObject.Properties) {
        Patch-ClaudeVariants $prop.Value
    }
}

if ($claudeMaxPatched -gt 0) {
    Write-Ok "$claudeMaxPatched variant(s) 'max' -> 'high' en modelos github-copilot/claude-*"
} else {
    Write-Ok "Sin variants 'max' en modelos Copilot/Claude (nada que parchear)"
}

# Serializar y guardar
$patchedJson = $config | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($omoConfig, $patchedJson)
Write-Ok "Config parcheado: $omoConfig"

# Distribuir a rutas alternativas
Ensure-Dir $AppDataOC
Copy-Item -Path $omoConfig -Destination (Join-Path $AppDataOC "oh-my-openagent.json") -Force
Write-Ok "Copia: $(Join-Path $AppDataOC 'oh-my-openagent.json')"

Ensure-Dir $OmoProfileDir
Copy-Item -Path $omoConfig -Destination (Join-Path $OmoProfileDir "oh-my-openagent.json") -Force
Write-Ok "Copia: $(Join-Path $OmoProfileDir 'oh-my-openagent.json')"

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
Write-Host "  Documentacion: https://ohmyopenagent.com/docs" -ForegroundColor Gray
Write-Host "  Log de resultados: $LogFile" -ForegroundColor Gray
Write-Host ""

# ---- Detener transcripcion ----
Stop-Transcript | Out-Null

Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
