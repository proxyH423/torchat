#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT=4444
DEFAULT_KEY="password"
MODE="client"

ENV_FILE="onion.env"

# Function to print error and exit
function error_exit() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Parse arguments
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

# Prompt for username
echo -en "${CYAN}Enter username: ${NC}"
read USERNAME

# Load .env file
if [[ ! -f "$ENV_FILE" ]]; then
    error_exit "Missing .env file."
fi

ONION=$(grep "^${USERNAME}=" "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$ONION" ]]; then
    error_exit "Username '$USERNAME' not found in $ENV_FILE."
fi

# Use default values if not set
PORT="${PORT:-$DEFAULT_PORT}"
KEY="${KEY:-$DEFAULT_KEY}"

# Display configuration
echo -e "${YELLOW}Selected Configuration:${NC}"
echo -e "${GREEN}Username: ${NC}$USERNAME"
echo -e "${GREEN}Onion ID: ${NC}$ONION"
echo -e "${GREEN}Port:     ${NC}$PORT"
echo -e "${GREEN}Key:      ${NC}$KEY"
echo ""

# Execute the appropriate command
if [[ "$MODE" == "server" ]]; then
    echo -e "${CYAN}Starting listener mode...${NC}"
    echo -e "${YELLOW}Command:${NC} cryptcat -l -p $PORT -k $KEY"
    cryptcat -l -p "$PORT" -k "$KEY"
else
    echo -e "${CYAN}Starting client mode via torsocks...${NC}"
    echo -e "${YELLOW}Command:${NC} torsocks cryptcat $ONION $PORT -k $KEY"
    torsocks cryptcat "$ONION" "$PORT" -k "$KEY"
fi
