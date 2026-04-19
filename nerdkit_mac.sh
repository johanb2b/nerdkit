#!/bin/bash

###############################################################################
# JA NERD KIT - THE ULTIMATE NETWORK & SYSADMIN TOOLBOX
# Version: 10.6 (MAC EDITION - COMMANDER UPDATE)
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
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
BASE_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )/data"

mkdir -p "$BASE_DIR" 2>/dev/null
WIN_TEMP="$BASE_DIR/logs"
mkdir -p "$WIN_TEMP" 2>/dev/null

TERM_HIST="$BASE_DIR/terminal_history"; NET_HIST="$BASE_DIR/nettest_history"
CERT_HIST="$BASE_DIR/certcheck_history"; IP_HIST="$BASE_DIR/ipcheck_history"
DNS_HIST="$BASE_DIR/dns_history"; SPEEDTEST_HIST="$BASE_DIR/speed_history"
SCP_HIST="$BASE_DIR/scp_history"; PASS_SAVE="$BASE_DIR/passwords.txt"
IPSCAN_HIST="$BASE_DIR/ipscan_history"; WHOIS_HIST="$BASE_DIR/whois_history"

touch "$TERM_HIST" "$NET_HIST" "$CERT_HIST" "$IP_HIST" "$DNS_HIST" "$SPEEDTEST_HIST" "$SCP_HIST" "$IPSCAN_HIST" "$WHOIS_HIST"

# --- Commander Variables ---
COM_LOCAL_CWD=$(pwd); COM_REMOTE_CWD="."
COM_HOST=""; COM_USER="root"; COM_FILE=""
COM_SSH_OPTS="-o ControlMaster=auto -o ControlPath=/tmp/ja_cmd_socket_%h_%p_%r -o ControlPersist=600"

# --- UI Functions ---

