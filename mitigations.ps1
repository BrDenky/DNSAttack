# Script de Activación de Mitigaciones - Versión Simple
# Activa: DNSSEC, DNS Fijo y cloudflared (DoH)
# Requiere: Permisos de Administrador

# Verificar permisos de Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "❌ ERROR: Este script DEBE ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Haz clic derecho en el archivo y selecciona 'Ejecutar como Administrador'`n" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "=== ACTIVANDO MEDIDAS DE MITIGACIÓN ===`n" -ForegroundColor Cyan

# -------------------------------------------------------------
# 1. CONFIGURAR DNS FIJO + DNSSEC (Cloudflare)
# -------------------------------------------------------------
Write-Host "[1] Configurando DNS Fijo + DNSSEC (Cloudflare)..." -ForegroundColor Yellow

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
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "1.1.1.1","1.0.0.1" -ErrorAction Stop
                Write-Host "  - ✓ DNS configurado en: $($adapter.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  - ⚠ Error en: $($adapter.Name)" -ForegroundColor Yellow
            }
        }
        Write-Host "  - DNS Primario: 1.1.1.1 (Cloudflare + DNSSEC)" -ForegroundColor Gray
        Write-Host "  - DNS Secundario: 1.0.0.1 (Cloudflare + DNSSEC)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - ❌ Error al configurar DNS: $($_.Exception.Message)" -ForegroundColor Red
}

# -------------------------------------------------------------
# 2. INSTALAR Y CONFIGURAR CLOUDFLARED (DoH)
# -------------------------------------------------------------
Write-Host "`n[2] Configurando cloudflared (DNS over HTTPS)..." -ForegroundColor Yellow

# Verificar si cloudflared ya está instalado
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue

if ($cloudflared) {
    Write-Host "  - ✓ cloudflared ya está instalado" -ForegroundColor Green
} else {
    Write-Host "  - cloudflared NO está instalado" -ForegroundColor Yellow
    Write-Host "  - Intentando instalar con winget..." -ForegroundColor Gray
    
    # Verificar si winget está disponible
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($winget) {
        try {
            Write-Host "  - Instalando cloudflared (esto puede tardar un minuto)..." -ForegroundColor Gray
            $resultado = winget install --id Cloudflare.cloudflared --silent --accept-source-agreements --accept-package-agreements 2>&1
            
            # Refrescar PATH para detectar cloudflared
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Start-Sleep -Seconds 3
            
            # Verificar instalación
            $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
            if ($cloudflared) {
                Write-Host "  - ✓ cloudflared instalado correctamente" -ForegroundColor Green
            } else {
                Write-Host "  - ⚠ cloudflared instalado pero requiere reinicio de PowerShell" -ForegroundColor Yellow
                Write-Host "  - Cierra y vuelve a abrir PowerShell como Admin" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  - ❌ Error al instalar con winget" -ForegroundColor Red
            Write-Host "  - Descarga manualmente desde: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Gray
        }
    } else {
        Write-Host "  - ❌ winget no está disponible" -ForegroundColor Red
        Write-Host "  - Instala cloudflared manualmente:" -ForegroundColor Gray
        Write-Host "    1. Descarga desde: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Gray
        Write-Host "    2. Extrae cloudflared.exe a C:\Windows\System32\" -ForegroundColor Gray
    }
}

# Configurar cloudflared si está disponible
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Write-Host "`n  - Configurando cloudflared como servicio..." -ForegroundColor Gray
    
    try {
        # Detener servicio existente si existe
        $servicioExistente = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($servicioExistente) {
            Write-Host "  - Deteniendo servicio existente..." -ForegroundColor Gray
            Stop-Service -Name "cloudflared" -Force -ErrorAction SilentlyContinue
            & cloudflared service uninstall 2>$null
            Start-Sleep -Seconds 2
        }
        
        # Instalar servicio cloudflared
        Write-Host "  - Instalando servicio cloudflared..." -ForegroundColor Gray
        & cloudflared service install 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        
        # Iniciar servicio
        Write-Host "  - Iniciando servicio cloudflared..." -ForegroundColor Gray
        Start-Service -Name "cloudflared" -ErrorAction Stop
        Start-Sleep -Seconds 3
        
        # Verificar que el servicio está corriendo
        $servicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($servicio -and $servicio.Status -eq "Running") {
            Write-Host "  - ✓ cloudflared configurado y ejecutándose como servicio" -ForegroundColor Green
            
            # Configurar DNS a localhost para usar cloudflared
            Write-Host "`n  - Configurando DNS para usar cloudflared (127.0.0.1)..." -ForegroundColor Gray
            
            foreach ($adapter in $adapters) {
                try {
                    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "127.0.0.1","1.1.1.1" -ErrorAction Stop
                    Write-Host "  - ✓ DNS actualizado en: $($adapter.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  - ⚠ Error en: $($adapter.Name)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "  - DNS Primario: 127.0.0.1 (cloudflared - DoH)" -ForegroundColor Gray
            Write-Host "  - DNS Secundario: 1.1.1.1 (Cloudflare - respaldo)" -ForegroundColor Gray
        } else {
            Write-Host "  - ⚠ El servicio se instaló pero no está ejecutándose" -ForegroundColor Yellow
            Write-Host "  - Intenta iniciar manualmente: Start-Service cloudflared" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  - ❌ Error al configurar servicio: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  - Puedes ejecutar cloudflared manualmente: cloudflared proxy-dns" -ForegroundColor Gray
    }
}

# -------------------------------------------------------------
# 3. VERIFICACIÓN FINAL
# -------------------------------------------------------------
Write-Host "`n=== VERIFICACIÓN FINAL ===`n" -ForegroundColor Cyan

# Verificar DNS
Write-Host "[1] DNS Fijo + DNSSEC:" -ForegroundColor White
$dnsConfig = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 -and $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1
if ($dnsConfig.ServerAddresses -contains "127.0.0.1" -or $dnsConfig.ServerAddresses -contains "1.1.1.1") {
    Write-Host "  ✓ DNS configurado correctamente" -ForegroundColor Green
} else {
    Write-Host "  ⚠ DNS puede no estar configurado correctamente" -ForegroundColor Yellow
}

# Verificar cloudflared
Write-Host "`n[2] cloudflared (DoH):" -ForegroundColor White
$cloudflaredServicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cloudflaredServicio -and $cloudflaredServicio.Status -eq "Running") {
    Write-Host "  ✓ cloudflared ejecutándose" -ForegroundColor Green
} else {
    $cloudflaredProceso = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($cloudflaredProceso) {
        Write-Host "  ✓ cloudflared ejecutándose (como proceso)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ cloudflared no está ejecutándose" -ForegroundColor Yellow
    }
}

# Probar DNS
Write-Host "`n[3] Prueba de resolución DNS:" -ForegroundColor White
try {
    $test = Resolve-DnsName google.com -Type A -ErrorAction Stop | Select-Object -First 1
    Write-Host "  ✓ DNS funcionando correctamente" -ForegroundColor Green
    Write-Host "  - google.com resuelve a: $($test.IPAddress)" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠ Error al resolver DNS" -ForegroundColor Yellow
}

Write-Host "`n=== CONFIGURACIÓN COMPLETADA ===`n" -ForegroundColor Cyan

Write-Host "NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "  • Si cloudflared no se instaló, descárgalo manualmente" -ForegroundColor Gray
Write-Host "  • Ejecuta el script de verificación para confirmar" -ForegroundColor Gray
Write-Host "  • cloudflared se iniciará automáticamente con Windows" -ForegroundColor Gray

Write-Host "`nPresiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")