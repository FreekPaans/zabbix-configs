#!/usr/bin/env bash

# Telegram bot alerter for Zabbix

# Script parameters in Zabbix UI.
# 1: {ALERT.SENDTO}
# 2: {ALERT.MESSAGE}
# 3: {ALERT.SUBJECT}

BOT_TOKEN="<insert telegram token>"
TO="$1"
MESSAGE="$2"
SUBJECT="$3"
TELEGRAM_MESSAGE=$(printf "%s\n\n%s" "$SUBJECT" "$MESSAGE")

JSON=$(echo {} | jq  --arg text "$TELEGRAM_MESSAGE" --arg to "$TO" '.text=$text | .chat_id=$to')

RESPONSE=$(curl -s --fail -H "Content-type: application/json" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d @<(echo "$JSON"))

if [[ "$?" -ne 0 ]]; then
        echo "Curl error: $RESPONSE"
        exit 1
fi

if [[ "$(echo "$RESPONSE" | jq .ok)" != "true" ]]; then
        printf "Response was not ok:\n%s" "$(echo "$RESPONSE" | jq .)"
        exit 1
fi