draw_banner() {
    local subtitle="$1"
    stty sane 2>/dev/null; clear; tput cup 0 0
    local conn_status="${G_GREY}Checking...${RESET}"
    ping -c 1 -t 1 8.8.8.8 &>/dev/null && conn_status="${G_CYAN}Online${RESET}" || conn_status="\033[38;5;196mOffline${RESET}"
    echo -e "${B1}  ████  ████   ${B2}JA NERD KIT v10.6 (MAC)${RESET}"
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
        local lines=(); while IFS= read -r item || [[ -n "$item" ]]; do [ -z "$item" ] && continue; lines=("$item" "${lines[@]}"); done < "$h_file"
        local unique_lines=(); local seen="|"
        for item in "${lines[@]}"; do
            if [[ "$seen" != *"|$item|"* ]]; then unique_lines+=("$item"); seen+="$item|"; fi
        done
        options=("${unique_lines[@]}" "Tillbaka")
        run_menu "$title" "Välj ett objekt" "${options[@]}"; choice=$?
        if [ $choice -lt $((${#options[@]} - 1)) ]; then
            selected_item="${unique_lines[$choice]}"
            run_menu "$selected_item" "Vad vill du göra?" "Kör / Starta" "Radera" "Backa"
            case $? in
                0) $run_func "$selected_item"; return ;;
                1) item_esc=$(echo "$selected_item" | sed 's/\./\\./g'); sed -i '' "/^$item_esc$/d" "$h_file"
                   [ ! -s "$h_file" ] && return ;;
            esac
        else return; fi
    done
}

check_and_install_prereqs() {
    if ! command -v brew >/dev/null; then return; fi
    local missing=()
    command -v tmux >/dev/null || missing+=("tmux")
    command -v jq >/dev/null || missing+=("jq")
    command -v speedtest-cli >/dev/null || missing+=("speedtest-cli")
    command -v timeout >/dev/null || missing+=("coreutils")
    [ ${#missing[@]} -gt 0 ] && brew install "${missing[@]}"
}

# ==============================================================================
# TOOL 1: JA TERM
# ==============================================================================

start_term_session() {
    local data="$1"; IFS='|' read -r type user host col date <<< "$data"
    local color_ansi=$(get_color_ansi "$col")
    local session_name="ja_$(echo $host | tr -cd '[:alnum:]')"
    local log_file="${WIN_TEMP}/term_${host}_$(date +%Y%m%d_%H%M).log"
    item_esc=$(echo "$host" | sed 's/\./\\./g')
    sed -i '' "/|$item_esc|/d" "$TERM_HIST" 2>/dev/null
    echo "$type|$user|$host|$col|$(date +%Y-%m-%d)" >> "$TERM_HIST"
    local cmd="echo -ne '${color_ansi}'; ssh ${user}@${host}"
    if command -v tmux >/dev/null; then
        tmux new-session -d -s "$session_name" "script -F $log_file $cmd" 2>/dev/null || true
        tmux attach-session -t "$session_name"
    else ssh "${user}@${host}"; fi
}

manage_term_history() {
    if [ ! -s "$TERM_HIST" ]; then echo -e "\n  Historik tom."; sleep 1; return; fi
    while true; do
        local all_lines=(); while IFS= read -r l || [[ -n "$l" ]]; do [ -n "$l" ] && all_lines=("$l" "${all_lines[@]}"); done < "$TERM_HIST"
        local display=(); for l in "${all_lines[@]}"; do
            IFS='|' read -r type user host col date <<< "$l"
            display+=("$(get_color_ansi "$col")[$type] $user@$host ($date)${RESET}")
        done
        display+=("${G_FG}Back")
        run_menu "TERM HISTORY" "Välj session" "${display[@]}"; local choice=$?
        if [ $choice -lt $((${#display[@]} - 1)) ]; then
            IFS='|' read -r type user host col date <<< "${all_lines[$choice]}"
            run_menu "$host" "Action" "Anslut Nu" "Radera Entry" "Backa"
            case $? in
                0) start_term_session "$type|$user|$host|$col|$date"; return ;;
                1) item_esc=$(echo "$host" | sed 's/\./\\./g'); sed -i '' "\|$item_esc|d" "$TERM_HIST"; [ ! -s "$TERM_HIST" ] && return ;;
            esac
        else return; fi
    done
}

run_term() {
    local colors=("1: Vit" "2: Grön" "3: Blå" "4: Orange" "5: Ljusblå" "6: Lila")
    while true; do
        options=("Ny SSH Anslutning" "Ny Seriell Anslutning" "Historik" "Läs Loggar" "Rensa Loggar" "Tillbaka")
        run_menu "TERMINAL MANAGER" "" "${options[@]}"
        case $? in
            0) read -p "  User [root]: " u; u=${u:-root}; read -p "  IP/Host: " h; [ -z "$h" ] && continue
               run_menu "VÄLJ FÄRG" "Välj färg" "${colors[@]}"; c_idx=$?
               start_term_session "SSH|$u|$h|$((c_idx+1))|$(date +%Y-%m-%d)" ;;
            1) ports=($(ls /dev/tty.* 2>/dev/null)); [ ${#ports[@]} -eq 0 ] && { echo "Inga portar."; sleep 1; continue; }
               run_menu "SERIAL PORT" "Välj port" "${ports[@]}"; p_idx=$?
               port=${ports[$p_idx]}; read -p "  Baud [9600]: " baud; 
               run_menu "VÄLJ FÄRG" "Välj färg" "${colors[@]}"; c_idx=$?
               start_term_session "COM|${baud:-9600}|$port|$((c_idx+1))|$(date +%Y-%m-%d)" ;;
            2) manage_term_history ;;
            3) while true; do
                local logs=(); local display=()
                for f in $(ls -t "$WIN_TEMP"/*.log 2>/dev/null | head -n 15); do
                    base=$(basename "$f"); col_code=$(echo "$base" | sed -E 's/.*_c([0-9])_.*/\1/')
                    [[ ! "$col_code" =~ ^[0-9]$ ]] && col_code=1
                    display+=("$(get_color_ansi "$col_code")${base}${RESET}"); logs+=("$f")
                done
                [ ${#logs[@]} -eq 0 ] && { echo "Inga loggar."; sleep 1; break; }
                display+=("Back")
                run_menu "LOG VIEWER" "Välj en logg" "${display[@]}"; local choice=$?
                if [ $choice -lt $((${#display[@]} - 1)) ]; then draw_banner "VIEWING LOG"; cat "${logs[$choice]}" | less -R
                else break; fi
               done ;;
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
    item_esc=$(echo "$target" | sed 's/\./\\./g')
    sed -i '' "/^$item_esc$/d" "$NET_HIST" 2>/dev/null; echo "$target" >> "$NET_HIST"
    echo -e "  ${G_ACCENT}${BOLD}DIAGNOSTIC DASHBOARD: ${target}${RESET}"
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    echo "DNS|Testing..." > "/tmp/net_dns"; echo "PING|Testing..." > "/tmp/net_ping"
    echo "TCP|Testing..." > "/tmp/net_tcp"; echo "CERT|Testing..." > "/tmp/net_cert"
    echo "GW|Testing..." > "/tmp/net_gw"; echo "HTTP|Testing..." > "/tmp/net_http"
    (res=$(nslookup "$target" 2>/dev/null | grep "Address:" | tail -n1 | awk '{print $2}'); [ -z "$res" ] && echo "DNS|FAILED" > "/tmp/net_dns" || echo "DNS|$res" > "/tmp/net_dns") &
    (ping_res=$(ping -c 2 -t 2 "$target" 2>/dev/null); if [ $? -eq 0 ]; then avg=$(echo "$ping_res" | tail -1 | awk -F '/' '{print $5}'); echo "PING|ONLINE (${avg}ms)" > "/tmp/net_ping"; else echo "PING|OFFLINE" > "/tmp/net_ping"; fi) &
    (timeout 2 bash -c "</dev/tcp/$target/$NT_PORT" &>/dev/null && echo "TCP|OPEN" > "/tmp/net_tcp" || echo "TCP|CLOSED" > "/tmp/net_tcp") &
    (cert_out=$(echo | timeout 4 openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null); 
     if [ -z "$cert_out" ]; then echo "CERT|NONE" > "/tmp/net_cert"; 
     else 
        expiry=$(echo "$cert_out" | cut -d'=' -f2)
        exp_sec=$(date -j -f "%b %d %T %Y %Z" "$expiry" "+%s" 2>/dev/null || date -j -f "%b %e %T %Y %Z" "$expiry" "+%s")
        now_sec=$(date +%s); days=$(( (exp_sec - now_sec) / 86400 ))
        [ $days -lt 0 ] && echo "CERT|EXPIRED" > "/tmp/net_cert" || echo "CERT|OK ($days days)" > "/tmp/net_cert"; 
     fi) &
    (gw=$(netstat -rn | grep default | head -n1 | awk '{print $2}'); echo "GW|$gw" > "/tmp/net_gw") &
    (proto="http"; [ "$NT_PORT" == "443" ] && proto="https"; 
     full_code=$(curl -Is -A "Mozilla/5.0" --connect-timeout 3 "${proto}://${target}" -o /dev/null -w "%{http_code}" 2>/dev/null | tr -d '[:space:]');
     case "$full_code" in 200) msg="200 (OK)";; 301) msg="301 (Redirect)";; 302) msg="302 (Redirect)";; 401) msg="401 (Auth Req)";; 403) msg="403 (Forbidden)";; 404) msg="404 (Not Found)";; 500) msg="500 (Srv Error)";; 503) msg="503 (Overload)";; 000|0) msg="FAILED";; *) msg="$full_code (Other)";; esac
     echo "HTTP|$msg" > "/tmp/net_http") &
    while true; do
        tput cup 6 0
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "DNS Resolution" "$(cat /tmp/net_dns 2>/dev/null | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "Ping Connectivity" "$(cat /tmp/net_ping 2>/dev/null | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "TCP Port $NT_PORT" "$(cat /tmp/net_tcp 2>/dev/null | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "HTTP Response" "$(cat /tmp/net_http 2>/dev/null | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "SSL/TLS Cert" "$(cat /tmp/net_cert 2>/dev/null | cut -d'|' -f2)"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]          \n" "Local Gateway" "$(cat /tmp/net_gw 2>/dev/null | cut -d'|' -f2)"
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}          "
        read -rsn1 -t 1 input; [ -n "$input" ] && break
        [ $(jobs -r | wc -l) -eq 0 ] && break
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
    local url="http://ip-api.com/json/${target}?fields=status,message,country,city,org,as,query"
    local data=$(curl -s --connect-timeout 5 "$url")
    if [ -z "$data" ]; then echo -e "  ${P5}Kunde inte hämta data.${RESET}"; else
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Public IP" "$(echo "$data" | jq -r .query)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Organisation" "$(echo "$data" | jq -r .org)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "ASN" "$(echo "$data" | jq -r .as)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Land / Stad" "$(echo "$data" | jq -r .country), $(echo "$data" | jq -r .city)"
        if [ -n "$target" ]; then item_esc=$(echo "$target" | sed 's/\./\\./g'); sed -i '' "/^$item_esc$/d" "$IP_HIST" 2>/dev/null; echo "$target" >> "$IP_HIST"; fi
    fi
    echo ""; read -rsn1 -p "Tryck tangent...";
}

run_getip() {
    while true; do
        options=("Visa min IP" "Ange IP" "Historik" "Tillbaka")
        run_menu "JA MIN IP" "" "${options[@]}"; case $? in
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

DNS_SERVER=""
run_dns_logic() {
    local domain="$1"; local server="$2"; draw_banner "DNS CHECK: $domain"
    item_esc=$(echo "$domain" | sed 's/\./\\./g'); sed -i '' "/^$item_esc$/d" "$DNS_HIST" 2>/dev/null; echo "$domain" >> "$DNS_HIST"
    local query_server=""; [ -n "$server" ] && query_server="@$server"
    echo -e "  ${G_ACCENT}${BOLD}RECORD LOOKUP:${RESET}\n  ${G_GREY}------------------------------------------------------------${RESET}"
    for type in A AAAA MX NS TXT SOA; do
        echo -e "  ${G_FG}${type} Records:${RESET}"
        res=$(dig $query_server +short "$domain" $type); [ -z "$res" ] && echo -e "    ${P5}(Ingen data)${RESET}" || echo "$res" | sed 's/^/    /'
        echo ""
    done; read -rsn1 -p "Tangent...";
}

run_dns_check() {
    while true; do
        options=("Ange domän" "DNS Server: ${DNS_SERVER:-"Default"}" "Historik" "Tillbaka")
        run_menu "JA DNS CHECK" "" "${options[@]}"; case $? in
            0) read -p "  Domän: " d; [ -n "$d" ] && run_dns_logic "$d" "$DNS_SERVER" ;;
            1) read -p "  Server: " s; DNS_SERVER=$s ;;
            2) manage_history_generic "$DNS_HIST" "DNS HISTORY" "run_dns_logic_wrapper" ;;
            *) return ;;
        esac
    done
}
run_dns_logic_wrapper() { run_dns_logic "$1" "$DNS_SERVER"; }

