# Pi-Mono Agent Dockerized

Run [Pi](https://pi.dev/) — a coding agent — inside an isolated Docker container with a full
development toolchain and sensible privacy defaults. Everything Pi needs (Node, Rust, Go, Python,
PHP, build tools) lives in the image; your settings, credentials, and sessions live in `~/.pi` on
the host. One command starts a session: `pi`.

> **Note:** A Bash script, **Linux only**. The first run builds the image and installs Pi — expect a few minutes.

## Quick start

```bash
alias pi="bash /path/to/pi-mono-dockerized/pi"   # add to ~/.bashrc
pi            # interactive session in the fixed Pi home (~/pi-home)
pi -m         # inside a project: mount it and work there
pi -m -p "fix the tests"
pi web        # start Pi and open the browser workspace (Web UI)
```

Pi starts in a fixed working home (`~/pi-home` on the host, `$HOME` in the container). The current
directory is **not** visible unless you use `-m`. All other Pi arguments are forwarded unchanged
(only `rebuild` is handled by the wrapper).

## Working modes

| Command | Effect |
|---|---|
| `pi` | Fixed Pi home only; no project mounted |
| `pi -m` | Mounts the current directory (plus subdirectories) as working directory |
| `pi -m README.md "MY FILE.md"` | Mounts only these files; everything else stays on the host |
| `pi -m web` | Web UI scoped to the current project |
| `pi --show-hidden -m` | One-off: also expose normally hidden project files (`.env`, `.pi`, …) |
| `pi rebuild` | Force-rebuild the Docker image (`PI_RUST_VERSION=1.83 pi rebuild` to pin Rust) |

- `-m` is a wrapper flag; Pi's own model flag stays `--model`.
- With file arguments, leading existing files are mounted individually; use `--` before a prompt that could be mistaken for a filename.
- A full `pi -m` mount hides `.env`, `.secret`, `.deploy`, `.build`, `.vscode`, ignore-files and `.pi/` (except `.pi/APPEND_SYSTEM.md` and `.pi/SYSTEM.md`). `.git`, `.gitignore`, `.gitmodules` are visible by default — set `PI_ALLOW_GIT=0` to hide them.
- Each mode keeps its own sessions; you never see sessions from other projects or from the Pi home.

### All commands

Everything except the wrapper-only words (`-m`, `web`, `rebuild`, `--show-hidden`) is forwarded
unchanged to `pi` inside the container.

```bash
# Interactive sessions (start in the fixed Pi home)
pi                               # fixed home session
pi -m                            # mount current directory and work there
pi -m README.md TEXT.md          # mount only these files
pi -m "MY FILE.md"               # quoted filename with spaces
pi -c                            # continue last session of the fixed home
pi -m -c                         # continue last session of the current project
pi -r                            # resume: pick from the current context's sessions
pi -m @AGENTS.md                 # load project context file into the prompt
pi -m @file1.md @file2.md "prompt"   # context files + prompt in one go

# Web UI
pi web                           # fixed home + /web (browser workspace)
pi -m web                        # Web UI scoped to the current project
pi -m -c web                     # continue the project's last session, open Web UI
pi -m -r web                     # pick a project session, open Web UI

# One-off exposure of default-hidden project files
pi --show-hidden -m              # .env, .pi, etc. visible for this run
pi --show-hidden -m web          # combinable with other wrapper commands

# Non-interactive (print mode)
pi -m -p "fix the bug in src/app.ts"
pi -m README.md -p "summarize this file"
pi -m README.md -- "summarize"   # force next argument to be the prompt
pi -m -p --model anthropic/claude-sonnet-4 "explain this code" @main.py

# Session handling (forwarded to Pi)
pi --session /path/to/session.json   # use a specific session file
pi --no-session                      # ephemeral, nothing is saved

# In-session slash commands (inside Pi, not the wrapper)
/web                               # open the browser workspace
/tps                               # token speed indicator
/acp  /acp-cache                   # billion-context state / cache stats
/context                           # pi-context-view: usage map
/skill:llm-wiki create a wiki …    # load the wiki skill on demand
/mcp                               # inspect/manage MCP servers
/share                             # manual session upload (review first)

# MCP servers
pi mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem .
pi mcp list

# Package management
pi install npm:pi-subagents        # from npm
pi install git:github.com/user/repo
pi install ./local/path
pi remove npm:pi-subagents
pi list                            # what is installed
pi config                          # TUI to enable/disable packages
pi update --extensions             # update packages only
pi update --all                    # update Pi and packages

# Image management
pi rebuild                         # force-rebuild the Docker image
PI_RUST_VERSION=1.83 pi rebuild    # rebuild with a pinned Rust version
```

The image rebuilds automatically when the build stamp changes (bumped whenever the embedded
Dockerfile changes) or when `PI_RUST_VERSION` changes. Default packages are floating (unpinned):
Pi shows a `Run pi update --extensions` notice when updates exist — nothing is upgraded on its own.

### Extra mounts

Permanent additional mounts go in `~/.pi/mounts.conf` (one per line, applied on next start):

```text
# <host-path>:<container-path>[:ro|:rw]
~/shared:/shared:ro
/srv/data:/data
```

`~` expands to your home; read-write mounts give the agent write access there, so add only paths
Pi should touch. The wrapper seeds commented examples on first use.

## Default Pi setup

The image ships Pi 1.x plus these packages (installed on first run, updated via `pi update --extensions`):

- **`pi-web-access`** — web search/fetch, PDFs, GitHub, YouTube; searches go to your local SearXNG (`http://192.168.178.2:4000`) with no external fallback
- **`pi-webapp`** — browser workspace: chat, files, real terminal, Git review (`/web` in-session, `pi web` as shortcut)
- **`pi-token-speed`** — tokens/second and time-to-first-token in the status bar (`/tps`)
- **`billion-context`** — context compression for long sessions (`/acp`, `/acp-cache`); replaces Pi's auto-compaction while active. Disable its delegate/sub-agent tools (keep compression) via `~/.pi/agent/billion-context.json` — see [docs/troubleshooting.md](docs/troubleshooting.md). Remove entirely with `pi remove npm:billion-context`
- **`pi-context-view`** — visualize what fills the context window; inspect system prompt and tool definitions (`/context`)
- **Built-in MCP** — `pi mcp add <name> -- <command>`, config in `~/.pi/agent/mcp.json`
- **`llm-wiki` skill** — build a persistent Markdown wiki from your sources on demand: `/skill:llm-wiki create a wiki for …`

Privacy defaults are enforced on every start: no install telemetry, no analytics, no Sentry;
update checks stay on. `/share` and `/bug` exist but are manual uploads only — review your
session before using them. Project trust is off (`--no-approve`): project `.pi` extensions and
skills are not loaded; project `AGENTS.md` still loads as context.

## Configuration

Seeded once into `~/.pi/agent` (existing files are never overwritten; reference copies in
[`examples/pi/`](examples/pi/)):

```
~/.pi/agent/settings.json     # privacy, compaction, default packages
~/.pi/agent/mcp.json          # MCP servers
~/.pi/agent/web-search.json   # SearXNG address for pi-web-access
~/.pi/agent/APPEND_SYSTEM.md  # persistent system-prompt addendum (seeded with container info)
~/.pi/agent/billion-context.json  # optional billion-context config (e.g. disable sub-agents)
~/.pi/agent/skills/llm-wiki/  # global wiki skill
~/.pi/mounts.conf             # permanent extra mounts (optional)
```

Provider/model setup: [pi.dev/docs/latest/models](https://pi.dev/docs/latest/models).
Persistent instructions: edit `~/.pi/agent/APPEND_SYSTEM.md` (`/reload` applies it in a session).
The seeded template includes a **sub-agents/delegation guard** (sequential execution, for local
or limited models). If your `APPEND_SYSTEM.md` predates this update, add it yourself — and pair
it with `"pi": { "subagents": false }` in `billion-context.json` to also remove the tools.

### Wrapper variables

These are **shell environment variables on the host** that the `pi` script reads before it starts
Docker — they are *not* Pi settings and do not belong in `~/.pi/agent/settings.json`. Set them
either per run (prefix before the command) or permanently (`export` in your `~/.bashrc`/`~/.zshrc`):

```bash
PI_ALLOW_GIT=0 pi -m            # just this run
export PI_ALLOW_GIT=0          # all future runs in your shell
```

Some variables only take effect at first setup (marked below); changes afterwards are ignored or
require deleting the generated config entry.

| Variable | Default | Purpose |
|---|---|---|
| `PI_ALLOW_GIT` | `1` | `0` hides `.git`, `.gitignore`, `.gitmodules` |
| `PI_SHOW_HIDDEN` | `0` | `1` exposes all hidden project files for one full-project run |
| `PI_GIT_NAME` / `PI_GIT_EMAIL` | host values | Commit identity inside the container |
| `PI_HOME_DIR` | `~/pi-home` | Host source of the fixed Pi home — **first run only**; afterwards the `mounts.conf` entry is authoritative |
| `PI_MOUNT_CWD` | `0` | `1` behaves like `pi -m` always |
| `PI_MOUNTS_FILE` | `~/.pi/mounts.conf` | Location of the extra-mounts config |
| `PI_SKIP_PACKAGES` | empty | Skip default packages, e.g. `PI_SKIP_PACKAGES="billion-context" pi` |
| `PI_PACKAGE_PINS` | empty | Pin exact versions, e.g. `pi-web-access@0.47.0` (disables update notices) |
| `PI_RUST_VERSION` | `stable` | Rust toolchain baked into the image (change ⇒ image rebuild) |

## Git

The agent uses plain `git` via its bash tool. Local commits work out of the box with your host
identity (`git config --global user.name/user.email`, or `PI_GIT_NAME`/`PI_GIT_EMAIL`).
**Push is not enabled** — the container has no SSH keys or credential helpers; provide
credentials deliberately if you want it. Put your commit conventions into the project's
`AGENTS.md`.

## Web UI

`pi web` (or `/web` in a session) starts a local browser workspace and prints a URL like
`http://127.0.0.1:<port>/#<token>`. It binds to **loopback** inside the container, so:

- On the Docker host: open the printed URL directly.
- From another machine: tunnel, e.g. `ssh -N -L 33461:127.0.0.1:33461 user@dockerhost`.
- The TUI must stay open while you use the Web UI; the service stops with it.

The wrapper always uses Docker host networking so the URL works on the host. The Web UI is not
meant for the public internet; its terminals run with your container user's permissions.

## Privacy & sessions — how isolation works

- One container per context (fixed home or each `pi -m` project), ephemeral (`--rm`).
- Only the fixed Pi home, the mounted project, and your `mounts.conf` paths are visible — never the whole host.
- The session mount contains only the active context's sessions, so `--resume` and the Web UI cannot see other projects' chats.
- Container runs as your host UID/GID — created files have your ownership.
- `/share` uploads to Radius or a GitHub gist (via `gh`); `~/.pi/GH_TOKEN` or `~/.pi/GITHUB_TOKEN` is passed in for gist sharing.

## Troubleshooting

- **Slow start / rebuilding?** A rebuild means the image or its build cache was pruned.
  Avoid unfiltered `docker image prune -a`, `docker system prune -a`, and `docker volume prune`;
  the image and volumes are labeled `pi.managed=true`. Details: [docs/troubleshooting.md](docs/troubleshooting.md).
- **Web URL not reachable?** You are likely not on the Docker host's loopback — use an SSH tunnel (see Web UI above).
- **`Warning: pi-webapp: …`** just means no browser could be opened inside the container; the service itself may be fine.
- Old `~/.pi` owned by root after legacy runs: `sudo chown -R $(whoami):$(id -gn) ~/.pi`.

More (image/volume lifecycle, diagnostics, legacy migrations): [docs/troubleshooting.md](docs/troubleshooting.md).

## Disclaimer

**Use at your own risk.** Provided as-is, no warranty. You are responsible for your API keys,
mounts, and credentials; review AI-generated code before using it. This is an unofficial wrapper,
not affiliated with the pi-coding-agent project.
