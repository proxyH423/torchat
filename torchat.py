#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
import re

# Colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"

# Config
DEFAULT_KEY = "12345"
ENV_FILE = "onion.env"
TORRC_PATH = "/etc/tor/torrc"

def read_tor_port():
    if not os.path.exists(TORRC_PATH):
        return None
    with open(TORRC_PATH, "r") as f:
        for line in f:
            if line.strip().startswith("HiddenServicePort"):
                match = re.search(r"\b(\d+)\b", line)
                if match:
                    return match.group(1)
    return None

# First get dynamic default port from torrc
DEFAULT_PORT = read_tor_port() or "4444"

def print_error(message):
    print(f"\n{RED}[ERROR]{NC} {message}")
    sys.exit(1)

def print_info(message):
    print(f"\n{CYAN}{message}{NC}")

def install_required_tools():
    tools = ["tor", "cryptcat", "torsocks"]
    for tool in tools:
        if subprocess.call(f"which {tool} > /dev/null", shell=True) != 0:
            print_info(f"Installing {tool}...")
            subprocess.call(f"sudo apt install -y {tool}", shell=True)

def show_torrc_manual():
    print(f"\n{BOLD}To set the port in torrc manually:{NC}")
    print(f"  1. Open {TORRC_PATH} in your editor (sudo may be needed).")
    print(f"  2. Find or add this line: {YELLOW}SocksPort 9050{NC}  # Example")
    print("  3. Restart tor using:")
    print(f"     {CYAN}sudo systemctl restart tor{NC}\n")

def show_help():
    print(f"""{BOLD}Usage:{NC} torchat.py [OPTIONS]

{BOLD}Options:{NC}
  {CYAN}-l, --listen{NC}           Run in listen mode (server)
  {CYAN}-p, --port <PORT>{NC}     Set custom port (default from torrc: {YELLOW}{DEFAULT_PORT}{NC})
  {CYAN}-k, --key <KEY>{NC}       Set custom encryption key (default: {YELLOW}{DEFAULT_KEY}{NC})
  {CYAN}-h, --help{NC}            Show this help message and exit

{BOLD}Examples:{NC}
  torchat.py                          # Run in client mode (default)
  torchat.py -p 9000 -k mypass        # Client with custom port/key
  torchat.py -l                       # Listener with default settings
  torchat.py -l -p 8888 -k secretkey  # Listener with custom settings

{BOLD}Note:{NC} Usernames and .onion addresses must be defined in '{ENV_FILE}' as:
  username1=exampleonionaddress.onion
""")
    sys.exit(0)

def parse_env(username):
    if not os.path.exists(ENV_FILE):
        print_error(f"Missing {ENV_FILE} file.")
    with open(ENV_FILE, 'r') as f:
        for line in f:
            if line.strip().startswith(username + "="):
                return line.strip().split("=", 1)[1]
    return None

def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-l", "--listen", action="store_true")
    parser.add_argument("-p", "--port")
    parser.add_argument("-k", "--key", default=DEFAULT_KEY)
    parser.add_argument("-h", "--help", action="store_true")
    args = parser.parse_args()

    if args.help:
        show_help()

    install_required_tools()

    if DEFAULT_PORT:
        print_info(f"Tor SOCKS Port (from torrc): {YELLOW}{DEFAULT_PORT}{NC}")
    else:
        show_torrc_manual()

    # If no --port was passed, use the one from torrc
    port = args.port if args.port else DEFAULT_PORT

    if args.listen:
        print(f"\n{GREEN}[LISTEN MODE]{NC} Waiting for connection on port {YELLOW}{port}{NC} with key {CYAN}{args.key}{NC}...\n")
        os.system(f"cryptcat -l -p {port} -k {args.key}")
        sys.exit(0)

    print(f"\n{CYAN}Enter username: {NC}", end="")
    username = input().strip()

    onion = parse_env(username)
    if not onion:
        print_error(f"Username '{username}' not found in {ENV_FILE}.")

    print_info(f"Connecting to {onion} on port {port} using key {args.key}...\n")
    os.system(f"torify cryptcat {onion} {port} -k {args.key}")

if __name__ == "__main__":
    main()