# ==============================================================================
# TOOL 5: JA P$SSWD
# ==============================================================================

PW_WORDS=3; PW_SPEC="!"; PW_SEP="-"; PW_COUNT=5; PW_CAT="ALLA"
run_passwd() {
    local b64_swe="U2tvciBIdXMgUGFzdGEgUGl6emEgR2F0YSBTa29nIFNqbyBWaW5kIFNvbCBHcm9uIFJvZCBCbGEgR2FtbWFsIFNuYWJiIExpdGVuIFN0b3IgS2F0dCBIdW5kIEZpc2sgQm9sbCBTb2ZhIExhbXBhIEdsYXMgU3RvbCBCb3JkIEthZmZlIEJ1bGxlIFRhbGxyaWsgS25pdiBHYWZmZWwgU2tlZCBIYXYgUmVnbiBNb2xuIEhhc3QgR3JpcyBGb2dlbCBQZW5uYSBWYXNrYSBGb25zdGVyIERvcnIgVGFrIEdvbHYgVmFnZyBUcmFwcGEgTWF0dGEgS3VkZGUgVHYgRGF0b3IgTXVzIEthbWVyYSBMYW1wYSBCb2sgUGFwcGVyIFBlbm5hIFNrcml2Ym9yZCBIeWxsYSBTYXBlIEtsYWRlciBCeXhvciBUcm9qYSBTb2Nrb3IgTW9zc2EgSGFudHNoZSBLYXBwYSBKYWNrYSBTa29yIFN0b3ZlbCA="
    local b64_eng="U2hvZSBIb3VzZSBCcmVhZCBNaWxrIFRyZWUgUm9hZCBTa3kgQmx1ZSBSZWQgR3JlZW4gRmFzdCBTbWFsbCBCaWcgS2F0dCBEb2cgQmFsbCBDaGFpciBUYWJsZSBBcHBsZSBXYXRlciBDdXAgRG9vciBCb3ggQm9vayBQZW4gUGFwcGVyIEJhZyBXaW5kb3cgUm9vZiBGbG9vciBXYWxsIFN0YWlycyBDdXJ0YWluIFJ1ZyBQaWxsb3cgQmxhbmtldCBTcG9vbiBGb3JrIEtuaWZlIFRhbGxyaWsgU2VhIExha2UgQ2xvdWQgQ29tcHV0ZXIgTW91c2UgQ2FtZXJhIFBob25lIExhbXAgQm9vayBQZW4gRGVzayBTaGVsZiBDbG90aGVzIFBhbnRzIFNoaXJ0IFNvY2tzIEhhdCBHbG92ZXMgQ29hdCBKYWNrZXQgQm9vdCBTbmVha2VyIA=="
    while true; do
        options=("Generera lösenord" "Antal ord: $PW_WORDS" "Specialtecken: $PW_SPEC" "Avdelare: $PW_SEP" "Kategori: $PW_CAT" "Tillbaka")
        run_menu "JA P\$SSWD" "Skapa säkra lösenord" "${options[@]}"; choice=$?
        case $choice in
            0) draw_banner "RESULTAT"; local words=($(echo "$b64_swe" | base64 -D) $(echo "$b64_eng" | base64 -D))
               for ((j=1; j<=PW_COUNT; j++)); do
                   local pass=""; for ((i=0; i<PW_WORDS; i++)); do
                       local r=$(( RANDOM % ${#words[@]} )); pass+="${words[$r]}"
                       [ $i -lt $((PW_WORDS-1)) ] && pass+="$PW_SEP"
                   done; echo -e "  [${j}] ${BOLD}${G_CYAN}${pass}${PW_SPEC}${RESET}"
               done; read -rsn1 -p "Tryck tangent för att fortsätta...";;
            1) read -p "  Antal ord [3]: " n; PW_WORDS=${n:-3} ;;
            2) read -p "  Specialtecken [!]: " s; PW_SPEC=${s:-"!"} ;;
            3) read -p "  Avdelare [-]: " d; PW_SEP=${d:-"-"} ;;
            4) run_menu "VÄLJ KATEGORI" "" "ALLA" "SVENSKA" "ENGELSKA"; case $? in 0) PW_CAT="ALLA";; 1) PW_CAT="SVENSKA";; 2) PW_CAT="ENGELSKA";; esac ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 6: JA CERTCHECK
