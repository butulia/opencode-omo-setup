#Requires -Version 5.1
# =========================================================
#  _mcp-helpers.ps1 - Funciones compartidas para scripts MCP
#
#  Uso: dot-source desde otro script:
#    . "$PSScriptRoot\_mcp-helpers.ps1"
# =========================================================

# ---- Transcripcion (log) ----

function Start-McpLog {
    <#
    .SYNOPSIS
        Inicia Start-Transcript con un archivo de log junto al script
        que lo invoca. El nombre sigue el patron:
          <nombre-script>_<timestamp>.log
    .PARAMETER ScriptPath
        Ruta completa del script que invoca ($PSCommandPath del caller).
        Si esta vacio, usa $PSScriptRoot como fallback.
    .PARAMETER FallbackDir
        Directorio fallback si ScriptPath esta vacio (usar $PSScriptRoot).
    .PARAMETER FallbackName
        Nombre base fallback si ScriptPath esta vacio.
    .OUTPUTS
        Devuelve la ruta del archivo de log creado.
    #>
    param(
        [string]$ScriptPath,
        [string]$FallbackDir,
        [string]$FallbackName
    )

    $baseName = $null
    $dir      = $null

    if ($ScriptPath -and $ScriptPath.Trim() -ne '') {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
        $dir      = Split-Path $ScriptPath -Parent
    } else {
        # Fallbacks para cuando $PSCommandPath no esta disponible
        if ($FallbackDir -and $FallbackDir.Trim() -ne '') {
            $dir = $FallbackDir
        } else {
            $dir = (Get-Location).Path
        }
        if ($FallbackName -and $FallbackName.Trim() -ne '') {
            $baseName = $FallbackName
        } else {
            $baseName = 'mcp-script'
        }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $logFile   = Join-Path $dir "${baseName}_${timestamp}.log"

    Start-Transcript -Path $logFile -Force | Out-Null
    return $logFile
}

function Stop-McpLog {
    <#
    .SYNOPSIS
        Detiene Start-Transcript de forma segura.
    #>
    try { Stop-Transcript | Out-Null } catch { }
}

# ---- Funciones de salida con colores ----

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

function Write-Info($msg) {
    Write-Host "    $msg" -ForegroundColor Gray
}

# ---- Validacion de Node.js ----

function Test-NodeVersion {
    <#
    .SYNOPSIS
        Valida que Node.js >= 20 y npm estan en PATH.
        Termina el script si no se cumplen los requisitos.
    #>
    try {
        $nodeRaw = (& node --version 2>&1).ToString().Trim()
        # Extraer major version de "v20.11.0" o similar
        if ($nodeRaw -match '^v(\d+)') {
            $major = [int]$Matches[1]
            if ($major -lt 20) {
                Write-Fail "Node.js $nodeRaw detectado, pero se requiere v20 o superior."
                Write-Fail "Actualiza desde https://nodejs.org"
                exit 1
            }
            Write-Ok "Node.js $nodeRaw"
        } else {
            Write-Fail "No se pudo determinar la version de Node.js (respuesta: $nodeRaw)"
            exit 1
        }
    } catch {
        Write-Fail "Node.js no encontrado en PATH. Instalalo desde https://nodejs.org"
        exit 1
    }

    try {
        $npmVer = (& npm --version 2>&1).ToString().Trim()
        Write-Ok "npm $npmVer"
    } catch {
        Write-Fail "npm no encontrado en PATH."
        exit 1
    }
}

# ---- Resolucion de ruta a opencode.json ----

function Resolve-OpencodeJsonPath {
    <#
    .SYNOPSIS
        Detecta la raiz de un repositorio git. Si no es un repo,
        propone el directorio actual. Permite al usuario modificar
        la ruta. Devuelve la ruta completa al opencode.json.
    #>
    $proposedDir = $null

    # Intentar detectar raiz del repo git
    try {
        $gitRoot = (& git rev-parse --show-toplevel 2>&1).ToString().Trim()
        if ($LASTEXITCODE -eq 0 -and (Test-Path $gitRoot)) {
            # Normalizar separadores en Windows
            $gitRoot = $gitRoot -replace '/', '\'
            $proposedDir = $gitRoot
            Write-Ok "Repositorio git detectado: $gitRoot"
        }
    } catch {
        # No estamos en un repo git
    }

    if (-not $proposedDir) {
        $proposedDir = (Get-Location).Path
        Write-Warn "No se detecto un repositorio git en esta ubicacion."
        Write-Info "Se propone el directorio actual: $proposedDir"
    }

    Write-Host ""
    Write-Host "    Ruta para opencode.json: $proposedDir" -ForegroundColor White
    $custom = Read-Host "    Pulsa Enter para aceptar o escribe otra ruta"

    if ($custom -and $custom.Trim() -ne '') {
        $proposedDir = $custom.Trim()
    }

    # Validar que el directorio existe
    if (-not (Test-Path $proposedDir -PathType Container)) {
        Write-Fail "El directorio no existe: $proposedDir"
        exit 1
    }

    $jsonPath = Join-Path $proposedDir "opencode.json"
    Write-Ok "opencode.json: $jsonPath"
    return $jsonPath
}

# ---- Lectura/escritura de opencode.json ----

function Read-OpencodeJson {
    <#
    .SYNOPSIS
        Lee y parsea opencode.json. Si no existe, devuelve un
        objeto base con solo $schema.
    .PARAMETER Path
        Ruta completa al archivo opencode.json.
    #>
    param([string]$Path)

    if (Test-Path $Path) {
        try {
            $raw = [System.IO.File]::ReadAllText($Path)
            $obj = $raw | ConvertFrom-Json
            Write-Ok "opencode.json leido: $Path"
            return $obj
        } catch {
            Write-Fail "Error parseando opencode.json: $_"
            exit 1
        }
    } else {
        Write-Info "opencode.json no existe, se creara uno nuevo."
        $obj = [PSCustomObject]@{
            '$schema' = 'https://opencode.ai/config.json'
        }
        return $obj
    }
}

function Write-OpencodeJson {
    <#
    .SYNOPSIS
        Serializa y escribe el objeto de configuracion a opencode.json
        con indentacion legible.
    .PARAMETER Path
        Ruta completa al archivo opencode.json.
    .PARAMETER Config
        Objeto PSCustomObject con la configuracion.
    #>
    param(
        [string]$Path,
        [PSCustomObject]$Config
    )

    $json = $Config | ConvertTo-Json -Depth 10
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $json)
    Write-Ok "opencode.json guardado: $Path"
}

