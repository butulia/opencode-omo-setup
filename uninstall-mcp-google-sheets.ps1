#Requires -Version 5.1
# =========================================================
#  uninstall-mcp-google-sheets.ps1
#
#  Elimina la configuracion del servidor MCP de Google Sheets
#  del archivo opencode.json.
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File uninstall-mcp-google-sheets.ps1
# =========================================================

# Cargar funciones compartidas (antes de StrictMode para que las funciones esten disponibles)
. "$PSScriptRoot\_mcp-helpers.ps1"

# Iniciar log lo antes posible (antes de StrictMode y ErrorAction)
$LogFile = Start-McpLog -ScriptPath $PSCommandPath -FallbackDir $PSScriptRoot -FallbackName 'uninstall-mcp-google-sheets'

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {

# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Desinstalar MCP - Google Sheets" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

# =========================================================
#  PASO 1: Resolver ruta opencode.json
# =========================================================

Write-Step "Localizando opencode.json..."
$jsonPath = Resolve-OpencodeJsonPath

# Verificar que el archivo existe
if (-not (Test-Path $jsonPath)) {
    Write-Fail "No se encontro opencode.json en: $jsonPath"
    Write-Info "No hay nada que desinstalar."
    exit 0
}

# =========================================================
#  PASO 2: Leer y verificar
# =========================================================

Write-Step "Leyendo configuracion..."
$config = Read-OpencodeJson -Path $jsonPath

# Comprobar si existe el servidor
$hasMcp    = ($config.PSObject.Properties.Name -contains 'mcp')
$hasSheets = $false
if ($hasMcp) {
    $hasSheets = ($config.mcp.PSObject.Properties.Name -contains 'google-sheets')
}

if (-not $hasSheets) {
    Write-Info "No existe configuracion de 'google-sheets' en el archivo."
    Write-Info "No hay nada que desinstalar."
    exit 0
}

# Detectar que metodo de auth se uso (para el mensaje de limpieza)
$wasServiceAccount = $false
$wasOAuth = $false
$sheetsDef = $config.mcp.'google-sheets'

if ($sheetsDef.PSObject.Properties.Name -contains 'environment') {
    $env = $sheetsDef.environment
    if ($env.PSObject.Properties.Name -contains 'GOOGLE_APPLICATION_CREDENTIALS') {
        $wasServiceAccount = $true
    }
    if ($env.PSObject.Properties.Name -contains 'GOOGLE_OAUTH_CREDENTIALS') {
        $wasOAuth = $true
    }
}

# Mostrar la configuracion actual
Write-Host ""
Write-Host "    Configuracion actual que se eliminara:" -ForegroundColor White
$preview = [PSCustomObject]@{
    mcp = [PSCustomObject]@{
        'google-sheets' = $sheetsDef
    }
}
$previewJson = $preview | ConvertTo-Json -Depth 10
foreach ($line in ($previewJson -split "`n")) {
    Write-Host "    $line" -ForegroundColor DarkCyan
}
Write-Host ""

$confirm = Read-Host "    Eliminar esta configuracion? (S/n)"
if ($confirm -ne '' -and $confirm -ne 's' -and $confirm -ne 'S') {
    Write-Info "Operacion cancelada."
    exit 0
}

# =========================================================
#  PASO 3: Eliminar
# =========================================================

Write-Step "Eliminando configuracion de Google Sheets..."

$config = Remove-McpServer -Config $config -Name 'google-sheets'

# Comprobar si el config quedo vacio
if (Test-ConfigEmpty -Config $config) {
    Write-Host ""
    Write-Host "    El archivo opencode.json ha quedado sin configuracion funcional." -ForegroundColor Yellow
    $deleteFile = Read-Host "    Eliminar el archivo? (s/N)"
    if ($deleteFile -eq 's' -or $deleteFile -eq 'S') {
        Remove-Item -Path $jsonPath -Force
        Write-Ok "Archivo eliminado: $jsonPath"
    } else {
        Write-OpencodeJson -Path $jsonPath -Config $config
    }
} else {
    Write-OpencodeJson -Path $jsonPath -Config $config
}

# =========================================================
#  PASO 4: Desinstalar paquete global (si existe)
# =========================================================

Write-Step "Limpiando paquete npm global..."

$globalCmd = Get-Command mcp-gsheets -ErrorAction SilentlyContinue
if ($globalCmd) {
    Write-Info "Desinstalando mcp-gsheets globalmente..."
    try {
        & npm uninstall -g mcp-gsheets 2>&1 | Out-Null
        Write-Ok "mcp-gsheets desinstalado globalmente."
    } catch {
        Write-Warn "No se pudo desinstalar mcp-gsheets globalmente. Puedes hacerlo manualmente:"
        Write-Warn "  npm uninstall -g mcp-gsheets"
    }
} else {
    Write-Info "No hay instalacion global de mcp-gsheets."
}

# =========================================================
#  PASO 5: Resumen
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Desinstalacion completada" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  El servidor MCP de Google Sheets ha sido eliminado de la" -ForegroundColor Gray
Write-Host "  configuracion de OpenCode." -ForegroundColor Gray
Write-Host ""

if ($wasServiceAccount) {
    Write-Host "  Limpieza adicional (manual):" -ForegroundColor Yellow
    Write-Host "  El archivo JSON de credenciales del Service Account sigue" -ForegroundColor Yellow
    Write-Host "  en tu disco. Si ya no lo necesitas:" -ForegroundColor Yellow
    Write-Host "    1. Eliminalo manualmente de tu sistema de archivos" -ForegroundColor Yellow
    Write-Host "    2. Revoca la clave desde Google Cloud Console:" -ForegroundColor Yellow
    Write-Host "       https://console.cloud.google.com/iam-admin/serviceaccounts" -ForegroundColor Cyan
    Write-Host ""
}

if ($wasOAuth) {
    Write-Host "  Limpieza adicional (manual):" -ForegroundColor Yellow
    Write-Host "  Puedes revocar el acceso de la aplicacion OAuth desde:" -ForegroundColor Yellow
    Write-Host "    https://myaccount.google.com/permissions" -ForegroundColor Cyan
    Write-Host "  Y eliminar las credenciales OAuth desde Google Cloud Console:" -ForegroundColor Yellow
    Write-Host "    https://console.cloud.google.com/apis/credentials" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "  Log: $LogFile" -ForegroundColor Gray
Write-Host ""

# ---- fin del bloque try ----
} catch {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "  ERROR INESPERADO" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    if ($_.InvocationInfo -and $_.InvocationInfo.ScriptName) {
        Write-Host "  Archivo : $($_.InvocationInfo.ScriptName)" -ForegroundColor DarkGray
        Write-Host "  Linea   : $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkGray
    }
    Write-Host "  Log     : $LogFile" -ForegroundColor DarkGray
    Write-Host ""
} finally {
    Stop-McpLog
    Write-Host "Pulsa cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