# ==============================================================================

run_certcheck_logic() {
    local target=$(echo "$1" | sed -E -e 's|^[^/]*//||' -e 's|/.*$||'); draw_banner "CERTCHECK: $target"
    item_esc=$(echo "$target" | sed 's/\./\\./g'); sed -i '' "/^$item_esc$/d" "$CERT_HIST" 2>/dev/null; echo "$target" >> "$CERT_HIST"
    data=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null)
    if [ -z "$data" ]; then echo -e "  ${P5}Kunde inte ansluta till ${target}:443.${RESET}"; else
        local issuer=$(echo "$data" | openssl x509 -noout -issuer | sed 's/issuer= //')
        local subject=$(echo "$data" | openssl x509 -noout -subject | sed 's/subject= //')
        local not_before=$(echo "$data" | openssl x509 -noout -dates | grep "notBefore" | cut -d'=' -f2)
        local not_after=$(echo "$data" | openssl x509 -noout -dates | grep "notAfter" | cut -d'=' -f2)
        exp_sec=$(date -j -f "%b %d %T %Y %Z" "$not_after" "+%s" 2>/dev/null || date -j -f "%b %e %T %Y %Z" "$not_after" "+%s")
        now_sec=$(date +%s); local days=$(( (exp_sec - now_sec) / 86400 ))
        echo -e "  ${G_ACCENT}${BOLD}SSL/TLS CERTIFICATE ANALYSIS:${RESET}"
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Start Date" "$not_before"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Expiry Date" "$not_after"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Days Remaining" "$days dagar"
        echo -e "\n  ${G_ACCENT}SUBJECT:${RESET}\n  ${G_CYAN}${subject}${RESET}"
        echo -e "\n  ${G_ACCENT}ISSUER:${RESET}\n  ${G_CYAN}${issuer}${RESET}"
        echo -e "\n  ${G_ACCENT}DOMAINS (SAN):${RESET}"; echo "$data" | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name:" | tail -n 1 | sed 's/DNS://g' | tr -d ' ' | tr ',' '\n' | awk '{print "  - " $1}'
        echo -e "\n  ${G_ACCENT}CERTIFICATE CHAIN:${RESET}"
        echo | openssl s_client -connect "${target}:443" -servername "${target}" -showcerts 2>/dev/null | grep -E "i:|s:" | while read -r line; do
            if [[ $line == s:* ]]; then echo -e "  ${G_CYAN}Subject: ${line#s:}${RESET}"; elif [[ $line == i:* ]]; then echo -e "  ${G_GREY}   Issued by: ${line#i:}${RESET}\n"; fi
        done
    fi
    echo ""; read -rsn1 -p "Tryck tangent för att fortsätta...";
}