# ---- Gestion de servidores MCP ----

function Set-McpServer {
    <#
    .SYNOPSIS
        Anade o sobreescribe un servidor MCP en la configuracion.
        Crea la clave "mcp" si no existe.
    .PARAMETER Config
        Objeto PSCustomObject de la configuracion.
    .PARAMETER Name
        Nombre del servidor MCP (ej: "azure-devops").
    .PARAMETER ServerDef
        Objeto PSCustomObject con la definicion del servidor.
    .OUTPUTS
        Devuelve el objeto $Config modificado.
    #>
    param(
        [PSCustomObject]$Config,
        [string]$Name,
        [PSCustomObject]$ServerDef
    )

    # Asegurar que existe la clave "mcp"
    if (-not ($Config.PSObject.Properties.Name -contains 'mcp')) {
        $Config | Add-Member -NotePropertyName 'mcp' -NotePropertyValue ([PSCustomObject]@{})
    }

    # Comprobar si ya existia
    if ($Config.mcp.PSObject.Properties.Name -contains $Name) {
        Write-Warn "Ya existia configuracion para '$Name'. Se sobreescribira."
    }

    # Anadir o sobreescribir
    if ($Config.mcp.PSObject.Properties.Name -contains $Name) {
        $Config.mcp.$Name = $ServerDef
    } else {
        $Config.mcp | Add-Member -NotePropertyName $Name -NotePropertyValue $ServerDef
    }

    return $Config
}

function Remove-McpServer {
    <#
    .SYNOPSIS
        Elimina un servidor MCP de la configuracion.
        Si "mcp" queda vacio, elimina la clave "mcp".
    .PARAMETER Config
        Objeto PSCustomObject de la configuracion.
    .PARAMETER Name
        Nombre del servidor MCP a eliminar.
    .OUTPUTS
        Devuelve el objeto $Config modificado.
    #>
    param(
        [PSCustomObject]$Config,
        [string]$Name
    )

    if (-not ($Config.PSObject.Properties.Name -contains 'mcp')) {
        Write-Warn "No existe la seccion 'mcp' en la configuracion."
        return $Config
    }

    if (-not ($Config.mcp.PSObject.Properties.Name -contains $Name)) {
        Write-Warn "No existe el servidor '$Name' en la configuracion."
        return $Config
    }

    $Config.mcp.PSObject.Properties.Remove($Name)
    Write-Ok "Servidor '$Name' eliminado de la configuracion."

    # Si mcp quedo vacio, eliminar la clave
    # Usar @() para forzar array y evitar error si Properties es $null
    $mcpProps = @($Config.mcp.PSObject.Properties)
    if ($mcpProps.Count -eq 0) {
        $Config.PSObject.Properties.Remove('mcp')
        Write-Info "La seccion 'mcp' quedo vacia y se elimino."
    }

    return $Config
}

function Test-ConfigEmpty {
    <#
    .SYNOPSIS
        Comprueba si la configuracion quedo "vacia" (solo contiene
        $schema y/o plugin vacio). Util para decidir si ofrecer
        eliminar el archivo.
    .PARAMETER Config
        Objeto PSCustomObject de la configuracion.
    .OUTPUTS
        $true si el config no tiene contenido funcional.
    #>
    param([PSCustomObject]$Config)

    # Si es $null, considerar vacio
    if (-not $Config) {
        return $true
    }

    # Obtener propiedades como array (para evitar $null.Count)
    $allProps = @($Config.PSObject.Properties)
    if ($allProps.Count -eq 0) {
        return $true
    }

    $functionalKeys = @($allProps.Name | Where-Object {
        $_ -ne '$schema' -and $_ -ne 'plugin'
    })

    if ($functionalKeys.Count -gt 0) {
        return $false
    }

    # Si tiene plugin, comprobar que no este vacio
    $pluginProp = $allProps | Where-Object { $_.Name -eq 'plugin' }
    if ($pluginProp) {
        $plugins = @($Config.plugin)
        if ($plugins.Count -gt 0 -and ($plugins | Where-Object { $_ -and $_.Trim() -ne '' }).Count -gt 0) {
            return $false
        }
    }

    return $true
}
