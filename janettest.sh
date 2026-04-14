#!/bin/bash

# --- JA NETTEST Colors (Optimized for Bash) ---
B1=$'\e[38;5;33m'
B2=$'\e[38;5;39m'
P1=$'\e[38;5;69m'
P2=$'\e[38;5;105m'
P3=$'\e[38;5;141m'
P4=$'\e[38;5;177m'
P5=$'\e[38;5;213m'
G_ACCENT=$'\e[38;5;33m' 
G_CYAN=$'\e[38;5;51m'
G_GREY=$'\e[38;5;244m'
G_FG=$'\e[38;5;255m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

# --- Settings ---
HISTORY_FILE="$HOME/.janettest_history"
touch "$HISTORY_FILE"
NT_PORT=443

# --- UI Functions ---

draw_banner() {
    local subtitle="$1"
    clear
    tput cup 0 0
    echo -e "${B1}  ████  ████   ${B2}JA NETTEST v2.0${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}IPv4 Full Path Diagnostic${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}${subtitle:-"Gateway, Next-Hop & SSL/TLS"}${RESET}"
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
        if [ -n "$help_text" ]; then
            echo -e "  ${G_GREY}${help_text}${RESET}\n"
        fi
        
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${G_ACCENT}> ${BOLD}${options[$i]}${RESET}"
            else
                echo -e "    ${options[$i]}${RESET}"
            fi
        done

        read -rsn3 key
        case "$key" in
            $'\x1b[A') ((selected--)); [ $selected -lt 0 ] && selected=$((${#options[@]} - 1)) ;;
            $'\x1b[B') ((selected++)); [ $selected -ge ${#options[@]} ] && selected=0 ;;
            "") return $selected ;;
        esac
    done
}

# --- Pre-req Check & Install ---
check_prereqs() {
    local missing=()
    command -v ping >/dev/null || missing+=("iputils-ping")
    command -v traceroute >/dev/null || missing+=("traceroute")
    command -v nslookup >/dev/null || missing+=("dnsutils")
    command -v openssl >/dev/null || missing+=("openssl")

    if [ ${#missing[@]} -gt 0 ]; then
        draw_banner "Installing Prerequisites"
        echo -e "  ${P2}Installerar nödvändiga verktyg...${RESET}"
        sudo apt-get update -y && sudo apt-get install -y "${missing[@]}"
    fi
}

# --- History Management ---
save_to_history() {
    local target="$1"
    sed -i "\|^$target$|d" "$HISTORY_FILE"
    echo "$target" >> "$HISTORY_FILE"
    tail -n 10 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# --- Test Functions ---
run_tests() {
    local target="$1"
    local port="$2"
    save_to_history "$target"
    
    draw_banner "DIAGNOSTIC DASHBOARD (IPv4): $target"
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    
    # Initiera statusfiler
    echo "DNS|Testing..." > "/tmp/nettest_dns"
    echo "PING|Testing..." > "/tmp/nettest_ping"
    echo "TCP|Testing..." > "/tmp/nettest_tcp"
    echo "GW|Testing..." > "/tmp/nettest_gw"
    echo "CERT|Testing..." > "/tmp/nettest_cert"
    > "/tmp/nettest_trace"

    # Starta tester och spara PIDs
    local pids=()

    # 1. DNS Lookup
    (
        res=$(nslookup -query=A "$target" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n1)
        [ -z "$res" ] && echo "DNS|FAILED" > "/tmp/nettest_dns" || echo "DNS|$res" > "/tmp/nettest_dns"
    ) & pids+=($!)

    # 2. Ping Test
    (
        ping_res=$(ping -4 -c 2 -W 2 "$target" 2>/dev/null)
        if [ $? -eq 0 ]; then
            avg=$(echo "$ping_res" | tail -1 | awk -F '/' '{print $5}'); echo "PING|ONLINE (${avg}ms)" > "/tmp/nettest_ping"
        else echo "PING|OFFLINE" > "/tmp/nettest_ping"; fi
    ) & pids+=($!)

    # 3. TCP Port Check
    (timeout 2 bash -c "</dev/tcp/$target/$port" &>/dev/null && echo "TCP|OPEN" > "/tmp/nettest_tcp" || echo "TCP|CLOSED/TIMEOUT" > "/tmp/nettest_tcp") & pids+=($!)

    # 4. Gateway & Interface
    (
        gw=$(ip -4 route show default | awk '{print $3}' | head -n1)
        iface=$(ip -4 route get "$target" 2>/dev/null | grep -oP 'dev \K\S+')
        echo "GW|$gw ($iface)" > "/tmp/nettest_gw"
    ) & pids+=($!)

    # 5. SSL Cert Check
    (
        cert_out=$(timeout 3 openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null)
        if [ -z "$cert_out" ]; then echo "CERT|NONE" > "/tmp/nettest_cert"
        else
            expiry=$(echo "$cert_out" | cut -d'=' -f2); expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null); current_epoch=$(date +%s)
            days=$(( (expiry_epoch - current_epoch) / 86400 ))
            [ $days -lt 0 ] && echo "CERT|EXPIRED" > "/tmp/nettest_cert" || echo "CERT|OK ($days days)" > "/tmp/nettest_cert"
        fi
    ) & pids+=($!)

    # 6. Full Trace
    traceroute -4 -n -m 20 -q 1 -w 1 "$target" 2>/dev/null | grep --line-buffered -v "traceroute" > "/tmp/nettest_trace" & 
    pids+=($!)

    # Loopa och visa resultat dynamiskt
    while true; do
        tput cup 6 0
        
        dns_stat=$(cat /tmp/nettest_dns 2>/dev/null | cut -d'|' -f2)
        ping_stat=$(cat /tmp/nettest_ping 2>/dev/null | cut -d'|' -f2)
        tcp_stat=$(cat /tmp/nettest_tcp 2>/dev/null | cut -d'|' -f2)
        gw_stat=$(cat /tmp/nettest_gw 2>/dev/null | cut -d'|' -f2)
        cert_stat=$(cat /tmp/nettest_cert 2>/dev/null | cut -d'|' -f2)
        
        next_stat=$(grep -E "^[[:space:]]*2[[:space:]]" "/tmp/nettest_trace" | awk '{print $2}')
        [ -z "$next_stat" ] && next_stat="..."

        # Färgkodning
        [[ "$dns_stat" == "FAILED" ]] && d_col="${P5}" || d_col="${G_CYAN}"
        [[ "$ping_stat" == "OFFLINE" ]] && p_col="${P5}" || p_col="${G_CYAN}"
        [[ "$tcp_stat" == "OPEN" ]] && t_col="${G_CYAN}" || t_col="${P5}"
        [[ "$cert_stat" == "NONE" ]] || [[ "$cert_stat" == "EXPIRED" ]] && c_col="${P5}" || c_col="${G_CYAN}"
        
        echo -ne "  ${G_FG}DNS Resolution      ${RESET} [ ${d_col}"; printf "%-25s" "${dns_stat:-...}"; echo -e "${RESET} ]"
        echo -ne "  ${G_FG}Ping Connectivity   ${RESET} [ ${p_col}"; printf "%-25s" "${ping_stat:-...}"; echo -e "${RESET} ]"
        echo -ne "  ${G_FG}TCP Port $port${RESET}       [ ${t_col}"; printf "%-25s" "${tcp_stat:-...}"; echo -e "${RESET} ]"
        echo -ne "  ${G_FG}SSL/TLS Cert        ${RESET} [ ${c_col}"; printf "%-25s" "${cert_stat:-...}"; echo -e "${RESET} ]"
        echo -ne "  ${G_FG}Local Gateway       ${RESET} [ ${G_CYAN}"; printf "%-25s" "${gw_stat:-...}"; echo -e "${RESET} ]"
        echo -ne "  ${G_FG}Next Hop (ISP/Ext)  ${RESET} [ ${G_CYAN}"; printf "%-25s" "${next_stat}"; echo -e "${RESET} ]"
        
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
        echo -e "  ${G_ACCENT}${BOLD}PATH ANALYSIS (First 8 hops):${RESET}"
        
        if [ -s "/tmp/nettest_trace" ]; then
            head -n 8 "/tmp/nettest_trace" | while read line; do
                echo -e "  ${G_GREY}$(echo "$line" | tr -s ' ')${RESET}                                        "
            done
        else echo -e "  ${G_GREY}Searching for hops...${RESET}\n\n"; fi
        
        local running=0
        for pid in "${pids[@]}"; do kill -0 "$pid" 2>/dev/null && ((running++)); done
        [ "$running" -eq 0 ] && break

        read -rsn1 -t 0.5 input
        if [ "$input" == "s" ]; then
            for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null; done; break
        fi
    done

    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    echo -e "\n  ${P2}${BOLD}ANALYS KLAR.${RESET} Tryck på valfri tangent för att återgå..."
    read -rsn1
}

manage_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        draw_banner "History is empty"
        sleep 1; return
    fi
    local lines=()
    mapfile -t lines < <(tac "$HISTORY_FILE")
    lines+=("Tillbaka")
    run_menu "VÄLJ TIDIGARE TEST" "" "${lines[@]}"
    local choice=$?
    if [ $choice -lt $((${#lines[@]} - 1)) ]; then run_tests "${lines[$choice]}" "$NT_PORT"; fi
}

# --- Main ---
check_prereqs

while true; do
    options=("Nytt Test (IPv4)" "Port att testa: $NT_PORT" "Historik / Senaste" "System Info" "Avsluta")
    run_menu "NETTEST MAIN MENU" "Välj eventuell TCP port först sen IP/FQDN" "${options[@]}"
    CHOICE=$?

    case $CHOICE in
        0) echo -ne "\n  ${G_ACCENT}Ange IP eller FQDN: ${RESET}"; read target
           [ -n "$target" ] && run_tests "$target" "$NT_PORT" ;;
        1) echo -ne "\n  ${G_ACCENT}Ange TCP port (t.ex. 80, 443, 3389): ${RESET}"; read val
           if [[ "$val" =~ ^[0-9]+$ ]]; then NT_PORT=$val; fi ;;
        2) manage_history ;;
        3) draw_banner "SYSTEM INFORMATION"
           echo -e "  Platform:  WSL / Ubuntu\n  Version:    JA NETTEST v2.0\n  Features:   Async TCP/SSL/Path\n\n  Tryck på valfri tangent..."
           read -rsn1 ;;
        4) clear; exit 0 ;;
    esac
done
