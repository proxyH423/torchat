#!/bin/bash

# === Color Settings ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ENV_FILE="onion.env"
TORRC_PATH="/etc/tor/torrc"
DEFAULT_KEY="12345"
DEFAULT_PORT="4444"
MODE="client"

# === Banner UI ===
function banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║           T O R C H A T              ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# === Error Exit ===
function error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# === Help Menu ===
function show_help() {
    echo -e "${BOLD}Usage:${NC} torchat [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${CYAN}-l, --listen${NC}           Run in listen mode (server)"
    echo -e "  ${CYAN}-p, --port <PORT>${NC}     Set custom port"
    echo -e "  ${CYAN}-k, --key <KEY>${NC}       Set custom encryption key"
    echo -e "  ${CYAN}-h, --help${NC}            Show this help message and exit"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  torchat                          # Client with auto-detected port"
    echo -e "  torchat -p 9000 -k mypass        # Client with custom port/key"
    echo -e "  torchat -l                       # Listener mode"
    echo -e "  torchat -l -p 8888 -k secretkey  # Listener with custom settings"
    echo ""
    echo -e "${BOLD}Note:${NC} Define usernames in '${ENV_FILE}' as:"
    echo -e "  username=exampleonionaddress.onion"
    exit 0
}

# === Dependency Check ===
function check_dependencies() {
    REQUIRED=("tor" "cryptcat" "torsocks")
    for pkg in "${REQUIRED[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${YELLOW}[INFO]${NC} Installing missing package: $pkg"
            sudo apt update && sudo apt install -y "$pkg" || error_exit "Failed to install $pkg"
        fi
    done
}

# === Extract Tor Port ===
function get_hidden_service_port() {
    if [[ -f "$TORRC_PATH" ]]; then
        PORT_FROM_TORRC=$(grep -E "^HiddenServicePort\s+[0-9]+" "$TORRC_PATH" | awk '{print $2}' | head -n1)
        [[ -n "$PORT_FROM_TORRC" ]] && echo "$PORT_FROM_TORRC" && return
    fi
    echo "$DEFAULT_PORT"
}

# === Message Formatters ===
function format_chat() {
    local NAME="$1"
    local COLOR="$2"
    echo -en "${COLOR}${NAME}${NC}> "
}

# === Start Here ===
check_dependencies
PORT=$(get_hidden_service_port)

# === Parse CLI Arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port) PORT="$2"; shift 2 ;;
        -k|--key) KEY="$2"; shift 2 ;;
        -l|--listen|--server) MODE="server"; shift ;;
        -h|--help) show_help ;;
        *) error_exit "Unknown option: $1. Use --help to see available options." ;;
    esac
done

KEY="${KEY:-$DEFAULT_KEY}"
banner

# === Server Mode ===
if [[ "$MODE" == "server" ]]; then
    echo -en "${GREEN}Enter your server name: ${NC}"
    read SERVER_NAME
    echo -e "${GREEN}[LISTENING]${NC} on port ${YELLOW}${PORT}${NC} with key ${CYAN}${KEY}${NC}..."
    
    # Accept the first line as client name
    cryptcat -l -p "$PORT" -k "$KEY" | while read -r line; do
        if [[ -z "$CLIENT_NAME" ]]; then
            CLIENT_NAME="$line"
            echo -e "${CYAN}[CONNECTED]${NC} Client name is: ${YELLOW}${CLIENT_NAME}${NC}"
        else
            format_chat "$CLIENT_NAME" "$YELLOW"
            echo "$line"
        fi
        format_chat "$SERVER_NAME" "$GREEN"
        read reply
        echo "$reply"
    done
    exit 0
fi

# === Client Mode ===
echo -en "${CYAN}Enter your client name: ${NC}"
read CLIENT_NAME

echo -en "${CYAN}Enter server username: ${NC}"
read SERVER_USERNAME

[[ ! -f "$ENV_FILE" ]] && error_exit "Missing $ENV_FILE"
ONION=$(grep "^${SERVER_USERNAME}=" "$ENV_FILE" | cut -d '=' -f2)
[[ -z "$ONION" ]] && error_exit "Username '$SERVER_USERNAME' not found in $ENV_FILE."

echo -e "${CYAN}[CONNECTING]${NC} to ${YELLOW}${ONION}:${PORT}${NC} with key ${CYAN}${KEY}${NC}..."

# Use a pipe to send name first, then continue chatting
{
    echo "$CLIENT_NAME"
    while true; do
        format_chat "$CLIENT_NAME" "$YELLOW"
        read msg
        echo "$msg"
    done
} | torsocks cryptcat "$ONION" "$PORT" -k "$KEY" | while read -r reply; do
    format_chat "$SERVER_USERNAME" "$GREEN"
    echo "$reply"
done
