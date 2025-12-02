# Script de Desactivación de Mitigaciones
# Desactiva: DNSSEC, DNS Fijo y cloudflared (DoH)
# ADVERTENCIA: Vuelve el sistema a un estado vulnerable
# Requiere: Permisos de Administrador

# Verificar permisos de Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "❌ ERROR: Este script DEBE ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Haz clic derecho en el archivo y selecciona 'Ejecutar como Administrador'`n" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "=== DESACTIVANDO MEDIDAS DE MITIGACIÓN ===`n" -ForegroundColor Cyan
Write-Host "⚠️  ADVERTENCIA: El sistema volverá a un estado VULNERABLE" -ForegroundColor Red
Write-Host "    Esto es útil para demostrar ataques en entornos de prueba`n" -ForegroundColor Yellow

# Confirmar acción
Write-Host "¿Estás seguro de que deseas desactivar las mitigaciones? (S/N): " -ForegroundColor Yellow -NoNewline
$confirmacion = Read-Host

if ($confirmacion -ne "S" -and $confirmacion -ne "s") {
    Write-Host "`n❌ Operación cancelada por el usuario" -ForegroundColor Red
    pause
    exit
}

Write-Host ""

# -------------------------------------------------------------
# 1. DETENER Y DESINSTALAR CLOUDFLARED
# -------------------------------------------------------------
Write-Host "[1] Desactivando cloudflared (DoH)..." -ForegroundColor Yellow

