#Requires -Version 5.1
# =========================================================
#  OmO Re-Patch Script
#  Applies known patches to oh-my-openagent's dist/index.js:
#
#  1. ZWSP: Removes Zero-Width Space (U+200B) from
#     AGENT_LIST_SORT_PREFIXES (agent name mismatch bug)
#     Issue refs: oh-my-openagent #3379, #3418, #3281
#
#  2. Variant: Replaces variant:"max" -> "high" in hardcoded
#     Claude model defaults when Anthropic nativo no disponible
#     (el proxy de Copilot no soporta effort "max")
#
#  Run this after OmO updates to re-apply patches.
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

$zwspChar   = [char]0x200B
$patchCount = 0
$skipCount  = 0

# Detectar si el usuario tiene Anthropic nativo (mirando el config JSON)
$hasNativeAnthropic = $false
$configPath = Join-Path $UserHome ".config\opencode\oh-my-openagent.json"
if (Test-Path $configPath) {
    $configText = [System.IO.File]::ReadAllText($configPath)
    if ($configText -match '"anthropic/') {
        $hasNativeAnthropic = $true
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor White
Write-Host "  OmO Re-Patch (ZWSP + Variant)" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor White

if ($hasNativeAnthropic) {
    Write-Host "  Anthropic nativo detectado: variant 'max' no se parchea" -ForegroundColor Gray
} else {
    Write-Host "  Sin Anthropic nativo: variant 'max' -> 'high'" -ForegroundColor Gray
}

foreach ($path in $paths) {
    $shortPath = $path.Replace($UserHome, "~")
    Write-Host ""
    Write-Host "--- $shortPath" -ForegroundColor Cyan

    if (-not (Test-Path $path)) {
        Write-Host "    SKIP: No existe" -ForegroundColor Yellow
        $skipCount++
        continue
    }

    $content  = [System.IO.File]::ReadAllText($path)
    $modified = $false

    # ---- Parche 1: ZWSP ----
    if ($content.Contains($zwspChar)) {
        $pattern = '(?s)(AGENT_LIST_SORT_PREFIXES\s*=\s*\{)(.*?)(\})'
        $match   = [regex]::Match($content, $pattern)

        if ($match.Success) {
            $originalBlock = $match.Value
            $cleanedBlock  = $originalBlock.Replace([string]$zwspChar, '')

            if ($originalBlock -ne $cleanedBlock) {
                $content  = $content.Remove($match.Index, $match.Length).Insert($match.Index, $cleanedBlock)
                $modified = $true
                Write-Host "    ZWSP: Parcheado (AGENT_LIST_SORT_PREFIXES)" -ForegroundColor Green
            } else {
                Write-Host "    ZWSP: Bloque encontrado pero ya limpio" -ForegroundColor Green
            }
        } else {
            # Fallback: remover ZWSP globalmente
            $content  = $content.Replace([string]$zwspChar, '')
            $modified = $true
            Write-Host "    ZWSP: Parcheado (limpieza global)" -ForegroundColor Green
        }
    } else {
        Write-Host "    ZWSP: OK (sin ZWSP)" -ForegroundColor Green
    }

    # ---- Parche 2: variant "max" -> "high" ----
    if (-not $hasNativeAnthropic) {
        $variantPattern = '(variant:\s*)"max"'
        $hits = [regex]::Matches($content, $variantPattern)

        if ($hits.Count -gt 0) {
            $content  = [regex]::Replace($content, $variantPattern, '${1}"high"')
            $modified = $true
            Write-Host "    VARIANT: $($hits.Count) ocurrencia(s) 'max' -> 'high'" -ForegroundColor Green
        } else {
            Write-Host "    VARIANT: OK (sin 'max' hardcodeado)" -ForegroundColor Green
        }
    }

    # ---- Escribir si hubo cambios ----
    if ($modified) {
        [System.IO.File]::WriteAllText($path, $content)
        $patchCount++
    } else {
        $skipCount++
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
