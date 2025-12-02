# Verificar si se está ejecutando como Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "⚠️  AVISO: Este script necesita permisos de Administrador para verificar el Firewall" -ForegroundColor Yellow
    Write-Host "   Algunas verificaciones pueden fallar. Para mejores resultados:" -ForegroundColor Yellow
    Write-Host "   1. Cierra esta ventana" -ForegroundColor Gray
    Write-Host "   2. Haz clic derecho en el archivo .ps1" -ForegroundColor Gray
    Write-Host "   3. Selecciona 'Ejecutar con PowerShell (como Administrador)'`n" -ForegroundColor Gray
    Start-Sleep -Seconds 3
}

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

# Verificar si los comandos DoH están disponibles (Windows 11 / Windows Server 2022+)
$dohSupported = Get-Command Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue

if ($dohSupported) {
    $doh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue
    
    if ($doh -eq $null -or $doh.Count -eq 0) {
        Write-Host "  - DoH DESACTIVADO (no hay servidores DoH registrados)" -ForegroundColor Red
    } else {
        # Verificar si Windows requiere DoH
        $dohConfig = Get-DnsClientDohConfiguration -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DohUsageMode
        if ($dohConfig -eq "Require") {
            Write-Host "  - DoH ACTIVADO y obligatorio" -ForegroundColor Green
        } else {
            Write-Host "  - DoH PARCIALMENTE ACTIVADO pero no obligatorio" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  - DoH NO SOPORTADO en esta versión de Windows" -ForegroundColor Yellow
    Write-Host "    (Requiere Windows 11 o Windows Server 2022+)" -ForegroundColor Gray
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

if ($esAdmin) {
    try {
        $arpRule = Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.DisplayName -like "*ARP*" }
        
        if ($arpRule) {
            Write-Host "  - REGLA ARP ACTIVADA (Firewall bloquea ARP)" -ForegroundColor Yellow
        } else {
            Write-Host "  - REGLA ARP DESACTIVADA (no hay reglas de protección)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  - ERROR: No se pudo verificar el Firewall" -ForegroundColor Red
        Write-Host "    Ejecuta el script como Administrador" -ForegroundColor Gray
    }
} else {
    Write-Host "  - NO VERIFICADO (se requieren permisos de Administrador)" -ForegroundColor Yellow
}

Write-Host "`n=== ANÁLISIS COMPLETO FINALIZADO ===" -ForegroundColor Cyan

# Pausar para ver los resultados
Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")