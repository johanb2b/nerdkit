#!/bin/bash

# --- JA P$SSWD Colors (From JA Terminal v2) ---
B1="\e[38;5;33m"
B2="\e[38;5;39m"
P1="\e[38;5;69m"
P2="\e[38;5;105m"
P3="\e[38;5;141m"
P4="\e[38;5;177m"
P5="\e[38;5;213m"
G_ACCENT="\033[38;5;33m" 
G_CYAN="\033[38;5;51m"
G_GREY="\033[38;5;244m"
G_FG="\033[38;5;255m"
BOLD="\033[1m"
RESET="\033[0m"

# --- Settings ---
# Ordlista helt utan å, ä, ö
WORDS=("bil" "hus" "stol" "bord" "kaffe" "mat" "hund" "katt" "fisk" "sand" \
       "sten" "berg" "dal" "vind" "moln" "sol" "regn" "sommar" "vinter" "natt" \
       "dag" "vecka" "lampa" "skola" "penna" "bok" "sko" "byxa" "varg" "kanin" \
       "apa" "orm" "glass" "sked" "gaffel" "kniv" "tallrik" "kopp" "glas" "dator" \
       "mus" "kabel" "port" "webb" "sajt" "park" "gata" "stad" "buss" "flyg" \
       "skepp" "plan" "skruv" "hammare" "spik" "lim" "sax" "papper" "plast" "metall")

# Defaults
NUM_WORDS=3
NUM_PASS=5
SAVE="Nej"
SPECIAL_CHARS="!#"

SAVE_PATH="/mnt/c/temp/passwords.txt"

# --- UI Functions ---

draw_banner() {
    clear
    tput cup 0 0
    echo -e "${B1}  ████  ████   ${B2}JA P\$SSWD v1.4${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}Security Level: Dynamic${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}Custom Special Characters Support${RESET}"
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

# Funktion för att hitta säkra platser MELLAN orden
get_safe_slots() {
    local str="$1"
    local len=${#str}
    local slots=()

    for ((j=0; j<=len; j++)); do
        if [ $j -eq $len ] || [ "${str:j:1}" == "-" ]; then
            local prev=""
            local next=""
            [ $j -gt 0 ] && prev="${str:j-1:1}"
            [ $j -lt $len ] && next="${str:j+1:1}"

            if [[ ! "$prev" =~ [iIlL] ]] && [[ ! "$next" =~ [iIlL] ]]; then
                slots+=($j)
            fi
        fi
    done
    echo "${slots[@]}"
}

generate_passwords() {
    local num_words=$1
    local num_passwords=$2
    local save_to_file=$3
    local spec_chars=$4
    local results=()

    echo -e "\n  ${G_ACCENT}Genererar lösenord...${RESET}"
    
    for ((p=1; p<=$num_passwords; p++)); do
        local current_words=()
        for ((w=0; w<num_words; w++)); do
            current_words+=("${WORDS[$RANDOM % ${#WORDS[@]}]}")
        done
        
        local password=$(IFS=-; echo "${current_words[*]}")
        local safe_slots=($(get_safe_slots "$password"))
        
        if [ ${#safe_slots[@]} -eq 0 ]; then
            for ((j=0; j<=${#password}; j++)); do
                if [ $j -eq ${#password} ] || [ "${password:j:1}" == "-" ]; then
                    safe_slots+=($j)
                fi
            done
        fi

        # 1. Sätt in siffra
        local slot_digit=${safe_slots[$RANDOM % ${#safe_slots[@]}]}
        local digit=$((RANDOM % 10))
        password="${password:0:slot_digit}${digit}${password:slot_digit}"

        # 2. Sätt in specialtecken (om några angetts)
        if [ -n "$spec_chars" ]; then
            safe_slots=($(get_safe_slots "$password"))
            local slot_spec=${safe_slots[$RANDOM % ${#safe_slots[@]}]}
            # Plocka ett slumpmässigt tecken från strängen
            local char_idx=$((RANDOM % ${#spec_chars}))
            local special="${spec_chars:$char_idx:1}"
            password="${password:0:slot_spec}${special}${password:slot_spec}"
        fi

        results+=("$password")
    done

    echo -e "\n  ${G_FG}${BOLD}Dina nya lösenord:${RESET}"
    echo -e "  ${G_GREY}----------------------------------------------------${RESET}"
    for res in "${results[@]}"; do
        echo -e "  ${G_CYAN}${res}${RESET}"
    done
    echo -e "  ${G_GREY}----------------------------------------------------${RESET}"

    if [ "$save_to_file" == "Ja" ]; then
        mkdir -p "$(dirname "$SAVE_PATH")" 2>/dev/null
        printf "%s\n" "${results[@]}" >> "$SAVE_PATH"
        echo -e "\n  ${P2}Lösenorden har sparats i: C:\\temp\\passwords.txt${RESET}"
    fi

    echo -e "\n  ${G_GREY}Tryck på valfri tangent för att gå tillbaka...${RESET}"
    read -n 1
}

# --- Main Loop ---
while true; do
    options=("Antal ord: $NUM_WORDS" "Antal lösenord: $NUM_PASS" "Tecken: $SPECIAL_CHARS" "Spara till fil: $SAVE" "GENERERA NU" "Avsluta")
    run_menu "INSTÄLLNINGAR" "${options[@]}"
    CHOICE=$?

    case $CHOICE in
        0)
            echo -ne "\n  Ange antal ord (1-10): "
            read val
            if [[ "$val" =~ ^[0-9]+$ ]]; then NUM_WORDS=$val; fi
            ;;
        1)
            echo -ne "\n  Ange antal lösenord: "
            read val
            if [[ "$val" =~ ^[0-9]+$ ]]; then NUM_PASS=$val; fi
            ;;
        2)
            echo -ne "\n  Ange specialtecken att använda (t.ex. !#@?): "
            read val
            SPECIAL_CHARS="$val"
            ;;
        3)
            [ "$SAVE" == "Nej" ] && SAVE="Ja" || SAVE="Nej"
            ;;
        4)
            generate_passwords "$NUM_WORDS" "$NUM_PASS" "$SAVE" "$SPECIAL_CHARS"
            ;;
        5)
            clear
            exit 0
            ;;
    esac
done
