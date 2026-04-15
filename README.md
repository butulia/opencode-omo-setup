# OpenCode + OmO Setup

Instalador automatico de [oh-my-openagent (OmO)](https://github.com/code-yeongyu/oh-my-openagent) para OpenCode Desktop en Windows.

Crea un **perfil aislado** que no afecta la instalacion principal de OpenCode. Configura todos los agentes OmO (Sisyphus, Hephaestus, Prometheus, Oracle, etc.) usando GitHub Copilot como proveedor, y aplica el parche ZWSP necesario para que los agentes funcionen correctamente.

## Requisitos

- Windows 10/11
- [Node.js](https://nodejs.org) + npm en PATH
- [OpenCode Desktop](https://opencode.ai) instalado
- GitHub Copilot configurado como proveedor en OpenCode

## Uso

```powershell
git clone https://github.com/butulia/opencode-omo-setup.git
cd opencode-omo-setup
powershell -ExecutionPolicy Bypass -File install-omo.ps1
```

Al terminar, hacer doble clic en `OpenCode-OmO.bat` en el Escritorio.

## Que incluye

| Archivo | Funcion |
|---|---|
| `install-omo.ps1` | Instalador principal (ejecutar una vez) |
| `repatch-zwsp.ps1` | Re-aplicar parche ZWSP despues de actualizaciones de OmO |
| `uninstall-omo.ps1` | Desinstalador limpio (revierte todo) |
| `config/opencode.json` | Registro del plugin OmO |
| `config/oh-my-openagent.json` | Modelos, agentes, y categorias |

## Agentes configurados

| Agente | Rol | Modelo principal |
|---|---|---|
| Sisyphus | Default, all-purpose | claude-opus-4.6 |
| Hephaestus | Deep/complex coding | gpt-5.4 |
| Prometheus | Planning | claude-opus-4.6 |
| Atlas | Plan execution | claude-sonnet-4.6 |
| Oracle | High-reasoning Q&A | gpt-5.4 |
| Explore | Codebase search | gpt-5-mini |
| Librarian | Docs/knowledge | (inherits) |
| Metis | Plan consulting | claude-opus-4.6 |
| Momus | Plan critique | gpt-5.4 |

El agente nativo `plan` de OpenCode se preserva junto a Prometheus (`replace_plan: false`).

## Despues de actualizaciones de OmO

```powershell
powershell -ExecutionPolicy Bypass -File repatch-zwsp.ps1
```

O click derecho en `OmO-repatch-ZWSP.ps1` en el Escritorio > Ejecutar con PowerShell.

## Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File uninstall-omo.ps1
```

Elimina todo lo creado por el instalador. No toca OpenCode Desktop ni su acceso directo original.

## Personalizar modelos

Editar `config/oh-my-openagent.json` antes de ejecutar el instalador. Los modelos usan el prefijo `github-copilot/` ya que es el unico proveedor configurado. Si tienes otros proveedores, ajusta los modelos segun corresponda.
