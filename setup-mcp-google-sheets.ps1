#Requires -Version 5.1
# =========================================================
#  setup-mcp-google-sheets.ps1
#
#  Configura el servidor MCP de Google Sheets en opencode.json
#  para conectar OpenCode con tus hojas de calculo de Google.
#
#  Opciones de autenticacion:
#    [1] Service Account (mcp-gsheets)
#    [2] OAuth2 (google-sheets-mcp)
#
#  Uso:
#    powershell -ExecutionPolicy Bypass -File setup-mcp-google-sheets.ps1
# =========================================================

# Cargar funciones compartidas (antes de StrictMode para que las funciones esten disponibles)
. "$PSScriptRoot\_mcp-helpers.ps1"

# Iniciar log lo antes posible (antes de StrictMode y ErrorAction)
$LogFile = Start-McpLog -ScriptPath $PSCommandPath -FallbackDir $PSScriptRoot -FallbackName 'setup-mcp-google-sheets'

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

try {

# =========================================================
#  PASO 0: Prerrequisitos
# =========================================================

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Configuracion MCP - Google Sheets" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

Write-Step "Validando prerrequisitos..."
Test-NodeVersion

# =========================================================
#  PASO 1: Resolver ruta opencode.json
# =========================================================

Write-Step "Localizando opencode.json..."
$jsonPath = Resolve-OpencodeJsonPath

# =========================================================
#  PASO 2: Elegir metodo de autenticacion
# =========================================================

Write-Step "Elige como quieres autenticarte con Google Sheets..."
Write-Host ""
Write-Host "    [1] Service Account (recomendado)" -ForegroundColor White
Write-Host "        Paquete: mcp-gsheets" -ForegroundColor Gray
Write-Host "        Usa una cuenta de servicio de Google Cloud. Ideal" -ForegroundColor Gray
Write-Host "        para acceso automatizado y entornos sin navegador." -ForegroundColor Gray
Write-Host "        Cada hoja de calculo debe compartirse explicitamente" -ForegroundColor Gray
Write-Host "        con el email de la cuenta de servicio." -ForegroundColor Gray
Write-Host ""
Write-Host "        Necesitaras tener a mano:" -ForegroundColor Yellow
Write-Host "          - Un proyecto en Google Cloud Console" -ForegroundColor Yellow
Write-Host "            (https://console.cloud.google.com)" -ForegroundColor Yellow
Write-Host "          - La Google Sheets API habilitada en ese proyecto" -ForegroundColor Yellow
Write-Host "          - Una cuenta de servicio (Service Account) creada" -ForegroundColor Yellow
Write-Host "            en IAM > Service Accounts" -ForegroundColor Yellow
Write-Host "          - El archivo JSON de clave de la cuenta de servicio" -ForegroundColor Yellow
Write-Host "            (se descarga al crear la clave)" -ForegroundColor Yellow
Write-Host "          - El Project ID de Google Cloud" -ForegroundColor Yellow
Write-Host ""
Write-Host "        Si no tienes nada de esto, no te preocupes: el script" -ForegroundColor DarkGray
Write-Host "        te guiara paso a paso en el siguiente apartado." -ForegroundColor DarkGray
Write-Host ""
Write-Host "    [2] OAuth2 (login con navegador)" -ForegroundColor White
Write-Host "        Paquete: google-sheets-mcp" -ForegroundColor Gray
Write-Host "        Usa tu cuenta personal de Google. Accede a todas las" -ForegroundColor Gray
Write-Host "        hojas de tu cuenta sin compartir una a una." -ForegroundColor Gray
Write-Host "        Requiere un navegador para la autenticacion inicial." -ForegroundColor Gray
Write-Host ""
Write-Host "        Necesitaras tener a mano:" -ForegroundColor Yellow
Write-Host "          - Un proyecto en Google Cloud Console" -ForegroundColor Yellow
Write-Host "          - La Google Sheets API habilitada en ese proyecto" -ForegroundColor Yellow
Write-Host "          - Un OAuth Client ID creado en APIs & Services >" -ForegroundColor Yellow
Write-Host "            Credentials (tipo: Desktop application)" -ForegroundColor Yellow
Write-Host "          - El archivo JSON de credenciales OAuth descargado" -ForegroundColor Yellow
Write-Host "          - Acceso a un navegador para autorizar la primera vez" -ForegroundColor Yellow
Write-Host ""
Write-Host "        Si no tienes nada de esto, no te preocupes: el script" -ForegroundColor DarkGray
Write-Host "        te guiara paso a paso en el siguiente apartado." -ForegroundColor DarkGray
Write-Host ""

$authChoice = Read-Host "    Selecciona [1] o [2]"
while ($authChoice -ne '1' -and $authChoice -ne '2') {
    $authChoice = Read-Host "    Opcion no valida. Selecciona [1] o [2]"
}

$useServiceAccount = ($authChoice -eq '1')

# =========================================================
#  PASO 3: Guia de configuracion en Google Cloud
# =========================================================

if ($useServiceAccount) {
    # ---- GUIA SERVICE ACCOUNT ----
    Write-Step "Guia: Configurar Service Account en Google Cloud..."
    Write-Host ""
    Write-Host "    Si ya tienes el archivo JSON de clave, puedes saltar esta guia" -ForegroundColor DarkGray
    Write-Host "    pulsando Enter directamente." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Paso 1: Abre Google Cloud Console" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Paso 2: Crea un proyecto nuevo (o selecciona uno existente)" -ForegroundColor White
    Write-Host "            Menu hamburguesa > IAM y administracion > Crear proyecto" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 3: Habilita la Google Sheets API" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com/apis/library/sheets.googleapis.com" -ForegroundColor Cyan
    Write-Host "            Pulsa 'Habilitar'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 4: Crea una cuenta de servicio" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com/iam-admin/serviceaccounts" -ForegroundColor Cyan
    Write-Host "            > Crear cuenta de servicio" -ForegroundColor Gray
    Write-Host "            > Nombre: por ejemplo 'mcp-sheets'" -ForegroundColor Gray
    Write-Host "            > Rol: Editor (o mas restrictivo segun necesidad)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 5: Genera una clave JSON" -ForegroundColor White
    Write-Host "            Haz clic en la cuenta de servicio creada" -ForegroundColor Gray
    Write-Host "            > Pestana 'Claves' > Agregar clave > Crear clave nueva" -ForegroundColor Gray
    Write-Host "            > Tipo: JSON > Crear" -ForegroundColor Gray
    Write-Host "            Se descargara un archivo .json automaticamente." -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 6: Comparte las hojas de calculo" -ForegroundColor White
    Write-Host "            Abre cada hoja de calculo que quieras acceder" -ForegroundColor Gray
    Write-Host "            > Compartir > Anadir el email de la cuenta de servicio" -ForegroundColor Gray
    Write-Host "            (tiene formato: nombre@proyecto.iam.gserviceaccount.com)" -ForegroundColor Gray
    Write-Host ""

    Read-Host "    Pulsa Enter cuando estes listo para continuar"

} else {
    # ---- GUIA OAUTH2 ----
    Write-Step "Guia: Configurar OAuth2 en Google Cloud..."
    Write-Host ""
    Write-Host "    Si ya tienes el archivo JSON de credenciales OAuth, puedes saltar" -ForegroundColor DarkGray
    Write-Host "    esta guia pulsando Enter directamente." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Paso 1: Abre Google Cloud Console" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Paso 2: Crea un proyecto nuevo (o selecciona uno existente)" -ForegroundColor White
    Write-Host ""
    Write-Host "    Paso 3: Habilita la Google Sheets API" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com/apis/library/sheets.googleapis.com" -ForegroundColor Cyan
    Write-Host "            Pulsa 'Habilitar'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 4: Configura la pantalla de consentimiento OAuth" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com/apis/credentials/consent" -ForegroundColor Cyan
    Write-Host "            > Tipo de usuario: Externo" -ForegroundColor Gray
    Write-Host "            > Rellena nombre de la aplicacion y email de contacto" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 5: Crea credenciales OAuth" -ForegroundColor White
    Write-Host "            https://console.cloud.google.com/apis/credentials" -ForegroundColor Cyan
    Write-Host "            > Crear credenciales > ID de cliente de OAuth" -ForegroundColor Gray
    Write-Host "            > Tipo de aplicacion: App de escritorio" -ForegroundColor Gray
    Write-Host "            > Nombre: por ejemplo 'OpenCode MCP'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Paso 6: Descarga el JSON de credenciales" -ForegroundColor White
    Write-Host "            En la credencial creada, pulsa el icono de descarga" -ForegroundColor Gray
    Write-Host "            Se descargara un archivo .json con client_id y client_secret." -ForegroundColor Gray
    Write-Host ""

    Read-Host "    Pulsa Enter cuando estes listo para continuar"
}

# =========================================================
#  PASO 4: Datos de conexion
# =========================================================

$serverDef = $null

if ($useServiceAccount) {
    # ---- SERVICE ACCOUNT ----
    Write-Step "Datos de conexion (Service Account)..."

    # Project ID
    Write-Host ""
    Write-Host "    Introduce el Project ID de Google Cloud." -ForegroundColor White
    Write-Host "    Lo encuentras en la pagina principal de tu proyecto en" -ForegroundColor Gray
    Write-Host "    https://console.cloud.google.com o en el archivo JSON de clave." -ForegroundColor Gray
    Write-Host ""
    $projectId = Read-Host "    Google Cloud Project ID"
    while (-not $projectId -or $projectId.Trim() -eq '') {
        $projectId = Read-Host "    El Project ID no puede estar vacio. Project ID"
    }
    $projectId = $projectId.Trim()
    Write-Ok "Project ID: $projectId"

    # Ruta al archivo JSON de clave
    Write-Host ""
    Write-Host "    Introduce la ruta al archivo JSON de clave del Service Account." -ForegroundColor White
    Write-Host "    (el archivo que descargaste en el Paso 5 de la guia)" -ForegroundColor Gray
    Write-Host ""
    $keyPath = Read-Host "    Ruta al archivo JSON"
    while (-not $keyPath -or $keyPath.Trim() -eq '') {
        $keyPath = Read-Host "    La ruta no puede estar vacia. Ruta al archivo JSON"
    }
    $keyPath = $keyPath.Trim().Trim('"')

    # Validar que existe
    if (-not (Test-Path $keyPath)) {
        Write-Fail "El archivo no existe: $keyPath"
        exit 1
    }

    # Convertir a ruta absoluta
    $keyPath = (Resolve-Path $keyPath).Path
    Write-Ok "Archivo: $keyPath"

    # Validar que es JSON parseable con los campos esperados
    try {
        $keyContent = [System.IO.File]::ReadAllText($keyPath)
        $keyObj = $keyContent | ConvertFrom-Json

        $hasEmail = ($keyObj.PSObject.Properties.Name -contains 'client_email')
        $hasKey   = ($keyObj.PSObject.Properties.Name -contains 'private_key')

        if (-not $hasEmail -or -not $hasKey) {
            Write-Fail "El archivo JSON no parece ser una clave de Service Account."
            Write-Fail "Debe contener los campos 'client_email' y 'private_key'."
            exit 1
        }

        $saEmail = $keyObj.client_email
        Write-Ok "Service Account: $saEmail"
        Write-Host ""
        Write-Host "    IMPORTANTE: Recuerda compartir tus hojas de calculo con:" -ForegroundColor Yellow
        Write-Host "    $saEmail" -ForegroundColor White
        Write-Host ""
    } catch {
        Write-Fail "El archivo no es un JSON valido: $_"
        exit 1
    }

    $serverDef = [PSCustomObject]@{
        type        = 'local'
        command     = @('npx', '-y', 'mcp-gsheets@latest')
        enabled     = $true
        environment = [PSCustomObject]@{
            GOOGLE_PROJECT_ID              = $projectId
            GOOGLE_APPLICATION_CREDENTIALS = $keyPath
        }
    }

} else {
    # ---- OAUTH2 ----
    Write-Step "Datos de conexion (OAuth2)..."

    # Ruta al archivo JSON de credenciales OAuth
    Write-Host ""
    Write-Host "    Introduce la ruta al archivo JSON de credenciales OAuth." -ForegroundColor White
    Write-Host "    (el archivo que descargaste en el Paso 6 de la guia)" -ForegroundColor Gray
    Write-Host ""
    $oauthPath = Read-Host "    Ruta al archivo JSON"
    while (-not $oauthPath -or $oauthPath.Trim() -eq '') {
        $oauthPath = Read-Host "    La ruta no puede estar vacia. Ruta al archivo JSON"
    }
    $oauthPath = $oauthPath.Trim().Trim('"')

    # Validar que existe
    if (-not (Test-Path $oauthPath)) {
        Write-Fail "El archivo no existe: $oauthPath"
        exit 1
    }

    # Convertir a ruta absoluta
    $oauthPath = (Resolve-Path $oauthPath).Path
    Write-Ok "Archivo: $oauthPath"

    # Validar formato del JSON de credenciales OAuth
    try {
        $oauthContent = [System.IO.File]::ReadAllText($oauthPath)
        $oauthObj = $oauthContent | ConvertFrom-Json

        # Las credenciales OAuth suelen estar envueltas en "installed" o "web"
        $creds = $null
        if ($oauthObj.PSObject.Properties.Name -contains 'installed') {
            $creds = $oauthObj.installed
        } elseif ($oauthObj.PSObject.Properties.Name -contains 'web') {
            $creds = $oauthObj.web
        } else {
            $creds = $oauthObj
        }

        $hasClientId     = ($creds.PSObject.Properties.Name -contains 'client_id')
        $hasClientSecret = ($creds.PSObject.Properties.Name -contains 'client_secret')

        if (-not $hasClientId -or -not $hasClientSecret) {
            Write-Fail "El archivo JSON no parece contener credenciales OAuth validas."
            Write-Fail "Debe contener 'client_id' y 'client_secret'."
            exit 1
        }

        Write-Ok "Credenciales OAuth validas."
    } catch {
        Write-Fail "El archivo no es un JSON valido: $_"
        exit 1
    }

    $serverDef = [PSCustomObject]@{
        type        = 'local'
        command     = @('npx', '-y', 'google-sheets-mcp')
        enabled     = $true
        environment = [PSCustomObject]@{
            GOOGLE_OAUTH_CREDENTIALS = $oauthPath
        }
    }
}

# =========================================================
#  PASO 5: Verificacion
# =========================================================

Write-Step "Verificando..."

if ($useServiceAccount) {
    Write-Info "Comprobando que el paquete mcp-gsheets esta disponible..."
    try {
        & npx -y mcp-gsheets@latest --help 2>&1 | Out-Null
        Write-Ok "Paquete mcp-gsheets accesible."
    } catch {
        Write-Warn "No se pudo verificar el paquete. Se configurara igualmente."
        Write-Warn "Puede que se descargue automaticamente la primera vez que OpenCode lo use."
    }
} else {
    Write-Info "Comprobando que el paquete google-sheets-mcp esta disponible..."
    try {
        & npx -y google-sheets-mcp --help 2>&1 | Out-Null
        Write-Ok "Paquete google-sheets-mcp accesible."
    } catch {
        Write-Warn "No se pudo verificar el paquete. Se configurara igualmente."
        Write-Warn "Puede que se descargue automaticamente la primera vez que OpenCode lo use."
    }
}

# =========================================================
#  PASO 6: Escribir configuracion
# =========================================================

Write-Step "Guardando configuracion..."

$config = Read-OpencodeJson -Path $jsonPath
$config = Set-McpServer -Config $config -Name 'google-sheets' -ServerDef $serverDef
Write-OpencodeJson -Path $jsonPath -Config $config

# =========================================================
#  PASO 7: Resumen
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
        'google-sheets' = $serverDef
    }
}
$previewJson = $preview | ConvertTo-Json -Depth 10
Write-Host ""
foreach ($line in ($previewJson -split "`n")) {
    Write-Host "    $line" -ForegroundColor DarkCyan
}
Write-Host ""

if ($useServiceAccount) {
    Write-Host "  Recuerda:" -ForegroundColor Yellow
    Write-Host "  Cada hoja de calculo que quieras acceder debe estar compartida con:" -ForegroundColor Yellow
    Write-Host "  $saEmail" -ForegroundColor White
    Write-Host ""
    Write-Host "  Documentacion: https://github.com/freema/mcp-gsheets" -ForegroundColor Gray
} else {
    Write-Host "  Siguiente paso:" -ForegroundColor Yellow
    Write-Host "  La primera vez que uses una herramienta de Google Sheets en OpenCode," -ForegroundColor Yellow
    Write-Host "  se abrira el navegador para que autorices el acceso con tu cuenta Google." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Documentacion: https://github.com/domdomegg/google-sheets-mcp" -ForegroundColor Gray
}

Write-Host ""
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
