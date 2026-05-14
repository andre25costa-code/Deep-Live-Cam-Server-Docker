# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a fork of [Deep-Live-Cam](https://github.com/hacksider/Deep-Live-Cam) reorganized as a **client/server architecture** for real-time face-swap deepfakes. The heavy GPU inference (InsightFace `inswapper_128_fp16` + optional GFPGAN) runs on a server; thin clients only capture webcam frames and display results.

```
Client (webcam capture) <-- WebSocket (base64 JPEG) --> Server (GPU inference)
```

The original Deep-Live-Cam CLI/UI code lives in [modules/](modules/) and is still importable via [run.py](run.py), but the primary entry points in this fork are the WebSocket server/client.

## Commands

### Run the server (GPU host)
```bash
# Native
python server_ws.py            # listens on 0.0.0.0:8765

# Docker (recommended — handles CUDA 11.8 + cuDNN setup)
docker compose up --build
```

The server requires `models/inswapper_128_fp16.onnx` and `models/GFPGANv1.4.pth` (download from the Hugging Face links in [README.md](README.md)). The compose file mounts `./models` and `./photos` into the container, so populate those on the host before `docker compose up`.

### Run the client (webcam host)
```bash
python client_ws.py            # connects to 127.0.0.1:8765 by default
```

The capture device index is hard-coded as `cv2.VideoCapture(4)` in [client_ws.py:93](client_ws.py:93) — change it to match the local machine. Use `python listar_cameras.py` (Windows/DirectShow only) to list available camera indices.

### Bootstrap a Windows host
`preparar-host.ps1` (run as Administrator) installs Git, Docker Desktop, WSL2, and checks for an NVIDIA driver via `nvidia-smi`.

### Legacy original CLI
`python run.py [args]` invokes `modules.core.run()` — the upstream Deep-Live-Cam CLI (image/video processing, GUI). Kept for compatibility; the WebSocket server is the active entry point.

There is no test suite, lint config, or CI in this repo.

## Architecture

### WebSocket protocol
Messages are line-oriented strings prefixed with a tag:
- `FRAME:<base64-jpeg>` — bidirectional (client → server raw frame, server → client processed frame)
- `ERRO: ...` — server error

The server broadcasts every processed frame to **all connected clients** (see [server_ws.py:124](server_ws.py:124)) — this is intentional for multi-viewer streaming, not a bug.

### Server pipeline ([server_ws.py](server_ws.py))
The `FaceSwapServer` runs three concurrent stages backed by `queue.Queue`:
1. **Receive** (asyncio handler): decodes incoming `FRAME:` messages → `raw_frames`
2. **Process** (N worker threads, default 10): pulls from `raw_frames`, calls `face_swapper.process_frame(source_face, frame)`, pushes to `processed_frames`
3. **Encode** (1 thread): JPEG-encodes + base64 → `frames_para_enviar`
4. **Broadcast** (asyncio coroutine): drains `frames_para_enviar`, sends to every client in `clientes_ativos`

Because workers process frames in parallel and the queue is FIFO, **frames can be delivered out of order** under load. The source face is loaded once at startup from a hard-coded path (default `photos/cr7.jpg`) — to swap faces, change `FaceSwapServer(source_image_path=...)` in `main()`.

A warm-up `face_swapper.process_frame` call runs at module import (lines 41–50) to force ONNX model load before accepting connections.

### Execution provider selection
`configurar_providers()` in [server_ws.py:20](server_ws.py:20) picks TensorRT > CUDA > CPU based on what's available in `onnxruntime.get_available_providers()` and writes the result into `modules.globals.execution_providers`. The Docker image installs `onnxruntime-gpu==1.16.3` against CUDA 11.8 / cuDNN 8 — these versions are tightly coupled, do not bump them in isolation.

### `modules/` (upstream Deep-Live-Cam core)
Everything under [modules/](modules/) is the original Deep-Live-Cam codebase, mostly untouched:
- [modules/globals.py](modules/globals.py) — **mutable global config** (quality flags, mask params, execution providers). The server mutates these directly in `configurar_qualidade()`; treat it as the configuration channel between `server_ws.py` and the processors.
- [modules/processors/frame/face_swapper.py](modules/processors/frame/face_swapper.py) — the InsightFace swap pipeline. Lazily loads `models/inswapper_128_fp16.onnx`; `models_dir` is resolved relative to this file (three `dirname` levels up from `modules/processors/frame/`).
- [modules/processors/frame/face_enhancer.py](modules/processors/frame/face_enhancer.py) — GFPGAN enhancement (currently commented out in the server hot path for performance).
- [modules/face_analyser.py](modules/face_analyser.py) — InsightFace detection wrappers (`get_one_face`, `get_many_faces`).
- [modules/core.py](modules/core.py) — original CLI entry point (parses argv, runs image/video pipelines). Not used by the WebSocket server.

### Docker layering
[DockerFile](DockerFile) deliberately splits the heavy `pip install`s (torch, tensorflow, onnxruntime-gpu) into separate `RUN` layers **before** copying `requirements.txt` — this is a workaround for I/O errors when installing all the gigabyte-scale wheels in a single layer on WSL2. Preserve this ordering when modifying.

## Gotchas

- All comments, log messages, and identifiers in `server_ws.py` / `client_ws.py` are in **Portuguese (pt-BR)**. Match this style when editing those files.
- `models/` is gitignored; the server will silently fall back / fail at first inference call if the ONNX model is missing.
- `switch_states.json` is UI state from the upstream project, not used by the WebSocket server.
- The client's `fps_desejado = 10` and `JPEG_QUALITY = 80` (in [client_ws.py](client_ws.py)) are the main knobs for trading bandwidth vs. responsiveness.
