# Script de Verificación de Mitigaciones - Versión Simple
# Verifica: DNSSEC, DNS Fijo y cloudflared (DoH)

Write-Host "=== VERIFICACIÓN DE MEDIDAS DE MITIGACIÓN ===`n" -ForegroundColor Cyan

# ---- 1. DNSSEC ----
Write-Host "[1] DNSSEC:"
$dnsServers = (Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object -ExpandProperty ServerAddresses)
$dnssecServers = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112")

if ($dnsServers -eq $null -or $dnsServers.Count -eq 0) {
    Write-Host "  - DNSSEC DESACTIVADO (no hay DNS configurado)" -ForegroundColor Red
}
elseif ($dnsServers | Where-Object { $dnssecServers -contains $_ }) {
    Write-Host "  - DNSSEC ACTIVADO (DNS con validación detectado)" -ForegroundColor Green
} else {
    Write-Host "  - DNSSEC DESACTIVADO (no se detectan DNS con validación)" -ForegroundColor Red
}

# ---- 2. DNS Fijo (Estático) ----
Write-Host "`n[2] DNS Fijo (Estático):"
$adaptadores = Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses.Count -gt 0 }

if ($adaptadores) {
    Write-Host "  - DNS FIJO ACTIVADO (servidores configurados manualmente)" -ForegroundColor Green
} else {
    Write-Host "  - DNS FIJO DESACTIVADO (usando DHCP)" -ForegroundColor Red
}

# ---- 3. cloudflared (DoH) ----
Write-Host "`n[3] cloudflared (DNS over HTTPS):"
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue

if ($cloudflared) {
    $procesoCloudflared = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    $servicioCloudflared = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
    
    if ($procesoCloudflared -or ($servicioCloudflared -and $servicioCloudflared.Status -eq "Running")) {
        Write-Host "  - cloudflared ACTIVADO (ejecutándose)" -ForegroundColor Green
    } else {
        Write-Host "  - cloudflared DESACTIVADO (instalado pero no ejecutándose)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - cloudflared DESACTIVADO (no instalado)" -ForegroundColor Red
}

Write-Host "`n=== ANÁLISIS COMPLETO FINALIZADO ===" -ForegroundColor Cyan

# Pausar para ver los resultados
Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")