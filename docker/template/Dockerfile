# ── eduadapt-pod-template: Ollama + qwen3.8:27b ─────────────────────────────
# Generisches RunPod-Pod-Template. KEIN Eduadapt-Code.
# Base-Tag im Docker Hub unter "runpod/base" vor dem Bau verifizieren.
ARG BASE_IMAGE=runpod/base:0.4.0-cuda12.4.0-cudnn9-ubuntu22.04
FROM ${BASE_IMAGE}

ARG OLLAMA_VERSION=0.33.2
ARG MODEL=qwen3.8:27b

ENV OLLAMA_MODELS=/opt/ollama/models \
    OLLAMA_HOST=0.0.0.0:11434

# Layer: Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# Layer: Ollama-Binary (deterministisch aus GitHub-Release)
RUN curl -fsSL -o /tmp/ollama.tgz \
        "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tgz" \
    && tar -C /usr/local -xzf /tmp/ollama.tgz \
    && rm /tmp/ollama.tgz \
    && ollama --version

# Layer: Modell einbacken (ollama pull braucht laufenden Server im Build)
RUN (ollama serve >/tmp/ollama_build.log 2>&1 &) \
    && sleep 4 \
    && ollama pull ${MODEL} \
    && ollama list

# Layer: Start-Skript
COPY start.sh /start.sh
RUN chmod +x /start.sh
ENV PUBLIC_KEY=""
CMD ["/start.sh"]
