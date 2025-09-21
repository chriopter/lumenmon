#!/bin/bash
# Interactive menu with arrow keys

# Menu drawing function
draw_menu() {
    local selected=$1
    shift
    local options=("$@")

    clear

    # Logo
    echo -e "\033[0;36m"
    echo "  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
    echo "  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║"
    echo "  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
    echo "  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
    echo "  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
    echo "  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "\033[0m"
    echo ""

    # Menu items
    for i in "${!options[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "  \033[1;36m→ ${options[$i]}\033[0m"
        else
            echo -e "    ${options[$i]}"
        fi
    done

    echo ""
    echo -e "  \033[0;90m[↑↓ Navigate, Enter Select, q Quit]\033[0m"
}

# Get single keypress
get_key() {
    local key
    # Read from /dev/tty if available (for piped execution)
    if [ -t 0 ]; then
        IFS= read -rsn1 key
    else
        IFS= read -rsn1 key < /dev/tty
    fi

    if [[ $key = $'\x1b' ]]; then
        # Read arrow key sequence
        if [ -t 0 ]; then
            read -rsn2 key
        else
            read -rsn2 key < /dev/tty
        fi
        case $key in
            '[A') echo UP ;;
            '[B') echo DOWN ;;
        esac
    else
        echo "$key"
    fi
}

# Main menu
show_menu() {
    local options=("Install Console" "Advanced" "Exit")
    local selected=0

    while true; do
        draw_menu $selected "${options[@]}"

        key=$(get_key)
        case $key in
            UP)
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                ;;
            DOWN)
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
                ;;
            q|Q)
                exit 0
                ;;
            '')  # Enter key
                case $selected in
                    0)  # Install Console
                        COMPONENT="console"
                        IMAGE=""
                        break
                        ;;
                    1)  # Advanced
                        show_advanced
                        break
                        ;;
                    2)  # Exit
                        exit 0
                        ;;
                esac
                ;;
        esac
    done
}

# Advanced menu
show_advanced() {
    local options=(
        "Console - Latest"
        "Console - Dev"
        "Console - Build local"
        "Agent - Latest"
        "Agent - Dev"
        "Agent - Build local"
        "Back"
    )
    local selected=0

    while true; do
        draw_menu $selected "${options[@]}"

        key=$(get_key)
        case $key in
            UP)
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                ;;
            DOWN)
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
                ;;
            q|Q)
                exit 0
                ;;
            '')  # Enter key
                case $selected in
                    0)  # Console - Latest
                        COMPONENT="console"
                        IMAGE="ghcr.io/chriopter/lumenmon-console:latest"
                        break
                        ;;
                    1)  # Console - Dev
                        COMPONENT="console"
                        IMAGE="ghcr.io/chriopter/lumenmon-console:main"
                        break
                        ;;
                    2)  # Console - Build local
                        COMPONENT="console"
                        IMAGE=""
                        break
                        ;;
                    3)  # Agent - Latest
                        COMPONENT="agent"
                        IMAGE="ghcr.io/chriopter/lumenmon-agent:latest"
                        break
                        ;;
                    4)  # Agent - Dev
                        COMPONENT="agent"
                        IMAGE="ghcr.io/chriopter/lumenmon-agent:main"
                        break
                        ;;
                    5)  # Agent - Build local
                        COMPONENT="agent"
                        IMAGE=""
                        break
                        ;;
                    6)  # Back
                        show_menu
                        break
                        ;;
                esac
                ;;
        esac
    done
}

# Export variables for deploy script
export COMPONENT IMAGE