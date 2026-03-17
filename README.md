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
pi           # start in current directory
pi rebuild   # force-rebuild the Docker image

# Extension/package management (mirrors host pi CLI)
pi install npm:pi-subagents     # install from npm
pi install git:github.com/user/repo  # install from git
pi install ./local/path         # install from local path
pi remove npm:pi-subagents      # remove extension
pi update                       # update all installed extensions
pi update npm:pi-subagents      # update specific extension
pi list                         # list installed extensions
pi config                       # open TUI to configure packages
```

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
