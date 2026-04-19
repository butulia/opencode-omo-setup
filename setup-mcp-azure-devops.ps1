#Requires -Version 5.1
# =========================================================
#  setup-mcp-azure-devops.ps1
#
#  Configura el servidor MCP de Azure DevOps en opencode.json
#  para conectar OpenCode con tus Work Items, repositorios,
#  pipelines, etc.
#
#  Paquete oficial: @azure-devops/mcp (Microsoft)
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
#  PASO 2: Elegir modo (local vs remoto)
# =========================================================

Write-Step "Elige como quieres conectar con Azure DevOps..."
Write-Host ""
Write-Host "    [1] Local (recomendado)" -ForegroundColor White
Write-Host "        El servidor MCP se ejecuta en tu maquina via npx." -ForegroundColor Gray
Write-Host "        La autenticacion se hace via navegador (login con tu" -ForegroundColor Gray
Write-Host "        cuenta Microsoft) la primera vez que uses una herramienta." -ForegroundColor Gray
Write-Host ""
Write-Host "        Necesitaras tener a mano:" -ForegroundColor Yellow
Write-Host "          - El nombre de tu organizacion en Azure DevOps" -ForegroundColor Yellow
Write-Host "            (lo encuentras en https://dev.azure.com/<AQUI>)" -ForegroundColor Yellow
Write-Host "          - Acceso a un navegador para el login inicial" -ForegroundColor Yellow
Write-Host "          - Tu cuenta Microsoft debe tener acceso a la org" -ForegroundColor Yellow
Write-Host ""
Write-Host "    [2] Remoto (preview)" -ForegroundColor White
Write-Host "        Servidor MCP alojado por Microsoft. No ejecuta nada" -ForegroundColor Gray
Write-Host "        en local. Conexion directa al servicio en la nube." -ForegroundColor Gray
Write-Host ""
Write-Host "        Necesitaras tener a mano:" -ForegroundColor Yellow
Write-Host "          - La URL del MCP server remoto de tu organizacion" -ForegroundColor Yellow
Write-Host "            (proporcionada por Azure DevOps, consulta:" -ForegroundColor Yellow
Write-Host "            https://learn.microsoft.com/azure/devops/" -ForegroundColor Yellow
Write-Host "            mcp-server/remote-mcp-server)" -ForegroundColor Yellow
Write-Host "          - Un token de autorizacion (Bearer) generado desde" -ForegroundColor Yellow
Write-Host "            Azure DevOps para autenticar las peticiones" -ForegroundColor Yellow
Write-Host ""

$modeChoice = Read-Host "    Selecciona [1] o [2]"
while ($modeChoice -ne '1' -and $modeChoice -ne '2') {
    $modeChoice = Read-Host "    Opcion no valida. Selecciona [1] o [2]"
}

$isLocal = ($modeChoice -eq '1')

# =========================================================
#  PASO 3: Datos de conexion
# =========================================================

$serverDef = $null

