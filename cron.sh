#!/bin/bash

SCRIPT_PATH="$(pwd)/monitor.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Eroare: Nu am gasit monitor.sh in $(pwd)!"
    exit 1
fi

chmod +x "$SCRIPT_PATH"
CRON_JOB="0 0 * * * $SCRIPT_PATH 1"

(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Gata!"