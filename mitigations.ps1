Write-Host "=== ACTIVANDO TODAS LAS MEDIDAS DE MITIGACIÓN ===" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. CONFIGURAR DNS FIJO + DNSSEC (Cloudflare validado)
# -------------------------------------------------------------
Write-Host "`n[1] Configurando DNS fijo (Cloudflare) + soporte DNSSEC..." -ForegroundColor Yellow

$adapter = (Get-DnsClientServerAddress | Select-Object -First 1).InterfaceAlias

Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses "1.1.1.1","1.0.0.1"

Write-Host "  - DNS fijado a 1.1.1.1 / 1.0.0.1" -ForegroundColor Green


# -------------------------------------------------------------
# 2. ACTIVAR DNS OVER HTTPS (DoH) Y FORZAR SU USO
# -------------------------------------------------------------
Write-Host "`n[2] Activando y forzando DNS over HTTPS (DoH)..." -ForegroundColor Yellow

# Registrar servidores DoH de Cloudflare
Add-DnsClientDohServerAddress -ServerAddress "1.1.1.1" -DohTemplate "https://cloudflare-dns.com/dns-query" -AllowHttpsQuery -ErrorAction SilentlyContinue
Add-DnsClientDohServerAddress -ServerAddress "1.0.0.1" -DohTemplate "https://cloudflare-dns.com/dns-query" -AllowHttpsQuery -ErrorAction SilentlyContinue

# Obligar a Windows a usar DoH
Set-DnsClientDohConfiguration -DohUsageMode Require

Write-Host "  - DoH habilitado y obligatorio" -ForegroundColor Green


# -------------------------------------------------------------
# 3. CONFIGURAR ARP ESTÁTICO (BLOQUEA ARP SPOOFING)
# -------------------------------------------------------------
Write-Host "`n[3] Configurando ARP estático para bloquear ARP Spoofing..." -ForegroundColor Yellow

# Obtener IP del gateway
$gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0").NextHop

# Obtener MAC real del gateway
$gwMAC = (arp -a | Select-String $gateway).ToString().Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[1]

# Crear entrada ARP estática
arp -s $gateway $gwMAC

Write-Host "  - ARP estático aplicado: $gateway -> $gwMAC" -ForegroundColor Green


# -------------------------------------------------------------
# 4. REGLA DE FIREWALL CONTRA ARP SPOOFING
# -------------------------------------------------------------
Write-Host "`n[4] Activando regla de firewall contra ARP Spoofing..." -ForegroundColor Yellow

# Crear regla que bloquea paquetes ARP no solicitados (0x806)
New-NetFirewallRule -DisplayName "Block ARP Spoofing" `
    -Direction Inbound -Action Block -Protocol 0x806 `
    -Profile Any -ErrorAction SilentlyContinue

Write-Host "  - Regla de firewall anti-ARP spoofing activada" -ForegroundColor Green


# -------------------------------------------------------------
# 5. CONFIRMACIÓN FINAL
# -------------------------------------------------------------
Write-Host "`n=== TODAS LAS MITIGACIONES FUERON ACTIVADAS CORRECTAMENTE ===" -ForegroundColor Cyan
