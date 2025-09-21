#!/bin/bash
# Simple menu

show_menu() {
    clear
    echo "
  ██╗     ██╗   ██╗███╗   ███╗███████╗███╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗
  ██║     ██║   ██║████╗ ████║██╔════╝████╗  ██║████╗ ████║██╔═══██╗████╗  ██║
  ██║     ██║   ██║██╔████╔██║█████╗  ██╔██╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
  ██║     ██║   ██║██║╚██╔╝██║██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
  ███████╗╚██████╔╝██║ ╚═╝ ██║███████╗██║ ╚████║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝

  1) Install Console
  2) Advanced
  3) Exit
"
    read -p "> " choice < /dev/tty 2>/dev/null || read -p "> " choice

    case $choice in
        1) COMPONENT="console" ;;
        2) show_advanced ;;
        3) exit 0 ;;
        *) echo "Invalid"; exit 1 ;;
    esac

    export COMPONENT
}

show_advanced() {
    clear
    echo "
Advanced Options:

  1) Agent - Latest
  2) Agent - Dev
  3) Agent - Build from source

  4) Console - Latest
  5) Console - Dev
  6) Console - Build from source

  7) Back
"
    read -p "> " choice

    case $choice in
        1) COMPONENT="agent"; IMAGE="ghcr.io/chriopter/lumenmon-agent:latest" ;;
        2) COMPONENT="agent"; IMAGE="ghcr.io/chriopter/lumenmon-agent:main" ;;
        3) COMPONENT="agent"; IMAGE="" ;;
        4) COMPONENT="console"; IMAGE="ghcr.io/chriopter/lumenmon-console:latest" ;;
        5) COMPONENT="console"; IMAGE="ghcr.io/chriopter/lumenmon-console:main" ;;
        6) COMPONENT="console"; IMAGE="" ;;
        7) show_menu; return ;;
        *) echo "Invalid"; exit 1 ;;
    esac

    export COMPONENT IMAGE
}