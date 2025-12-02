# Script de Activacion de Mitigaciones - Version Simple
# Activa: DNSSEC, DNS Fijo y cloudflared (DoH)
# Requiere: Permisos de Administrador

# Verificar permisos de Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "ERROR: Este script DEBE ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Haz clic derecho en el archivo y selecciona Ejecutar como Administrador" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "=== ACTIVANDO MEDIDAS DE MITIGACION ===" -ForegroundColor Cyan
Write-Host ""

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
        Write-Host "  - ERROR: No se encontraron adaptadores de red activos" -ForegroundColor Red
    } else {
        foreach ($adapter in $adapters) {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "1.1.1.1","1.0.0.1" -ErrorAction Stop
                Write-Host "  - OK: DNS configurado en: $($adapter.Name)" -ForegroundColor Green
            } catch {
                Write-Host "  - ADVERTENCIA: Error en $($adapter.Name)" -ForegroundColor Yellow
            }
        }
        Write-Host "  - DNS Primario: 1.1.1.1 (Cloudflare + DNSSEC)" -ForegroundColor Gray
        Write-Host "  - DNS Secundario: 1.0.0.1 (Cloudflare + DNSSEC)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - ERROR al configurar DNS" -ForegroundColor Red
}

# -------------------------------------------------------------
# 2. INSTALAR Y CONFIGURAR CLOUDFLARED (DoH)
# -------------------------------------------------------------
Write-Host ""
Write-Host "[2] Configurando cloudflared (DNS over HTTPS)..." -ForegroundColor Yellow

# Verificar si cloudflared ya esta instalado
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue

