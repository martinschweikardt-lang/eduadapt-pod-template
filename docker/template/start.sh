#!/bin/bash
# ── eduadapt-pod-template v2 start.sh (Image-CMD) ───────────────────────────
# Startet sshd + Ollama, dann boot.sh (Code-Pull + Stack). Kein Eduadapt-Code.
set -e

# 1) SSH einrichten (PUBLIC_KEY aus RunPod-Template-Env)
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if [ -n "$PUBLIC_KEY" ]; then
  echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  echo "[start.sh] PUBLIC_KEY hinterlegt"
fi
ssh-keygen -A >/dev/null 2>&1 || true
if ! pgrep -x sshd >/dev/null 2>&1; then
  (service ssh start || /usr/sbin/sshd) >/dev/null 2>&1 \
    && echo "[start.sh] sshd gestartet" \
    || echo "[start.sh] WARNUNG: sshd-Start fehlgeschlagen"
fi

# 2) Ollama-Server (Modelle aus /opt/ollama/models im Image)
if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/var/log/ollama.log 2>&1 &
  disown || true
  echo "[start.sh] ollama serve gestartet (PID $!)"
fi

# 3) Stack-Boot (Code-Pull, DB, Backend, Frontend-async) — blockiert nicht
echo "[start.sh] Starte boot.sh im Hintergrund ..."
setsid bash /boot.sh >/var/log/boot.log 2>&1 < /dev/null &
disown || true

sleep infinity
