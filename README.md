# eduadapt-pod-template

RunPod-**Pod-Template** (Container-Image) mit **Ollama + qwen3.8:27b (Q4)** eingebacken.
Pods starten damit **ohne Netzwerk-Volume** auf beliebigen GPUs (auch Community).

> **Kein Eduadapt-Code enthalten** — nur generische Infrastruktur (Base-Image, Ollama,
> Modell, Start-Skript). Deshalb public. Modell-Gewichte: qwen3.8 (Apache-2.0).
> Q4-Quantisierung läuft auf 24-GB-VRAM-Pods (verifiziert).

## Struktur

```
docker/template/Dockerfile    Image-Bau (Modell als eigener Layer)
docker/template/start.sh      Start-Skript (ollama serve + Base-Start)
.github/workflows/template-build.yml   GitHub Actions → GHCR (GITHUB_TOKEN, kein PAT)
```

## Build

Push auf `main` (nur bei Änderungen unter `docker/template/**`) oder Tag `template-*`
baut automatisch → `ghcr.io/martinschweikardt-lang/eduadapt-pod:latest` (public).

Manuell: *Actions → template-build → Run workflow*.

## Template in RunPod anlegen

1. **Templates → New Template**
2. Container-Image: `ghcr.io/martinschweikardt-lang/eduadapt-pod:latest` (public → keine Creds)
3. **Container Disk: 100 GB** (Image ~35–45 GB — 30 GB Default reicht NICHT)
4. Ports: `22/TCP` (SSH)
5. Env: `PUBLIC_KEY=<dein SSH-Public-Key>` (Base-Image richtet SSH ein)
6. Pod starten → Template wählen → **kein Volume anhängen**

## Test (erster Pod, ohne Volume)

```bash
nvidia-smi                                  # GPU sichtbar
ollama list                                 # qwen3.8:27b muss gelistet sein
ollama run qwen3.8:27b "1+1"                # Funktionstest (VRAM ~16–17 GB)
```

## Modellwechsel / Updates

`ARG MODEL` im Dockerfile ändern → Tag `template-<datum>` pushen → Actions baut
(Layer-Cache hält den Rest) → beim Pod-Start das neue Tag wählen.
