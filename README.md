# 🛠️ JA Nerd Kit v10.0
### "Hur svårt kan det va?"

**JA Nerd Kit** är den ultimata verktygslådan för nätverkstekniker och systemadministratörer. Utvecklat av Johan Andersson för att samla alla viktiga diagnos- och administrationsverktyg i ett snyggt och lättanvänt terminalgränssnitt. **Designat specifikt för att köras i WSL (Windows Subsystem for Linux) på Windows.**

<img width="777" height="366" alt="image" src="https://github.com/user-attachments/assets/c6133fce-4b1f-47fb-947a-f72fcfd9cb5b" />


---

## 🚀 Funktioner

### 1. JA TERM - Terminal Manager
Hantera dina SSH- och seriella anslutningar (COM) på ett smidigt sätt.
- **Historik & Favoriter:** Spara dina vanligaste anslutningar med färgkodade namn.
- **Loggning:** Automatisk loggning av sessioner till `data/logs`. Instruktioner för att avsluta loggläsning med 'q'.
- **TMUX-integration:** Kör stabila sessioner som överlever nätverksavbrott.

### 2. JA NETTEST - Diagnostic Dashboard
En kraftfull vy som ger dig allt du behöver veta om en anslutning på en gång.
- DNS-uppslag, Ping, TCP-porttest, SSL-status och Traceroute i realtid.
- **Historik:** Spara och hantera dina vanligaste tester.

### 3. JA MIN IP - IP Intel
Hämta detaljerad information om din publika IP eller valfri IP-adress.
- Organisation, ASN, Land och Stad via stabila API-anrop.
- **Menystyrd:** Växla mellan "Min IP", "Ange IP" och "Historik".

### 4. JA DNS CHECK - Record Lookup
Snabba uppslag av de vanligaste DNS-posterna (A, AAAA, MX, NS, TXT, SOA).
- **Nyhet:** Fullständig historikhantering för domäner.

### 5. JA P$SSWD - Password Generator
Skapa säkra, slumpmässiga lösenord baserade på vardagliga ord.
- **Blandat språk:** Slumpar svenska och engelska vardagsord (400+ dolda ord).
- **Anpassningsbar:** Välj antal ord, specialtecken, avdelare och antal lösenord.
- **Säkerhet:** Använder `/dev/urandom` för maximal slumpmässighet.

### 6. JA CERTCHECK - SSL Analysis
Djupanalys av SSL/TLS-certifikat för valfri host.
- **Kedjeanalys:** Se hela förtroendekedjan ([LEAF], [INTERM], [ROOT]).
- **CRL Info:** Kontrollera CRL Distribution Points.
- **Historik:** Spara och radera tidigare certifikatanalyser.

### 7. JA SPEEDTEST - Bandwidth Analysis
Detaljerat bandbreddstest direkt i terminalen.
- **Utökad Info:** Visar ISP, Publik IP, Testserver (namn/land) och Host.
- **Historik:** Spara dina mätvärden för framtida jämförelser.

### 8. JA IP-SCANNER - Network Discovery
Skanna ett helt subnet eller IP-range för att hitta aktiva enheter.
- **Smart gruppering:** Lediga IP-adresser klumpas ihop för en renare lista.
- **Parallell skanning:** Snabb analys via parallella ping-förfrågningar.
- **Historik:** Spara och återvisa dina nätverksskanningar.

### 9. JA COMMANDER - File Transfer (SCP)
En kraftfull filhanterare för att flytta filer mellan din lokala maskin och fjärrservrar.
- **Commander Mode:** Navigera i både lokala och fjärrstyrda mappar.
- **Dubbelriktad:** Ladda upp (Local -> Remote) eller Ladda ner (Remote -> Local).
- **Persistent:** Använder SSH ControlMaster för att behålla anslutningen öppen (endast ett lösenord behövs för hela sessionen).
- **Filhantering:** Skapa mappar och radera filer/mappar både lokalt och på servern.

---

## 🛠️ Installation & Användning

### Förutsättningar
Verktyget är optimerat för **Windows Subsystem for Linux (WSL)** med en Ubuntu/Debian-distro. Det installerar automatiskt de beroenden som krävs:
- `tmux`, `curl`, `jq`, `openssl`, `dnsutils`, `traceroute`, `speedtest-cli`, `bc`.

### Starta verktyget
Du kan välja att köra scriptet från vilken mapp som helst. All data, historik och loggar kommer att sparas i en undermapp som heter `data/` på den plats där scriptet ligger.

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
- **Lokal data:** All historik, loggar och lösenord sparas i mappen `data/` i samma katalog som scriptet. (Exkluderas automatiskt från git via `.gitignore`).
- **Loggar:** Sparas i `data/logs`.
- **Historik:** Sparas som textfiler i `data/` (t.ex. `terminal_history`).

---

**Utvecklare:** Johan Andersson  
**Version:** 10.0 (Definitive Edition)