if ($cloudflared) {
    Write-Host "  - OK: cloudflared ya esta instalado" -ForegroundColor Green
} else {
    Write-Host "  - cloudflared NO esta instalado" -ForegroundColor Yellow
    Write-Host "  - Intentando instalar con winget..." -ForegroundColor Gray
    
    # Verificar si winget esta disponible
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($winget) {
        try {
            Write-Host "  - Instalando cloudflared (esto puede tardar un minuto)..." -ForegroundColor Gray
            winget install --id Cloudflare.cloudflared --silent --accept-source-agreements --accept-package-agreements | Out-Null
            
            # Refrescar PATH para detectar cloudflared
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Start-Sleep -Seconds 3
            
            # Verificar instalacion
            $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
            if ($cloudflared) {
                Write-Host "  - OK: cloudflared instalado correctamente" -ForegroundColor Green
            } else {
                Write-Host "  - ADVERTENCIA: cloudflared instalado pero requiere reinicio de PowerShell" -ForegroundColor Yellow
                Write-Host "  - Cierra y vuelve a abrir PowerShell como Admin" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  - ERROR al instalar con winget" -ForegroundColor Red
            Write-Host "  - Descarga manualmente desde: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Gray
        }
    } else {
        Write-Host "  - ERROR: winget no esta disponible" -ForegroundColor Red
        Write-Host "  - Instala cloudflared manualmente:" -ForegroundColor Gray
        Write-Host "    1. Descarga desde: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Gray
        Write-Host "    2. Extrae cloudflared.exe a C:\Windows\System32\" -ForegroundColor Gray
    }
}

# Configurar cloudflared si esta disponible
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Write-Host ""
    Write-Host "  - Configurando cloudflared como servicio..." -ForegroundColor Gray
    
    try {
        # Detener servicio existente si existe
        $servicioExistente = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($servicioExistente) {
            Write-Host "  - Deteniendo servicio existente..." -ForegroundColor Gray
            Stop-Service -Name "cloudflared" -Force -ErrorAction SilentlyContinue
            cloudflared service uninstall 2>$null
            Start-Sleep -Seconds 2
        }
        
        # Instalar servicio cloudflared
        Write-Host "  - Instalando servicio cloudflared..." -ForegroundColor Gray
        cloudflared service install 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        
        # Iniciar servicio
        Write-Host "  - Iniciando servicio cloudflared..." -ForegroundColor Gray
        Start-Service -Name "cloudflared" -ErrorAction Stop
        Start-Sleep -Seconds 3
        
        # Verificar que el servicio esta corriendo
        $servicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($servicio -and $servicio.Status -eq "Running") {
            Write-Host "  - OK: cloudflared configurado y ejecutandose como servicio" -ForegroundColor Green
            
            # Configurar DNS a localhost para usar cloudflared
            Write-Host ""
            Write-Host "  - Configurando DNS para usar cloudflared (127.0.0.1)..." -ForegroundColor Gray
            
            foreach ($adapter in $adapters) {
                try {
                    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "127.0.0.1","1.1.1.1" -ErrorAction Stop
                    Write-Host "  - OK: DNS actualizado en $($adapter.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  - ADVERTENCIA: Error en $($adapter.Name)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "  - DNS Primario: 127.0.0.1 (cloudflared - DoH)" -ForegroundColor Gray
            Write-Host "  - DNS Secundario: 1.1.1.1 (Cloudflare - respaldo)" -ForegroundColor Gray
        } else {
            Write-Host "  - ADVERTENCIA: El servicio se instalo pero no esta ejecutandose" -ForegroundColor Yellow
            Write-Host "  - Intenta iniciar manualmente: Start-Service cloudflared" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  - ERROR al configurar servicio" -ForegroundColor Red
        Write-Host "  - Puedes ejecutar cloudflared manualmente: cloudflared proxy-dns" -ForegroundColor Gray
    }
}

# -------------------------------------------------------------
# 3. VERIFICACION FINAL
# -------------------------------------------------------------
Write-Host ""
Write-Host "=== VERIFICACION FINAL ===" -ForegroundColor Cyan
Write-Host ""

# Verificar DNS
Write-Host "[1] DNS Fijo + DNSSEC:" -ForegroundColor White
$dnsConfig = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 -and $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1
if ($dnsConfig.ServerAddresses -contains "127.0.0.1" -or $dnsConfig.ServerAddresses -contains "1.1.1.1") {
    Write-Host "  OK: DNS configurado correctamente" -ForegroundColor Green
} else {
    Write-Host "  ADVERTENCIA: DNS puede no estar configurado correctamente" -ForegroundColor Yellow
}

# Verificar cloudflared
Write-Host ""
Write-Host "[2] cloudflared (DoH):" -ForegroundColor White
$cloudflaredServicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cloudflaredServicio -and $cloudflaredServicio.Status -eq "Running") {
    Write-Host "  OK: cloudflared ejecutandose" -ForegroundColor Green
} else {
    $cloudflaredProceso = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($cloudflaredProceso) {
        Write-Host "  OK: cloudflared ejecutandose (como proceso)" -ForegroundColor Green
    } else {
        Write-Host "  ADVERTENCIA: cloudflared no esta ejecutandose" -ForegroundColor Yellow
    }
}

# Probar DNS
Write-Host ""
Write-Host "[3] Prueba de resolucion DNS:" -ForegroundColor White
try {
    $test = Resolve-DnsName google.com -Type A -ErrorAction Stop | Select-Object -First 1
    Write-Host "  OK: DNS funcionando correctamente" -ForegroundColor Green
    Write-Host "  - google.com resuelve a: $($test.IPAddress)" -ForegroundColor Gray
} catch {
    Write-Host "  ADVERTENCIA: Error al resolver DNS" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== CONFIGURACION COMPLETADA ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "  - Si cloudflared no se instalo, descargalo manualmente" -ForegroundColor Gray
Write-Host "  - Ejecuta el script de verificacion para confirmar" -ForegroundColor Gray
Write-Host "  - cloudflared se iniciara automaticamente con Windows" -ForegroundColor Gray

Write-Host ""
Write-Host "Presiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")