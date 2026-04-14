#!/bin/bash

# --- JA CERTCHECK Colors ---
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
HISTORY_FILE="$HOME/.jacertcheck_history"
touch "$HISTORY_FILE"

# --- UI Functions ---

draw_banner() {
    clear
    tput cup 0 0
    echo -e "${B1}  ████  ████   ${B2}JA CERTCHECK v1.0${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}Certificate Analysis Engine${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}Expiration, Chain & CRL Analysis${RESET}"
    echo -e "${P2}  ███  ██  ██  ${P3}Hur svårt kan det va?${RESET}"
    echo ""
}

run_menu() {
    local title=$1
    shift
    local options=("$@")
    local selected=0

    while true; do
        draw_banner
        echo -e "  ${G_CYAN}${BOLD}${title}${RESET}"
        
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

# --- History Management ---
save_to_history() {
    local target="$1"
    sed -i "\|^$target$|d" "$HISTORY_FILE"
    echo "$target" >> "$HISTORY_FILE"
    tail -n 10 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# --- Analysis Functions ---

run_analysis() {
    local url="$1"
    # Städa URL (ta bort https:// och /)
    local target=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    
    save_to_history "$target"
    draw_banner
    echo -e "  ${G_ACCENT}${BOLD}ANALYZING CERTIFICATE: ${target}${RESET}"
    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    
    # Hämta certifikat-data via openssl
    local cert_data=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null)
    
    if [ -z "$cert_data" ]; then
        echo -e "  ${P5}FEL: Kunde inte ansluta till ${target}.${RESET}"
        echo -e "  ${G_GREY}Kontrollera internetanslutningen eller URL:en.${RESET}"
    else
        # 1. Hämta grundinfo
        local issuer=$(echo "$cert_data" | openssl x509 -noout -issuer | sed 's/issuer= //')
        local subject=$(echo "$cert_data" | openssl x509 -noout -subject | sed 's/subject= //')
        local dates=$(echo "$cert_data" | openssl x509 -noout -dates)
        local not_after=$(echo "$dates" | grep "notAfter" | cut -d'=' -f2)
        
        # 2. Beräkna dagar kvar
        local expiry_epoch=$(date -d "$not_after" +%s)
        local current_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        # 3. CRL info
        local crl_urls=$(echo "$cert_data" | openssl x509 -noout -text | grep -A 4 "CRL Distribution Points" | grep "URI:" | awk '{print $NF}' | sed 's/URI://')

        # Rendera resultat
        printf "  %-20s [ ${G_CYAN}%-30s${RESET} ]\n" "${G_FG}Issuer${RESET}" "${issuer:0:30}..."
        printf "  %-20s [ ${G_CYAN}%-30s${RESET} ]\n" "${G_FG}Subject${RESET}" "${subject:0:30}..."
        
        # Färgkodning på dagar
        local d_col="${G_CYAN}"
        if [ $days_left -lt 30 ]; then d_col="${P5}"; fi
        if [ $days_left -lt 7 ]; then d_col="${P5}${BOLD}"; fi
        
        printf "  %-20s [ ${G_CYAN}%-30s${RESET} ]\n" "${G_FG}Expiry Date${RESET}" "$not_after"
        printf "  %-20s [ ${d_col}%-30s${RESET} ]\n" "${G_FG}Days Remaining${RESET}" "$days_left dagar"
        
        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
        echo -e "  ${G_ACCENT}${BOLD}CRL / REVOCATION INFO:${RESET}"
        if [ -n "$crl_urls" ]; then
            for url in $crl_urls; do
                echo -e "  - ${G_CYAN}${url}${RESET}"
            done
        else
            echo -e "  ${G_GREY}Ingen CRL-information hittades.${RESET}"
        fi

        echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
        # Verifiera kedja
        local verify_res=$(echo | openssl s_client -connect "${target}:443" -servername "${target}" 2>&1 | grep "Verification:" || echo "Verification: FAILED")
        echo -e "  ${G_ACCENT}${BOLD}CHAIN STATUS:${RESET} ${G_CYAN}${verify_res}${RESET}"
    fi

    echo -e "  ${G_GREY}------------------------------------------------------------${RESET}"
    echo -e "\n  ${P2}${BOLD}ANALYS KLAR.${RESET} Tryck på valfri tangent för att återgå..."
    read -rsn1
}

manage_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        draw_banner
        echo -e "  ${G_GREY}Historiken är tom.${RESET}"
        sleep 1
        return
    fi
    local lines=()
    mapfile -t lines < <(tac "$HISTORY_FILE")
    lines+=("Tillbaka")
    run_menu "VÄLJ TIDIGARE ANALYS" "${lines[@]}"
    local choice=$?
    if [ $choice -lt $((${#lines[@]} - 1)) ]; then
        run_analysis "${lines[$choice]}"
    fi
}

# --- Main ---

while true; do
    options=("Ny Certifikat-koll" "Historik / Tidigare" "System Info" "Avsluta")
    run_menu "CERTIFICATE MANAGER" "${options[@]}"
    CHOICE=$?

    case $CHOICE in
        0)
            echo -ne "\n  ${G_ACCENT}Ange URL (t.ex. google.com): ${RESET}"
            read target
            if [ -n "$target" ]; then run_analysis "$target"; fi
            ;;
        1) manage_history ;;
        2)
            draw_banner
            echo -e "  ${G_CYAN}${BOLD}SYSTEM INFORMATION${RESET}"
            echo -e "  Plattform:  WSL / Ubuntu"
            echo -e "  Verktyg:    OpenSSL Engine"
            echo -e "  Analys:     Expiration, Issuer, CRL & Chain Verification"
            echo -e "\n  ${G_GREY}Tryck på valfri tangent...${RESET}"
            read -n 1
            ;;
        3) clear; exit 0 ;;
    esac
done
