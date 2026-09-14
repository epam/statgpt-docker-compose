# StatGPT Docker Compose

- [StatGPT Docker Compose](#statgpt-docker-compose)
  - [Prerequisites](#prerequisites)
  - [Expected Outcome](#expected-outcome)
  - [Install](#install)
  - [Uninstall](#uninstall)
  - [Configuration reference](#configuration-reference)
  - [StatGPT Configuration](#statgpt-configuration)
  - [DIAL Configuration](#dial-configuration)
  - [What's next?](#whats-next)

## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/install) with [Compose V2](https://docs.docker.com/compose) (`docker compose version`)
- Shared Docker network (once): `docker network create statgpt`
- [AI DIAL](https://docs.dialx.ai) reachable from this stack - either:
  - the sibling [**dial/**](dial/) Compose (local Core + Redis + dial-to-dial adapter to a remote DIAL, plus Chat 1.x and Themes), or
  - any other DIAL deployment with an API key that can use `gpt-4.1-2025-04-14`, `gpt-5.4-2026-03-05`, `gpt-5.6-terra-2026-07-09`, and `text-embedding-3-large`
- [Keycloak](https://www.keycloak.org/) (or compatible OIDC IdP) with clients for StatGPT Admin and StatGPT Portal (and optionally DIAL Chat)
- Network connectivity from Compose containers to DIAL and Keycloak

When using [dial/](dial/), models are served from a **remote** DIAL via the dial-to-dial adapter; you still need that remote DIAL (and its model deployments). See [dial/README.md](dial/README.md).

## Expected Outcome

By following this guide you will start all StatGPT components with Docker Compose:

| Component | Host port |
|---|---|
| chat-backend | http://localhost:5100 |
| admin-backend | http://localhost:8000 |
| admin-frontend | http://localhost:4100 |
| pgvector | localhost:5432 |
| elasticsearch | http://localhost:9200 |
| portal-frontend | http://localhost:4200 |
| mcp-app-frontend | http://localhost:3002 |
| generic-rag | http://localhost:5001 |
| sdmx-proxy | http://localhost:8050 |
| sdmx-proxy-config-server | http://localhost:8060 |

Keycloak is **not** started by this Compose file. DIAL is either started via [dial/](dial/) or provided externally - set URLs and credentials in `.env`.

This example is a basic deployment scenario and **should not be used in production** as-is. Encrypted secrets management, TLS termination, resource limits, and hardened IdP configuration are out of scope.

## Install

0. Create the shared network (once) and, if you use the sibling stack, start local DIAL first:

    ```sh
    docker network create statgpt
    cd dial
    cp .env.example .env
    # set REMOTE_DIAL_URL, REMOTE_DIAL_API_KEY, and CHAT_AUTH_SESSION_SECRET, then:
    ./generate-config.sh
    docker compose up -d
    cd ..
    ```

    Details: [dial/README.md](dial/README.md). Skip this step only if you already have another DIAL and will override the DIAL URLs in `.env`.

1. Copy the environment template and fill in missing values:

    ```sh
    cp .env.example .env
    ```

    Edit `.env`. Sections are ordered by component. Defaults assume local Core on the shared network (`http://core:8080`) and API key `statgpt_api_key`. At minimum set:

    **chat-backend / admin-backend**
    - `CHAT_BACKEND_DIAL_URL`, `CHAT_BACKEND_DIAL_API_KEY`
    - `ADMIN_BACKEND_DIAL_URL`, `ADMIN_BACKEND_DIAL_API_KEY`
    - Matching DB credentials: set `PGVECTOR_PASSWORD` once (backends inherit it unless you uncomment per-component overrides)
    - Admin OIDC placeholders (`ADMIN_BACKEND_OIDC_*`, `ADMIN_BACKEND_ADMIN_*`)
    - MCP Apps (when using mcp-app-frontend): `*_MCP_APP_ORIGIN`, `*_MCP_APP_HTML_HOST`
    - Data related (for channels that use SDMX): `CHAT_BACKEND_SDMX_PROXY_HOST`, `ADMIN_BACKEND_SDMX_PROXY_HOST`, `ADMIN_BACKEND_SDMX_PROXY_CONFIG_SERVER_HOST`

    **admin-frontend**
    - `ADMIN_FRONTEND_DIAL_API_URL`, `ADMIN_FRONTEND_DIAL_API_KEY`
    - `ADMIN_FRONTEND_AUTH_URL` (default `http://localhost:4100`)
    - `ADMIN_FRONTEND_AUTH_SECRET` (`openssl rand -base64 64`)
    - Keycloak host, client ID, and secret

    **pgvector / elasticsearch**
    - `PGVECTOR_USER`, `PGVECTOR_PASSWORD`
    - `PGVECTOR_GENERIC_RAG_DATABASE` (DB created on first start for generic-rag; must match `GENERIC_RAG_DB_NAME`)
    - Elasticsearch security is disabled by default; uncomment `ELASTIC_AUTH_*` in `.env` if you enable it later

    **portal-frontend**
    - DIAL URL/key, `PORTAL_FRONTEND_AUTH_URL` (default `http://localhost:4200`)
    - `PORTAL_FRONTEND_AUTH_SECRET`, Keycloak settings
    - `PORTAL_FRONTEND_DIAL_API_VERSION`, `PORTAL_FRONTEND_DEFAULT_MODEL` (default `statgpt-sample`; must match a DIAL `applications` id / channel name)

    **sdmx-proxy-config-server**
    - `SDMX_PROXY_CONFIG_SERVER_DIAL_STORAGE_BASE_URL`, `SDMX_PROXY_CONFIG_SERVER_DIAL_STORAGE_API_KEY`
    - `SDMX_PROXY_CONFIG_SERVER_CONFIG_SERVER_SOURCE_CONFIG_PATH`

    **mcp-app-frontend**
    - `MCP_APP_FRONTEND_VITE_BASE_URL` (default `http://localhost:3002`; must match backend `*_MCP_APP_ORIGIN`)

    **generic-rag**
    - `GENERIC_RAG_DIAL_URL`, `GENERIC_RAG_DIAL_API_KEY`
    - `GENERIC_RAG_DB_NAME` (must match `PGVECTOR_GENERIC_RAG_DATABASE`; must not share schema with `PGVECTOR_DATABASE`)
    - Optional Elasticsearch URL/prefix (`GENERIC_RAG_ELASTICSEARCH_*`)

    > **Security note:** `.env` stores secrets in plain text. Do not commit it (see `.gitignore`).

2. Start the stack:

    ```sh
    docker compose up -d
    ```

3. Check status:

    ```sh
    docker compose ps
    docker compose logs -f
    ```

4. Access:
    - StatGPT Admin: http://localhost:4100
    - StatGPT Portal: http://localhost:4200
    - MCP App Frontend: http://localhost:3002
    - Local DIAL Chat (if using [dial/](dial/)): http://localhost:5000
    - Local DIAL Core (if using [dial/](dial/)): http://localhost:8080

## Uninstall

```sh
# Stop and remove StatGPT containers (keeps named volumes)
docker compose down

# Also remove database volumes
docker compose down -v
```

To stop local DIAL as well: `docker compose -f dial/docker-compose.yml down` (see [dial/README.md](dial/README.md)).

## Configuration reference

| File | Purpose |
|---|---|
| [`.env.example`](.env.example) | Image versions, per-component env and secrets (copy to `.env`) |
| [`docker-compose.yml`](docker-compose.yml) | Services, ports, healthchecks, volumes, and dependency order |
| [`dial/`](dial/) | Optional minimal local DIAL (Core, Redis, adapter-dial, Chat 1.x, Themes) |

Compose loads `.env` from this directory and substitutes `${VAR}` in `docker-compose.yml`. Prefixed names in `.env` (e.g. `CHAT_BACKEND_DIAL_API_KEY`) are mapped to the container env names each image expects (e.g. `DIAL_API_KEY`), so components can use different DIAL keys or Keycloak clients.

Defaults that reference Compose service names (`pgvector`, `elasticsearch`, `admin-backend`, `sdmx-proxy-config-server`, `core`) work for the bundled stack. Override them in `.env` if you use external PostgreSQL, Elasticsearch, or DIAL.

Image tags are controlled by version variables in `.env` (`BACKEND_VERSION`, `ADMIN_FRONTEND_VERSION`, `PORTAL_FRONTEND_VERSION`, `SDMX_PROXY_VERSION`, `MCP_APP_FRONTEND_VERSION`, `GENERIC_RAG_VERSION`, `PGVECTOR_IMAGE_TAG`, `ELASTICSEARCH_VERSION`). Aligned with [StatGPT Helm Chart 1.14.3](https://github.com/epam/statgpt-helm/releases/tag/statgpt-1.14.3).

`admin-backend-init` runs once with `ADMIN_MODE=INIT` (database migrations) before `admin-backend` starts.

All long-running services define Docker healthchecks: backends, generic-rag, and sdmx-proxy-config-server use `GET /health`, frontends use `/api/health` (mcp-app-frontend uses `/`), sdmx-proxy uses `/statgpt/sdmx-proxy/api/v0/health`. Backends and generic-rag start only after `pgvector` and `elasticsearch` are healthy (`depends_on`), so healthcheck `start_period` only covers application boot, not dependency wait.

`pgvector` uses `pgvector/pgvector:0.8.1-pg16` (PostgreSQL 16 with pgvector 0.8.1). On first startup it creates the `vector` extension and a separate database for generic-rag (`PGVECTOR_GENERIC_RAG_DATABASE`, default `statgpt_generic_rag`; must match `GENERIC_RAG_DB_NAME`). If the `pgvector` volume already exists from an older run, init scripts do not re-run — create that database manually or recreate the volume (`docker compose down -v`).

Both Compose projects use the external network `statgpt` (`docker network create statgpt`).

## StatGPT Configuration

1. Open StatGPT Admin at http://localhost:4100
1. Go to the Channels tab and import a channel archive
1. Wait until the channel appears, then register it in DIAL (below)

## DIAL Configuration

If you use [dial/](dial/), the full Core config lives in [`dial/core/config.json.example`](dial/core/config.json.example) (copied to `dial/core/config.json` by `generate-config.sh`). It includes:

- Local API key `statgpt_api_key` / role `statgpt` with limits for `gpt-4.1-2025-04-14`, `gpt-5.4-2026-03-05`, `gpt-5.6-terra-2026-07-09`, `text-embedding-3-large`, the sample StatGPT applications, and Generic RAG
- Model entries routed through `adapter-dial` to your remote DIAL
- SDMX routes to `sdmx-proxy` and `sdmx-proxy-config-server` on the shared network
- A sample application `statgpt-sample` pointing at `http://chat-backend:5000/...` (including MCP and deployment routes)
- StatGPT Generic RAG type schema (`statgpt-generic-rag`) + app `statgpt-generic-rag-grade-b-and-c` pointing at `http://generic-rag:5000/...`

`dial/settings/settings.json` includes `toolsets.security.allowedRedirectUris` for Chat 1.x toolset OAuth (`http://localhost:5000/auth/toolset-signin`). Update that URI if you change the Chat public origin.

Defaults use application id `statgpt-sample` (`PORTAL_FRONTEND_DEFAULT_MODEL` and `CHAT_DEFAULT_DEPLOYMENT`). To use another imported channel, set the same id in those variables and recreate Core:

```sh
docker compose -f dial/docker-compose.yml up -d --force-recreate core
```

Full steps: [dial/README.md](dial/README.md).

For an **external** DIAL (not `dial/`), merge the relevant sections from [`dial/core/config.json.example`](dial/core/config.json.example) into that Core config: grant the StatGPT API key a role with access to the three models and the application, register each channel as an application whose endpoint is reachable **from that DIAL**, and add the SDMX routes if Portal/Admin should reach the proxies through DIAL.

StatGPT is ready via Portal once the application id matches `PORTAL_FRONTEND_DEFAULT_MODEL` and Core can reach `chat-backend`.

## What's next?

- [Local DIAL Compose](dial/README.md)
- [StatGPT Helm Chart](https://github.com/epam/statgpt-helm)
- [StatGPT Documentation](https://github.com/epam/statgpt)
- [DIAL Helm Chart](https://github.com/epam/ai-dial-helm)
- [AI DIAL Documentation](https://docs.dialx.ai)
