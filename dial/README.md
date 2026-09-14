# Minimal local DIAL (Core + Redis + dial-to-dial adapter + Chat 1.x + Themes)

- [Minimal local DIAL (Core + Redis + dial-to-dial adapter + Chat 1.x + Themes)](#minimal-local-dial-core--redis--dial-to-dial-adapter--chat-1x--themes)
  - [What this stack provides](#what-this-stack-provides)
  - [Prerequisites](#prerequisites)
  - [Install](#install)
  - [How models work](#how-models-work)
  - [Register a StatGPT application](#register-a-statgpt-application)
  - [Uninstall](#uninstall)
  - [Configuration reference](#configuration-reference)

## What this stack provides

| Component | Host port | Role |
|---|---|---|
| `core` | http://localhost:8080 | DIAL Core + filesystem storage |
| `redis` | (internal) | Core cache |
| `adapter-dial` | (internal) | Proxies model calls to a **remote** DIAL |
| `themes` | (internal) | Chat themes static config |
| `chat` | http://localhost:5000 | New generation DIAL Chat (NestJS BFF + React SPA) |

Versions align with [DIAL Helm Chart 7.2.0](https://github.com/epam/ai-dial-helm/releases/tag/dial-7.2.0) for Core (`0.47.0`), adapter-dial (`0.18.0`), and themes (`0.19.1`). Chat uses the **new generation** image (`1.0.x`), not the legacy `0.49.x` still listed in that Helm chart.

Both this stack and the parent StatGPT Compose attach to the external Docker network `statgpt`, so StatGPT containers reach Core as `http://core:8080`.

This example is for local/dev use and **should not be used in production** as-is.

## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/install) with [Compose V2](https://docs.docker.com/compose)
- A **remote** DIAL Core URL and API key with access to the models StatGPT needs: `gpt-4.1-2025-04-14`, `gpt-5.4-2026-03-05`, `gpt-5.6-terra-2026-07-09`, and `text-embedding-3-large`. Deployment names on the remote must match the IDs in [`core/config.json.example`](core/config.json.example) (or edit the example before generating).
- (Optional) Keycloak client for DIAL Chat login — register redirect URI `{CHAT_AUTH_CALLBACK_BASE_URL}/api/v1/auth/callback/keycloak` and post-logout URI `CHAT_AUTH_POST_LOGOUT_REDIRECT_URI`

## Install

1. Create the shared network once (if it does not exist):

    ```sh
    docker network create statgpt
    ```

2. Copy env and set remote DIAL access:

    ```sh
    cp .env.example .env
    ```

    Set `REMOTE_DIAL_URL` (no trailing slash) and `REMOTE_DIAL_API_KEY`. For Chat, set `CHAT_AUTH_SESSION_SECRET` (`openssl rand -hex 32`). Uncomment Keycloak vars when you want Chat login.

3. Generate Core config (substitutes remote URL/key into the example):

    ```sh
    chmod +x generate-config.sh
    ./generate-config.sh
    ```

4. Start DIAL:

    ```sh
    docker compose up -d
    ```

5. Check Core and Chat are up:

    ```sh
    docker compose ps
    curl -sS http://localhost:8080/health
    curl -sS http://localhost:5000/api/health
    ```

6. Point StatGPT at this Core (parent folder `.env` defaults already match when using `dial/`):

    - DIAL URL for Compose services: `http://core:8080`
    - API key: `statgpt_api_key`
    - `PORTAL_FRONTEND_DEFAULT_MODEL` / `CHAT_DEFAULT_DEPLOYMENT` must equal an `applications` id in `core/config.json`

    Then start StatGPT from the parent directory - see [../README.md](../README.md).

## How models work

```text
StatGPT / Chat / clients  →  local Core (:8080)  →  adapter-dial  →  remote DIAL
```

Local `core/config.json` defines the chat models (`gpt-4.1-2025-04-14`, `gpt-5.4-2026-03-05`, `gpt-5.6-terra-2026-07-09`) and the embedding model (`text-embedding-3-large`). Each model `endpoint` is `http://adapter-dial:5000/...` and `upstreams` point at the remote DIAL deployment URLs and key. Adjust model IDs if your remote uses different deployment names.

The **local** API key string in `keys` (default `statgpt_api_key`) is what StatGPT and Chat put in `*_DIAL_API_KEY`. It is independent of the remote key used in `upstreams`.

The example also registers **StatGPT Generic RAG** (`applicationTypeSchemas` id `statgpt-generic-rag`, application `statgpt-generic-rag-grade-b-and-c`) pointing at `http://generic-rag:5000` on the shared network.

## Register a StatGPT application

1. Import a channel in StatGPT Admin and note its name (e.g. `statgpt-sample`).
2. Edit `core/config.json`: set `applications.<channel-name>` endpoints to
   `http://chat-backend:5000/openai/deployments/<channel-name>/...`
   (same shared network as StatGPT Compose). Keep or adjust per-application `routes` / `mcp` as needed.
3. Add that application id under `roles.statgpt.limits`.
4. Set `PORTAL_FRONTEND_DEFAULT_MODEL=<channel-name>` in the parent `.env` and `CHAT_DEFAULT_DEPLOYMENT` here if you use Chat.
5. Recreate Core so it reloads config:

    ```sh
    docker compose up -d --force-recreate core
    ```

See also [DIAL-to-DIAL adapter docs](https://docs.dialx.ai/tutorials/developers/apps-development/adapter-dial).

## Uninstall

```sh
# Stop and remove containers (keeps named volumes)
docker compose down

# Also remove Core storage / log volumes
docker compose down -v
```

Removing the shared network (only if nothing else uses it):

```sh
docker network rm statgpt
```

## Configuration reference

| File | Purpose |
|---|---|
| [`.env.example`](.env.example) | Image tags, remote DIAL URL/key, Chat auth (copy to `.env`) |
| [`docker-compose.yml`](docker-compose.yml) | `redis`, `core`, `adapter-dial`, `themes`, `chat`, shared network |
| [`core/config.json.example`](core/config.json.example) | Template for local Core config |
| [`generate-config.sh`](generate-config.sh) | Writes `core/config.json` from the example + `.env` |
| [`settings/`](settings/) | Core `settings.json` (incl. toolsets redirect allowlist) and logging |

Runtime (gitignored): `.env`, `core/config.json`.
