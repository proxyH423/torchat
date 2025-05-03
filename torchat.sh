#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Files
ENV_FILE="onion.env"
TORRC_PATH="/etc/tor/torrc"

# Default Fallbacks
DEFAULT_KEY="12345"
DEFAULT_PORT="4444"
MODE="client"

# Function to print errors and exit
function error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Help message
function show_help() {
    echo -e "${BOLD}Usage:${NC} torchat [OPTIONS]"
    echo -e ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${CYAN}-l, --listen${NC}           Run in listen mode (server)"
    echo -e "  ${CYAN}-p, --port <PORT>${NC}     Set custom port"
    echo -e "  ${CYAN}-k, --key <KEY>${NC}       Set custom encryption key"
    echo -e "  ${CYAN}-h, --help${NC}            Show this help message and exit"
    echo -e ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  torchat                          # Client with auto-detected port"
    echo -e "  torchat -p 9000 -k mypass        # Client with custom port/key"
    echo -e "  torchat -l                       # Listener mode"
    echo -e "  torchat -l -p 8888 -k secretkey  # Listener with custom settings"
    echo -e ""
    echo -e "${BOLD}Note:${NC} Username-to-Onion mappings must exist in '${ENV_FILE}':"
    echo -e "  username1=exampleonionaddress.onion"
    exit 0
}

# Check and install missing dependencies
function check_dependencies() {
    REQUIRED=("tor" "cryptcat" "torsocks")
    for pkg in "${REQUIRED[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${YELLOW}[INFO]${NC} Installing missing package: $pkg"
            sudo apt update && sudo apt install -y "$pkg" || error_exit "Failed to install $pkg"
        fi
    done
}

# Get default port from torrc or fallback
function get_hidden_service_port() {
    if [[ -f "$TORRC_PATH" ]]; then
        PORT_FROM_TORRC=$(grep -E "^HiddenServicePort\s+[0-9]+" "$TORRC_PATH" | awk '{print $2}' | head -n1)
        if [[ -n "$PORT_FROM_TORRC" ]]; then
            echo "$PORT_FROM_TORRC"
            return
        fi
    fi
    echo "$DEFAULT_PORT"
}

# Run dependency check first
check_dependencies

# Default port: read from torrc
TOR_PORT=$(get_hidden_service_port)

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -k|--key)
            KEY="$2"
            shift 2
            ;;
        -l|--listen|--server)
            MODE="server"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            error_exit "Unknown option: $1. Use --help to see available options."
            ;;
    esac
done

# Final defaults
PORT="${PORT:-$TOR_PORT}"
KEY="${KEY:-$DEFAULT_KEY}"

# SERVER MODE
if [[ "$MODE" == "server" ]]; then
    echo -e "${GREEN}[LISTEN MODE]${NC} Waiting on port ${YELLOW}$PORT${NC} with key ${CYAN}$KEY${NC}..."
    cryptcat -l -p "$PORT" -k "$KEY"
    exit 0
fi

# CLIENT MODE
echo -en "${CYAN}Enter username: ${NC}"
read USERNAME

[[ ! -f "$ENV_FILE" ]] && error_exit "Missing $ENV_FILE file."

ONION=$(grep "^${USERNAME}=" "$ENV_FILE" | cut -d '=' -f2)

[[ -z "$ONION" ]] && error_exit "Username '$USERNAME' not found in $ENV_FILE."

echo -e "${CYAN}Connecting to ${ONION}:${PORT}...${NC}"
torsocks cryptcat "$ONION" "$PORT" -k "$KEY" && echo -e "${GREEN}Connected.${NC}\n${BOLD}${USERNAME}@torchat# ${NC}"
