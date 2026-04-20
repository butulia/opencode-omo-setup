#Requires -Version 5.1
# =========================================================
#  setup-mcp-azure-devops.ps1
#
#  Configura el servidor MCP de Azure DevOps en opencode.json
#  para conectar OpenCode con tus Work Items, repositorios,
#  pipelines, etc.
#
#  NOTA: Microsoft recomienda usar el servidor remoto MCP.
#  El servidor local @azure-devops/mcp NO soporta autenticacion PAT.
#  Repo: https://github.com/microsoft/azure-devops-mcp
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File setup-mcp-azure-devops.ps1
# =========================================================

# Cargar funciones compartidas (antes de StrictMode para que las funciones esten disponibles)
. "$PSScriptRoot\_mcp-helpers.ps1"

# Iniciar log lo antes posible (antes de StrictMode y ErrorAction)
$LogFile = Start-McpLog -ScriptPath $PSCommandPath -FallbackDir $PSScriptRoot -FallbackName 'setup-mcp-azure-devops'

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {

# =========================================================
#  PASO 0: Prerrequisitos
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Configuracion MCP - Azure DevOps" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

Write-Step "Validando prerrequisitos..."
Test-NodeVersion

# =========================================================
#  PASO 1: Resolver ruta opencode.json
# =========================================================

Write-Step "Localizando opencode.json..."
$jsonPath = Resolve-OpencodeJsonPath

# =========================================================
#  PASO 2: Datos de conexion
# =========================================================

Write-Step "Configuracion del servidor MCP remoto..."
Write-Host ""
Write-Host "    Microsoft recomienda usar el servidor MCP remoto de Azure DevOps." -ForegroundColor Yellow
Write-Host "    Este metodo es mas estable y soporta todos los tipos de cuenta." -ForegroundColor Gray
Write-Host ""
Write-Host "    Para obtener la URL del servidor MCP:" -ForegroundColor White
Write-Host "    1. Ve a https://dev.azure.com/{tu-org}/_settings/mcp" -ForegroundColor Cyan
Write-Host "    2. Habilita el servidor MCP si no esta habilitado" -ForegroundColor Gray
Write-Host "    3. Copia la URL del endpoint MCP" -ForegroundColor Gray
Write-Host ""
Write-Host "    Documentacion:" -ForegroundColor White
Write-Host "    https://learn.microsoft.com/azure/devops/mcp-server/remote-mcp-server" -ForegroundColor Cyan
Write-Host ""

$remoteUrl = Read-Host "    URL del servidor MCP remoto"
while (-not $remoteUrl -or $remoteUrl.Trim() -eq '') {
    $remoteUrl = Read-Host "    La URL no puede estar vacia. URL del servidor"
}
$remoteUrl = $remoteUrl.Trim()

Write-Host ""
Write-Host "    Para generar un token de acceso:" -ForegroundColor White
Write-Host "    1. Ve a https://dev.azure.com/{tu-org}/_usersSettings/tokens" -ForegroundColor Cyan
Write-Host "    2. Haz clic en 'Nuevo token'" -ForegroundColor Gray
Write-Host "    3. Nombre: OpenCode MCP" -ForegroundColor Gray
Write-Host "    4. Organizacion: Selecciona tu organizacion" -ForegroundColor Gray
Write-Host "    5. Expiracion: Elige la duracion (recomendado: 90 dias)" -ForegroundColor Gray
Write-Host "    6. Permisos personalizados (selecciona los que necesites):" -ForegroundColor Gray
Write-Host "       - Work Items: Read & Write" -ForegroundColor Gray
Write-Host "       - Code: Read & Write (si usas repositorios)" -ForegroundColor Gray
Write-Host "       - Build: Read (si usas pipelines)" -ForegroundColor Gray
Write-Host "       - Project: Read" -ForegroundColor Gray
Write-Host "    7. Copia el token (solo se muestra una vez)" -ForegroundColor Gray
Write-Host ""

$bearerToken = Read-Host "    Token de acceso (PAT)" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($bearerToken)
$tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

while (-not $tokenPlain -or $tokenPlain.Trim() -eq '') {
    Write-Host "    El token no puede estar vacio." -ForegroundColor Red
    $bearerToken = Read-Host "    Token de acceso (PAT)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($bearerToken)
    $tokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

Write-Ok "URL: $remoteUrl"
Write-Ok "Token: $(($tokenPlain.Substring(0, [Math]::Min(8, $tokenPlain.Length))))..."

$serverDef = [PSCustomObject]@{
    type    = 'remote'
    url     = $remoteUrl
    enabled = $true
    headers = [PSCustomObject]@{
        Authorization = "Bearer $tokenPlain"
    }
}

# Limpiar token de memoria
$tokenPlain = $null

# =========================================================
#  PASO 3: Verificacion
# =========================================================

Write-Step "Verificando..."
Write-Info "Comprobando que la URL es alcanzable..."
try {
    $response = Invoke-WebRequest -Uri $remoteUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Ok "URL alcanzable (HTTP $($response.StatusCode))."
} catch {
    Write-Warn "No se pudo verificar la URL: $_"
    Write-Warn "Se configurara igualmente. Verifica la URL manualmente si hay problemas."
}

# =========================================================
#  PASO 4: Escribir configuracion
# =========================================================

Write-Step "Guardando configuracion..."

$config = Read-OpencodeJson -Path $jsonPath
$config = Set-McpServer -Config $config -Name 'azure-devops' -ServerDef $serverDef
Write-OpencodeJson -Path $jsonPath -Config $config

# =========================================================
#  PASO 5: Resumen
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Configuracion completada" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  Archivo: $jsonPath" -ForegroundColor Gray
Write-Host ""
Write-Host "  Configuracion generada:" -ForegroundColor Gray

# Mostrar solo el bloque del servidor
$preview = [PSCustomObject]@{
    mcp = [PSCustomObject]@{
        'azure-devops' = $serverDef
    }
}
$previewJson = $preview | ConvertTo-Json -Depth 10
Write-Host ""
foreach ($line in ($previewJson -split "`n")) {
    Write-Host "    $line" -ForegroundColor DarkCyan
}
Write-Host ""

Write-Host "  El servidor MCP remoto esta configurado y listo para usar." -ForegroundColor Yellow
Write-Host "  Si el token expira, vuelve a ejecutar este script para actualizarlo." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Documentacion: https://github.com/microsoft/azure-devops-mcp" -ForegroundColor Gray
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
