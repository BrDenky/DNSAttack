Write-Host "=== VERIFICACIÓN DE MEDIDAS DE MITIGACIÓN ===`n" -ForegroundColor Cyan

# ---- 1. DNSSEC ----
Write-Host "[1] DNSSEC:"
$dnsServers = (Get-DnsClientServerAddress | Select-Object -ExpandProperty ServerAddresses)
# DNSSEC está activo solo si se usan validadores conocidos: Cloudflare, Google, Quad9
$dnssecServers = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112")

if ($dnsServers -eq $null) {
    Write-Host "  - No hay DNS configurado, posible DHCP → DNSSEC probablemente desactivado" -ForegroundColor Yellow
}
elseif ($dnsServers | Where-Object { $dnssecServers -contains $_ }) {
    Write-Host "  - DNSSEC POTENCIALMENTE ACTIVADO (se detectan DNS validadores)" -ForegroundColor Green
} else {
    Write-Host "  - DNSSEC DESACTIVADO (no se detectan DNS con validación)" -ForegroundColor Red
}

# ---- 2. DoH / DNS over HTTPS ----
Write-Host "`n[2] DNS over HTTPS (DoH):"
$doh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue

if ($doh -eq $null -or $doh.Count -eq 0) {
    Write-Host "  - DoH DESACTIVADO (no hay servidores DoH registrados)" -ForegroundColor Red
} else {
    # Verificar si Windows requiere DoH
    $dohConfig = Get-DnsClientDohConfiguration | Select-Object -ExpandProperty DohUsageMode
    if ($dohConfig -eq "Require") {
        Write-Host "  - DoH ACTIVADO y obligatorio" -ForegroundColor Green
    } else {
        Write-Host "  - DoH PARCIALMENTE ACTIVADO pero no obligatorio" -ForegroundColor Yellow
    }
}

# ---- 3. DNS Fijo / DNS Estático ----
Write-Host "`n[3] DNS Fijo (Estático):"
$ipv4 = Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 }
$dnsFixo = $false

foreach ($entry in $ipv4) {
    if ($entry.ServerAddresses.Count -gt 0) {
        Write-Host "  - DNS FIJO ACTIVADO (servidores asignados manualmente)" -ForegroundColor Green
        $dnsFixo = $true
        break
    }
}

if (-not $dnsFixo) {
    Write-Host "  - DNS FIJO DESACTIVADO (usando DHCP)" -ForegroundColor Red
}

# ---- 4. ARP Estático (ARP -s) ----
Write-Host "`n[4] ARP Estático:"
$arp = arp -a

if ($arp -match "static") {
    Write-Host "  - ARP ESTÁTICO ACTIVADO (entradas estáticas detectadas)" -ForegroundColor Yellow
} else {
    Write-Host "  - ARP ESTÁTICO DESACTIVADO" -ForegroundColor Red
}

# ---- 5. Reglas de Firewall contra ARP Spoofing ----
Write-Host "`n[5] Firewall contra ARP Spoofing:"
$arpRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*ARP*" }

if ($arpRule) {
    Write-Host "  - REGLA ARP ACTIVADA (Firewall bloquea ARP)" -ForegroundColor Yellow
} else {
    Write-Host "  - REGLA ARP DESACTIVADA (no hay reglas de protección)" -ForegroundColor Red
}

Write-Host "`n=== ANÁLISIS COMPLETO FINALIZADO ===" -ForegroundColor Cyan

# Pausar para ver los resultados
Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")