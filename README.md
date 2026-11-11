# Pi-Mono Agent Dockerized

Run [Pi](https://pi.dev/) in an isolated Docker container with zero host dependencies.

> **Note:** This is a Bash script and runs on **Linux only**. macOS and Windows are not supported.

## What's Inside

The Docker image comes with everything you need:

- **Node.js 22 LTS** (Debian Bookworm slim)
- **Pi 1.x** (`@earendil-works/pi-coding-agent`, installed into a persistent volume)
- **Rust** via rustup — `cargo`, `rustfmt`, `clippy` plus native build dependencies
- **Go**, **Python 3** (pip, venv, [uv](https://astral.sh/uv)), **PHP 8** + Composer
- **MariaDB/MySQL client** (`mysql`)
- **Build tools**: gcc/g++, make, cmake, clang/lld, pkg-config, libssl-dev, zlib1g-dev
- **pandoc**, **ffmpeg**, **ImageMagick**
- **ripgrep**, **gawk**, **jq**, **git**, **curl**, **wget**, **openssh**
- **pnpm**

Default Pi setup:

- **`pi-web-access`** — web search/fetch, PDF extraction, GitHub and YouTube content; configured for the local SearXNG at `http://192.168.178.2:4000`
- **`pi-webapp`** — browser workspace for chat, files, a real terminal, and Git review (`/web`)
- **Built-in MCP support** — add servers with `pi mcp add` or `~/.pi/agent/mcp.json`
- **Automatic compaction** — explicitly enabled and on by default
- **Global `llm-wiki` skill** — build a persistent Markdown wiki from raw sources on demand
- **Privacy defaults** — no install telemetry, no analytics, no Sentry, update checks enabled, project trust off
- **Git by default** — `.git`, `.gitignore`, and `.gitmodules` are visible; local commits use your host Git identity
- **Fixed Pi home** — starts in `~/pi-home`; the current directory is mounted only with `pi -m`

> The first run builds the image, installs Pi, and downloads the default Pi packages — expect this to take a few minutes.

## Setup

### Configuration

Pi 1.x uses the agent directory `~/.pi/agent` (not the old `~/.pi` root). The wrapper seeds it on first use:

```
~/.pi/agent/settings.json       # privacy, compaction, default packages
~/.pi/agent/mcp.json            # MCP servers
~/.pi/agent/web-search.json     # SearXNG for pi-web-access
~/.pi/agent/APPEND_SYSTEM.md    # persistent system-prompt addendum
~/.pi/agent/skills/llm-wiki/    # global on-demand wiki skill
~/.pi/mounts.conf               # optional permanent extra mounts
```

Existing files are never overwritten. A copy-ready reference lives in [`examples/pi/`](examples/pi/); copy it manually if you prefer:

```bash
mkdir -p ~/.pi/agent
cp -r examples/pi/agent/. ~/.pi/agent/
cp examples/pi/mounts.conf ~/.pi/mounts.conf
```

> Upgrading from an older wrapper: the legacy `@mariozechner/pi-coding-agent` package in the persistent volume is replaced by `@earendil-works/pi-coding-agent`; an old `~/.pi/settings.json` is migrated to `~/.pi/agent/settings.json`; existing per-project sessions are preserved. A `/share` patch from the previous wrapper version is reverted automatically by reinstalling the Pi package once.

See the official documentation for providers and models: [pi.dev/docs/latest/models](https://pi.dev/docs/latest/models)

### Fixed Pi working home

By default Pi starts in a fixed working home, independent of where you invoke it:

| Host | Container |
|---|---|
| `~/pi-home` | `/home/hostuser/pi-home` |

- The host directory is created with `mkdir -p` if missing.
- It is mounted through a managed entry in `~/.pi/mounts.conf`, so it is visible and editable there.
- `$HOME` inside the container points to this directory; Pi's configuration stays at the separate `/home/hostuser/.pi` mount.
- The current project is **not** mounted by default.
- `pi -m` mounts the current directory at `/<project>_<hash>` and uses it as the working directory. The fixed home stays available as `$HOME` (`/home/hostuser/pi-home`).
- `pi -m FILE...` mounts only the listed files, at their relative paths, and uses a temporary project view as the working directory. Other files from the current directory are not mounted.
- Override the default host path with `PI_HOME_DIR` before the first run; afterwards the source path in `mounts.conf` is authoritative.
- A managed entry still pointing to the previous default `~/documents/pi-home` is updated once to `~/pi-home`; existing data is **not** moved automatically.
- Keep the container target `/home/hostuser/pi-home`; Pi uses it as `$HOME`.
- `-m` is a wrapper flag. Pi's model flag remains `--model`.

```bash
pi          # fixed Pi home
pi -m       # current directory as working directory
pi -m -p "fix the tests"
pi -m web   # project-scoped Web UI

# Selective file mounts
pi -m README.md TEXT.md            # only these two files
pi -m README.md "TEXT.md"          # quoted names work too
pi -m "MY FILE.md"                 # filenames with spaces
pi -m README.md -p "summarize"     # selected files + prompt
pi -m README.md -- "summarize"     # force the next argument to be a prompt
```

File selection rules:

- With no file arguments, `pi -m` mounts the whole directory.
- Leading arguments that name existing files are mounted individually; the first non-file, option, or `--` stops file detection.
- Selected files must be inside the current directory. Directories are not accepted mixed with file arguments; use `pi -m` without arguments for the whole directory.
- Explicitly selected hidden files (`.env`, `.pi/...`) are mounted even though the normal full-project rules would hide them.
- File edits go to the host files. Other current-directory files are absent; a selection gets its own temporary project view, container, and session.
- Use `--` if a prompt would otherwise be interpreted as a file name.

### Extra mounts

The current project is mounted recursively at `/<project>_<hash>` only when `pi -m` is used without file arguments; `pi -m FILE...` mounts just those files. Add further permanent mounts in `~/.pi/mounts.conf`:

```text
# <host-path>:<container-path>[:ro|:rw]
~/shared:/shared:ro
/srv/data:/data
```

- `~` is expanded to your home directory.
- `:ro` mounts read-only; without a mode Docker uses read-write.
- Missing host paths, relative paths, and reserved targets (`/`, `~/.pi`, `/opt/pi-packages`, the current project path) are skipped with a warning.
- Only full-line comments are supported.
- The wrapper seeds the file with commented examples on first use. Changes apply on the next container start; no image rebuild is needed.
- Override the location with `PI_MOUNTS_FILE=/path/to/mounts.conf`.
- Only add paths that Pi is allowed to read or modify; a read-write mount gives the agent host-level write access to that directory.

### Global system prompt

Pi has three user-level places for persistent instructions:

| Path | Effect |
|---|---|
| `~/.pi/agent/APPEND_SYSTEM.md` | **Adds** instructions to Pi's system prompt (recommended) |
| `~/.pi/agent/SYSTEM.md` | **Replaces** Pi's built-in system prompt (use with care) |
| `~/.pi/agent/AGENTS.md` | Adds user context/instructions across projects |

The wrapper seeds `APPEND_SYSTEM.md` with a container/environment description if it does not exist. Edit it and start a new session, or run `/reload` in an active session. Existing custom content is preserved.

Project-root `AGENTS.md` files load as context when the project is mounted with `pi -m`. Project `.pi/APPEND_SYSTEM.md` and `.pi/SYSTEM.md` are **visible in that mode** (the rest of `.pi` is hidden), but they are **not applied automatically** because project trust is off (`--no-approve`). Put automatically applied project-specific instructions in the project-root `AGENTS.md` instead.

### Alias

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
alias pi="bash /path/to/pi-mono-dockerized/pi"
```

Reload your shell:

```bash
source ~/.bashrc
```

Done. Run `pi` for the fixed Pi home, or `pi -m` inside a project directory.

## Usage

```bash
# Interactive session (starts in the fixed Pi home)
pi
pi -m                              # mount current directory and use it as workdir
pi -m README.md TEXT.md            # mount only these files
pi -m "MY FILE.md"                 # quoted filename with spaces
pi -c                              # continue last home session
pi -m -c                           # continue current project session
pi -r                              # resume (pick session)
pi -m @AGENTS.md                   # load project context
pi -m @file1.md @file2.md "prompt" # context + prompt

# Web UI
pi web                             # fixed home + /web
pi -m web                          # project + /web

# One-off exposure of default-hidden project files
pi --show-hidden -m                 # .env, .pi, etc. visible for this project run

# In-session commands
/web                               # open the pi-webapp browser workspace
/skill:llm-wiki create a wiki ...  # load the global LLM-wiki skill on demand
/mcp                               # inspect/manage MCP servers
/share                             # upload the session manually (review first)

# Non-interactive (print mode)
pi -m -p "fix the bug in src/app.ts"
pi -m README.md -p "summarize this file"
pi -m -p --model anthropic/claude-sonnet-4 "explain this code" @main.py

# Session management
pi --session /path/to/session.json  # use specific session
pi --no-session                     # ephemeral, no saving

# MCP
pi mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem .
pi mcp list

# Extension / package management
pi install npm:pi-subagents
pi install git:github.com/user/repo
pi install ./local/path
pi remove npm:pi-subagents
pi update                          # update all
pi update npm:pi-subagents         # update one
pi list                            # list installed
pi config                          # TUI for package config

# Image management
pi rebuild                         # force-rebuild the Docker image
PI_RUST_VERSION=1.83 pi rebuild    # rebuild with a specific Rust version
```

The image is rebuilt automatically when the build stamp changes (bumped whenever the embedded Dockerfile changes) or when `PI_RUST_VERSION` changes.

All arguments are forwarded directly to `pi` inside the container. Only `rebuild` is intercepted by this script.

## Privacy & defaults

The wrapper enforces these defaults on every container start:

- **No telemetry:** `PI_TELEMETRY=0`, `enableInstallTelemetry: false`, and `enableAnalytics: false`. This also disables provider attribution headers controlled by Pi's install telemetry.
- **Update checks on:** the wrapper does not set `PI_SKIP_VERSION_CHECK`, so Pi can show available updates. This is a version request to `pi.dev`, not install telemetry.
- **No Sentry from the Web UI:** `PI_WEB_SENTRY_ENABLED=false`; pi-webapp's Sentry integration is off.
- **Manual sharing:** `/share` and `/bug` are available but never automatic. Review the session before uploading.
- **Project resources off by default:** `defaultProjectTrust: "never"` plus `--no-approve`; project `.pi` is also hidden from the container. With `pi -m`, project `AGENTS.md`/`CLAUDE.md` context still loads, but project extensions and skills do not. Pass `--approve` explicitly for a one-off trusted run.
- **No access to other sessions:** a temporary sessions root containing only the active context's subdirectory (fixed Pi home or a `pi -m` project) is mounted over `~/.pi/agent/sessions`. The session picker, `--resume`, and the Web UI therefore see only the active context's sessions; other contexts' session files are not visible in the container. Existing sessions for the same context are preserved.

`/share` and `/bug` are manual upload actions, not telemetry; do not invoke them if you want nothing to leave the machine.

`/share` uploads through Radius when you are authenticated, otherwise it creates a GitHub gist with `gh` (installed in the image). For gist sharing, either authenticate `gh` inside the container or place a token in `~/.pi/GH_TOKEN` or `~/.pi/GITHUB_TOKEN`; the wrapper passes it into the container.

## MCP

Pi 1.x includes MCP support, so no extra extension is required. Servers are read from `~/.pi/agent/mcp.json` and can be managed with:

```bash
pi mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem .
pi mcp list
```

See [`examples/pi/agent/mcp.example.json`](examples/pi/agent/mcp.example.json) for stdio and HTTP examples. If you prefer `pi-mcp-extension`, install it and disable the built-in MCP (`"extensions": ["-builtin:mcp"]`); keep only one active.

## Search & web

`pi-web-access` is installed by default and configured in `~/.pi/agent/web-search.json` for:

```
http://192.168.178.2:4000
```

`searchRouting.providers: ["searxng"]` keeps searches on your network and prevents a fallback to external providers. `ssrf.allowRanges` contains the narrow `192.168.178.2/32` entry required for the private SearXNG address. The instance must expose JSON (`json` under `search.formats` in SearXNG's `settings.yml`):

```bash
curl -sf 'http://192.168.178.2:4000/search?q=test&format=json' | jq '.results | length'
```

If you want Pi to fall back to hosted providers when SearXNG is unavailable, replace the `searchRouting` block with `"provider": "auto"`; queries may then leave your network.

Existing `~/.pi/agent/web-search.json` files are never overwritten. If yours still points to an older SearXNG address, update it or delete it so the wrapper seeds the new example.

For PDFs, GitHub repositories, YouTube videos, and general URL fetching, use the same `pi-web-access` tools (`fetch_content`, `get_search_content`, `source_check`). If you prefer the lighter `@juicesharp/rpiv-web-tools`, remove `pi-web-access` first to avoid duplicate `web_search` tools; a SearXNG config for it is in [`examples/pi/rpiv-web-tools/config.json`](examples/pi/rpiv-web-tools/config.json).

## LLM wiki

The global `llm-wiki` skill implements the [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). It is loaded only when needed:

```text
/skill:llm-wiki create an LLM wiki for this research topic
```

The skill creates `llm-wiki/raw/` (immutable sources), `llm-wiki/wiki/` (index, log, source/entity/concept pages), and a `SCHEMA.md` that you co-evolve with Pi. For automated codebase documentation, `pi install npm:openwiki` is an optional alternative.

## Git

Pi has no separate Git tool; the agent uses its `bash` tool to run `git`. Git is enabled by default: `.git`, `.gitignore`, and `.gitmodules` are visible, so `git status`, diffs, and `git add` behave correctly.

Disable it with:

```bash
PI_ALLOW_GIT=0 pi
```

`.git` visibility is a Docker mount decision, so it is controlled by the wrapper (`PI_ALLOW_GIT`) or your environment, not by `~/.pi/agent/settings.json`.

Local commits work as usual (`git status`, `git diff`, `git add`, `git commit -m`, branches, amend, rebase, …). The wrapper passes a commit identity from your host:

- `git config --global user.name` / `user.email`
- or `PI_GIT_NAME` / `PI_GIT_EMAIL`

If either value is missing, configure the repository or pass the variables explicitly.

Notes:

- **Push is not enabled by default.** The container does not mount `~/.ssh`, credential helpers, or a GitHub token. Local commits work; pushing needs credentials that you deliberately make available.
- **Commit signing:** host GPG/SSH signing setup is not mounted. If a repository enforces `commit.gpgsign=true`, commits may fail inside the container.
- **Web UI:** the pi-webapp Git panel can stage, review, branch, and commit while Git is enabled (default); treat push credentials separately.
- `.git` can contain remotes and full history. Since Git is visible by default, set `PI_ALLOW_GIT=0` if you do not want that.

To make Pi commit consistently, add the conventions to `AGENTS.md` (for example: run tests, use imperative commit subjects, never amend published commits).

## Web UI

`pi-webapp` is installed by default. The shortcut

```bash
pi web
```

starts Pi in the fixed Pi home and executes `/web` as the initial prompt, so the web workspace starts immediately. Use `pi -m web` to open the Web UI for the current project instead. Either way the command prints a local URL for the browser workspace (chat, files, terminal, Git review); the Pi TUI stays open as long as the web service should run. Git review is available when the active workdir is a Git repository; set `PI_ALLOW_GIT=0` if you want to hide repository metadata instead.

The `/web` service runs **inside the same container as Pi**, binds `127.0.0.1` on a random port, and stops when Pi exits. It is not a separate container or a fixed published port. With host networking the printed URL works on the Docker host's loopback; from another machine use an SSH tunnel.

### `/web` is not reachable

`pi-webapp` binds to `127.0.0.1`, not `0.0.0.0`. Therefore a URL like `http://10.1.1.2:33461/` will not work even when the container uses host networking: the service only listens on the Docker host's loopback.

- **Browser on the Docker host:** open the printed `http://127.0.0.1:<port>/#<token>` URL directly. Check that the container really uses host networking:

  ```bash
  docker inspect $(docker ps -q --filter name=pi-) --format '{{.HostConfig.NetworkMode}}'
  ```

  It must print `host`. If it prints `bridge`, you are still running an older copy of the `pi` script or an old alias; the current wrapper always uses host networking.

- **Browser on another machine:** create a tunnel to the Docker host and keep it open:

  ```bash
  ssh -N -L 33461:127.0.0.1:33461 user@10.1.1.2
  ```

  Then open `http://127.0.0.1:33461/#<token>` locally. The port changes with every `/web`, so adjust the tunnel.

- **Docker Desktop, Colima, rootless Docker, or a remote Docker host:** host networking refers to the VM, rootless network namespace, or remote host, not to your local loopback. Use an SSH tunnel into that environment or a port-forwarding setup.

- The `Warning: pi-webapp: ...` line only means Pi could not open a browser inside the container. Verify the service from inside the container with:

  ```bash
  docker exec <container> sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:33461/'
  ```

  Any HTTP response means the server is listening; the remaining problem is reachability.

The wrapper always uses Docker host networking (`--network host`) because pi-webapp binds `127.0.0.1` inside the container. That makes the printed URL reachable from a browser on the same Linux host, while the Web UI itself still listens only on loopback. The container therefore shares the host network namespace; there is no bridge mode in this wrapper. The Web UI is intentionally scoped to the active context (the fixed Pi home, or a `pi -m` project): other sessions are not mounted, so its workspace/session picker cannot see them. The Web UI is not designed to be exposed to the public internet; its terminals and tools run with the same container user permissions as Pi itself.

## Configuration reference

| Variable | Default | Purpose |
|---|---|---|
| `PI_CODING_AGENT_VERSION` | `1.5.2` | Pi package version installed in the persistent volume |
| `PI_RUST_VERSION` | `stable` | Rust toolchain version baked into the image |
| `PI_ALLOW_GIT` | `1` | Set to `0` to hide `.git`, `.gitignore`, and `.gitmodules`; default exposes them for local commits and Web UI Git review |
| `PI_SHOW_HIDDEN` | `0` | Set to `1` (or use `pi --show-hidden -m`) to expose all default-hidden project files for one full-project run (no file arguments) |
| `PI_GIT_NAME` | host `user.name` | Git author/committer name inside the container |
| `PI_GIT_EMAIL` | host `user.email` | Git author/committer email inside the container |
| `PI_HOME_DIR` | `~/pi-home` | Host source for the fixed Pi home when the managed `mounts.conf` entry is created |
| `PI_MOUNT_CWD` | `0` | Set to `1` to behave like `pi -m` (mount the current directory) |
| `PI_MOUNTS_FILE` | `~/.pi/mounts.conf` | Optional config for permanent extra mounts |

Install telemetry/analytics and Sentry are disabled by the wrapper; update checks remain on. `/share` and `/bug` are manual, so use them deliberately.

## How It Works

Without `-m`, each Pi home gets one fixed container (`pi-home-<hash>`). The current directory is not mounted:

| Host path | Container path |
|---|---|
| `~/pi-home` | `/home/hostuser/pi-home` |

With `pi -m`, the current project is mounted too and gets its own container (`pi-<md5-hash>`):

| Host path | Container path |
|---|---|
| `/home/user/my-project` | `/my-project_a1b2c3` |

The project path is built from the **directory name** + the **last 6 characters** of the directory's MD5 hash. This keeps it readable while avoiding collisions between identically named directories. With `pi -m FILE...`, the container name and project path include a hash of the selected file list (`pi-files-...`); only those files are mounted, inside a temporary project view.

`~/.pi/agent` is shared across containers for settings, credentials, models, and installed packages. Sessions are kept per context: the fixed home has its own session directory, and each `pi -m` project gets `~/.pi/agent/sessions/--<container-path>--`. Inside the container a temporary sessions root containing only the active subdirectory is mounted over `~/.pi/agent/sessions`, so other contexts' sessions are not visible. Containers are ephemeral (`--rm`) and cleaned up on exit; the Web UI always uses host networking (see [Web UI](#web-ui)).

## File Ignoring

When a project is mounted with `pi -m` **without file arguments**, these **project-relative** paths are hidden by default. The fixed Pi home and paths from `mounts.conf` are fully visible. Selective `pi -m FILE...` mounts only the files you explicitly name; those explicit files are not filtered by this list.

| Path | Default |
|---|---|
| `.env`, `.secret`, `.deploy`, `.build`, `.vscode`, `.DS_Store` | hidden |
| `.aiignore`, `.aiexclude`, `.copilotignore`, `.geminiignore`, `.codeiumignore`, `.cursorignore` | hidden |
| `.pi/` | hidden, **except** `.pi/APPEND_SYSTEM.md` and `.pi/SYSTEM.md`, which stay visible if present |
| `.git`, `.gitignore`, `.gitmodules` | visible (set `PI_ALLOW_GIT=0` to hide) |

Only the fixed Pi home, a `pi -m` project, and paths from `~/.pi/mounts.conf` are mounted; these rules never expose other host directories.

To expose all default-hidden project files for one run:

```bash
pi --show-hidden -m
# or
PI_SHOW_HIDDEN=1 pi -m
```

This removes only the project-relative ignore mounts. It does **not** mount the host and does not change extra mounts. It applies to a full project mount; selective file mounts are explicit and unaffected. `--show-hidden` can be combined with other wrapper commands, for example:

```bash
pi --show-hidden -m web
```

It overrides `PI_ALLOW_GIT=0` for that run. Hidden paths can contain credentials; use it deliberately. Without `pi -m` there is no project mount, so the flag has no effect.

The wrapper hides paths by bind-mounting `/dev/null` (files) or an empty directory (directories). It does not evaluate `.gitignore`-style patterns; add further exclusions to `PI_DEFAULT_IGNORED_FILES` in the `pi` script, or keep secrets outside the project directory.

## Directory Structure

```
~/.pi/
├── mounts.conf             # permanent extra mounts (optional)
├── agent/
│   ├── settings.json       # privacy, compaction, packages
│   ├── APPEND_SYSTEM.md    # persistent system-prompt addendum
│   ├── mcp.json            # MCP servers (built-in MCP)
│   ├── web-search.json     # SearXNG for pi-web-access
│   ├── auth.json           # provider credentials (created by /login)
│   ├── skills/
│   │   └── llm-wiki/       # global on-demand wiki skill
│   └── sessions/
│       └── --<project>--/  # only this project's sessions are visible
└── settings.json           # legacy path from older wrapper versions (unused)
```

`~/.pi/agent` is persisted through the `~/.pi` mount. Existing files are never overwritten by the wrapper.

The fixed working home is outside this tree at `~/pi-home` (host) and is mounted to `/home/hostuser/pi-home` via its managed `mounts.conf` entry.

## Image and volume lifecycle

The wrapper does **not** pull or rebuild on every start. It builds only when:

- `pi:latest` is missing, or
- the image's `pi.build.stamp` label differs from the current script stamp.

`docker build` uses the local `node:22-bookworm-slim` base image by default. It pulls the base image or `ghcr.io/astral-sh/uv` only when they are not present locally. A rebuild that takes minutes therefore usually means the image (and possibly the build cache) was removed.

Common causes:

- `docker image prune -a` removes `pi:latest` while no Pi container is running.
- `docker system prune -a` does the same and also removes the build cache.
- `docker system prune --volumes` or `docker volume prune` can remove `pi-software-binaries`, which forces a Pi/package reinstall.
- `docker builder prune` removes the cached apt/Rust/uv layers; the next rebuild downloads everything again.
- Portainer, Watchtower, cron jobs, or `docker-gc` may run similar cleanups.

`docker compose down --rmi all` only removes images used by that compose project; it does not remove `pi:latest` unless a compose service references it. A global prune command is the usual culprit.

### Keep the Pi image and volume

The image and new volumes are labeled `pi.managed=true`. Use filtered cleanup:

```bash
# Safe: only dangling images (also clears old pi rebuilds)
docker image prune

# Remove unused images, but keep pi:latest
docker image prune -a --filter "label!=pi.managed=true"

# Only if you really need to prune volumes; keeps new labeled volumes
docker volume prune --filter "label!=pi.managed=true"
```

The existing `pi-software-binaries` volume may predate the label. Check it with:

```bash
docker volume inspect pi-software-binaries --format '{{json .Labels}}'
```

If the label is missing, do not run `docker volume prune` or `docker system prune --volumes`; recreate the volume once (no Pi container running) to get the label and reinstall Pi:

```bash
docker volume rm pi-software-binaries
```

For compose projects, prefer `docker compose down --rmi local`, or target only that project's images:

```bash
docker image prune -a \
  --filter "label=com.docker.compose.project=my-project" \
  --filter "label!=pi.managed=true"
```

Avoid `docker image prune -a`, `docker system prune -a`, `docker builder prune`, and `docker volume prune` without filters unless you accept a slow Pi rebuild.

### Diagnose

```bash
docker image inspect pi:latest --format '{{json .Config.Labels}}'
docker volume inspect pi-software-binaries --format '{{json .Labels}}'
docker system df
docker events --filter type=image --filter event=delete
```

The wrapper prints `pi: image pi:latest is missing; rebuilding.` when the image was removed. `Installing Pi ...` means the persistent volume lost the Pi installation; `Installing default Pi packages...` means the package marker is gone.

As a last-resort backup you can save and reload the image:

```bash
docker save pi:latest -o ~/pi-image.tar
docker load -i ~/pi-image.tar
```

## File Permissions

The container runs with `--user $(id -u):$(id -g)`, matching your host user's UID/GID. Files created by pi on mounted volumes have the same ownership as your host user — no root-owned files.

If an old `~/.pi` directory was created by a previous root-based run:

```bash
sudo chown -R $(whoami):$(id -gn) ~/.pi
```

## Disclaimer

**Use at your own risk.**

This project is provided as-is, without warranty of any kind. By using this software you agree that:

- The author(s) assume **no liability** for any damages, data loss, security breaches, or other issues arising from its use.
- You are solely responsible for managing your **API keys and credentials**. Do not share them or expose them publicly.
- Docker containers interact with your filesystem — **review mounts and permissions** before running.
- AI-generated code may contain bugs or vulnerabilities. **Always review** any output before using it in production.
- This is an **unofficial** wrapper and is not affiliated with or endorsed by the pi-coding-agent project.

**TL;DR:** If it breaks, that's on you. Back up your stuff. Think before you run.
