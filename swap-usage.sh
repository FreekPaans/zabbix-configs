#!/usr/bin/env bash

# Also create the following user-param: UserParameter=proc.swap[*], /etc/zabbix/zabbix_agentd.d/swap-usage.sh "$1"

FOR_USER="$1"

if [[ -z "$FOR_USER" ]]; then
        echo "Usage: $0 <proc-user>"
        exit 1
fi

ps h -o pid,c -U "$FOR_USER" | awk '{print $1}' | while read PROC_PID; do
cat "/proc/$PROC_PID/status" | grep VmSwap
done | awk '{sum+=$2} END {print sum*1024}'
