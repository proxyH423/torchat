#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Defaults
DEFAULT_PORT=4444
DEFAULT_KEY="12345"
MODE="client"
ENV_FILE="onion.env"

# Functions
function error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

function show_help() {
    echo -e "${BOLD}Usage:${NC} torcon [OPTIONS]"
    echo -e ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${CYAN}-l, --listen${NC}           Run in listen mode (server)"
    echo -e "  ${CYAN}-p, --port <PORT>${NC}     Set custom port (default: ${YELLOW}$DEFAULT_PORT${NC})"
    echo -e "  ${CYAN}-k, --key <KEY>${NC}       Set custom encryption key (default: ${YELLOW}$DEFAULT_KEY${NC})"
    echo -e "  ${CYAN}-h, --help${NC}            Show this help message and exit"
    echo -e ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  torcon                          # Run in client mode (default)"
    echo -e "  torcon -p 9000 -k mypass        # Client with custom port/key"
    echo -e "  torcon -l                       # Listener with default settings"
    echo -e "  torcon -l -p 8888 -k secretkey  # Listener with custom settings"
    echo -e ""
    echo -e "${BOLD}Note:${NC} Usernames and .onion addresses must be defined in '${ENV_FILE}' as:"
    echo -e "  username1=exampleonionaddress.onion"
    exit 0
}

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

# Set defaults if not passed
PORT="${PORT:-$DEFAULT_PORT}"
KEY="${KEY:-$DEFAULT_KEY}"

# SERVER MODE
if [[ "$MODE" == "server" ]]; then
    echo -e "${GREEN}[LISTEN MODE]${NC} Waiting for connection on port ${YELLOW}$PORT${NC} with key ${CYAN}$KEY${NC}..."
    cryptcat -l -p "$PORT" -k "$KEY"
    exit 0
fi

# CLIENT MODE
# Prompt for username
echo -en "${CYAN}Enter username: ${NC}"
read USERNAME

# Check if .env exists
[[ ! -f "$ENV_FILE" ]] && error_exit "Missing $ENV_FILE file."

# Fetch onion address
ONION=$(grep "^${USERNAME}=" "$ENV_FILE" | cut -d '=' -f2)

[[ -z "$ONION" ]] && error_exit "Username '$USERNAME' not found in $ENV_FILE."

# Start connection with cryptcat (client)
echo -e "${CYAN}Connecting...${NC}"
torsocks cryptcat "$ONION" "$PORT" -k "$KEY" && echo -e "${GREEN}Connected.${NC}\n${BOLD}Th334GL35@torchat# ${NC}"
  