run_cert_check() {
    while true; do
        options=("Ange Host" "Historik" "Tillbaka")
        run_menu "JA CERTCHECK" "" "${options[@]}"; case $? in
            0) read -p "  Host: " h; [ -n "$h" ] && run_certcheck_logic "$h" ;;
            1) manage_history_generic "$CERT_HIST" "CERTCHECK HISTORY" "run_certcheck_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 7: JA SPEEDTEST
# ==============================================================================

run_speedtest_logic() {
    draw_banner "JA SPEEDTEST"; echo -e "  ${G_ACCENT}Startar test...${RESET}"; local out=$(speedtest-cli --json 2>/dev/null)
    if [ -z "$out" ]; then echo -e "  ${P5}Kunde inte köra test.${RESET}"; else
        local down=$(echo "scale=2; $(echo "$out" | jq -r .download) / 1000000" | bc)
        local up=$(echo "scale=2; $(echo "$out" | jq -r .upload) / 1000000" | bc)
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Download" "${down} Mbit/s"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Upload" "${up} Mbit/s"
        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Ping" "$(echo "$out" | jq -r .ping) ms"
    fi; echo ""; read -rsn1 -p "Tangent...";
}

# ==============================================================================
# TOOL 8: JA IP-SCANNER (SMART & COMPACT)
# ==============================================================================

