# OpenCode + OmO Setup

Instalador automatico de [oh-my-openagent (OmO)](https://github.com/code-yeongyu/oh-my-openagent) para OpenCode Desktop en Windows.

Crea un **perfil aislado** que no afecta la instalacion principal de OpenCode. Permite elegir entre 9 proveedores de modelos (Claude, OpenAI, Gemini, GitHub Copilot, OpenCode Zen, Z.ai, Kimi, OpenCode Go, Vercel AI Gateway) y configura automaticamente los agentes OmO (Sisyphus, Hephaestus, Prometheus, Oracle, etc.). Aplica parches conocidos (ZWSP en nombres de agentes, effort `max` en proxy Copilot).

**Nuevo:** Scripts de configuracion MCP para conectar OpenCode con servicios externos como Azure DevOps y Google Sheets.

## Requisitos

- Windows 10/11
- [Node.js](https://nodejs.org) + npm en PATH
- [OpenCode Desktop](https://opencode.ai) instalado
- Al menos un proveedor de modelos configurado (Claude, OpenAI, GitHub Copilot, etc.)

## Uso

```powershell
git clone https://github.com/butulia/opencode-omo-setup.git
cd opencode-omo-setup
powershell -ExecutionPolicy Bypass -File install-omo.ps1
```

Al terminar, hacer doble clic en `OpenCode-OmO.bat` en el Escritorio.

## Que hace el instalador

1. Valida prerequisitos (Node.js, npm, OpenCode Desktop)
2. Comprueba si `oh-my-opencode` ya esta instalado; solo instala/actualiza si es necesario
3. Presenta menu interactivo para elegir proveedores y opcion `--skip-auth`
4. Ejecuta `npx oh-my-opencode install` con los proveedores seleccionados
5. Crea perfil aislado en `~/.config/opencode-omo/`
6. Parchea `variant: "max"` a `"high"` en modelos `github-copilot/claude-*` (el proxy de Copilot no soporta `"max"`)
7. Distribuye el config a rutas alternativas de busqueda
8. Aplica parche ZWSP (Zero-Width Space) en nombres de agentes
9. Crea launcher (`OpenCode-OmO.bat`) y script de re-parcheo en el Escritorio

## Archivos del repositorio

| Archivo | Funcion |
|---|---|
| `install-omo.ps1` | Instalador principal |
| `repatch-zwsp.ps1` | Re-aplicar parches (ZWSP + variant) despues de actualizaciones de OmO |
| `uninstall-omo.ps1` | Desinstalador limpio (revierte todo) |
| `config/opencode.json` | Registro del plugin OmO para el perfil aislado |
| `setup-mcp-azure-devops.ps1` | Configura servidor MCP para Azure DevOps (local o remoto) |
| `setup-mcp-google-sheets.ps1` | Configura servidor MCP para Google Sheets (Service Account u OAuth2) |
| `uninstall-mcp-azure-devops.ps1` | Elimina configuracion MCP de Azure DevOps |
| `uninstall-mcp-google-sheets.ps1` | Elimina configuracion MCP de Google Sheets |
| `_mcp-helpers.ps1` | Funciones compartidas para scripts MCP (no ejecutar directamente) |

## Proveedores soportados

| # | Proveedor | Prefijo de modelos |
|---|---|---|
| 1 | Claude (Anthropic) | `anthropic/` |
| 2 | OpenAI / ChatGPT | `openai/` |
| 3 | Gemini (Google) | `google/` |
| 4 | GitHub Copilot | `github-copilot/` |
| 5 | OpenCode Zen | `opencode/` |
| 6 | Z.ai Coding Plan | `zai-coding-plan/` |
| 7 | Kimi For Coding | `kimi-for-coding/` |
| 8 | OpenCode Go | `opencode/` |
| 9 | Vercel AI Gateway | `vercel/` |

Prioridad de modelos: Nativo > Copilot > OpenCode Zen > Z.ai > Kimi > Vercel.

## Despues de actualizaciones de OmO

```powershell
powershell -ExecutionPolicy Bypass -File repatch-zwsp.ps1
```

O click derecho en `OmO-repatch.ps1` en el Escritorio > Ejecutar con PowerShell.

## Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-omo.ps1
```

Elimina todo lo creado por el instalador: perfil aislado, configs, plugin cacheado, launcher y scripts del Escritorio. Opcionalmente desinstala el paquete npm. No toca OpenCode Desktop ni su acceso directo original.

## Parches aplicados

| Parche | Motivo |
|---|---|
| ZWSP (U+200B) | OmO prefixa nombres de agentes con Zero-Width Space para ordenar en la UI, causando que los lookups fallen. Se eliminan los ZWSP de `AGENT_LIST_SORT_PREFIXES`. |
| Variant `max` -> `high` | El proxy de GitHub Copilot no soporta `effort: "max"` en modelos Claude. Se parchea automaticamente a `"high"`. Los modelos nativos (`anthropic/`) si soportan `"max"`. |

## Scripts MCP

Scripts para configurar servidores MCP (Model Context Protocol) que permiten a OpenCode interactuar con servicios externos.

### Azure DevOps

```powershell
# Configurar
powershell -ExecutionPolicy Bypass -File setup-mcp-azure-devops.ps1

# Desinstalar
powershell -ExecutionPolicy Bypass -File uninstall-mcp-azure-devops.ps1
```

**Metodo de conexion (Servidor Remoto):**
Microsoft recomienda usar el **servidor MCP remoto** de Azure DevOps. Este metodo es mas estable y soporta todos los tipos de cuenta (personales, profesionales y educativas).

**Requisitos:**
- URL del servidor MCP remoto de tu organizacion (disponible en https://dev.azure.com/{tu-org}/_settings/mcp)
- Token de acceso personal (PAT) generado desde Azure DevOps

**El script te guiara paso a paso para:**
1. Obtener la URL del servidor MCP remoto
2. Generar un PAT con los permisos necesarios
3. Configurar la conexion de forma segura

**Herramientas disponibles:** Work items, repositorios, pipelines, wiki, busqueda, boards, sprints, test plans.

**Documentacion:**
- https://github.com/microsoft/azure-devops-mcp
- https://learn.microsoft.com/azure/devops/mcp-server/remote-mcp-server

### Google Sheets

```powershell
# Configurar
powershell -ExecutionPolicy Bypass -File setup-mcp-google-sheets.ps1

# Desinstalar
powershell -ExecutionPolicy Bypass -File uninstall-mcp-google-sheets.ps1
```

**Metodos de autenticacion:**
- **Service Account (recomendado):** Usa `mcp-gsheets`. Acceso automatizado via cuenta de servicio.
  - Necesitas: Google Cloud Project ID + archivo JSON de clave de Service Account
  - Cada hoja debe compartirse explicitamente con el email de la cuenta de servicio
- **OAuth2:** Usa `google-sheets-mcp`. Login con tu cuenta personal de Google.
  - Necesitas: Archivo JSON de credenciales OAuth + navegador para autorizacion inicial

**Documentacion:**
- Service Account: https://github.com/freema/mcp-gsheets
- OAuth2: https://github.com/domdomegg/google-sheets-mcp

### Caracteristicas comunes de los scripts MCP

- **Guias interactivas:** Te explican paso a paso que necesitas tener a mano antes de empezar
- **Validacion de prerrequisitos:** Comprueban que tienes Node.js instalado
- **Deteccion automatica:** Buscan el archivo `opencode.json` en la raiz del repo o permiten especificar ruta
- **Idempotencia:** Re-ejecutar un setup sobrescribe la configuracion anterior
- **Logs:** Generan archivos `.log` con timestamp para depuracion
- **Manejo de errores robusto:** Capturan errores inesperados y muestran informacion detallada

## Documentacion

- [oh-my-openagent docs](https://ohmyopenagent.com/docs)
- [Anthropic effort levels](https://platform.claude.com/docs/en/build-with-claude/effort#effort-levels)
- [Azure DevOps MCP](https://github.com/microsoft/azure-devops-mcp)
