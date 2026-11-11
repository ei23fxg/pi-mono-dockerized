# Environment

You are running inside a Docker container managed by `pi-mono-dockerized`, based on Debian Bookworm slim.

- **Project:** the current working directory is mounted at `/<project>_<hash>`; edits persist on the host.
- **Home:** `/home/hostuser/.pi` is mounted from the host and contains settings, auth, packages, and this project's sessions.
- **Extra host directories:** only those configured in `~/.pi/mounts.conf`; respect `:ro` mounts and do not try to write to them.
- **Host filesystem:** no general host filesystem is mounted. Do not expect host paths outside the project and the configured extra mounts.
- **Hidden by default:** `.env`, `.secret`, `.deploy`, `.build`, `.vscode`, `.pi` (except `.pi/APPEND_SYSTEM.md` and `.pi/SYSTEM.md`), `.DS_Store`, and the `.aiignore`/`.aiexclude`/`.copilotignore`/`.geminiignore`/`.codeiumignore`/`.cursorignore` files. `.git`, `.gitignore`, and `.gitmodules` are visible by default. Do not probe for hidden files; ask the user, who can start `pi --show-hidden`.
- **Installed tools:** Node.js 22 + npm/pnpm, git + gh, ripgrep, jq, curl, wget, openssh, gcc/g++, make, cmake, clang/lld, pkg-config, libssl-dev, zlib1g-dev, Rust (rustup, cargo, rustfmt, clippy), Go, Python 3 + uv, PHP 8 + Composer, MariaDB/MySQL client, pandoc, ffmpeg, and ImageMagick.
- **Python:** use `uv` and a `uv` virtual environment for Python work. Create one with `uv venv .venv`, install with `uv pip install ...`, and run with `uv run ...`. Do not install packages into the system Python with plain `pip`.
- **Other ecosystems:** use npm/pnpm for Node, `cargo` for Rust, `go` for Go, and `composer` for PHP.
- **Git:** local commits are allowed and a host identity is provided. Do not push or create signed commits unless credentials/signing are explicitly configured.
- **Network:** internet access is available. Web search is routed through the local SearXNG instance by default.
- **Privacy:** `/share` and `/bug` upload data. Use them only when the user explicitly asks.
- **Access checks:** if a path is outside the project and configured mounts, or appears to be hidden, ask the user before trying to access it.
