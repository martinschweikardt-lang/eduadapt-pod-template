#!/bin/bash
# Start-Skript: Ollama hochziehen, dann Base-Image-Start weiterreichen.
set -e
nohup ollama serve >/var/log/ollama.log 2>&1 &
sleep 2
tail -f /var/log/ollama.log &
# Base-Image-Start (sshd/Jupyter etc.) weiterreichen, falls vorhanden:
if [ -f /scripts/start.sh ]; then
  exec /scripts/start.sh
else
  sleep infinity
fi
