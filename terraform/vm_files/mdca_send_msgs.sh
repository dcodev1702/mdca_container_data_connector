#!/bin/bash

# MDCA Syslog Message Sender
# Sends syslog messages from a file to MDCA data connector

#INPUT_FILE="test.log"
INPUT_FILE="cisco_asa_fp_c.ai2k.log"
#INPUT_FILE="cisco_asa_fp_c.ai.log"
#INPUT_FILE="cisco_asa_fp_fullLog.log"
TARGET_IP="10.0.1.4"
TARGET_PORT="514"
DELAY="0.2"

# Check if input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    exit 1
fi

# Check if netcat is available
if ! command -v nc &> /dev/null; then
    echo "Error: netcat (nc) is not installed"
    exit 1
fi

echo "Starting to send syslog messages to $TARGET_IP:$TARGET_PORT"
echo "Delay between messages: ${DELAY}s"
echo "Input file: $INPUT_FILE"
echo "---"

# Read file line by line and send each message
line_count=0
while IFS= read -r line; do
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi
    
    line_count=$((line_count + 1))
    echo "Sending message $line_count: $(echo "$line" | cut -c1-80)..."
    
    # Send the syslog message via TCP
    echo "$line" | timeout "$DELAY" nc -u "$TARGET_IP" "$TARGET_PORT"
    
    # Wait before sending next message
    sleep "$DELAY"
done < "$INPUT_FILE"

echo "---"
echo "Completed sending $line_count messages to MDCA"
