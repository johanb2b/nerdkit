# 🛠️ JA Nerd Kit v10.6 (Mac Edition)
### "Hur svårt kan det va?"

**JA Nerd Kit** är den ultimata verktygslådan för nätverkstekniker och systemadministratörer. Utvecklat av Johan Andersson för att samla alla viktiga diagnos- och administrationsverktyg i ett snyggt och lättanvänt terminalgränssnitt. **Denna version är optimerad specifikt för macOS.**

![Main Dashboard Placeholder](https://via.placeholder.com/800x400?text=JA+Nerd+Kit+Mac+Dashboard)

---

## 🚀 Funktioner

### 1. JA TERM - Terminal Manager
Hantera dina SSH- och seriella anslutningar (t.ex. USB-till-Console) på ett smidigt sätt.
- **Historik & Favoriter:** Spara dina vanligaste anslutningar med färgkodning.
- **Loggning:** Automatisk loggning av sessioner till den lokala mappen `data/logs`.
- **TMUX-integration:** Kör stabila sessioner som överlever nätverksavbrott (kräver tmux).

### 2. JA NETTEST - Diagnostic Dashboard
En kraftfull realtidsvy som ger dig en snabb överblick av en anslutning.
- DNS-uppslag, Ping (latency), TCP-porttest, HTTP-statuskod, SSL-certifikatstatus och lokal gateway.

### 3. JA MIN IP - IP Intel
Hämta detaljerad information om din publika IP eller valfri IP-adress.
- Organisation, ASN, Land och Stad direkt i terminalen.

### 4. JA DNS CHECK - Record Lookup
Snabba uppslag av de vanligaste DNS-posterna (A, AAAA, MX, NS, TXT, SOA) med möjlighet att välja specifik DNS-server.

### 5. JA P$SSWD - Generator
Skapa säkra, slumpmässiga lösenord baserat på svenska eller engelska ordkombinationer.
- Anpassa antal ord, specialtecken och avdelare för maximal säkerhet och läsbarhet.

### 6. JA CERTCHECK - SSL Analysis
Djupanalys av SSL/TLS-certifikat för valfri host. Se utgångsdatum, återstående dagar, utfärdare, SAN-namn och hela certifikatkedjan.

### 7. JA SPEEDTEST - Bandwidth
Bandbreddstest direkt i terminalen via `speedtest-cli`.

### 8. JA IP-SCANNER - IP Range
Smart nätverksinventering som skannar subnät eller IP-intervall.
- Identifierar aktiva enheter, lediga adressintervall och utför automatiska namn-uppslag (nslookup).

### 9. JA COMMANDER - File Manager
En inbyggd filhanterare för enkel överföring via SCP.
- **Navigering:** Bläddra lokalt och på fjärrserver i ett grafiskt menysystem.
- **Smart Tunneling:** Använder SSH ControlMaster för att hålla anslutningen öppen och snabb under filbläddring.

---

## 🛠️ Installation & Användning

### Förutsättningar
Verktyget är optimerat för **macOS Terminal** (eller iTerm2). Det använder **Homebrew** för att automatiskt installera beroenden som saknas:
- `tmux`, `jq`, `speedtest-cli`, `coreutils` (för timeout-funktionalitet).

### Starta verktyget
Scriptet är portabelt. All data, historik och loggar sparas i en undermapp som heter `data/` på den plats där scriptet körs ifrån.

1. Öppna din terminal.
2. Skapa eller gå till den mapp där du vill ha verktyget:
   ```bash
   mkdir -p ~/tools/nerdkit
   cd ~/tools/nerdkit
   ```
3. Placera `janerdkit_mac.sh` i mappen.
4. Gör filen exekverbar:
   ```bash
   chmod +x janerdkit_mac.sh
   ```
5. Kör scriptet:
   ```bash
   ./janerdkit_mac.sh
   ```

---

## 📂 Struktur & Loggar
- **Lokal data:** All historik, loggar och lösenord sparas i mappen `data/` i samma katalog som scriptet.
- **Loggar:** Sparas i `data/logs`.
- **Genväg:** Under "Inställningar" i menyn kan du automatiskt installera ett alias (t.ex. `nerdkit`) i din `.zshrc` eller `.bashrc` för att starta verktyget snabbare.

---

**Utvecklare:** Johan Andersson  
**Version:** 10.6 (Mac Edition)
