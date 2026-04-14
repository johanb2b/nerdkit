# 🛠️ JA Nerd Kit v10.0
### "Hur svårt kan det va?"

**JA Nerd Kit** är den ultimata verktygslådan för nätverkstekniker och systemadministratörer. Utvecklat av Johan Andersson för att samla alla viktiga diagnos- och administrationsverktyg i ett snyggt och lättanvänt terminalgränssnitt.

![Main Dashboard Placeholder](https://via.placeholder.com/800x400?text=JA+Nerd+Kit+Main+Dashboard)

---

## 🚀 Funktioner

### 1. JA TERM - Terminal Manager
Hantera dina SSH- och seriella anslutningar (COM) på ett smidigt sätt.
- **Historik & Favoriter:** Spara dina vanligaste anslutningar med färgkodning.
- **Loggning:** Automatisk loggning av sessioner till `/mnt/c/temp/TerminalLogs`.
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

### 7. Övriga Verktyg
- **JA P$SSWD:** Lösenordsgenerator.
- **JA SPEEDTEST:** Bandbreddstest direkt i terminalen via `speedtest-cli`.

---

## 🛠️ Installation & Användning

### Förutsättningar
Verktyget är optimerat för **Ubuntu/Debian** (fungerar utmärkt i WSL) och installerar automatiskt de beroenden som krävs:
- `tmux`, `curl`, `jq`, `openssl`, `dnsutils`, `traceroute`, `speedtest-cli`.

### Starta verktyget
1. Klona repot eller ladda ner `janerdkit.sh`.
2. Gör filen exekverbar:
   ```bash
   chmod +x janerdkit.sh
   ```
3. Kör scriptet:
   ```bash
   ./janerdkit.sh
   ```

---

## 📂 Struktur & Loggar
- **Allt-i-ett-mapp:** Alla loggar, historik och lösenord sparas i `/mnt/c/temp/nerdkit`.
- **Loggar:** Sparas specifikt i `/mnt/c/temp/nerdkit/logs`.
- **Historik:** Sparas som textfiler i samma mapp (t.ex. `terminal_history`).

---

**Utvecklare:** Johan Andersson  
**Version:** 10.0 (Definitive Edition)