run_ipscan_logic() {
    local input="$1"; draw_banner "JA IP-SCANNER: $input"
    item_esc=$(echo "$input" | sed 's/\./\\./g'); sed -i '' "/^$item_esc$/d" "$IPSCAN_HIST" 2>/dev/null; echo "$input" >> "$IPSCAN_HIST"
    echo -e "  ${G_ACCENT}${BOLD}SKANNAR NÄTVERK...${RESET}"; echo -e "  ${G_GREY}Kör parallella pingar och kollar hostnames...${RESET}\n"
    local ips=()
    if [[ $input == *"/"* ]]; then
        local base=$(echo "$input" | cut -d'/' -f1 | cut -d'.' -f1-3)
        for i in {1..254}; do ips+=("$base.$i"); done
    elif [[ $input == *"-"* ]]; then
        local start_ip=$(echo "$input" | cut -d'-' -f1); local end_ip=$(echo "$input" | cut -d'-' -f2)
        local base=$(echo "$start_ip" | cut -d'.' -f1-3); local start_num=$(echo "$start_ip" | cut -d'.' -f4); local end_num=$(echo "$end_ip" | cut -d'.' -f4)
        for ((i=start_num; i<=end_num; i++)); do ips+=("$base.$i"); done
    fi
    local results_file="/tmp/ipscan_$(date +%s)"; touch "$results_file"
    local total=${#ips[@]}; local count=0
    for ip in "${ips[@]}"; do
        ((count++))
        ( if ping -c 1 -t 1 "$ip" &>/dev/null; then
             name=$(nslookup "$ip" 2>/dev/null | grep "name =" | awk '{print $4}' | sed 's/\.$//'); [ -z "$name" ] && name="N/A"
             echo "$ip|ONLINE|$name" >> "$results_file"
          else echo "$ip|OFFLINE|-" >> "$results_file"; fi ) &
        while [ $(jobs -r | wc -l) -ge 50 ]; do sleep 0.1; done
        if (( count % 10 == 0 )); then echo -ne "  Progression: ${count}/${total}\r"; fi
    done
    wait; echo -e "  Skanning klar! Genererar smart översikt...          "
    echo -e "  ${G_ACCENT}${BOLD}RESULTAT:${RESET}"; echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    local offline_start=""; local offline_end=""; local offline_count=0
    while IFS='|' read -r ip status name || [[ -n "$ip" ]]; do
        if [[ "$status" == "ONLINE" ]]; then
            if [ $offline_count -gt 0 ]; then
                if [ $offline_count -eq 1 ]; then echo -e "  ${G_GREY}${offline_start}${RESET}           [ ${P5}LEDIG${RESET} ]"
                else printf "  ${G_GREY}%-18s${RESET} [ ${P5}%-25s${RESET} ]\n" "${offline_start#*.*.*.}-${offline_end#*.*.*.}" "${offline_count} adresser lediga"; fi
                offline_count=0; offline_start=""; offline_end=""
            fi
            printf "  ${G_CYAN}%-18s${RESET} [ ${BOLD}%-10s${RESET} ] ${G_GREY}%s${RESET}\n" "$ip" "ONLINE" "$name"
        else
            if [ -z "$offline_start" ]; then offline_start="$ip"; fi
            offline_end="$ip"; ((offline_count++))
        fi
    done < <(sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n "$results_file" 2>/dev/null)
    if [ $offline_count -gt 0 ]; then
        if [ $offline_count -eq 1 ]; then echo -e "  ${G_GREY}${offline_start}${RESET}           [ ${P5}LEDIG${RESET} ]"
        else printf "  ${G_GREY}%-18s${RESET} [ ${P5}%-25s${RESET} ]\n" "${offline_start#*.*.*.}-${offline_end#*.*.*.}" "${offline_count} adresser lediga"; fi
    fi
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"; rm "$results_file" 2>/dev/null
    read -rsn1 -p "Tryck tangent för att återgå...";
}

run_ipscan() {
    while true; do
        options=("Skanna Subnet (t.ex. 192.168.0.0/24)" "Skanna Range (t.ex. 192.168.0.1-100)" "Historik" "Tillbaka")
        run_menu "JA IP-SCANNER" "Smart nätverksinventering" "${options[@]}"; case $? in
            0) read -p "  Ange subnet (t.ex. 192.168.0.0/24): " s; [ -n "$s" ] && run_ipscan_logic "$s" ;;
            1) read -p "  Ange range (t.ex. 192.168.0.1-100): " r; [ -n "$r" ] && run_ipscan_logic "$r" ;;
            2) manage_history_generic "$IPSCAN_HIST" "SCANNER HISTORY" "run_ipscan_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 9: JA COMMANDER (SCP FILE MANAGER)
# ==============================================================================

