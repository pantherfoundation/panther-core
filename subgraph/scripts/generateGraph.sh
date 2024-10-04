#!/bin/bash

ABI_FOLDER=""
CONTRACT_ADDRESS=""
START_BLOCK=""

# Function to display usage information
usage() {
    echo "Usage: $0 --abi-folder <ABI_FOLDER> --contract-address <CONTRACT_ADDRESS> --start-block <START_BLOCK>"
    echo
    echo "Options:"
    echo "  --abi-folder        Path to the folder containing ABI files"
    echo "  --contract-address  Contract address"
    echo "  --start-block       Start block number"
    exit 1
}

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --abi-folder) ABI_FOLDER="$2"; shift ;;
        --contract-address) CONTRACT_ADDRESS="$2"; shift ;;
        --start-block) START_BLOCK="$2"; shift ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Check if all required arguments are provided
if [ -z "$ABI_FOLDER" ] || [ -z "$CONTRACT_ADDRESS" ] || [ -z "$START_BLOCK" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Function to process a single ABI file
process_abi_file() {
    local abi_file="$1"
    local contract_name=$(basename "$abi_file" .json)

    echo "Processing $contract_name..."

    yarn graph add "$CONTRACT_ADDRESS" \
        --contract-name "$contract_name" \
        --abi "$abi_file" \
        --start-block "$START_BLOCK"

    echo "Finished processing $contract_name"
    echo "-----------------------------------"
}

# Process files in the specified folder
echo "Processing files in $ABI_FOLDER"
for abi_file in "$ABI_FOLDER"/*.json; do
    if [ -f "$abi_file" ]; then
        process_abi_file "$abi_file"
    fi
done

echo "All ABI files processed"
