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
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Set defaults if not passed
PORT="${PORT:-$DEFAULT_PORT}"
KEY="${KEY:-$DEFAULT_KEY}"

# SERVER MODE
if [[ "$MODE" == "server" ]]; then
    echo -e "${GREEN}[LISTEN MODE]${NC} Waiting for connection on port ${YELLOW}$PORT${NC} with key ${CYAN}$KEY${NC}..."
    #echo -e "${YELLOW}Command:${NC} cryptcat -l -p $PORT -k $KEY"
    cryptcat -l -p "$PORT" -k "$KEY"
    exit 0
fi

# CLIENT MODE
# Prompt for username
echo -en "${CYAN}Enter username: ${NC}"
read USERNAME

# Check if .env exists
[[ ! -f "$ENV_FILE" ]] && error_exit "Missing .env file."

# Fetch onion address
ONION=$(grep "^${USERNAME}=" "$ENV_FILE" | cut -d '=' -f2)

[[ -z "$ONION" ]] && error_exit "Username '$USERNAME' not found in $ENV_FILE."

# Print config
echo -e "${YELLOW}Connecting to Hidden Service...${NC}"
# echo -e "${GREEN}Username: ${NC}$USERNAME"
# echo -e "${GREEN}Onion ID: ${NC}$ONION"
# echo -e "${GREEN}Port:     ${NC}$PORT"
# echo -e "${GREEN}Key:      ${NC}$KEY"
# echo ""

# Start connection with cryptcat (client)
echo -e "${CYAN}Connecting...${NC}"
torsocks cryptcat "$ONION" "$PORT" -k "$KEY" && echo -e "${GREEN}Connected.${NC}\n${BOLD}${USERNAME}@connection# ${NC}"
   
