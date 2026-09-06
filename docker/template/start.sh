#!/bin/bash
# ── eduadapt-pod-template start.sh (selbsttragend) ──────────────────────────
# Dieses Skript IST /start.sh im Image (Base-/start.sh wird bewusst ersetzt)
# und startet: sshd (PUBLIC_KEY aus Env) + Ollama-Server. Kein Eduadapt-Code.
set -e

# 1) SSH einrichten (PUBLIC_KEY kommt aus der RunPod-Template-Env)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -n "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "[start.sh] PUBLIC_KEY hinterlegt (~/.ssh/authorized_keys)"
fi

# 2) Host-Keys erzeugen + sshd starten
ssh-keygen -A >/dev/null 2>&1 || true
if ! pgrep -x sshd >/dev/null 2>&1; then
  (service ssh start || /usr/sbin/sshd) >/dev/null 2>&1 \
    && echo "[start.sh] sshd gestartet" \
    || echo "[start.sh] WARNUNG: sshd-Start fehlgeschlagen"
fi

# 3) Ollama-Server im Hintergrund starten
if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/var/log/ollama.log 2>&1 &
  disown || true
  echo "[start.sh] ollama serve gestartet (PID $!)"
else
  echo "[start.sh] ollama laeuft bereits"
fi

# 4) Container am Leben halten
sleep infinity
