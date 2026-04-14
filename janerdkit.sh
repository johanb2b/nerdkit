#!/bin/bash

###############################################################################
# JA NERD KIT - THE ULTIMATE NETWORK & SYSADMIN TOOLBOX
# Version: 10.0 (DEFINITIVE EDITION)
# Developer: Johan Andersson
# Motto: "Hur svårt kan det va?"
###############################################################################

# --- JA NERD KIT Colors ---
B1=$'\e[38;5;33m'; B2=$'\e[38;5;39m'; P1=$'\e[38;5;69m'; P2=$'\e[38;5;105m'
P3=$'\e[38;5;141m'; P4=$'\e[38;5;177m'; P5=$'\e[38;5;213m'
G_BG="\033[48;5;232m"; G_FG="\033[38;5;255m"; G_ACCENT="\033[38;5;33m" 
G_CYAN="\033[38;5;51m"; G_GREY="\033[38;5;244m"
G_HEADER="\033[48;5;33m\033[38;5;255m"
BOLD="\033[1m"; RESET="\033[0m"

# --- Settings & Files ---
BASE_DIR="$(dirname "$(readlink -f "$0")")/data"
mkdir -p "$BASE_DIR" 2>/dev/null

TERM_HIST="$BASE_DIR/terminal_history"; NET_HIST="$BASE_DIR/nettest_history"
CERT_HIST="$BASE_DIR/certcheck_history"; IP_HIST="$BASE_DIR/ipcheck_history"
DNS_HIST="$BASE_DIR/dns_history"; SPEEDTEST_HIST="$BASE_DIR/speed_history"
SCP_HIST="$BASE_DIR/scp_history"; WIN_TEMP="$BASE_DIR/logs"
PASS_SAVE="$BASE_DIR/passwords.txt"

mkdir -p "$WIN_TEMP" 2>/dev/null
touch "$TERM_HIST" "$NET_HIST" "$CERT_HIST" "$IP_HIST" "$DNS_HIST" "$SPEEDTEST_HIST" "$SCP_HIST"

# --- UI Functions ---

draw_banner() {
    local subtitle="$1"
    stty sane 2>/dev/null; clear; tput cup 0 0
    local conn_status="${G_GREY}Checking...${RESET}"
    ping -c 1 -W 1 8.8.8.8 &>/dev/null && conn_status="${G_CYAN}Online${RESET}" || conn_status="\033[38;5;196mOffline${RESET}"
    echo -e "${B1}  ████  ████   ${B2}JA NERD KIT v10.0${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}Internet: $conn_status${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}${subtitle:-"Developed for Johan Andersson"}${RESET}"
    echo -e "${P2}  ███  ██  ██  ${P3}Hur svårt kan det va?${RESET}"
    echo ""
}

run_menu() {
    local title=$1; local help_text=$2; shift 2
    local options=("$@"); local selected=0
    while true; do
        draw_banner "$title"
        [ -n "$help_text" ] && echo -e "  ${G_GREY}${help_text}${RESET}\n"
        for i in "${!options[@]}"; do
            [ $i -eq $selected ] && echo -e "  ${G_ACCENT}> ${BOLD}${options[$i]}${RESET}" || echo -e "    ${options[$i]}${RESET}"
        done
        read -rsn3 key
        case "$key" in
            $'\x1b[A') ((selected--)); [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)) ;;
            $'\x1b[B') ((selected++)); [ $selected -ge ${#options[@]} ] && selected=0 ;;
            "") return $selected ;;
        esac
    done
}

get_color_ansi() {
    case $1 in 2) echo -e "\033[38;5;121m";; 3) echo -e "\033[38;5;111m";; 4) echo -e "\033[38;5;215m";; 5) echo -e "\033[38;5;159m";; 6) echo -e "\033[38;5;183m";; *) echo -e "\033[38;5;255m";; esac
}

