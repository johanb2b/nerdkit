# 🛠️ JA Nerd Kit v10.0
### "Hur svårt kan det va?"

**JA Nerd Kit** är den ultimata verktygslådan för nätverkstekniker och systemadministratörer. Utvecklat av Johan Andersson för att samla alla viktiga diagnos- och administrationsverktyg i ett snyggt och lättanvänt terminalgränssnitt. **Designat specifikt för att köras i WSL (Windows Subsystem for Linux) på Windows.**

![Main Dashboard Placeholder](https://via.placeholder.com/800x400?text=JA+Nerd+Kit+Main+Dashboard)

---

## 🚀 Funktioner

### 1. JA TERM - Terminal Manager
Hantera dina SSH- och seriella anslutningar (COM) på ett smidigt sätt.
- **Historik & Favoriter:** Spara dina vanligaste anslutningar med färgkodning.
- **Loggning:** Automatisk loggning av sessioner till den lokala mappen `data/logs`.
- **TMUX-integration:** Kör stabila sessioner som överlever nätverksavbrott.

### 2. JA NETTEST - Diagnostik-Dashboard
En kraftfull vy som ger dig allt du behöver veta om en anslutning på en gång.
- DNS-uppslag, Ping (latency), TCP-porttest, SSL-certifikatstatus och Traceroute i realtid.

### 3. JA MIN IP - IP Intel
Hämta detaljerad information om din publika IP eller valfri IP-adress.
- Organisation, ASN, Land och Stad direkt i terminalen.

### 4. JA DNS DIG - Record Lookup
Snabba uppslag av de vanligaste DNS-posterna (A, AAAA, MX, NS, TXT, SOA).

### 5. JA CERTCHECK - SSL Analysis
Djupanalys av SSL/TLS-certifikat för valfri host. Se utgångsdatum, utfärdare och SAN-namn.

### 6. JA SCP - Filöverföring
Enkel filöverföring med inbyggd filbläddrare för både lokala filer och fjärrservrar.

### 7. JA P$SSWD - Generator
Skapa säkra, slumpmässiga lösenord direkt i terminalen.
- **Lagring:** Endast de lösenord som *genereras* av verktyget sparas automatiskt i `data/passwords.txt` för enkel åtkomst senare. Inga manuellt inmatade lösenord sparas.

### 8. JA SPEEDTEST - Bandwidth
Bandbreddstest direkt i terminalen via `speedtest-cli`.

---

## 🛠️ Installation & Användning

### Förutsättningar
Verktyget är optimerat för **Windows Subsystem for Linux (WSL)** med en Ubuntu/Debian-distro. Det installerar automatiskt de beroenden som krävs:
- `tmux`, `curl`, `jq`, `openssl`, `dnsutils`, `traceroute`, `speedtest-cli`.

### Starta verktyget
Du kan välja att köra scriptet från vilken mapp som helst. All data, historik och loggar kommer att sparas i una undermapp som heter `data/` på den plats där scriptet ligger.

1. Öppna din WSL-terminal.
2. Skapa eller gå till den mapp där du vill ha verktyget:
   ```bash
   mkdir -p ~/tools/nerdkit
   cd ~/tools/nerdkit
   ```
3. Placera `janerdkit.sh` i mappen.
4. Gör filen exekverbar:
   ```bash
   chmod +x janerdkit.sh
   ```
5. Kör scriptet:
   ```bash
   ./janerdkit.sh
   ```

---

## 📂 Struktur & Loggar
- **Valfri placering:** Flytta scriptet till den mapp du vill använda som din "bas".
- **Lokal data:** All historik, loggar och lösenord sparas i mappen `data/` i samma katalog som scriptet.
- **Loggar:** Sparas i `data/logs`.
- **Historik:** Sparas som textfiler i `data/` (t.ex. `terminal_history`).

---

**Utvecklare:** Johan Andersson  
**Version:** 10.0 (Definitive Edition)
