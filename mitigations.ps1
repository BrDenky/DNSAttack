# Script de Activacion de Mitigaciones
# Activa: DNSSEC, DNS Fijo y cloudflared (DoH)
# Requiere: Permisos de Administrador

$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host "ERROR: Este script DEBE ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "Haz clic derecho en el archivo y selecciona Ejecutar como Administrador" -ForegroundColor Yellow
    pause
    exit
}

Write-Host "=== ACTIVANDO MEDIDAS DE MITIGACION ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Configurando DNS Fijo + DNSSEC (Cloudflare)..." -ForegroundColor Yellow

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Loopback*" }

if ($adapters.Count -eq 0) {
    Write-Host "  ERROR: No se encontraron adaptadores activos" -ForegroundColor Red
} else {
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "1.1.1.1","1.0.0.1"
        Write-Host "  OK: DNS configurado en $($adapter.Name)" -ForegroundColor Green
    }
    Write-Host "  DNS: 1.1.1.1 y 1.0.0.1 (Cloudflare + DNSSEC)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "[2] Configurando cloudflared (DNS over HTTPS)..." -ForegroundColor Yellow

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue

if ($cloudflared) {
    Write-Host "  OK: cloudflared ya esta instalado" -ForegroundColor Green
} else {
    Write-Host "  cloudflared NO instalado" -ForegroundColor Yellow
    Write-Host "  Intentando instalar con winget..." -ForegroundColor Gray
    
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($winget) {
        Write-Host "  Instalando cloudflared..." -ForegroundColor Gray
        winget install --id Cloudflare.cloudflared --silent --accept-source-agreements --accept-package-agreements | Out-Null
        
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 3
        
        $cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
        if ($cloudflared) {
            Write-Host "  OK: cloudflared instalado" -ForegroundColor Green
        } else {
            Write-Host "  ADVERTENCIA: Reinicia PowerShell como Admin" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ERROR: winget no disponible" -ForegroundColor Red
        Write-Host "  Descarga desde: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Gray
    }
}

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Write-Host ""
    Write-Host "  Configurando cloudflared como servicio..." -ForegroundColor Gray
    
    $servicioExistente = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($servicioExistente) {
        Stop-Service -Name "cloudflared" -Force -ErrorAction SilentlyContinue
        cloudflared service uninstall 2>$null
        Start-Sleep -Seconds 2
    }
    
    cloudflared service install 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    Start-Service -Name "cloudflared"
    Start-Sleep -Seconds 3
    
    $servicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
    if ($servicio -and $servicio.Status -eq "Running") {
        Write-Host "  OK: cloudflared ejecutandose como servicio" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "  Configurando DNS para usar cloudflared..." -ForegroundColor Gray
        
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses "127.0.0.1","1.1.1.1"
            Write-Host "  OK: DNS actualizado en $($adapter.Name)" -ForegroundColor Green
        }
        
        Write-Host "  DNS: 127.0.0.1 (cloudflared) + 1.1.1.1 (respaldo)" -ForegroundColor Gray
    } else {
        Write-Host "  ADVERTENCIA: Servicio no esta corriendo" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== VERIFICACION FINAL ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] DNS Fijo + DNSSEC:" -ForegroundColor White
$dnsConfig = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 -and $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1
if ($dnsConfig.ServerAddresses -contains "127.0.0.1" -or $dnsConfig.ServerAddresses -contains "1.1.1.1") {
    Write-Host "  OK: DNS configurado" -ForegroundColor Green
} else {
    Write-Host "  ADVERTENCIA: Verificar DNS" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2] cloudflared (DoH):" -ForegroundColor White
$cloudflaredServicio = Get-Service -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cloudflaredServicio -and $cloudflaredServicio.Status -eq "Running") {
    Write-Host "  OK: cloudflared activo" -ForegroundColor Green
} else {
    Write-Host "  ADVERTENCIA: cloudflared no activo" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3] Prueba DNS:" -ForegroundColor White
$test = Resolve-DnsName google.com -Type A -ErrorAction SilentlyContinue | Select-Object -First 1
if ($test) {
    Write-Host "  OK: DNS funciona - google.com = $($test.IPAddress)" -ForegroundColor Green
} else {
    Write-Host "  ADVERTENCIA: Error al resolver DNS" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== CONFIGURACION COMPLETADA ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Presiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")