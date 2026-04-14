#!/bin/bash

###############################################################################
# JA MAC KIT - THE ULTIMATE NETWORK & SYSADMIN TOOLBOX (macOS VERSION)
# Version: 9.2-MAC
# Developer: Johan Andersson
# Motto: "Hur svårt kan det va? (Även på en Mac)"
#
# GETTING STARTED:
# 1. Install Homebrew if you haven't: https://brew.sh
# 2. Make the script executable: chmod +x jamackit.sh
# 3. Run the script: ./jamackit.sh
# 4. Prerequisites: The script uses 'brew' to install missing tools like
#    jq, tmux, speedtest-cli, etc.
#
###############################################################################

# --- JA MAC KIT Colors ---
B1=$'\e[38;5;33m'   # Deep Blue
B2=$'\e[38;5;39m'   # Sky Blue
P1=$'\e[38;5;69m'   # Light Purple
P2=$'\e[38;5;105m'  # Lavender
P3=$'\e[38;5;141m'  # Purple
P4=$'\e[38;5;177m'  # Pinkish
P5=$'\e[38;5;213m'  # Light Pink
G_BG="\033[48;5;232m"
G_FG="\033[38;5;255m"
G_ACCENT="\033[38;5;33m" 
G_CYAN="\033[38;5;51m"
G_GREY="\033[38;5;244m"
G_HEADER="\033[48;5;33m\033[38;5;255m"
BOLD="\033[1m"
RESET="\033[0m"

# --- Settings & Files ---
TERM_HIST="$HOME/.jamacterm_history"
NET_HIST="$HOME/.jamacnet_history"
CERT_HIST="$HOME/.jamaccert_history"
IP_HIST="$HOME/.jamacip_history"
DNS_HIST="$HOME/.jamacdns_history"
SPEEDTEST_HIST="$HOME/.jamacspeed_history"
LOG_DIR="$HOME/Documents/TerminalLogs" # Updated for Mac path
PASS_SAVE="$HOME/Documents/passwords.txt"

mkdir -p "$LOG_DIR" 2>/dev/null
touch "$TERM_HIST" "$NET_HIST" "$CERT_HIST" "$IP_HIST" "$DNS_HIST" "$SPEEDTEST_HIST"

# --- UI Functions ---

draw_banner() {
    local subtitle="$1"
    stty sane 2>/dev/null
    clear
    tput cup 0 0
    local conn_status="${G_GREY}Checking...${RESET}"
    # Mac ping flags: -c (count), -t (timeout in sec)
    if ping -c 1 -t 1 8.8.8.8 &>/dev/null; then
        conn_status="${G_CYAN}Online${RESET}"
    else
        conn_status="\033[38;5;196mOffline${RESET}"
    fi

    echo -e "${B1}  ████  ████   ${B2}JA MAC KIT v9.2${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}Internet: $conn_status${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}${subtitle:-"Developed for Johan Andersson"}${RESET}"
    echo -e "${P2}  ███  ██  ██  ${P3}Hur svårt kan det va?${RESET}"
    echo ""
}

run_menu() {
    local title=$1
    local help_text=$2
    shift 2
    local options=("$@")
    local selected=0
    while true; do
        draw_banner "$title"
        if [ -n "$help_text" ]; then echo -e "  ${G_GREY}${help_text}${RESET}\n"; fi
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${G_ACCENT}> ${BOLD}${options[$i]}${RESET}"
            else echo -e "    ${options[$i]}${RESET}"; fi
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
    case $1 in
        2) echo -e "\033[38;5;121m" ;; # Green
        3) echo -e "\033[38;5;111m" ;; # Blue
        4) echo -e "\033[38;5;215m" ;; # Orange
        5) echo -e "\033[38;5;159m" ;; # Cyan
        6) echo -e "\033[38;5;183m" ;; # Purple
        *) echo -e "\033[38;5;255m" ;; # White
    esac
}

