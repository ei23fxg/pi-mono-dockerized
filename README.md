# Pi-Mono Agent Dockerized

Run [pi-coding-agent](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent) in an isolated Docker container with zero host dependencies.

> **Note:** This is a Bash script and runs on **Linux only**. macOS and Windows are not supported.

## What's Inside

The Docker image comes with everything you need:

- **Node.js 22 LTS** (Debian Bookworm)
- **pi-coding-agent** and **summarize** pre-installed
- **uv** — Python package manager ([astral.sh](https://astral.sh/uv))
- **curl**, **wget**, **jq**
- **ffmpeg**, **imagemagick**

## Setup

### Configuration

This setup uses the `~/.pi` folder in your home directory for configuration — exactly like the original [pi-mono](https://github.com/badlogic/pi-mono).

See the official documentation for setup instructions: [Providers & Models](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent#providers--models)

### Alias

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
alias pi="bash /path/to/pi-mono-dockerized/pi"
```

Reload your shell:

```bash
source ~/.bashrc
```

Done. Now just run `pi` in any project directory.

## Usage

```bash
# Interactive session (starts in current directory)
pi
pi -c                              # continue last session
pi -r                              # resume (pick session)
pi @AGENTS.md                      # load context files
pi @file1.md @file2.md "prompt"    # context + prompt

# Non-interactive (print mode)
pi -p "fix the bug in src/app.ts"
pi -p --model anthropic/claude-sonnet-4 "explain this code" @main.py

# Session management
pi --session /path/to/session.json  # use specific session
pi --no-session                     # ephemeral, no saving

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
```

All arguments are forwarded directly to `pi` inside the container. Only `rebuild` is intercepted by this script.

## How It Works

Each working directory gets its own container (`pi-<md5-hash>`). Your project is mounted at a readable path inside the container:

| Host path | Container path |
|---|---|
| `/home/user/my-project` | `/my-project_a1b2c3` |

The path is built from the **directory name** + the **last 6 characters** of the directory's MD5 hash. This keeps it readable while avoiding collisions between identically named directories.

`~/.pi` is shared across all containers — matching the native pi directory structure. Containers are ephemeral (`--rm`) and cleaned up on exit.

## File Ignoring

Sensitive files are hidden from the container by bind-mounting `/dev/null` over them.

**Ignored by default:** `.env`, `.secret`, `.deploy`, `.git`, `.build`, `.vscode`, `.gitmodules`, `.pi`, `.DS_Store`

**Custom patterns:** Add glob patterns to any of these files (locally or in `~/.pi/`):

```
.aiignore  .aiexclude  .copilotignore  .gitignore
.geminiignore  .codeiumignore  .cursorignore
```

Example `.aiignore`:

```
*.secret
credentials.json
dist/
```

## Directory Structure

```
~/.pi/                          # pi config + API key scripts + ignore configs
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
is is an **unofficial** wrapper and is not affiliated with or endorsed by the pi-coding-agent project.

**TL;DR:** If it breaks, that's on you. Back up your stuff. Think before you run.