browse_local_dir() {
    while true; do
        local dirs=(); local display=()
        display+=("${P3}[UPP] ..${RESET}" "${G_ACCENT}[VÄLJ DENNA MAPP] .${RESET}")
        while IFS= read -r i || [[ -n "$i" ]]; do
            [ -z "$i" ] && continue; dirs+=("${i%/}"); display+=("${G_CYAN}[DIR] ${i%/}${RESET}")
        done < <(ls -1F "$COM_LOCAL_CWD" | grep '/$')
        display+=("Avbryt")
        run_menu "LOCAL BROWSER: $COM_LOCAL_CWD" "Välj mapp" "${display[@]}"; choice=$?
        [ $choice -eq $(( ${#display[@]} - 1 )) ] && return
        [ $choice -eq 0 ] && { COM_LOCAL_CWD=$(cd "$COM_LOCAL_CWD/.." && pwd); continue; }
        [ $choice -eq 1 ] && return
        COM_LOCAL_CWD=$(cd "$COM_LOCAL_CWD/${dirs[$((choice-2))]}" && pwd)
    done
}

browse_local_file() {
    local files=(); local display=()
    while IFS= read -r i || [[ -n "$i" ]]; do
        [ -z "$i" ] && continue; files+=("$i"); display+=("${G_FG}[FIL] $i${RESET}")
    done < <(ls -1p "$COM_LOCAL_CWD" | grep -v '/$')
    [ ${#files[@]} -eq 0 ] && { echo "Inga filer."; sleep 1; return 1; }
    display+=("Avbryt")
    run_menu "SELECT FILE" "Välj fil" "${display[@]}"; choice=$?
    [ $choice -eq $(( ${#display[@]} - 1 )) ] && return 1
    COM_FILE="${files[$choice]}"; return 0
}

browse_remote_dir() {
    local uh="${COM_USER}@${COM_HOST}"
    while true; do
        local dirs=(); local display=()
        display+=("${P3}[UPP] ..${RESET}" "${G_ACCENT}[VÄLJ DENNA MAPP] .${RESET}" "MANUELL SÖKVÄG")
        out=$(ssh $COM_SSH_OPTS -o ConnectTimeout=3 "$uh" "ls -1F \"$COM_REMOTE_CWD\"" 2>/dev/null)
        if [ $? -ne 0 ]; then echo "Kunde inte läsa."; read -p "Sökväg: " m; COM_REMOTE_CWD=${m:-"."}; return; fi
        while IFS= read -r l || [[ -n "$l" ]]; do [[ "$l" == */ ]] && { dirs+=("${l%/}"); display+=("${G_CYAN}[DIR] ${l%/}${RESET}"); }; done <<< "$out"
        display+=("Avbryt")
        run_menu "REMOTE: $COM_REMOTE_CWD" "Välj mapp" "${display[@]}"; choice=$?
        [ $choice -eq $(( ${#display[@]} - 1 )) ] && return
        [ $choice -eq 2 ] && { read -p "Sökväg: " m; COM_REMOTE_CWD=${m:-"."}; continue; }
        if [ $choice -eq 0 ]; then COM_REMOTE_CWD=$(ssh $COM_SSH_OPTS "$uh" "cd \"$COM_REMOTE_CWD/..\" && pwd" 2>/dev/null || echo ".."); 
        elif [ $choice -eq 1 ]; then return
        else COM_REMOTE_CWD="$COM_REMOTE_CWD/${dirs[$((choice-3))]}"; fi
    done
}

browse_remote_file() {
    local uh="${COM_USER}@${COM_HOST}"; local files=(); local display=()
    out=$(ssh $COM_SSH_OPTS -o ConnectTimeout=3 "$uh" "ls -1F \"$COM_REMOTE_CWD\"" 2>/dev/null)
    while IFS= read -r l || [[ -n "$l" ]]; do [[ "$l" != */ ]] && { files+=("$l"); display+=("${G_FG}[FIL] $l${RESET}"); }; done <<< "$out"
    [ ${#files[@]} -eq 0 ] && { echo "Inga filer."; sleep 1; return 1; }
    display+=("Avbryt")
    run_menu "SELECT REMOTE FILE" "Välj fil" "${display[@]}"; choice=$?
    [ $choice -eq $(( ${#display[@]} - 1 )) ] && return 1
    COM_FILE="${files[$choice]}"; return 0
}

run_commander() {
    while true; do
        local conn="${G_CYAN}${COM_USER}@${COM_HOST}${RESET}"
        [ -z "$COM_HOST" ] && conn="${G_GREY}EJ VALD${RESET}"
        
        options=(
            "1. Välj Server ($conn)"
            "2. Bläddra Lokalt (${G_GREY}...${COM_LOCAL_CWD#$HOME}${RESET})"
            "3. Bläddra på Server (${G_GREY}${COM_REMOTE_CWD}${RESET})"
            "--- ÖVERFÖRING ---"
            "Ladda UPP (Dator -> Server)"
            "Ladda NER (Server -> Dator)"
            "--- HANTERA ---"
            "Ta bort filer"
            "Historik / Återställ"
            "Tillbaka"
        )
        
        run_menu "JA COMMANDER" "Navigera och överför filer enkelt" "${options[@]}"; choice=$?
        
        case $choice in
            0) read -p "  Host/IP: " h; [ -n "$h" ] && COM_HOST=$h; read -p "  Användare [root]: " u; COM_USER=${u:-root} ;;
            1) browse_local_dir ;;
            2) [ -z "$COM_HOST" ] && { echo "Välj server först."; sleep 1; continue; }
               browse_remote_dir ;;
            4) # Ladda UPP
               [ -z "$COM_HOST" ] && { echo "Välj server först."; sleep 1; continue; }
               if browse_local_file; then
                   draw_banner "LADDAR UPP..."
                   scp $COM_SSH_OPTS "$COM_LOCAL_CWD/$COM_FILE" "${COM_USER}@${COM_HOST}:${COM_REMOTE_CWD}/"
                   [ $? -eq 0 ] && { echo -e "\n  KLART!"; echo "$COM_USER|$COM_HOST|$COM_REMOTE_CWD" >> "$SCP_HIST"; } || echo -e "\n  FEL!"
                   read -rsn1 -p "Tangent...";
               fi ;;
            5) # Ladda NER
               [ -z "$COM_HOST" ] && { echo "Välj server först."; sleep 1; continue; }
               if browse_remote_file; then
                   draw_banner "LADDAR NER..."
                   scp $COM_SSH_OPTS "${COM_USER}@${COM_HOST}:${COM_REMOTE_CWD}/$COM_FILE" "$COM_LOCAL_CWD/"
                   [ $? -eq 0 ] && echo -e "\n  KLART!" || echo -e "\n  FEL!"
                   read -rsn1 -p "Tangent...";
               fi ;;
            7) # Ta bort filer
               run_menu "RADERA" "Välj varifrån du vill radera" "Lokal Fil" "Fjärr Fil" "Avbryt"
               case $? in
                   0) # Lokal radering
                      local files=(); local display=()
                      while IFS= read -r i || [[ -n "$i" ]]; do
                          [ -z "$i" ] && continue; files+=("$i"); display+=("$i")
                      done < <(ls -1p "$COM_LOCAL_CWD" | grep -v '/$')
                      [ ${#files[@]} -eq 0 ] && { echo "Inga filer."; sleep 1; continue; }
                      display+=("Avbryt")
                      run_menu "RADERA LOKALT" "Välj fil att ta bort PERMANENT" "${display[@]}"; sel=$?
                      if [ $sel -lt $((${#display[@]} - 1)) ]; then
                          local target_file="${files[$sel]}"
                          read -p "  Radera $target_file? [j/N]: " confirm
                          if [[ "$confirm" == "j" ]]; then
                              rm -f "$COM_LOCAL_CWD/$target_file" && echo "Fil raderad." || echo "Kunde inte radera."
                              sleep 1
                          fi
                      fi ;;
                   1) # Fjärr radering
                      [ -z "$COM_HOST" ] && { echo "Välj server först."; sleep 1; continue; }
                      local files=(); local display=()
                      local out=$(ssh $COM_SSH_OPTS "${COM_USER}@${COM_HOST}" "ls -1p \"$COM_REMOTE_CWD\" | grep -v '/$'" 2>/dev/null)
                      while IFS= read -r l || [[ -n "$l" ]]; do
                          [ -z "$l" ] && continue; files+=("$l"); display+=("$l")
                      done <<< "$out"
                      [ ${#files[@]} -eq 0 ] && { echo "Inga filer."; sleep 1; continue; }
                      display+=("Avbryt")
                      run_menu "RADERA PÅ SERVER" "Välj fil att ta bort PERMANENT" "${display[@]}"; sel=$?
                      if [ $sel -lt $((${#display[@]} - 1)) ]; then
                          local target_file="${files[$sel]}"
                          read -p "  Radera $target_file på servern? [j/N]: " confirm
                          if [[ "$confirm" == "j" ]]; then
                              ssh $COM_SSH_OPTS "${COM_USER}@${COM_HOST}" "rm -f \"$COM_REMOTE_CWD/$target_file\"" && echo "Fil raderad." || echo "Kunde inte radera."
                              sleep 1
                          fi
                      fi ;;
               esac ;;
            8) # Historik / Reset
               run_menu "INSTÄLLNINGAR" "Hantera anslutning" "Visa Historik" "Nollställ Tunnel" "Avbryt"
               case $? in
                   0) manage_history_generic "$SCP_HIST" "HISTORY" "run_com_hist" ;;
                   1) ssh $COM_SSH_OPTS -O exit "${COM_USER}@${COM_HOST}" 2>/dev/null; echo "Nollställd."; sleep 1 ;;
               esac ;;
            9) return ;;
        esac
    done
}
run_com_hist() { IFS='|' read -r u h dst <<< "$1"; COM_USER=$u; COM_HOST=$h; COM_REMOTE_CWD=$dst; }

# ==============================================================================
# MAIN DASHBOARD
# ==============================================================================
check_and_install_prereqs
while true; do
    options=("JA TERM - SSH & COM" "JA NETTEST - Diagnostic" "JA MIN IP - IP Intel" "JA DNS CHECK - Record Lookup" "JA P\$SSWD - Generator" "JA CERTCHECK - SSL Analysis" "JA SPEEDTEST - Bandwidth" "JA IP-SCANNER - IP Range" "JA COMMANDER - File Manager" "Avsluta")
    run_menu "MAIN DASHBOARD" "Välkommen Johan! Hur svårt kan det va?" "${options[@]}"
    case $? in
        0) run_term ;;
        1) run_nettest ;;
        2) run_getip ;;
        3) run_dns_check ;;
        4) run_passwd ;;
        5) run_cert_check ;;
        6) run_speedtest_logic ;;
        7) run_ipscan ;;
        8) run_commander ;;
        9) clear; exit 0 ;;
    esac
done
