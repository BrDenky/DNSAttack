Write-Host "=== REVERTIENDO TODAS LAS MEDIDAS DE MITIGACIÓN ===" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. RESTAURAR DNS AUTOMÁTICO (DHCP)
# -------------------------------------------------------------
Write-Host "`n[1] Restaurando DNS automático (DHCP)..." -ForegroundColor Yellow

$adapter = (Get-DnsClientServerAddress | Select-Object -First 1).InterfaceAlias

Set-DnsClientServerAddress -InterfaceAlias $adapter -ResetServerAddresses

Write-Host "  - DNS automático restaurado" -ForegroundColor Green


# -------------------------------------------------------------
# 2. DESHABILITAR DoH (DNS over HTTPS)
# -------------------------------------------------------------
Write-Host "`n[2] Eliminando servidores DoH y desactivando DoH..." -ForegroundColor Yellow

# Obtener servidores DoH registrados
$dohServers = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue

if ($dohServers) {
    foreach ($srv in $dohServers) {
        Remove-DnsClientDohServerAddress -ServerAddress $srv.ServerAddress -ErrorAction SilentlyContinue
    }
}

# Cambiar modo de uso de DoH
Set-DnsClientDohConfiguration -DohUsageMode Off

Write-Host "  - DoH desactivado completamente" -ForegroundColor Green


# -------------------------------------------------------------
# 3. ELIMINAR ARP ESTÁTICO (ARP -d)
# -------------------------------------------------------------
Write-Host "`n[3] Eliminando entradas ARP estáticas..." -ForegroundColor Yellow

arp -d *

Write-Host "  - Todas las entradas ARP estáticas fueron eliminadas" -ForegroundColor Green


# -------------------------------------------------------------
# 4. ELIMINAR REGLA DE FIREWALL CONTRA ARP SPOOFING
# -------------------------------------------------------------
Write-Host "`n[4] Eliminando regla de firewall anti-ARP Spoofing..." -ForegroundColor Yellow

$arpRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Block ARP Spoofing" }

if ($arpRule) {
    Remove-NetFirewallRule -DisplayName "Block ARP Spoofing"
    Write-Host "  - Regla de firewall eliminada" -ForegroundColor Green
} else {
    Write-Host "  - No existe regla ARP para eliminar" -ForegroundColor Yellow
}


# -------------------------------------------------------------
# 5. CONFIRMACIÓN FINAL
# -------------------------------------------------------------
Write-Host "`n=== TODAS LAS CONFIGURACIONES HAN SIDO REVERTIDAS ===" -ForegroundColor Cyan
Write-Host "Tu VM ahora es nuevamente VULNERABLE a ARP Spoofing y DNS Spoofing." -ForegroundColor Red