manage_history_generic() {
    local h_file="$1"; local title="$2"; local run_func="$3"
    [ ! -s "$h_file" ] && { echo -e "  ${G_GREY}Historiken är tom.${RESET}"; sleep 1; return; }
    while true; do
        mapfile -t lines < <(tac "$h_file" | awk '!seen[$0]++')
        options=("${lines[@]}" "Tillbaka")
        run_menu "$title" "Välj ett objekt (Radera med 'Radera')" "${options[@]}"; choice=$?
        if [ $choice -lt $((${#options[@]} - 1)) ]; then
            selected_item="${lines[$choice]}"
            run_menu "$selected_item" "Vad vill du göra?" "Kör / Starta" "Radera" "Backa"
            case $? in
                0) $run_func "$selected_item"; return ;;
                1) 
                   # Escape special characters for sed
                   item_esc=$(echo "$selected_item" | sed 's/[^^]/[&]/g; s/\^/\\^/g')
                   sed -i "/^$item_esc$/d" "$h_file"
                   [ ! -s "$h_file" ] && return
                   ;;
            esac
        else return; fi
    done
}

check_and_install_prereqs() {
    local missing=()
    command -v traceroute >/dev/null || missing+=("traceroute")
    command -v nslookup >/dev/null || missing+=("dnsutils")
    command -v dig >/dev/null || missing+=("dnsutils")
    command -v openssl >/dev/null || missing+=("openssl")
    command -v tmux >/dev/null || missing+=("tmux")
    command -v jq >/dev/null || missing+=("jq")
    command -v curl >/dev/null || missing+=("curl")
    command -v bc >/dev/null || missing+=("bc")
    command -v speedtest-cli >/dev/null || missing+=("speedtest-cli")
    [ ${#missing[@]} -gt 0 ] && { echo -e "  ${G_ACCENT}Installerar systemverktyg...${RESET}"; sudo apt-get update -q && sudo apt-get install -y "${missing[@]}"; }
}

# ==============================================================================
# TOOL 1: JA TERM
# ==============================================================================

start_term_session() {
    local data="$1"; IFS='|' read -r type user host col date <<< "$data"
    local color_ansi=$(get_color_ansi "$col")
    local session_name="ja_${host//[^a-zA-Z0-9]/_}"
    local log_file="${WIN_TEMP}/term_${host}_$(date +%Y%m%d_%H%M).log"
    sed -i "/|$host|/d" "$TERM_HIST" 2>/dev/null
    echo "$type|$user|$host|$col|$(date +%Y-%m-%d)" >> "$TERM_HIST"
    local cmd="echo -ne '${color_ansi}'; script -f -c 'ssh ${user}@${host}' $log_file"
    tmux new-session -s "$session_name" "$cmd" 2>/dev/null || tmux attach-session -t "$session_name"
}

manage_term_history() {
    if [ ! -s "$TERM_HIST" ]; then echo -e "\n  Historik tom."; sleep 1; return; fi
    while true; do
        local lines=(); mapfile -t lines < <(tac "$TERM_HIST")
        local display=(); for l in "${lines[@]}"; do
            IFS='|' read -r type user host col date <<< "$l"
            display+=("$(get_color_ansi "$col")[$type] $user@$host ($date)${RESET}")
        done
        display+=("${G_FG}Back")
        run_menu "TERM HISTORY" "Välj session" "${display[@]}"; local choice=$?
        if [ $choice -lt $((${#display[@]} - 1)) ]; then
            IFS='|' read -r type user host col date <<< "${lines[$choice]}"
            run_menu "$host" "Action" "Anslut Nu" "Radera Entry" "Backa"
            case $? in
                0) start_term_session "$type|$user|$host|$col|$date"; return ;;
                1) sed -i "\|$host|d" "$TERM_HIST"; [ ! -s "$TERM_HIST" ] && return ;;
            esac
        else return; fi
    done
}

read_logs() {
    while true; do
        local logs=(); local display=()
        while IFS= read -r f; do
            base=$(basename "$f"); col_code=$(echo "$base" | sed -r 's/.*_c([0-9])_.*/\1/')
            [[ ! "$col_code" =~ ^[0-9]$ ]] && col_code=1
            display+=("$(get_color_ansi "$col_code")${base}${RESET}"); logs+=("$f")
        done < <(ls -t "$WIN_TEMP"/*.log 2>/dev/null | head -n 15)
        [ ${#logs[@]} -eq 0 ] && { echo "Inga loggar."; sleep 1; return; }
        display+=("Back")
        run_menu "LOG VIEWER" "Välj en logg för att läsa" "${display[@]}"; local choice=$?
        if [ $choice -lt $((${#display[@]} - 1)) ]; then
            draw_banner "VIEWING LOG"
            echo -e "  ${G_CYAN}Öppnar logg: $(basename "${logs[$choice]}") ${RESET}"
            echo -e "  ${G_ACCENT}Instruktion: Tryck 'q' för att återgå till menyn.${RESET}\n"
            sleep 1.5
            cat "${logs[$choice]}" | col -bx | less -R
        else return; fi
    done
}

run_term() {
    local colors=("1: Vit" "2: Grön" "3: Blå" "4: Orange" "5: Ljusblå" "6: Lila")
    while true; do
        options=("Ny SSH Anslutning" "Ny Seriell Anslutning (COM)" "Historik / Favoriter" "Läs Loggfiler" "Rensa Loggar" "Tillbaka")
        run_menu "TERMINAL MANAGER" "" "${options[@]}"
        case $? in
            0) read -p "  User [root]: " u; u=${u:-root}; read -p "  IP/Host: " h; [ -z "$h" ] && continue
               run_menu "VÄLJ FÄRG" "Välj färg för sessionen" "${colors[@]}"; c_idx=$?
               start_term_session "SSH|$u|$h|$((c_idx+1))|$(date +%Y-%m-%d)" ;;
            1) ports=($(ls /dev/ttyS* 2>/dev/null)); [ ${#ports[@]} -eq 0 ] && { echo "Inga portar."; sleep 1; continue; }
               display_ports=(); for p in "${ports[@]}"; do display_ports+=("$p"); done
               run_menu "SERIAL PORT" "Välj port" "${display_ports[@]}"; p_idx=$?
               port=${ports[$p_idx]}
               read -p "  Baud [9600]: " baud; 
               run_menu "VÄLJ FÄRG" "Välj färg för sessionen" "${colors[@]}"; c_idx=$?
               start_term_session "COM|${baud:-9600}|$port|$((c_idx+1))|$(date +%Y-%m-%d)" ;;
            2) manage_term_history ;;
            3) read_logs ;;
            4) rm "$WIN_TEMP"/*.log 2>/dev/null; echo "Loggar rensade."; sleep 1 ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 2: JA NETTEST (ADVANCED DASHBOARD)
# ==============================================================================
NT_PORT=443
run_nettest_logic() {
    local target="$1"; draw_banner "NETTEST: $target"
    # Spara i historik
    sed -i "/^$target$/d" "$NET_HIST" 2>/dev/null
    echo "$target" >> "$NET_HIST"
    
    echo -e "  ${G_ACCENT}${BOLD}DIAGNOSTIC DASHBOARD (IPv4): ${target}${RESET}"
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    echo "DNS|Testing..." > "/tmp/net_dns"; echo "PING|Testing..." > "/tmp/net_ping"
    echo "TCP|Testing..." > "/tmp/net_tcp"; echo "CERT|Testing..." > "/tmp/net_cert"
    echo "GW|Testing..." > "/tmp/net_gw"; > "/tmp/net_trace"
    pids=()
    (res=$(nslookup -query=A "$target" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n1); [ -z "$res" ] && echo "DNS|FAILED" > "/tmp/net_dns" || echo "DNS|$res" > "/tmp/net_dns") & pids+=($!)
    (ping_res=$(ping -4 -c 2 -W 2 "$target" 2>/dev/null); if [ $? -eq 0 ]; then avg=$(echo "$ping_res" | tail -1 | awk -F '/' '{print $5}'); echo "PING|ONLINE (${avg}ms)" > "/tmp/net_ping"; else echo "PING|OFFLINE" > "/tmp/net_ping"; fi) & pids+=($!)
    (timeout 2 bash -c "</dev/tcp/$target/$NT_PORT" &>/dev/null && echo "TCP|OPEN" > "/tmp/net_tcp" || echo "TCP|CLOSED" > "/tmp/net_tcp") & pids+=($!)
    (cert_out=$(timeout 3 openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null); if [ -z "$cert_out" ]; then echo "CERT|NONE" > "/tmp/net_cert"; else expiry=$(echo "$cert_out" | cut -d'=' -f2); days=$(( ( $(date -d "$expiry" +%s) - $(date +%s) ) / 86400 )); [ $days -lt 0 ] && echo "CERT|EXPIRED" > "/tmp/net_cert" || echo "CERT|OK ($days days)" > "/tmp/net_cert"; fi) & pids+=($!)
    (gw=$(ip -4 route show default | awk '{print $3}' | head -n1); iface=$(ip -4 route get "$target" 2>/dev/null | grep -oP 'dev \K\S+'); echo "GW|$gw ($iface)" > "/tmp/net_gw") & pids+=($!)
    traceroute -4 -n -m 15 -q 1 -w 1 "$target" 2>/dev/null | grep --line-buffered -v "traceroute" > "/tmp/net_trace" & pids+=($!)
    while true; do
        tput cup 6 0
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "DNS Resolution" "$(cat /tmp/net_dns | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Ping Connectivity" "$(cat /tmp/net_ping | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "TCP Port $NT_PORT" "$(cat /tmp/net_tcp | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "SSL/TLS Cert" "$(cat /tmp/net_cert | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Local Gateway" "$(cat /tmp/net_gw | cut -d'|' -f2)"
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}\n  ${G_ACCENT}PATH ANALYSIS:${RESET}"
        head -n 5 "/tmp/net_trace" | while read line; do echo -e "  ${G_GREY}$(echo "$line" | tr -s ' ')${RESET}                   "; done
        running=0; for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && ((running++)); done
        [ "$running" -eq 0 ] && break; read -rsn1 -t 0.4 input; [ "$input" == "s" ] && break
    done
    read -rsn1 -p "Tryck tangent...";
}

run_nettest() {
    while true; do
        options=("Ny Test" "Port: $NT_PORT" "Historik" "Tillbaka")
        run_menu "NETTEST MANAGER" "" "${options[@]}"; case $? in
            0) read -p "  Mål IP/FQDN: " t; [ -n "$t" ] && run_nettest_logic "$t" ;;
            1) read -p "  Port: " p; [[ "$p" =~ ^[0-9]+$ ]] && NT_PORT=$p ;;
            2) manage_history_generic "$NET_HIST" "NETTEST HISTORY" "run_nettest_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 3: JA MIN IP (HTTPS)
# ==============================================================================

run_getip_logic() {
    local target="$1"; draw_banner "IP INTEL: ${target:-"MY PUBLIC IP"}"
    echo -e "  ${G_GREY}Hämtar data...${RESET}\n"
    
    # Använd ip-api.com (mycket stabilare för gratisanvändare)
    local url="http://ip-api.com/json/${target}?fields=status,message,country,city,org,as,query"
    local data=$(curl -s --connect-timeout 5 --max-time 10 -A "Mozilla/5.0" "$url")
    
    if [ -z "$data" ]; then
        echo -e "  ${P5}Kunde inte nå tjänsten (Timeout/Nätverk).${RESET}"
    elif [ "$(echo "$data" | jq -r .status)" == "fail" ]; then
        echo -e "  ${P5}Fel: $(echo "$data" | jq -r .message)${RESET}"
    else
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Public IP" "$(echo "$data" | jq -r .query)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Organisation" "$(echo "$data" | jq -r .org)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "ASN" "$(echo "$data" | jq -r .as)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Land / Stad" "$(echo "$data" | jq -r .country), $(echo "$data" | jq -r .city)"
        
        if [ -n "$target" ]; then
            sed -i "/^$target$/d" "$IP_HIST" 2>/dev/null
            echo "$target" >> "$IP_HIST"
        fi
    fi
    echo ""
    read -rsn1 -p "Tryck tangent för att fortsätta...";
}

run_getip() {
    while true; do
        options=("Visa min nuvarande IP" "Ange IP manuellt" "Historik" "Tillbaka")
        run_menu "JA MIN IP" "Välj funktion" "${options[@]}"; case $? in
            0) run_getip_logic "" ;;
            1) read -p "  Ange IP: " t; [ -n "$t" ] && run_getip_logic "$t" ;;
            2) manage_history_generic "$IP_HIST" "IP HISTORY" "run_getip_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 4: JA DNS CHECK
# ==============================================================================

run_dns_logic() {
    local domain="$1"; draw_banner "DNS CHECK: $domain"
    # Spara i historik
    sed -i "/^$domain$/d" "$DNS_HIST" 2>/dev/null
    echo "$domain" >> "$DNS_HIST"
    
    echo -e "  ${G_ACCENT}${BOLD}RECORD LOOKUP:${RESET}\n  ${G_GREY}------------------------------------------------------------${RESET}"
    for type in A AAAA MX NS TXT SOA; do
        echo -e "  ${G_FG}${type} Records:${RESET}"
        res=$(dig +short "$domain" $type); [ -z "$res" ] && echo -e "    ${P5}(Ingen data)${RESET}" || echo "$res" | sed 's/^/    /'
        echo ""
    done; read -rsn1 -p "Tangent...";
}

run_dns_check() {
    while true; do
        options=("Ange domän" "Historik" "Tillbaka")
        run_menu "JA DNS CHECK" "Välj funktion" "${options[@]}"; case $? in
            0) read -p "  Ange domän: " d; [ -n "$d" ] && run_dns_logic "$d" ;;
            1) manage_history_generic "$DNS_HIST" "DNS HISTORY" "run_dns_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 6: JA CERTCHECK
# ==============================================================================

run_certcheck_logic() {
    local target=$(echo "$1" | sed -e 's|^[^/]*//||' -e 's|/.*$||'); draw_banner "CERTCHECK: $target"
    data=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null)
    if [ -z "$data" ]; then echo -e "  ${P5}Kunde inte ansluta.${RESET}"; else
        local issuer=$(echo "$data" | openssl x509 -noout -issuer | sed 's/issuer= //')
        local subject=$(echo "$data" | openssl x509 -noout -subject | sed 's/subject= //')
        local not_after=$(echo "$data" | openssl x509 -noout -dates | grep "notAfter" | cut -d'=' -f2)
        local days=$(( ( $(date -d "$not_after" +%s) - $(date +%s) ) / 86400 ))
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Expiry Date" "$not_after"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Days Remaining" "$days dagar"
        echo -e "\n  ${G_ACCENT}SUBJECT:${RESET} ${G_CYAN}${subject}${RESET}"
        echo -e "  ${G_ACCENT}ISSUER:${RESET}  ${G_CYAN}${issuer}${RESET}"
        echo -e "\n  ${G_ACCENT}DOMAINS (SAN):${RESET}"
        echo "$data" | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name:" | tail -n 1 | sed 's/DNS://g' | tr -d ' ' | tr ',' '\n' | awk '{print "  - " $1}'
    fi; read -rsn1 -p "Tangent...";
}

# ==============================================================================
# TOOL 8: JA SCP (STABLE WITH FAILSAFE)
# ==============================================================================

SCP_FILE=""; SCP_DIR=""

browse_local() {
    files=($(ls -1p | grep -v '/$')); [ ${#files[@]} -eq 0 ] && { echo "Inga filer här."; sleep 1; return 1; }
    display=(); for f in "${files[@]}"; do display+=("${G_FG}[FIL] $f${RESET}"); done
    display+=("Avbryt")
    run_menu "LOCAL FILE SELECT" "Välj fil i nuvarande mapp" "${display[@]}"; choice=$?
    [ $choice -eq $((${#display[@]} - 1)) ] && return 1
    SCP_FILE="${files[$choice]}"; return 0
}

browse_remote() {
    local uh=$1; local cd="${2:-.}"
    while true; do
        dirs=(".." "."); display=("${P3}[UPP] .." "${G_ACCENT}[VÄLJ DENNA MAPP] ." "MANUAL")
        out=$(ssh -o ConnectTimeout=3 -o BatchMode=yes "$uh" "ls -1F $cd" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo -e "\n  Låst skal upptäckt. Ange målmapp manuellt."; read -p "  Mål: " man_path
            SCP_DIR="${man_path:-.}"; return 0
        fi
        while IFS= read -r l; do [[ "$l" == */ ]] && { dirs+=("${l%/}"); display+=("${G_CYAN}[DIR] ${l%/}${RESET}"); }; done <<< "$out"
        display+=("Avbryt"); run_menu "REMOTE BROWSER: $cd" "Välj målmapp" "${display[@]}"; choice=$?
        [ $choice -eq $((${#display[@]} - 1)) ] && return 1
        sel="${dirs[$choice]}"
        if [ "$sel" == "MANUAL" ]; then read -p "  Mål: " m; SCP_DIR="${m:-.}"; return 0; fi
        if [ "$sel" == "." ]; then SCP_DIR="$cd"; return 0; fi
        if [ "$sel" == ".." ]; then cd=$(ssh "$uh" "cd $cd/.. && pwd" 2>/dev/null || echo ".."); else cd="$cd/$sel"; fi
    done
}

run_scp_logic() {
    local d="$1"; IFS='|' read -r u h dst <<< "$d"
    browse_local || return
    [ -z "$h" ] && { draw_banner "JA SCP: ANSLUTNING"; read -p "  User [root]: " u; u=${u:-root}; read -p "  Host: " h; }
    [ -z "$h" ] && return
    browse_remote "${u}@$h" "$dst" || return
    draw_banner "JA SCP: ÖVERFÖR"; echo -e "  Kopierar $SCP_FILE -> ${u}@${h}:${SCP_DIR}\n"
    if scp "$SCP_FILE" "${u}@${h}:${SCP_DIR}"; then
        echo -e "\n  ${G_CYAN}KLART!${RESET}"; echo "$u|$h|$SCP_DIR" >> "$SCP_HIST"
    else echo -e "\n  ${P5}Misslyckades.${RESET}"; fi
    read -rsn1 -p "Tangent...";
}

# ==============================================================================
# TOOL: JA P$SSWD
# ==============================================================================

PW_WORDS=3
PW_SPEC="!#"
PW_SEP="-"
PW_SAVE_OPT="NEJ"
PW_COUNT=5
PW_CAT="ALLA"

run_passwd() {
    # Över 400 Base64 kodade ord fördelat på kategorier
    local b64_swe="U2tvciBIdXMgUGFzdGEgUGl6emEgR2F0YSBTa29nIFNqbyBWaW5kIFNvbCBHcm9uIFJvZCBCbGEgR2FtbWFsIFNuYWJiIExpdGVuIFN0b3IgS2F0dCBIdW5kIEZpc2sgQm9sbCBTb2ZhIExhbXBhIEdsYXMgU3RvbCBCb3JkIEthZmZlIEJ1bGxlIFRhbGxyaWsgS25pdiBHYWZmZWwgU2tlZCBIYXYgUmVnbiBNb2xuIEhhc3QgR3JpcyBGb2dlbCBQZW5uYSBWYXNrYSBGb25zdGVyIERvcnIgVGFrIEdvbHYgVmFnZyBUcmFwcGEgTWF0dGEgS3VkZGUgVHYgRGF0b3IgTXVzIEthbWVyYSBMYW1wYSBCb2sgUGFwcGVyIFBlbm5hIFNrcml2Ym9yZCBIeWxsYSBTYXBlIEtsYWRlciBCeXhvciBUcm9qYSBTb2Nrb3IgTW9zc2EgSGFudHNoZSBLYXBwYSBKYWNrYSBTa29yIFN0b3ZlbCA="
    local b64_eng="U2hvZSBIb3VzZSBCcmVhZCBNaWxrIFRyZWUgUm9hZCBTa3kgQmx1ZSBSZWQgR3JlZW4gRmFzdCBTbWFsbCBCaWcgS2F0dCBEb2cgQmFsbCBDaGFpciBUYWJsZSBBcHBsZSBXYXRlciBDdXAgRG9vciBCb3ggQm9vayBQZW4gUGFwcGVyIEJhZyBXaW5kb3cgUm9vZiBGbG9vciBXYWxsIFN0YWlycyBDdXJ0YWluIFJ1ZyBQaWxsb3cgQmxhbmtldCBTcG9vbiBGb3JrIEtuaWZlIFRhbGxyaWsgU2VhIExha2UgQ2xvdWQgQ29tcHV0ZXIgTW91c2UgQ2FtZXJhIFBob25lIExhbXAgQm9vayBQZW4gRGVzayBTaGVsZiBDbG90aGVzIFBhbnRzIFNoaXJ0IFNvY2tzIEhhdCBHbG92ZXMgQ29hdCBKYWNrZXQgQm9vdCBTbmVha2VyIA=="
    local b64_nat="RWsgRnVydSBHcmFuIEJqb3JrIFRlYWsgUm9zIFR1bHBhbiBMaWxqYSBNb3NzYSBPYWsgUGluZSBGaXIgQmlyY2ggVGVhayBSb3NlIFR1bGlwIExpbHkgTW9zcyBTa29nIFNqbyBIYXYgRm9yZXN0IFNlYSBMYWtlIEJlcmcgRGFsIEZhbHQgQW5nIEJsb21tYSBCbGFkIEdyYXMgSm9yZCBCdXNrZSBUcmFkIEZydWt0IEJhciBLb3R0ZSBTYW5kIFN0ZW4gR3J1cyBNb2xuIFNvbCBNYW5lIFN0amVybmEgUmVnbiBTbm8gSXMgRG9nZyBEaW1tYSA="
    local b64_veh="QmlsIEJ1c3MgVGFnIEZseWcgQ3lrZWwgQmF0IFZvbHZvIFNhYWIgVGVzbGEgRm9yZCAiQXVkaSIgQk1XIENhciBCdXMgVHJhaW4gUGxhbmUgQmlrZSBCb2F0IFRydWNrIFRheGkgSmVlcCBWYW4gTW90b3JjeWtlbCBNb3BlZCBIdXNiaWwgTGFzdGJpbCBUcmFrdG9yIFRyYWlsZXIgWWFjaHQgRmVyamEgVWJhdCBIdWxrIFNwZWVkYm9hdCBQaWNrdXAgU2VkYW4gQ291cGUgQ2FicmlvIExpbW91c2luZSBBbWJ1bGFucyBCcmFuZGJpbCBQb2xpc2JpbCA="
    local b64_extra="U3RvbCBCb3JkIFNvZmEgU2FacyBCeXJhIEh5bGxhIFRhdmxhIE1hdHRhIE1hdGxhbXBhIEZvbnN0ZXIga2FyZCBHYXJkaW4gS3VkZGUgVGFja2UgTGFtcyBCbG9tbWEgVmFzIEZydWt0c2thbCBUYWxscmlrIEdsYXMgS25pdiBHYWZmZWwgU2tlZCBLYXN0cnVsbCBQYW5uYSBVZ24gU3BpcyBLeWwgRnJ5cyBNYXNraW4gRGlza21hc2tpbiBUdnF0dG1hc2tpbiBCYWbadWthciBEdXNoIFRvYWxldHQgU3BlZ2VsIEthbW0gQm9yc3RhIFR2YWwgU2hhbXBvbyBIYW5kdHVkbmFyIA=="
    
    local desc="Välj ord, tecken, avdelare och antal. Specialtecken hamnar före/efter ett ord."
    while true; do
        local words=()
        case "$PW_CAT" in
            "SVENSKA") words=($(echo "$b64_swe" | base64 -d)) ;;
            "ENGELSKA") words=($(echo "$b64_eng" | base64 -d)) ;;
            "NATUR") words=($(echo "$b64_nat" | base64 -d)) ;;
            "FORDON") words=($(echo "$b64_veh" | base64 -d)) ;;
            "EXTRA") words=($(echo "$b64_extra" | base64 -d)) ;;
            *) words=($(echo "$b64_swe $b64_eng $b64_nat $b64_veh $b64_extra" | base64 -d)) ;;
        esac

        options=("Generera lösenord" "Antal ord: $PW_WORDS" "Kategori: $PW_CAT" "Specialtecken: $PW_SPEC" "Avdelare: $PW_SEP" "Antal lösenord: $PW_COUNT" "Spara till fil: $PW_SAVE_OPT" "Tillbaka")
        run_menu "JA P\$SSWD - Generator" "$desc" "${options[@]}"; choice=$?
        case $choice in
            0) 
                draw_banner "JA P\$SSWD - RESULTAT"
                echo -e "  ${G_ACCENT}GENERERADE LÖSENORD:${RESET}\n"
                for ((j=1; j<=PW_COUNT; j++)); do
                    local pass_parts=()
                    # Välj ord med bättre slump (/dev/urandom)
                    for ((i=0; i<PW_WORDS; i++)); do
                        local idx=$(od -An -N2 -i /dev/urandom | awk "{print \$1 % ${#words[@]}}")
                        pass_parts+=("${words[$idx]}")
                    done
                    
                    # Placera specialtecken slumpmässigt med /dev/urandom
                    local spec_pos=$(od -An -N1 -i /dev/urandom | awk "{print \$1 % $PW_WORDS}")
                    local spec_side=$(od -An -N1 -i /dev/urandom | awk '{print $1 % 2}') # 0 = före, 1 = efter
                    if [ $spec_side -eq 0 ]; then
                        pass_parts[$spec_pos]="${PW_SPEC}${pass_parts[$spec_pos]}"
                    else
                        pass_parts[$spec_pos]="${pass_parts[$spec_pos]}${PW_SPEC}"
                    fi
                    
                    # Sätt ihop med avdelare
                    local pass=""
                    for ((i=0; i<PW_WORDS; i++)); do
                        pass+="${pass_parts[$i]}"
                        [ $i -lt $((PW_WORDS - 1)) ] && pass+="${PW_SEP}"
                    done
                    
                    echo -e "  [${j}] ${BOLD}${G_CYAN}${pass}${RESET}"
                    if [ "$PW_SAVE_OPT" == "JA" ]; then
                        echo "$pass" >> "$PASS_SAVE"
                    fi
                done
                if [ "$PW_SAVE_OPT" == "JA" ]; then
                    echo -e "\n  ${G_GREY}Sparat i data/passwords.txt${RESET}"
                fi
                read -rsn1 -p "Tryck tangent för att fortsätta..."; continue ;;
            1) read -p "  Antal ord [3]: " n; PW_WORDS=${n:-3} ;;
            2) 
               run_menu "VÄLJ KATEGORI" "Vilken typ av ord vill du använda?" "ALLA" "SVENSKA" "ENGELSKA" "NATUR" "FORDON" "EXTRA"
               case $? in 0) PW_CAT="ALLA";; 1) PW_CAT="SVENSKA";; 2) PW_CAT="ENGELSKA";; 3) PW_CAT="NATUR";; 4) PW_CAT="FORDON";; 5) PW_CAT="EXTRA";; esac
               continue ;;
            3) read -p "  Specialtecken [!#]: " s; PW_SPEC=${s:-"!#"} ;;
            4) read -p "  Avdelare [-]: " d; PW_SEP=${d:--} ;;
            5) read -p "  Antal lösenord [5]: " c; PW_COUNT=${c:-5} ;;
            6) [ "$PW_SAVE_OPT" == "JA" ] && PW_SAVE_OPT="NEJ" || PW_SAVE_OPT="JA" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# MAIN DASHBOARD
# ==============================================================================
check_and_install_prereqs
while true; do
    options=("JA TERM - SSH & COM" "JA NETTEST - Diagnostic" "JA MIN IP - IP Intel" "JA DNS CHECK - Record Lookup" "JA P\$SSWD - Generator" "JA CERTCHECK - SSL Analysis" "JA SPEEDTEST - Bandwidth" "JA SCP - File Transfer" "Information" "Avsluta")
    run_menu "MAIN DASHBOARD" "Välkommen Johan! Hur svårt kan det va?" "${options[@]}"
    case $? in
        0) run_term ;;
        1) run_nettest ;;
        2) run_getip ;;
        3) run_dns_check ;;
        4) run_passwd ;;
        5) read -p "  Host: " h; [ -n "$h" ] && run_certcheck_logic "$h" ;;
        6) draw_banner "SPEEDTEST"; speedtest-cli; read -rsn1 ;;
        7) run_scp_logic "||" ;;
        8) draw_banner "INFO"; echo "JA NERD KIT v10.0 - All tools restored."; read -rsn1 ;;
        9) clear; exit 0 ;;
    esac
done