manage_history_generic() {
    local h_file="$1" title="$2" run_func="$3"
    if [ ! -s "$h_file" ]; then echo -e "  ${G_GREY}Historiken är tom.${RESET}"; sleep 1; return; fi
    while true; do
        mapfile -t lines < <(tail -r "$h_file") # Mac uses tail -r instead of tac
        options=("${lines[@]}" "Tillbaka")
        run_menu "$title" "Välj ett objekt för att köra eller radera" "${options[@]}"
        choice=$?
        if [ $choice -lt $((${#options[@]} - 1)) ]; then
            selected_item="${lines[$choice]}"
            run_menu "$selected_item" "Vad vill du göra?" "Kör / Starta" "Radera från historik" "Backa"
            case $? in
                0) $run_func "$selected_item"; return ;;
                1) sed -i '' "\|^$selected_item$|d" "$h_file"; [ ! -s "$h_file" ] && return ;;
                *) continue ;;
            esac
        else return; fi
    done
}

check_and_install_prereqs() {
    local force=$1
    local missing=()
    command -v brew >/dev/null || { echo "Installera Homebrew först!"; exit 1; }
    
    command -v nslookup >/dev/null || missing+=("bind") # Provides nslookup/dig
    command -v openssl >/dev/null || missing+=("openssl")
    command -v screen >/dev/null || missing+=("screen")
    command -v tmux >/dev/null || missing+=("tmux")
    command -v jq >/dev/null || missing+=("jq")
    command -v curl >/dev/null || missing+=("curl")
    command -v speedtest-cli >/dev/null || missing+=("speedtest-cli")

    if [ ${#missing[@]} -gt 0 ] || [ "$force" == "true" ]; then
        echo -e "  ${G_ACCENT}Kontrollerar systemverktyg via brew...${RESET}"
        brew update
        for tool in "${missing[@]}"; do
            brew install "$tool"
        done
        echo -e "  ${G_CYAN}Klart!${RESET}"; sleep 1
    fi
}

# ==============================================================================
# TOOL 1: JA TERM (macOS VERSION)
# ==============================================================================

start_term_session() {
    local data="$1"
    IFS='|' read -r type user host color_idx date <<< "$data"
    local color_ansi=$(get_color_ansi "$color_idx")
    local session_name="jamac_${type,,}_${host//[^a-zA-Z0-9]/_}"
    local ts=$(date +"%Y%m%d_%H%M")
    local log_file="${LOG_DIR}/term_${type,,}_${host//[^a-zA-Z0-9.]/_}_c${color_idx}_${ts}.log"
    
    if [ "$type" == "SSH" ]; then
        echo -e "  ${G_GREY}Testing connection to $host...${RESET}"
        if ! nc -z -G 2 "$host" 22 2>/dev/null; then # Mac uses nc instead of /dev/tcp
            echo -e "\n  \033[38;5;196mERROR: Connection failed on port 22.${RESET}"; sleep 2; return
        fi
    fi
    
    sed -i '' "/|$host|/d" "$TERM_HIST" 2>/dev/null
    echo "$type|$user|$host|$color_idx|$(date +%Y-%m-%d)" >> "$TERM_HIST"
    
    draw_banner "CONNECTING"
    echo -e "${G_ACCENT}${BOLD}╭──────────────────────────────────────────────────────╮${RESET}"
    echo -e "  ${G_FG}Target:  $host ($type)${RESET}"
    echo -e "  ${G_GREY}Journal: $(basename "$log_file")${RESET}"
    echo -e "${G_ACCENT}${BOLD}╰──────────────────────────────────────────────────────╯${RESET}\n"
    
    local cmd=""
    # Mac script syntax: script -q [file] [command]
    [ "$type" == "SSH" ] && cmd="echo -ne '${color_ansi}'; script -q $log_file ssh ${user}@${host}" \
                         || cmd="echo -ne '${color_ansi}'; script -q $log_file screen $host $user"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then tmux attach-session -t "$session_name"
    else tmux new-session -s "$session_name" "$cmd"; fi
}

manage_term_history() {
    if [ ! -s "$TERM_HIST" ]; then echo -e "\n  Historik tom."; sleep 1; return; fi
    while true; do
        local lines=(); mapfile -t lines < <(tail -r "$TERM_HIST")
        local display=(); for l in "${lines[@]}"; do
            IFS='|' read -r type user host col date <<< "$l"
            display+=("$(get_color_ansi "$col")[$type] $user@$host ($date)${RESET}")
        done
        display+=("${G_FG}Back")
        run_menu "TERM HISTORY" "Välj session för att ansluta eller radera" "${display[@]}"
        local choice=$?
        if [ $choice -lt $((${#display[@]} - 1)) ]; then
            IFS='|' read -r type user host col date <<< "${lines[$choice]}"
            run_menu "$host" "Action for session" "Anslut Nu" "Radera Entry" "Backa"
            case $? in
                0) start_term_session "$type|$user|$host|$col|$date"; return ;;
                1) sed -i '' "\|$host|d" "$TERM_HIST"; [ ! -s "$TERM_HIST" ] && return ;;
            esac
        else return; fi
    done
}

read_logs() {
    while true; do
        local log_files=(); local display_names=()
        while IFS= read -r f; do
            base=$(basename "$f"); color_code=$(echo "$base" | sed -E 's/.*_c([0-9])_.*/\1/')
            [[ ! "$color_code" =~ ^[0-9]$ ]] && color_code=1
            local col_ansi=$(get_color_ansi "$color_code")
            log_files+=("$f"); display_names+=("${col_ansi}${base}${RESET}")
        done < <(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 15)
        if [ ${#log_files[@]} -eq 0 ]; then echo -e "\n  Inga loggar."; sleep 1; return; fi
        display_names+=("${G_FG}Back")
        run_menu "LOG VIEWER" "Välj en logg för att läsa eller radera" "${display_names[@]}"
        local choice=$?
        if [ $choice -lt $((${#display_names[@]} - 1)) ]; then
            local selected_log="${log_files[$choice]}"
            run_menu "$(basename "$selected_log")" "" "Läs Logg" "Radera Logg" "Backa"
            case $? in
                0) echo -e "\n  ${G_CYAN}Reading log...${RESET}"; cat "$selected_log" | col -bx | less -R ;;
                1) rm "$selected_log"; echo "Raderad."; sleep 1 ;;
            esac
        else return; fi
    done
}

run_term() {
    while true; do
        options=("Ny SSH Anslutning" "Ny Seriell Anslutning (USB/COM)" "Historik / Favoriter" "Läs Loggfiler" "Rensa Alla Loggar" "Tillbaka")
        run_menu "TERMINAL MANAGER" "" "${options[@]}"
        case $? in
            0) read -p "  User [root]: " u; u=${u:-root}; read -p "  IP/Host: " h; [ -z "$h" ] && continue
               echo -e "  ${G_FG}Colors: 1:Vit, 2:Grön, 3:Blå, 4:Orange, 5:Cyan, 6:Lila${RESET}"
               read -p "  Färg [1]: " c; start_term_session "SSH|$u|$h|${c:-1}|$(date +%Y-%m-%d)" ;;
            1) # macOS serial ports are usually /dev/tty.*
               ports=($(ls /dev/tty.* 2>/dev/null)); [ ${#ports[@]} -eq 0 ] && { echo "Inga portar funna."; sleep 1; continue; }
               for i in "${!ports[@]}"; do echo "  $((i+1))) ${ports[$i]}"; done
               read -p "  Välj port: " p_idx; port=${ports[$((p_idx-1))]}
               read -p "  Baud [115200]: " baud; read -p "  Färg [1]: " c
               start_term_session "COM|${baud:-115200}|$port|${c:-1}|$(date +%Y-%m-%d)" ;;
            2) manage_term_history ;;
            3) read_logs ;;
            4) rm "$LOG_DIR"/*.log 2>/dev/null; echo "Loggar rensade."; sleep 1 ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 2: JA NETTEST (macOS ADAPTED)
# ==============================================================================
NT_PORT=443

run_nettest_logic() {
    local target="$1"
    sed -i '' "\|^$target$|d" "$NET_HIST"; echo "$target" >> "$NET_HIST"
    draw_banner "NETTEST: $target"
    echo -e "  ${G_ACCENT}${BOLD}DIAGNOSTIC DASHBOARD: ${target}${RESET}"
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    
    echo "DNS|Testing..." > "/tmp/net_dns"; echo "PING|Testing..." > "/tmp/net_ping"
    echo "TCP|Testing..." > "/tmp/net_tcp"; echo "CERT|Testing..." > "/tmp/net_cert"
    echo "GW|Testing..." > "/tmp/net_gw"; > "/tmp/net_trace"
    
    pids=()
    (res=$(nslookup -query=A "$target" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n1); [ -z "$res" ] && echo "DNS|FAILED" > "/tmp/net_dns" || echo "DNS|$res" > "/tmp/net_dns") & pids+=($!)
    (ping_res=$(ping -c 2 -t 2 "$target" 2>/dev/null); if [ $? -eq 0 ]; then avg=$(echo "$ping_res" | tail -1 | awk -F '/' '{print $5}'); echo "PING|ONLINE (${avg}ms)" > "/tmp/net_ping"; else echo "PING|OFFLINE" > "/tmp/net_ping"; fi) & pids+=($!)
    (nc -z -G 2 "$target" "$NT_PORT" &>/dev/null && echo "TCP|OPEN" > "/tmp/net_tcp" || echo "TCP|CLOSED" > "/tmp/net_tcp") & pids+=($!)
    (cert_out=$(timeout 3 openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null); if [ -z "$cert_out" ]; then echo "CERT|NONE" > "/tmp/net_cert"; else 
        expiry=$(echo "$cert_out" | cut -d'=' -f2); 
        # Mac date calculation
        exp_sec=$(date -j -f "%b %d %T %Y %Z" "$expiry" "+%s" 2>/dev/null)
        now_sec=$(date "+%s")
        days=$(( (exp_sec - now_sec) / 86400 ))
        [ $days -lt 0 ] && echo "CERT|EXPIRED" > "/tmp/net_cert" || echo "CERT|OK ($days days)" > "/tmp/net_cert"; fi) & pids+=($!)
    (gw=$(netstat -nr | grep default | awk '{print $2}' | head -n1); iface=$(route get "$target" 2>/dev/null | grep interface | awk '{print $2}'); echo "GW|$gw ($iface)" > "/tmp/net_gw") & pids+=($!)
    traceroute -n -m 15 -q 1 -w 1 "$target" 2>/dev/null | grep -v "traceroute" > "/tmp/net_trace" & pids+=($!)
    
    while true; do
        tput cup 6 0
        d_stat=$(cat /tmp/net_dns | cut -d'|' -f2); p_stat=$(cat /tmp/net_ping | cut -d'|' -f2)
        t_stat=$(cat /tmp/net_tcp | cut -d'|' -f2); c_stat=$(cat /tmp/net_cert | cut -d'|' -f2)
        g_stat=$(cat /tmp/net_gw | cut -d'|' -f2); n_stat=$(grep " 2 " "/tmp/net_trace" | head -n1 | awk '{print $2}')
        
        printf "  %-20s [ %b%-25s%b ]\n" "DNS Resolution" "${G_CYAN}" "${d_stat:-...}" "${RESET}"
        printf "  %-20s [ %b%-25s%b ]\n" "Ping Connectivity" "${G_CYAN}" "${p_stat:-...}" "${RESET}"
        printf "  %-20s [ %b%-25s%b ]\n" "TCP Port $NT_PORT" "${G_CYAN}" "${t_stat:-...}" "${RESET}"
        printf "  %-20s [ %b%-25s%b ]\n" "SSL/TLS Cert" "${G_CYAN}" "${c_stat:-...}" "${RESET}"
        printf "  %-20s [ %b%-25s%b ]\n" "Local Gateway" "${G_CYAN}" "${g_stat:-...}" "${RESET}"
        printf "  %-20s [ %b%-25s%b ]\n" "Next Hop" "${G_CYAN}" "${n_stat:-...}" "${RESET}"
        
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}\n  ${G_ACCENT}PATH ANALYSIS:${RESET}"
        head -n 6 "/tmp/net_trace" | while read line; do echo -e "  ${G_GREY}$(echo "$line" | tr -s ' ')${RESET}                   "; done
        
        running=0; for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && ((running++)); done
        [ "$running" -eq 0 ] && break
        read -rsn1 -t 0.4 input; [ "$input" == "s" ] && { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done; break; }
    done
    echo -e "\n  Tryck på valfri tangent för att återgå..."; read -rsn1
}

run_nettest() {
    while true; do
        options=("Ny Test (IPv4)" "Port: $NT_PORT" "Historik" "Tillbaka")
        run_menu "NETTEST MANAGER" "Välj port först sen IP/FQDN" "${options[@]}"
        case $? in
            0) read -p "  Mål IP/FQDN: " target; [ -n "$target" ] && run_nettest_logic "$target" ;;
            1) read -p "  Port: " val; [[ "$val" =~ ^[0-9]+$ ]] && NT_PORT=$val ;;
            2) manage_history_generic "$NET_HIST" "NETTEST HISTORY" "run_nettest_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 3: JA MIN IP (HTTPS)
# ==============================================================================

run_getip_logic() {
    local target="$1"
    draw_banner "IP INTEL: ${target:-"MY PUBLIC IP"}"
    local url="https://ipapi.co/json/"
    [ -n "$target" ] && url="https://ipapi.co/${target}/json/"
    local data=$(curl -s "$url")
    if [ -z "$data" ] || [ "$(echo "$data" | jq -r .error)" == "true" ]; then echo "FEL."; else
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Public IP" "$(echo "$data" | jq -r .ip)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Organisation" "$(echo "$data" | jq -r .org)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "ASN" "$(echo "$data" | jq -r .asn)"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Land / Stad" "$(echo "$data" | jq -r .country_name), $(echo "$data" | jq -r .city)"
        [ -n "$target" ] && { sed -i '' "\|$target|d" "$IP_HIST" 2>/dev/null; echo "$target" >> "$IP_HIST"; }
    fi
    read -rsn1 -p "Tangent...";
}

run_getip() {
    while true; do
        options=("Visa MIN publika IP" "Slå upp valfri IP" "Historik" "Tillbaka")
        run_menu "JA MIN IP" "" "${options[@]}"
        case $? in
            0) run_getip_logic "" ;;
            1) read -p "  IP: " h; [ -n "$h" ] && run_getip_logic "$h" ;;
            2) manage_history_generic "$IP_HIST" "IP HISTORY" "run_getip_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 4: JA DNS DIG
# ==============================================================================

run_dnsdig_logic() {
    local domain="$1"
    sed -i '' "\|^$domain$|d" "$DNS_HIST" 2>/dev/null; echo "$domain" >> "$DNS_HIST"
    draw_banner "DNS DIG: $domain"
    echo -e "  ${G_ACCENT}${BOLD}RECORD LOOKUP:${RESET}\n  ${G_GREY}------------------------------------------------------------${RESET}"
    for type in A AAAA MX NS TXT SOA; do
        echo -e "  ${G_FG}${type} Records:${RESET}"
        res=$(dig +short "$domain" $type); [ -z "$res" ] && echo -e "    ${P5}(Ingen data)${RESET}" || echo "$res" | sed 's/^/    /'
        echo ""
    done
    read -rsn1 -p "Tangent...";
}

run_dnsdig() {
    while true; do
        options=("Ny Domän-koll" "Historik" "Tillbaka")
        run_menu "JA DNS DIG" "" "${options[@]}"
        case $? in
            0) read -p "  Ange domän: " domain; [ -n "$domain" ] && run_dnsdig_logic "$domain" ;;
            1) manage_history_generic "$DNS_HIST" "DNS HISTORY" "run_dnsdig_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 5: JA P$SSWD
# ==============================================================================
PW_WORDS=("bil" "hus" "stol" "bord" "kaffe" "mat" "hund" "katt" "fisk" "sand" \
          "sten" "berg" "dal" "vind" "moln" "sol" "regn" "sommar" "vinter" "natt")
PW_SPECIALS="!#"
PW_NUM_WORDS=3; PW_NUM_PASS=5; PW_SAVE="Nej"

run_passwd() {
    while true; do
        options=("Antal ord: $PW_NUM_WORDS" "Antal lösen: $PW_NUM_PASS" "Tecken: $PW_SPECIALS" "Spara: $PW_SAVE" "GENERERA" "Tillbaka")
        run_menu "P\$SSWD GENERATOR" "" "${options[@]}"
        case $? in
            0) read -p "  Ord: " PW_NUM_WORDS ;;
            1) read -p "  Lösen: " PW_NUM_PASS ;;
            2) read -p "  Tecken: " PW_SPECIALS ;;
            3) [ "$PW_SAVE" == "Nej" ] && PW_SAVE="Ja" || PW_SAVE="Nej" ;;
            4) echo -e "\n  ${G_ACCENT}Genererar...${RESET}"
               results=(); for ((p=0; p<PW_NUM_PASS; p++)); do
                   c=(); for ((w=0; w<PW_NUM_WORDS; w++)); do c+=("${PW_WORDS[$RANDOM % ${#PW_WORDS[@]}]}"); done
                   pass=$(IFS=-; echo "${c[*]}")
                   pass="${pass}$((RANDOM % 10))${PW_SPECIALS:RANDOM%${#PW_SPECIALS}:1}"
                   results+=("$pass"); echo -e "  ${G_CYAN}$pass${RESET}"
               done
               [ "$PW_SAVE" == "Ja" ] && { printf "%s\n" "${results[@]}" >> "$PASS_SAVE"; echo "Sparat."; }
               read -rsn1 -p "Tangent...";;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 6: JA CERTCHECK (macOS ADAPTED)
# ==============================================================================

run_certcheck_logic() {
    local target=$(echo "$1" | sed -E 's|^[^/]*//||' | sed -E 's|/.*$||')
    sed -i '' "\|^$target$|d" "$CERT_HIST"; echo "$target" >> "$CERT_HIST"
    draw_banner "CERTCHECK: $target"
    data=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null)
    if [ -z "$data" ]; then echo -e "  ${P5}Kunde inte ansluta.${RESET}"; else
        local issuer=$(echo "$data" | openssl x509 -noout -issuer | sed 's/issuer= //')
        local subject=$(echo "$data" | openssl x509 -noout -subject | sed 's/subject= //')
        local not_after=$(echo "$data" | openssl x509 -noout -dates | grep "notAfter" | cut -d'=' -f2)
        
        # Mac date calculation
        exp_sec=$(date -j -f "%b %d %T %Y %Z" "$not_after" "+%s" 2>/dev/null)
        now_sec=$(date "+%s")
        local days=$(( (exp_sec - now_sec) / 86400 ))
        
        local d_col="${G_CYAN}"; [ $days -lt 30 ] && d_col="${P5}"; [ $days -lt 7 ] && d_col="${P5}${BOLD}"

        printf "  %-20s [ ${G_CYAN}%-25s${RESET} ]\n" "Expiry Date" "$not_after"
        printf "  %-20s [ ${d_col}%-25s${RESET} ]\n" "Days Remaining" "$days dagar"
        
        echo -e "\n  ${G_ACCENT}${BOLD}SUBJECT:${RESET}\n  ${G_CYAN}${subject}${RESET}"
        echo -e "\n  ${G_ACCENT}${BOLD}ISSUER:${RESET}\n  ${G_CYAN}${issuer}${RESET}"
        
        echo -e "\n  ${G_ACCENT}${BOLD}DOMAINS (SAN):${RESET}"
        echo "$data" | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name:" | tail -n 1 | sed 's/DNS://g' | tr -d ' ' | tr ',' '\n' | awk '{print "  - " $1}'
        
        echo -e "\n  ${G_ACCENT}${BOLD}CHAIN STATUS:${RESET}"
        local verify=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>&1 | grep "Verification:")
        echo -e "  ${G_CYAN}${verify:-"Verification: FAILED"}${RESET}"
    fi
    echo -e "\n  Tryck på valfri tangent för att återgå..."; read -rsn1
}

run_certcheck() {
    while true; do
        options=("Ny Analys" "Historik" "Tillbaka")
        run_menu "CERTIFICATE CHECKER" "" "${options[@]}"
        case $? in
            0) read -p "  URL: " target; [ -n "$target" ] && run_certcheck_logic "$target" ;;
            1) manage_history_generic "$CERT_HIST" "CERT HISTORY" "run_certcheck_logic" ;;
            *) return ;;
        esac
    done
}

# ==============================================================================
# TOOL 7: JA SPEEDTEST
# ==============================================================================

run_speedtest_logic() {
    draw_banner "SPEEDTEST"
    echo -e "  ${G_ACCENT}Kör Speedtest... Detta kan ta en stund.${RESET}"
    local data=$(speedtest-cli --json 2>/dev/null)
    if [ -z "$data" ]; then
        echo -e "  ${P5}Kunde inte köra speedtest-cli.${RESET}"
    else
        local download=$(echo "$data" | jq -r .download)
        local upload=$(echo "$data" | jq -r .upload)
        local ping=$(echo "$data" | jq -r .ping)
        
        download=$(echo "scale=2; $download / 1000000" | bc)
        upload=$(echo "scale=2; $upload / 1000000" | bc)

        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Download" "${download} Mbps"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Upload" "${upload} Mbps"
        printf "  %-20s [ ${G_CYAN}%-35s${RESET} ]\n" "Ping" "${ping} ms"
        
        echo "$(date +%Y-%m-%d\ %H:%M)|${download}|${upload}|${ping}" >> "$SPEEDTEST_HIST"
    fi
    read -rsn1 -p "Tangent...";
}

run_speedtest() {
    while true; do
        options=("Starta Speedtest" "Historik" "Tillbaka")
        run_menu "JA SPEEDTEST" "" "${options[@]}"
        case $? in
            0) run_speedtest_logic ;;
            1) 
               if [ ! -s "$SPEEDTEST_HIST" ]; then echo -e "  Historik tom."; sleep 1; continue; fi
               draw_banner "SPEEDTEST HISTORY"
               echo -e "  ${G_ACCENT}%-18s | %-10s | %-10s | %-8s${RESET}" "Datum" "Ned" "Upp" "Ping"
               tail -r "$SPEEDTEST_HIST" | head -n 15 | while IFS='|' read -r date down up ping; do
                   printf "  %-18s | %-10s | %-10s | %-8s\n" "$date" "${down}M" "${up}M" "${ping}ms"
               done
               read -rsn1 -p "Tangent...";;
            *) return ;;
        esac
    done
}

# ==============================================================================
# MAIN KIT ENTRY
# ==============================================================================

check_and_install_prereqs "false"

while true; do
    options=("JA TERM - SSH & USB" "JA NETTEST - Diagnostic" "JA MIN IP - IP Intel" "JA DNS DIG - Record Lookup" "JA P\$SSWD - Generator" "JA CERTCHECK - SSL Analysis" "JA SPEEDTEST - Bandwidth" "Information" "Avsluta")
    run_menu "MAIN DASHBOARD (macOS)" "Välkommen Johan! Hur svårt kan det va?" "${options[@]}"
    case $? in
        0) run_term ;;
        1) run_nettest ;;
        2) run_getip ;;
        3) run_dnsdig ;;
        4) run_passwd ;;
        5) run_certcheck ;;
        6) run_speedtest ;;
        7) draw_banner "INFO"; echo "JA MAC KIT v9.2 - Optimerad för macOS."; read -rsn1 ;;
        8) clear; exit 0 ;;
    esac
done
