#Requires -Version 5.1
# =========================================================
#  OpenCode + OmO - Desinstalador
#
#  Elimina todo lo creado por install-omo.ps1:
#    - Perfil aislado OmO
#    - Config oh-my-openagent.json en rutas estandar
#    - Plugin cacheado (fuerza re-descarga limpia)
#    - Launcher y scripts en Desktop
#    - Paquete npm oh-my-opencode (opcional)
#
#  NO toca:
#    - La instalacion de OpenCode Desktop
#    - El acceso directo original de OpenCode
#    - La base de datos/data de OpenCode
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File uninstall-omo.ps1
# =========================================================

$ErrorActionPreference = "Stop"

$UserHome      = $env:USERPROFILE
$ConfigDir     = Join-Path $UserHome ".config\opencode"
$OmoProfileDir = Join-Path $UserHome ".config\opencode-omo"
$CacheDir      = Join-Path $UserHome ".cache\opencode\packages\oh-my-openagent@latest"
$AppDataOC     = Join-Path $env:APPDATA "opencode"
$DataDir       = Join-Path $UserHome ".local\share\opencode-omo"
$DesktopDir    = [Environment]::GetFolderPath("Desktop")
$ScriptRoot    = $PSScriptRoot
$Timestamp     = Get-Date -Format "yyyy-MM-dd_HHmmss"
$LogFile       = Join-Path $ScriptRoot "uninstall-omo_$Timestamp.log"

function Write-Step($msg) {
    Write-Host ""
    Write-Host ">>> $msg" -ForegroundColor Cyan
}

function Remove-SafeItem($path, $label) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    ELIMINADO: $label" -ForegroundColor Green
    } else {
        Write-Host "    SKIP: $label (no existe)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  OpenCode + OmO - Desinstalador" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  Esto eliminara:" -ForegroundColor Yellow
Write-Host "    - Perfil OmO aislado ($OmoProfileDir)" -ForegroundColor Yellow
Write-Host "    - Configs oh-my-openagent.json" -ForegroundColor Yellow
Write-Host "    - Plugin cacheado" -ForegroundColor Yellow
Write-Host "    - Launcher y scripts en Desktop" -ForegroundColor Yellow
Write-Host "    - Datos de la instancia OmO ($DataDir)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  NO se tocara: OpenCode Desktop, acceso directo original, ni datos de OpenCode." -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Continuar? (s/N)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Cancelado." -ForegroundColor Yellow
    exit 0
}

# ---- Iniciar transcripcion (log de resultados) ----
Start-Transcript -Path $LogFile -Force | Out-Null

# ---- Perfil aislado ----
Write-Step "Eliminando perfil OmO aislado..."
Remove-SafeItem $OmoProfileDir "~\.config\opencode-omo\"

# ---- Configs oh-my-openagent.json ----
Write-Step "Eliminando configs oh-my-openagent.json..."
Remove-SafeItem (Join-Path $ConfigDir "oh-my-openagent.json") "~\.config\opencode\oh-my-openagent.json"
Remove-SafeItem (Join-Path $AppDataOC "oh-my-openagent.json") "%APPDATA%\opencode\oh-my-openagent.json"

# Restaurar backup si existe
$backup = Join-Path $ConfigDir "opencode.json.bak-omo"
if (Test-Path $backup) {
    Remove-Item $backup -Force -ErrorAction SilentlyContinue
    Write-Host "    ELIMINADO: opencode.json.bak-omo" -ForegroundColor Green
}

# ---- Plugin cacheado ----
Write-Step "Eliminando plugin cacheado..."
Remove-SafeItem $CacheDir "~\.cache\opencode\packages\oh-my-openagent@latest\"

# ---- Datos de la instancia OmO ----
Write-Step "Eliminando datos de la instancia OmO..."
Remove-SafeItem $DataDir "~\.local\share\opencode-omo\"

# ---- Desktop files ----
Write-Step "Eliminando archivos del Desktop..."
Remove-SafeItem (Join-Path $DesktopDir "OpenCode-OmO.bat") "OpenCode-OmO.bat"
Remove-SafeItem (Join-Path $DesktopDir "OmO-repatch-ZWSP.ps1") "OmO-repatch-ZWSP.ps1"
Remove-SafeItem (Join-Path $DesktopDir "OmO-Setup-Reference.md") "OmO-Setup-Reference.md"

# ---- npm package (opcional) ----
Write-Step "Paquete npm oh-my-opencode..."

$npmDir = Join-Path $ConfigDir "node_modules\oh-my-opencode"
if (Test-Path $npmDir) {
    $removeNpm = Read-Host "    Desinstalar oh-my-opencode de npm tambien? (s/N)"
    if ($removeNpm -eq "s" -or $removeNpm -eq "S") {
        Push-Location $ConfigDir
        try {
            & npm uninstall oh-my-opencode 2>&1 | Out-Null
            Write-Host "    ELIMINADO: oh-my-opencode (npm)" -ForegroundColor Green
        } catch {
            Write-Host "    WARN: No se pudo desinstalar via npm: $_" -ForegroundColor Yellow
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "    SKIP: oh-my-opencode conservado en npm" -ForegroundColor Gray
    }
} else {
    Write-Host "    SKIP: oh-my-opencode no esta instalado en npm" -ForegroundColor Gray
}

# ---- Resumen ----
Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Desinstalacion completada" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  OpenCode Desktop funciona con normalidad via su acceso directo original." -ForegroundColor Gray
Write-Host ""
Write-Host "  Log de resultados: $LogFile" -ForegroundColor Gray
Write-Host ""

# ---- Detener transcripcion ----
Stop-Transcript | Out-Null

Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
