# Script de Verificación de Medidas de Mitigación
# Autor: Script de seguridad de red
# Descripción: Verifica el estado de DNSSEC, DoH, DNS Fijo, ARP Estático y Firewall

# Verificar si se está ejecutando como Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "⚠️  AVISO: Ejecutando sin permisos de Administrador" -ForegroundColor Yellow
    Write-Host "   La verificación del Firewall puede fallar.`n" -ForegroundColor Gray
}

Write-Host "=== VERIFICACIÓN DE MEDIDAS DE MITIGACIÓN ===`n" -ForegroundColor Cyan

# ---- 1. DNSSEC ----
Write-Host "[1] DNSSEC:"
try {
    $dnsServers = Get-DnsClientServerAddress -ErrorAction Stop | 
                  Where-Object { $_.ServerAddresses.Count -gt 0 } | 
                  Select-Object -ExpandProperty ServerAddresses -First 10
    
    # Servidores DNS con validación DNSSEC conocidos
    $dnssecServers = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112")
    
    if ($dnsServers.Count -eq 0) {
        Write-Host "  - No hay DNS configurado, posible DHCP → DNSSEC probablemente desactivado" -ForegroundColor Yellow
    }
    elseif ($dnsServers | Where-Object { $dnssecServers -contains $_ }) {
        Write-Host "  - DNSSEC POTENCIALMENTE ACTIVADO (se detectan DNS validadores)" -ForegroundColor Green
    } else {
        Write-Host "  - DNSSEC DESACTIVADO (no se detectan DNS con validación)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - ERROR: No se pudo verificar configuración DNS" -ForegroundColor Red
}

# ---- 2. DoH / DNS over HTTPS ----
Write-Host "`n[2] DNS over HTTPS (DoH):"

try {
    # Verificar si el comando está disponible
    $comandoDisponible = Get-Command Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue
    
    if ($comandoDisponible) {
        $doh = Get-DnsClientDohServerAddress -ErrorAction Stop
        
        if ($doh -eq $null -or $doh.Count -eq 0) {
            Write-Host "  - DoH DESACTIVADO (no hay servidores DoH registrados)" -ForegroundColor Red
        } else {
            # Verificar configuración DoH
            try {
                $dohConfig = Get-DnsClientDohConfiguration -ErrorAction Stop
                $modoUso = $dohConfig | Select-Object -ExpandProperty DohUsageMode -First 1
                
                if ($modoUso -eq "Require") {
                    Write-Host "  - DoH ACTIVADO y obligatorio" -ForegroundColor Green
                } else {
                    Write-Host "  - DoH PARCIALMENTE ACTIVADO pero no obligatorio" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  - DoH configurado pero no se pudo verificar el modo" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  - DoH NO SOPORTADO en esta versión de Windows" -ForegroundColor Yellow
        Write-Host "    (Requiere Windows 11 Build 22000+ o Windows Server 2022+)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - DoH DESACTIVADO (no hay servidores DoH registrados)" -ForegroundColor Red
}

# ---- 3. DNS Fijo / DNS Estático ----
Write-Host "`n[3] DNS Fijo (Estático):"
try {
    $adaptadores = Get-DnsClientServerAddress -ErrorAction Stop | 
                   Where-Object { $_.AddressFamily -eq 2 -and $_.ServerAddresses.Count -gt 0 }
    
    if ($adaptadores) {
        Write-Host "  - DNS FIJO ACTIVADO (servidores asignados manualmente)" -ForegroundColor Green
        foreach ($adaptador in $adaptadores) {
            $interfaz = $adaptador.InterfaceAlias
            $servidores = $adaptador.ServerAddresses -join ", "
            Write-Host "    · $interfaz`: $servidores" -ForegroundColor Gray
        }
    } else {
        Write-Host "  - DNS FIJO DESACTIVADO (usando DHCP)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - ERROR: No se pudo verificar configuración DNS" -ForegroundColor Red
}

# ---- 4. ARP Estático (ARP -s) ----
Write-Host "`n[4] ARP Estático:"
try {
    $arp = arp -a 2>$null
    
    if ($arp -match "estático|static") {
        Write-Host "  - ARP ESTÁTICO ACTIVADO (entradas estáticas detectadas)" -ForegroundColor Yellow
        # Mostrar entradas estáticas
        $arpEstatico = $arp | Select-String -Pattern "estático|static"
        foreach ($entrada in $arpEstatico) {
            Write-Host "    $entrada" -ForegroundColor Gray
        }
    } else {
        Write-Host "  - ARP ESTÁTICO DESACTIVADO (todas las entradas son dinámicas)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - ERROR: No se pudo ejecutar el comando ARP" -ForegroundColor Red
}

# ---- 5. Reglas de Firewall contra ARP Spoofing ----
Write-Host "`n[5] Firewall contra ARP Spoofing:"

if ($esAdmin) {
    try {
        $arpRule = Get-NetFirewallRule -ErrorAction Stop | 
                   Where-Object { $_.DisplayName -like "*ARP*" -or $_.DisplayName -like "*Spoofing*" }
        
        if ($arpRule) {
            Write-Host "  - REGLA ARP ACTIVADA (Firewall tiene reglas relacionadas)" -ForegroundColor Yellow
            foreach ($regla in $arpRule) {
                $estado = if ($regla.Enabled) { "Activa" } else { "Inactiva" }
                Write-Host "    · $($regla.DisplayName) - $estado" -ForegroundColor Gray
            }
        } else {
            Write-Host "  - REGLA ARP DESACTIVADA (no hay reglas de protección específicas)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  - ERROR: No se pudo verificar las reglas del Firewall" -ForegroundColor Red
    }
} else {
    Write-Host "  - NO VERIFICADO (se requieren permisos de Administrador)" -ForegroundColor Yellow
    Write-Host "    Ejecuta el script como Administrador para verificar" -ForegroundColor Gray
}

Write-Host "`n=== ANÁLISIS COMPLETO FINALIZADO ===" -ForegroundColor Cyan

# Pausar para ver los resultados
Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")