function Guardar-PidControlado {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivoPid,
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Proceso
    )

    $inicio = $Proceso.StartTime.ToUniversalTime().Ticks
    $registro = '{0}|{1}' -f $Proceso.Id, $inicio
    [System.IO.File]::WriteAllText($ArchivoPid, $registro, [System.Text.Encoding]::ASCII)
}

function Obtener-ProcesoControlado {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivoPid,
        [Parameter(Mandatory = $true)][string]$NombreEsperado
    )

    if (-not (Test-Path -LiteralPath $ArchivoPid)) { return $null }

    try {
        $archivo = Get-Item -LiteralPath $ArchivoPid -ErrorAction Stop
        $linea = (Get-Content -LiteralPath $ArchivoPid -TotalCount 1 -ErrorAction Stop).Trim()
        $partes = $linea -split '\|', 2
        $identificador = 0
        if (-not [int]::TryParse($partes[0], [ref]$identificador) -or $identificador -le 0) {
            return $null
        }

        $proceso = Get-Process -Id $identificador -ErrorAction Stop
        if ($proceso.ProcessName -ine $NombreEsperado) { return $null }
        $inicio = $proceso.StartTime.ToUniversalTime().Ticks

        if ($partes.Count -eq 2) {
            $inicioRegistrado = [long]0
            if (-not [long]::TryParse($partes[1], [ref]$inicioRegistrado)) { return $null }
            if ($inicio -ne $inicioRegistrado) { return $null }
        }
        else {
            # v3.3 wrote only a PID. Reject it when that PID has been reused.
            if ($proceso.StartTime.ToUniversalTime() -gt $archivo.LastWriteTimeUtc.AddSeconds(2)) {
                return $null
            }
        }

        return $proceso
    }
    catch { return $null }
}
