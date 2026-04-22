# Agent Instructions

PowerShell automation suite for OpenCode Desktop setup and MCP server configuration.

## Project Structure

```
.
├── install-omo.ps1              # Main OmO plugin installer (755 lines)
├── repatch-zwsp.ps1             # Re-apply patches after OmO updates
├── uninstall-omo.ps1            # Clean uninstaller
├── setup-mcp-google-sheets.ps1  # Configure Google Sheets MCP server
├── uninstall-mcp-*.ps1          # Remove MCP configurations
├── _mcp-helpers.ps1             # Shared functions for MCP scripts
└── config/opencode.json         # OmO plugin manifest
```

## Code Conventions

**All PowerShell scripts must:**
- Include `#Requires -Version 5.1` header
- Set `$ErrorActionPreference = "Stop"` and `Set-StrictMode -Version Latest`
- MCP scripts: Wrap body in `try { } catch { } finally { }` with `Stop-McpLog` in finally
- Use shared helpers from `_mcp-helpers.ps1` (dot-source before StrictMode)
- Output via color functions: `Write-Step`, `Write-Ok`, `Write-Warn`, `Write-Fail`, `Write-Info`
- Generate timestamped logs: `<script-name>_<yyyy-MM-dd_HHmmss>.log`

**Execution pattern for MCP scripts:**
```powershell
. "$PSScriptRoot\_mcp-helpers.ps1"
$LogFile = Start-McpLog -ScriptPath $PSCommandPath -FallbackDir $PSScriptRoot -FallbackName 'script-name'
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
try {
    # script body
} catch {
    # error display
} finally {
    Stop-McpLog
}
```

## Validation

Check PowerShell syntax before committing:
```powershell
$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile('script.ps1',[ref]$t,[ref]$e);$e
```

## Runtime Requirements

- **Target OS**: Windows 10/11 only
- **Prerequisites**: Node.js >= 20, npm, OpenCode Desktop
- **Isolated profile**: Created at `~/.config/opencode-omo/`
- **Patches applied**: 
  - ZWSP removal from agent names (breaks lookups)
  - Variant `"max"` → `"high"` for GitHub Copilot proxy (doesn't support max)

## Key Dependencies

- `oh-my-openagent` npm package (auto-installed/updated)
- MCP servers via npx: `mcp-gsheets`, `google-sheets-mcp`

## Git Ignore

Logs (`*.log`) and temp validation script (`_validate.ps1`) are ignored.