if ($isLocal) {
    # ---- MODO LOCAL ----
    Write-Step "Configuracion local..."

    # Nombre de la organizacion
    Write-Host ""
    Write-Host "    Introduce el nombre de tu organizacion en Azure DevOps." -ForegroundColor White
    Write-Host "    Es la parte que aparece en la URL: https://dev.azure.com/<nombre>" -ForegroundColor Gray
    Write-Host ""
    $orgName = Read-Host "    Organizacion"
    while (-not $orgName -or $orgName.Trim() -eq '') {
        $orgName = Read-Host "    El nombre no puede estar vacio. Organizacion"
    }
    $orgName = $orgName.Trim()
    Write-Ok "Organizacion: $orgName"

    # Dominios
    Write-Step "Selecciona los dominios que quieres habilitar..."
    Write-Host ""
    Write-Host "    Los dominios determinan que herramientas estaran disponibles." -ForegroundColor Gray
    Write-Host "    Puedes seleccionar varios separados por comas." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    [1] work-items       - Gestionar Work Items (tareas, bugs, historias)" -ForegroundColor White
    Write-Host "    [2] repositories     - Acceder a repositorios y codigo" -ForegroundColor White
    Write-Host "    [3] pipelines        - Consultar pipelines de CI/CD" -ForegroundColor White
    Write-Host "    [4] wiki             - Acceder a la wiki del proyecto" -ForegroundColor White
    Write-Host "    [5] search           - Buscar en codigo y work items" -ForegroundColor White
    Write-Host "    [6] core             - Proyectos y equipos" -ForegroundColor White
    Write-Host "    [7] work             - Boards, sprints, backlogs" -ForegroundColor White
    Write-Host "    [8] test-plans       - Planes de pruebas" -ForegroundColor White
    Write-Host "    [9] advanced-security - Seguridad avanzada" -ForegroundColor White
    Write-Host ""
    Write-Host "    Por defecto: 1,2 (work-items + repositories)" -ForegroundColor DarkGray
    Write-Host ""

    $domainInput = Read-Host "    Dominios (ej: 1,2,3 o Enter para defecto)"

    $domainMap = @{
        '1' = 'work-items'
        '2' = 'repositories'
        '3' = 'pipelines'
        '4' = 'wiki'
        '5' = 'search'
        '6' = 'core'
        '7' = 'work'
        '8' = 'test-plans'
        '9' = 'advanced-security'
    }

    $selectedDomains = @()
    if (-not $domainInput -or $domainInput.Trim() -eq '') {
        $selectedDomains = @('work-items', 'repositories')
    } else {
        $choices = $domainInput -split ',' | ForEach-Object { $_.Trim() }
        foreach ($c in $choices) {
            if ($domainMap.ContainsKey($c)) {
                $selectedDomains += $domainMap[$c]
            } else {
                Write-Warn "Opcion '$c' no reconocida, se ignora."
            }
        }
    }

    if ($selectedDomains.Count -eq 0) {
        $selectedDomains = @('work-items', 'repositories')
        Write-Warn "Ninguna seleccion valida. Se usan los dominios por defecto."
    }

    Write-Ok "Dominios: $($selectedDomains -join ', ')"

    # Construir comando
    $command = @('npx', '-y', '@azure-devops/mcp', $orgName)
    if ($selectedDomains.Count -gt 0) {
        $command += '-d'
        $command += $selectedDomains
    }

    $serverDef = [PSCustomObject]@{
        type    = 'local'
        command = $command
        enabled = $true
    }

} else {
    # ---- MODO REMOTO ----
    Write-Step "Configuracion remota..."

    Write-Host ""
    Write-Host "    Introduce la URL del servidor MCP remoto de Azure DevOps." -ForegroundColor White
    Write-Host "    Consulta la documentacion de Microsoft para obtenerla:" -ForegroundColor Gray
    Write-Host "    https://learn.microsoft.com/azure/devops/mcp-server/remote-mcp-server" -ForegroundColor Gray
    Write-Host ""
    $remoteUrl = Read-Host "    URL del servidor MCP remoto"
    while (-not $remoteUrl -or $remoteUrl.Trim() -eq '') {
        $remoteUrl = Read-Host "    La URL no puede estar vacia. URL del servidor"
    }
    $remoteUrl = $remoteUrl.Trim()

    Write-Host ""
    Write-Host "    Introduce el token de autorizacion (Bearer) para autenticar" -ForegroundColor White
    Write-Host "    las peticiones al servidor remoto." -ForegroundColor Gray
    Write-Host ""
    $bearerToken = Read-Host "    Token Bearer"
    while (-not $bearerToken -or $bearerToken.Trim() -eq '') {
        $bearerToken = Read-Host "    El token no puede estar vacio. Token Bearer"
    }
    $bearerToken = $bearerToken.Trim()

    Write-Ok "URL: $remoteUrl"
    Write-Ok "Token: $(($bearerToken.Substring(0, [Math]::Min(8, $bearerToken.Length))))..."

    $serverDef = [PSCustomObject]@{
        type    = 'remote'
        url     = $remoteUrl
        enabled = $true
        headers = [PSCustomObject]@{
            Authorization = "Bearer $bearerToken"
        }
    }
}

# =========================================================
#  PASO 4: Verificacion
# =========================================================

Write-Step "Verificando..."

if ($isLocal) {
    Write-Info "Comprobando que el paquete @azure-devops/mcp esta disponible..."
    try {
        $helpOutput = & npx -y @azure-devops/mcp --help 2>&1
        Write-Ok "Paquete @azure-devops/mcp accesible."
    } catch {
        Write-Warn "No se pudo verificar el paquete. Se configurara igualmente."
        Write-Warn "Puede que se descargue automaticamente la primera vez que OpenCode lo use."
    }
} else {
    Write-Info "Comprobando que la URL es alcanzable..."
    try {
        $response = Invoke-WebRequest -Uri $remoteUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Ok "URL alcanzable (HTTP $($response.StatusCode))."
    } catch {
        Write-Warn "No se pudo verificar la URL: $_"
        Write-Warn "Se configurara igualmente. Verifica la URL manualmente si hay problemas."
    }
}

# =========================================================
#  PASO 5: Escribir configuracion
# =========================================================

Write-Step "Guardando configuracion..."

$config = Read-OpencodeJson -Path $jsonPath
$config = Set-McpServer -Config $config -Name 'azure-devops' -ServerDef $serverDef
Write-OpencodeJson -Path $jsonPath -Config $config

# =========================================================
#  PASO 6: Resumen
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

if ($isLocal) {
    Write-Host "  Siguiente paso:" -ForegroundColor Yellow
    Write-Host "  La primera vez que uses una herramienta de Azure DevOps en OpenCode," -ForegroundColor Yellow
    Write-Host "  se abrira el navegador para que te autentiques con tu cuenta Microsoft." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Tu cuenta debe tener acceso a la organizacion '$orgName'." -ForegroundColor Yellow
} else {
    Write-Host "  Siguiente paso:" -ForegroundColor Yellow
    Write-Host "  El servidor MCP remoto esta configurado y listo para usar." -ForegroundColor Yellow
    Write-Host "  Si el token expira, vuelve a ejecutar este script para actualizarlo." -ForegroundColor Yellow
}

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
