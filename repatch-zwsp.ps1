#Requires -Version 5.1
# =========================================================
#  OmO ZWSP Re-Patch Script
#  Removes Zero-Width Space (U+200B) characters from
#  AGENT_LIST_SORT_PREFIXES in oh-my-openagent's dist/index.js
#
#  Run this after OmO updates to fix the agent name mismatch bug.
#  Issue refs: oh-my-openagent #3379, #3418, #3281
#
#  Uso:
#    Click derecho > Ejecutar con PowerShell
#    o: powershell -ExecutionPolicy Bypass -File repatch-zwsp.ps1
# =========================================================

$ErrorActionPreference = "Stop"

$UserHome = $env:USERPROFILE
$paths = @(
    (Join-Path $UserHome ".cache\opencode\packages\oh-my-openagent@latest\node_modules\oh-my-openagent\dist\index.js"),
    (Join-Path $UserHome ".config\opencode\node_modules\oh-my-opencode\dist\index.js")
)

$zwspChar = [char]0x200B
$patchCount = 0
$skipCount = 0

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  OmO ZWSP Re-Patch" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

foreach ($path in $paths) {
    $shortPath = $path.Replace($UserHome, "~")
    Write-Host ""
    Write-Host "--- $shortPath" -ForegroundColor Cyan

    if (-not (Test-Path $path)) {
        Write-Host "    SKIP: No existe" -ForegroundColor Yellow
        $skipCount++
        continue
    }

    $content = [System.IO.File]::ReadAllText($path)

    if (-not $content.Contains($zwspChar)) {
        Write-Host "    OK: Sin ZWSP (ya parcheado o upstream arreglado)" -ForegroundColor Green
        $skipCount++
        continue
    }

    $pattern = '(?s)(AGENT_LIST_SORT_PREFIXES\s*=\s*\{)(.*?)(\})'
    $match = [regex]::Match($content, $pattern)

    if ($match.Success) {
        $originalBlock = $match.Value
        $cleanedBlock = $originalBlock.Replace([string]$zwspChar, '')

        if ($originalBlock -ne $cleanedBlock) {
            $content = $content.Remove($match.Index, $match.Length).Insert($match.Index, $cleanedBlock)
            [System.IO.File]::WriteAllText($path, $content)
            Write-Host "    PARCHEADO: ZWSP eliminado de AGENT_LIST_SORT_PREFIXES" -ForegroundColor Green
            $patchCount++
        } else {
            Write-Host "    OK: Bloque encontrado pero ya limpio" -ForegroundColor Green
            $skipCount++
        }
    } else {
        Write-Host "    WARN: ZWSP encontrado pero bloque no coincide. Limpieza global..." -ForegroundColor Yellow
        $cleaned = $content.Replace([string]$zwspChar, '')
        [System.IO.File]::WriteAllText($path, $cleaned)
        Write-Host "    PARCHEADO: Limpieza global de ZWSP aplicada" -ForegroundColor Green
        $patchCount++
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  Resultado: $patchCount parcheados, $skipCount sin cambios" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

if ($patchCount -gt 0) {
    Write-Host ""
    Write-Host "  Reinicia OpenCode Desktop (OmO) para aplicar los cambios." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Presiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