try {
    # Verificar si cloudflared está instalado
    $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
    
    if ($cloudflared) {
        # Detener servicio cloudflared
        $servicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($servicio) {
            Write-Host "  - Deteniendo servicio cloudflared..." -ForegroundColor Gray
            try {
                Stop-Service -Name "cloudflared" -Force -ErrorAction Stop
                Write-Host "  - ✓ Servicio detenido" -ForegroundColor Green
            } catch {
                Write-Host "  - ⚠ No se pudo detener el servicio" -ForegroundColor Yellow
            }
            
            # Desinstalar servicio
            Write-Host "  - Desinstalando servicio cloudflared..." -ForegroundColor Gray
            try {
                & cloudflared service uninstall 2>&1 | Out-Null
                Start-Sleep -Seconds 2
                Write-Host "  - ✓ Servicio desinstalado" -ForegroundColor Green
            } catch {
                Write-Host "  - ⚠ Error al desinstalar servicio" -ForegroundColor Yellow
            }
        }
        
        # Detener proceso cloudflared si está corriendo
        $proceso = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($proceso) {
            Write-Host "  - Deteniendo proceso cloudflared..." -ForegroundColor Gray
            Stop-Process -Name "cloudflared" -Force -ErrorAction SilentlyContinue
            Write-Host "  - ✓ Proceso detenido" -ForegroundColor Green
        }
        
        Write-Host "  - ✓ cloudflared desactivado correctamente" -ForegroundColor Green
    } else {
        Write-Host "  - cloudflared no está instalado (omitiendo)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - ❌ Error al desactivar cloudflared: $($_.Exception.Message)" -ForegroundColor Red
}

# -------------------------------------------------------------
# 2. RESTAURAR DNS A AUTOMÁTICO (DHCP)
# -------------------------------------------------------------
Write-Host "`n[2] Restaurando DNS a automático (DHCP)..." -ForegroundColor Yellow

try {
    $adapters = Get-NetAdapter | Where-Object { 
        $_.Status -eq "Up" -and 
        $_.InterfaceDescription -notlike "*Loopback*"
    }
    
    if ($adapters.Count -eq 0) {
        Write-Host "  - ❌ No se encontraron adaptadores de red activos" -ForegroundColor Red
    } else {
        foreach ($adapter in $adapters) {
            try {
                # Configurar DNS automático (obtener por DHCP)
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction Stop
                Write-Host "  - ✓ DNS automático restaurado en: $($adapter.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  - ⚠ Error en: $($adapter.Name)" -ForegroundColor Yellow
            }
        }
        Write-Host "  - Ahora el DNS se obtiene automáticamente por DHCP" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - ❌ Error al restaurar DNS: $($_.Exception.Message)" -ForegroundColor Red
}

# -------------------------------------------------------------
# 3. LIMPIAR CACHÉ DNS
# -------------------------------------------------------------
Write-Host "`n[3] Limpiando caché DNS..." -ForegroundColor Yellow

try {
    Clear-DnsClientCache -ErrorAction Stop
    Write-Host "  - ✓ Caché DNS limpiada" -ForegroundColor Green
} catch {
    Write-Host "  - ⚠ Error al limpiar caché DNS" -ForegroundColor Yellow
}

# -------------------------------------------------------------
# 4. VERIFICACIÓN FINAL
# -------------------------------------------------------------
Write-Host "`n=== VERIFICACIÓN FINAL ===`n" -ForegroundColor Cyan

# Verificar DNS
Write-Host "[1] Estado DNS:" -ForegroundColor White
$dnsConfig = Get-DnsClientServerAddress | Where-Object { 
    $_.ServerAddresses.Count -gt 0 -and 
    $_.InterfaceAlias -notlike "*Loopback*" 
} | Select-Object -First 1

if ($dnsConfig -and $dnsConfig.ServerAddresses.Count -gt 0) {
    Write-Host "  ⚠ DNS Fijo aún configurado:" -ForegroundColor Yellow
    foreach ($dns in $dnsConfig.ServerAddresses) {
        Write-Host "    • $dns" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✓ DNS en modo AUTOMÁTICO (DHCP)" -ForegroundColor Green
}

# Verificar cloudflared
Write-Host "`n[2] Estado cloudflared:" -ForegroundColor White
$cloudflaredServicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
$cloudflaredProceso = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue

if ($cloudflaredServicio -or $cloudflaredProceso) {
    Write-Host "  ⚠ cloudflared aún está ejecutándose" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ cloudflared DESACTIVADO" -ForegroundColor Green
}

# Verificar DNSSEC
Write-Host "`n[3] Estado DNSSEC:" -ForegroundColor White
$dnsServers = (Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object -ExpandProperty ServerAddresses)
$dnssecServers = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112")

if ($dnsServers | Where-Object { $dnssecServers -contains $_ }) {
    Write-Host "  ⚠ Aún hay DNS con DNSSEC detectado" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ DNSSEC DESACTIVADO" -ForegroundColor Green
}

# Probar DNS
Write-Host "`n[4] Prueba de resolución DNS:" -ForegroundColor White
try {
    $test = Resolve-DnsName google.com -Type A -ErrorAction Stop | Select-Object -First 1
    Write-Host "  ✓ DNS funcionando" -ForegroundColor Green
    Write-Host "  - google.com resuelve a: $($test.IPAddress)" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠ Error al resolver DNS" -ForegroundColor Yellow
}

Write-Host "`n=== DESACTIVACIÓN COMPLETADA ===`n" -ForegroundColor Cyan

Write-Host "RESUMEN:" -ForegroundColor Yellow
Write-Host "  • DNS restaurado a AUTOMÁTICO (sin DNSSEC)" -ForegroundColor Gray
Write-Host "  • cloudflared desactivado (sin DoH)" -ForegroundColor Gray
Write-Host "  • Sistema en estado VULNERABLE para pruebas" -ForegroundColor Gray

Write-Host "`n⚠️  EL SISTEMA AHORA ES VULNERABLE A:" -ForegroundColor Red
Write-Host "  • DNS Spoofing / DNS Cache Poisoning" -ForegroundColor Gray
Write-Host "  • ARP Spoofing / ARP Poisoning" -ForegroundColor Gray
Write-Host "  • Man-in-the-Middle (MitM) attacks" -ForegroundColor Gray
Write-Host "  • Intercepción de tráfico DNS sin cifrar" -ForegroundColor Gray

Write-Host "`n💡 Para REACTIVAR las mitigaciones:" -ForegroundColor Cyan
Write-Host "   Ejecuta el script: Activar-Mitigaciones.ps1" -ForegroundColor Gray

Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")