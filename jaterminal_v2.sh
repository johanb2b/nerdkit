#!/bin/bash

# --- J-A TERMINAL Colors ---
B1="\e[38;5;33m"
B2="\e[38;5;39m"
P1="\e[38;5;69m"
P2="\e[38;5;105m"
P3="\e[38;5;141m"
P4="\e[38;5;177m"
P5="\e[38;5;213m"
G_BG="\033[48;5;232m"
G_FG="\033[38;5;255m"
G_ACCENT="\033[38;5;33m" 
G_CYAN="\033[38;5;51m"
G_GREY="\033[38;5;244m"
G_HEADER="\033[48;5;33m\033[38;5;255m"
BOLD="\033[1m"
RESET="\033[0m"

# --- Settings ---
APP_NAME="J-A TERMINAL"
WIN_TEMP="/mnt/c/temp/TerminalLogs"
HISTORY_FILE="$HOME/.jaterminal_history"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# --- Initialize ---
mkdir -p "$WIN_TEMP" 2>/dev/null

# --- UI Functions ---

draw_banner() {
    clear
    tput cup 0 0
    local conn_status="${G_GREY}Checking...${RESET}"
    if ping -c 1 -W 1 8.8.8.8 &>/dev/null; then
        conn_status="${G_CYAN}Online${RESET}"
    else
        conn_status="\033[38;5;196mOffline${RESET}"
    fi

    # JA Logo with Text info to the right
    echo -e "${B1}  ████  ████   ${B2}Terminal v6.5${RESET}"
    echo -e "${B2}    ██ ██  ██  ${P1}Internet Connection: $conn_status${RESET}"
    echo -e "${P1} ██ ██ ██████  ${P2}Developed for Johan Andersson${RESET}"
    echo -e "${P2}  ███  ██  ██  ${P3}${RESET}"
    echo ""
}

