function Confirmar-Sha256 {
    param(
        [Parameter(Mandatory = $true)][string]$Archivo,
        [Parameter(Mandatory = $true)][string]$ArchivoSha256
    )

    $esperado = (Get-Content -LiteralPath $ArchivoSha256 -Raw -ErrorAction Stop).Trim()
    if ($esperado -notmatch '^[a-fA-F0-9]{64}$') { throw 'Checksum de FFmpeg inválido.' }
    $actual = (Get-FileHash -LiteralPath $Archivo -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($actual -ine $esperado) { throw 'La descarga de FFmpeg no pasó la verificación SHA-256.' }
}
