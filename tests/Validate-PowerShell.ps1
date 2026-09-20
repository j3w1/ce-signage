$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$files = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot 'package') -Filter '*.ps1' -File -Recurse
)

if ($files.Count -eq 0) {
    throw 'No se encontraron scripts PowerShell.'
}

$failed = $false

foreach ($file in $files) {
    $tokens = $null
    $errors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    )

    if ($errors -and $errors.Count -gt 0) {
        $failed = $true
        Write-Host "ERROR: $($file.FullName)" -ForegroundColor Red

        foreach ($err in $errors) {
            Write-Host (
                '  Línea {0}, columna {1}: {2}' -f
                $err.Extent.StartLineNumber,
                $err.Extent.StartColumnNumber,
                $err.Message
            ) -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "OK: $($file.FullName)" -ForegroundColor Green
    }
}

if ($failed) {
    throw 'Hay errores de sintaxis PowerShell.'
}

Write-Host ''
Write-Host 'Todos los scripts PowerShell tienen sintaxis válida.' -ForegroundColor Green