draw_header() {
    draw_banner
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

save_history() {
    local type=$1 user=$2 host=$3 color=$4
    sed -i "/|$host|/d" "$HISTORY_FILE" 2>/dev/null
    echo "$type|$user|$host|$color|$(date +%Y-%m-%d)" >> "$HISTORY_FILE"
    tail -n 20 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

start_session() {
    local type=$1 user=$2 host=$3 color_idx=$4
    local color_ansi=$(get_color_ansi "$color_idx")
    local session_name="ja_${type,,}_${host//[^a-zA-Z0-9]/_}"
    local ts=$(date +"%Y-%m-%d_%H.%M")
    local log_file="${WIN_TEMP}/${ts}_c${color_idx}_host_${host//[^a-zA-Z0-9.]/_}_${type,,}_${user}.log"
    
    # --- Pre-connection Check ---
    if [ "$type" == "SSH" ]; then
        echo -e "  ${G_GREY}Testing connection to $host...${RESET}"
        # Check if port 22 is open
        if ! timeout 2 bash -c "true > /dev/tcp/$host/22" 2>/dev/null; then
            # Port is closed or host down, get the real SSH error message
            local real_error=$(ssh -o ConnectTimeout=2 -o BatchMode=yes ${user}@${host} 2>&1 | head -n 1)
            echo -e "\n  \033[38;5;196mERROR: ${real_error:-"Connection failed"}${RESET}"
            echo -e "  ${G_GREY}Returning to menu in 3 seconds...${RESET}"
            sleep 3
            return
        fi
    else
        if [ ! -e "$host" ]; then
            echo -e "\n  \033[38;5;196mERROR: Serial port $host not found!${RESET}"
            echo -e "  ${G_GREY}Returning to menu in 3 seconds...${RESET}"
            sleep 3
            return
        fi
    fi

    save_history "$type" "$user" "$host" "$color_idx"

    clear
    tput cup 0 0
    echo -e "${G_ACCENT}${BOLD}╭── INITIALIZING SESSION ──────────────────────────────╮${RESET}"
    echo -e "  ${G_FG}Target:  $host ($type)${RESET}"
    [ "$type" == "COM" ] && echo -e "  ${G_FG}Baud:    $user${RESET}" || echo -e "  ${G_FG}User:    $user${RESET}"
    echo -e "  ${G_GREY}Journal: $(basename "$log_file")${RESET}"
    echo -e "${G_ACCENT}${BOLD}╰──────────────────────────────────────────────────────╯${RESET}\n"

    local cmd=""
    if [ "$type" == "SSH" ]; then
        cmd="echo -ne '${color_ansi}'; script -f -c 'ssh ${user}@${host}' $log_file"
    else
        cmd="echo -ne '${color_ansi}'; script -f -c 'screen $host $user' $log_file"
    fi

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux attach-session -t "$session_name"
    else
        tmux new-session -s "$session_name" "$cmd"
    fi
}

run_menu() {
    local title=$1
    shift
    local options=("$@")
    local selected=0

    while true; do
        draw_header
        echo -e "  ${G_CYAN}${BOLD}${title}${RESET}"
        
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${G_ACCENT}> ${BOLD}${options[$i]}${RESET}"
            else
                # Clean up existing color codes for menu display if necessary, 
                # but we keep them for the list
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

read_logs() {
    local log_files=()
    local display_names=()
    
    while IFS= read -r f; do
        base=$(basename "$f")
        # Extract color code directly from filename (e.g. ..._c3_host...)
        local color_code=$(echo "$base" | sed -r 's/.*_c([0-9])_host.*/\1/')
        # Fallback if old log format
        [[ ! "$color_code" =~ ^[0-9]$ ]] && color_code=1
        
        local col_ansi=$(get_color_ansi "$color_code")
        local display=$(echo "$base" | sed -r 's/^([0-9-]{10})_([0-9.]{5})_c[0-9]_host_([^_]+)_([^_]+).*/\1 \2 host: \3 (\4)/' | tr '.' ':')
        
        log_files+=("$f")
        display_names+=("${col_ansi}${display}${RESET}")
    done < <(ls -t "$WIN_TEMP"/*.log 2>/dev/null | head -n 15)

    if [ ${#log_files[@]} -eq 0 ]; then
        echo -e "\n  No logs found."; sleep 1; return
    fi

    display_names+=("${G_FG}Back")
    
    run_menu "LOG VIEWER: Select to Read/Delete | 'q' to Exit" "${display_names[@]}"
    local choice=$?
    
    if [ $choice -lt $((${#display_names[@]} - 1)) ]; then
        local selected_log="${log_files[$choice]}"
        run_menu "Action: $(basename "$selected_log")" "Read Log" "Delete Log" "Back"
        local action=$?
        case $action in
            0)
                echo -e "\n  ${G_CYAN}Reading: $(basename "$selected_log")${RESET}"
                echo -e "  ${G_GREY}Press 'q' to exit viewer${RESET}\n"
                sleep 1
                cat "$selected_log" | col -bx | less -R
                ;;
            1)
                rm "$selected_log"
                echo "  Log deleted."
                sleep 1
                ;;
        esac
    fi
}

show_readme() {
    clear
    tput cup 0 0
    draw_banner
    echo -e "${G_HEADER}${BOLD}  ⬢  SYSTEM INFORMATION  ${RESET}\n"
    echo -e "  ${G_ACCENT}${BOLD}LOGGING ENGINE${RESET}"
    echo -e "  Terminal traffic is automatically indexed and stored."
    echo -e "  Storage:  ${G_CYAN}C:\\temp\\TerminalLogs${RESET}\n"
    
    echo -e "  ${G_ACCENT}${BOLD}USER IDENTITY${RESET}"
    echo -e "  Profile:  Johan Andersson"
    echo -e "  History:  ~/.jaterminal_history\n"
    
    echo -e "  ${G_ACCENT}${BOLD}MAINTENANCE${RESET}"
    echo -e "  Use the 'Clean logs' option to free up space in C:\\temp.\n"
    
    echo -e "  ${G_GREY}Press any key to return to menu...${RESET}"
    read -n 1
}

manage_history() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        echo -e "\n  History is empty."; sleep 1; return
    fi
    local lines=()
    mapfile -t lines < <(tac "$HISTORY_FILE")
    local display=()
    for l in "${lines[@]}"; do
        IFS='|' read -r type user host col date <<< "$l"
        local col_ansi=$(get_color_ansi "$col")
        display+=("${col_ansi}[$type] $user@$host ($date)")
    done
    display+=("${G_GREY}CLEAR ALL HISTORY" "${G_FG}Back")
    run_menu "History (Latest first):" "${display[@]}"
    local choice=$?
    if [ $choice -eq $((${#display[@]} - 2)) ]; then
        > "$HISTORY_FILE"; echo "  History cleared."; sleep 1
    elif [ $choice -lt $((${#display[@]} - 2)) ]; then
        local entry="${lines[$choice]}"
        IFS='|' read -r type user host col date <<< "$entry"
        run_menu "$user@$host" "Connect Now" "Delete Entry" "Back"
        local action=$?
        case $action in
            0) start_session "$type" "$user" "$host" "$col" ;;
            1) 
                local total_lines=$(wc -l < "$HISTORY_FILE")
                local line_num=$((total_lines - choice))
                sed -i "${line_num}d" "$HISTORY_FILE"
                echo "  Entry deleted."; sleep 1 
                ;;
        esac
    fi
}

# --- Main Loop ---
while true; do
    options=("New SSH Connection" "New Serial Connection (COM)" "History / Favorites" "Read Log Files" "Clean All Logs" "System Info & Help" "Exit")
    run_menu "MAIN MENU" "${options[@]}"
    CHOICE=$?

    case $CHOICE in
        0)
            echo -e "\n  ${G_ACCENT}SSH Setup${RESET}"
            read -p "  Username [root]: " USER_NAME
            USER_NAME=${USER_NAME:-root}
            read -p "  IP / Host: " DEST
            echo -e "  ${G_FG}Colors: 1:White, 2:Green, 3:Blue, 4:Orange, 5:Cyan, 6:Purple${RESET}"
            read -p "  Selection [1]: " COLOR_IDX
            COLOR_IDX=${COLOR_IDX:-1}
            start_session "SSH" "$USER_NAME" "$DEST" "$COLOR_IDX"
            ;;
        1)
            echo -e "\n  ${G_ACCENT}Serial Setup${RESET}"
            local ports=($(ls /dev/ttyS* 2>/dev/null))
            [ ${#ports[@]} -eq 0 ] && echo "  No serial ports found." && sleep 1 && continue
            for i in "${!ports[@]}"; do
                com_num=${ports[$i]#/dev/ttyS}
                echo -e "  ${G_ACCENT}$((i+1)))${RESET} ${ports[$i]} (COM$com_num)"
            done
            read -p "  Select port [1]: " PORT_NUM
            PORT_VAL=${PORT_NUM:-1}
            PORT=${ports[$((PORT_VAL-1))]}
            echo -e "\n  ${G_ACCENT}Baud Rate:${RESET}"
            echo -e "  1: 9600, 2: 19200, 3: 38400, 4: 57600, 5: 115200"
            read -p "  Selection [1]: " BAUD_IDX
            case ${BAUD_IDX:-1} in 2) BAUD=19200 ;; 3) BAUD=38400 ;; 4) BAUD=57600 ;; 5) BAUD=115200 ;; *) BAUD=9600 ;; esac
            echo -e "  ${G_FG}Colors: 1:White, 2:Green, 3:Blue, 4:Orange, 5:Cyan, 6:Purple${RESET}"
            read -p "  Color [1]: " COLOR_IDX
            start_session "COM" "$BAUD" "$PORT" "${COLOR_IDX:-1}"
            ;;
        2) manage_history ;;
        3) read_logs ;;
        4) rm "$WIN_TEMP"/*.log 2>/dev/null; echo "  Logs cleaned."; sleep 1 ;;
        5) show_readme ;;
        6) clear; exit 0 ;;
    esac
done
