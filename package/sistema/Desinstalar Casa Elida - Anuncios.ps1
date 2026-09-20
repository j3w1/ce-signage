$ErrorActionPreference = 'SilentlyContinue'

$TaskName = 'Casa Elida - Anuncios'
$InstallDir = 'C:\ProgramData\Casa Elida\Anuncios'
$MediaFolder = 'C:\Users\windows\Desktop\anuncios'

function Es-Administrador {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Es-Administrador)) {
    Write-Host 'ERROR: Ejecute DESINSTALAR.cmd y acepte el aviso de Windows.' -ForegroundColor Red
    exit 1
}

try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}

Start-Sleep -Milliseconds 300

foreach ($pidFile in @(
    (Join-Path $InstallDir 'vlc.pid'),
    (Join-Path $InstallDir 'controlador.pid')
)) {
    if (Test-Path -LiteralPath $pidFile) {
        try {
            $pidObjetivo = [int](Get-Content -LiteralPath $pidFile | Select-Object -First 1)
            Stop-Process -Id $pidObjetivo -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
}

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}
catch {}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Casa Elida - Anuncios fue desinstalado.' -ForegroundColor Green
Write-Host "NO se borraron los anuncios de: $MediaFolder"
