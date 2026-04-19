#Requires -Version 5.1
# =========================================================
#  uninstall-mcp-azure-devops.ps1
#
#  Elimina la configuracion del servidor MCP de Azure DevOps
#  del archivo opencode.json.
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File uninstall-mcp-azure-devops.ps1
# =========================================================

# Cargar funciones compartidas (antes de StrictMode para que las funciones esten disponibles)
. "$PSScriptRoot\_mcp-helpers.ps1"

# Iniciar log lo antes posible (antes de StrictMode y ErrorAction)
$LogFile = Start-McpLog -ScriptPath $PSCommandPath -FallbackDir $PSScriptRoot -FallbackName 'uninstall-mcp-azure-devops'

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {

# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Desinstalar MCP - Azure DevOps" -ForegroundColor White
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
$hasMcp   = ($config.PSObject.Properties.Name -contains 'mcp')
$hasAzure = $false
if ($hasMcp) {
    $hasAzure = ($config.mcp.PSObject.Properties.Name -contains 'azure-devops')
}

if (-not $hasAzure) {
    Write-Info "No existe configuracion de 'azure-devops' en el archivo."
    Write-Info "No hay nada que desinstalar."
    exit 0
}

# Mostrar la configuracion actual
Write-Host ""
Write-Host "    Configuracion actual que se eliminara:" -ForegroundColor White
$preview = [PSCustomObject]@{
    mcp = [PSCustomObject]@{
        'azure-devops' = $config.mcp.'azure-devops'
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

Write-Step "Eliminando configuracion de Azure DevOps..."

$config = Remove-McpServer -Config $config -Name 'azure-devops'

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
#  PASO 4: Resumen
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Desinstalacion completada" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  El servidor MCP de Azure DevOps ha sido eliminado de la" -ForegroundColor Gray
Write-Host "  configuracion de OpenCode." -ForegroundColor Gray
Write-Host ""
Write-Host "  Nota: el paquete @azure-devops/mcp se descarga bajo demanda" -ForegroundColor Gray
Write-Host "  con npx. No hay nada que desinstalar del sistema." -ForegroundColor Gray
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
