Write-Host "=== DETECCIÓN DE DNS OVER HTTPS (DoH) EN WINDOWS 10 ===`n" -ForegroundColor Cyan

# 1. Verificar si el sistema soporta DoH
$build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

Write-Host "Build del sistema: $build"

if ([int]$build -ge 19041) {
    Write-Host "✔ El sistema SOPORTA DNS over HTTPS (DoH)" -ForegroundColor Green
} else {
    Write-Host "❌ Este sistema NO soporta DoH (requiere Windows 10 2004+)" -ForegroundColor Red
    exit
}

# 2. Verificar si DoH está habilitado en el Registro
$dohKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters\Doh"
$dohMode = (Get-ItemProperty $dohKey -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DohDnsMode -ErrorAction SilentlyContinue)

if ($dohMode -eq 2) {
    Write-Host "✔ DoH está ACTIVADO y OBLIGATORIO (DohDnsMode = 2)" -ForegroundColor Green
} elseif ($dohMode -eq 1) {
    Write-Host "✔ DoH está ACTIVADO (Modo Automático)" -ForegroundColor Yellow
} else {
    Write-Host "❌ DoH está DESACTIVADO (DohDnsMode = 0)" -ForegroundColor Red
}

# 3. Verificar si el DNS configurado es compatible con DoH
$dns = Get-DnsClientServerAddress | Select-Object -ExpandProperty ServerAddresses -ErrorAction SilentlyContinue

$dohServers = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9")

if ($dns | Where-Object { $dohServers -contains $_ }) {
    Write-Host "✔ DNS compatible con DoH detectado: $($dns -join ', ')" -ForegroundColor Green
} else {
    Write-Host "❌ El DNS configurado NO soporta DoH" -ForegroundColor Red
}

Write-Host "`n=== FIN DEL ANÁLISIS ==="
