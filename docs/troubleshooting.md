# Troubleshooting & Reference (details from the main README)

## `/web` is not reachable

`pi-webapp` binds to `127.0.0.1`, not `0.0.0.0`. A URL like `http://10.1.1.2:33461/` will not
work even with host networking — the service only listens on the Docker host's loopback.

- **Browser on the Docker host:** open the printed `http://127.0.0.1:<port>/#<token>` URL.
  Check the network mode:

  ```bash
  docker inspect $(docker ps -q --filter name=pi-) --format '{{.HostConfig.NetworkMode}}'
  ```

  It must print `host`. `bridge` means an older copy of the `pi` script or an old alias is running.

- **Browser on another machine:** tunnel to the Docker host and keep it open (the port changes with every `/web`):

  ```bash
  ssh -N -L 33461:127.0.0.1:33461 user@10.1.1.2
  ```

- **Docker Desktop, Colima, rootless Docker, remote Docker host:** host networking refers to the
  VM/rootless namespace/remote host, not your local loopback. Use an SSH tunnel or port forwarding.
- The `Warning: pi-webapp: ...` line only means no browser could be opened inside the container.
  Verify the service from inside the container:

  ```bash
  docker exec <container> sh -c 'curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:33461/'
  ```

The wrapper always uses `--network host` because pi-webapp binds `127.0.0.1` inside the container.
The Web UI is scoped to the active context (fixed home or the `pi -m` project); other sessions are
not mounted. It is not designed for public internet exposure.

## Image and volume lifecycle

The wrapper does **not** pull or rebuild on every start. It builds only when `pi:latest` is
missing or the image's `pi.build.stamp` label differs from the script stamp. Base images
(`node:22-bookworm-slim`, `ghcr.io/astral-sh/uv`) are pulled only when absent locally.

Common causes of unexpected rebuilds:

- `docker image prune -a` removes `pi:latest` while no Pi container runs.
- `docker system prune -a` also removes the build cache.
- `docker system prune --volumes` / `docker volume prune` can remove `pi-software-binaries` (forces a Pi/package reinstall).
- `docker builder prune` removes cached apt/Rust/uv layers.
- Portainer, Watchtower, cron, or `docker-gc` may run similar cleanups.

`docker compose down --rmi all` only removes that compose project's images.

### Safe cleanup

The image and new volumes are labeled `pi.managed=true`:

```bash
docker image prune                                   # only dangling images
docker image prune -a --filter "label!=pi.managed=true"
docker volume prune --filter "label!=pi.managed=true"
```

`pi-software-binaries` may predate the label; check:

```bash
docker volume inspect pi-software-binaries --format '{{json .Labels}}'
```

If unlabeled, avoid unfiltered volume prunes; recreate once (no Pi container running):
`docker volume rm pi-software-binaries` (then Pi reinstalls).
For compose: prefer `docker compose down --rmi local`.

Last resort: `docker save pi:latest -o ~/pi-image.tar && docker load -i ~/pi-image.tar`.

### Diagnostics

```bash
docker image inspect pi:latest --format '{{json .Config.Labels}}'
docker volume inspect pi-software-binaries --format '{{json .Labels}}'
docker system df
docker events --filter type=image --filter event=delete
```

Wrapper messages: `pi: image pi:latest is missing; rebuilding.` (image gone),
`Installing Pi ...` (volume lost the Pi install), `Installing default Pi packages...` (package marker gone).

## Package updates, pins, migration

Default packages are registered floating (`npm:pi-web-access`, not `@0.47.0`), so Pi checks npm at
each start and may show `Package Updates Available — Run pi update --extensions`. Nothing is
upgraded automatically:

```bash
pi update --extensions   # packages only
pi update --all          # Pi + packages
pi update                # Pi only
```

A newer Pi in the volume is kept (`PI_CODING_AGENT_VERSION` is a floor, not a ceiling — it prints
`Keeping Pi <new> from the volume`). Pinned entries (`PI_PACKAGE_PINS="pi-web-access@0.47.0"`) are
skipped by the update check and never moved. Existing pinned entries migrate once when
`PI_PACKAGES_STAMP` bumps (re-`pi install npm:<name>` replaces the pinned entry; the installed
copy upgrades on the next notice + `pi update --extensions`).

## Plan mode (`/plan`)

`@narumitw/pi-plan-mode` is installed as a default package (requires Pi ≥ 0.80.6; the wrapper
installs Pi 1.5.2). It adds a read-only planning mode: `edit`/`write` are blocked, `bash` is
restricted to inspection and reviewed checks, and implementation starts only after you approve the
plan.

```text
/plan                  # menu: start/stop, review, implement here or in a fresh session
/plan <prompt>         # start planning right away
/plan tools            # per-session tool allowlist before starting
/plan exit (alias off) # leave plan mode
```

- **There is no startup switch.** No Pi setting and no CLI flag turns plan mode on at launch
  (`planModeOn` does not exist upstream — delete it if you ever added it). Start it per session;
  the seeded `APPEND_SYSTEM.md` still instructs the agent to plan before non-trivial changes.
- **Existing `~/.pi`:** the package arrives with the next start because `PI_PACKAGES_STAMP` was
  bumped (the one-time `pi install` re-runs). Or install it yourself: `pi install npm:@narumitw/pi-plan-mode`.
- **Options:** `~/.pi/agent/pi-plan-mode.json` (`defaultPlanTools`, `implementationPlanRetention`,
  `defaultImplementationModel`/`ThinkingLevel`, `defaultPlanExportPath`, `toggleShortcut`,
  JSON-only `safeSubcommands`). `/plan settings` edits the same file.
- **MCP and extension tools are denied in plan mode by default.** If you use the built-in MCP
  servers while planning, allow their names explicitly (`/plan tools`, or list them in
  `defaultPlanTools`) — only after reviewing what those servers can do.

## Git identity and auto-init

The wrapper always injects `GIT_AUTHOR_NAME/EMAIL` and `GIT_COMMITTER_NAME/EMAIL` into project
containers: host values, or `Pi Agent <agent@pi.dev>` when the host has none. Without that, git in
the container refuses to commit.

For a full `pi -m` project without a repository, the container runs — just before `exec pi` —
`git init -q && git add -A && git commit -qm "checkpoint: initial workspace snapshot"`. It is a
plain `git init`, so an existing `.gitignore` is honored; **without** a `.gitignore` everything in
the project (including `node_modules`) lands in the snapshot commit. Add a `.gitignore` first, or
disable the whole thing with `PI_GIT_AUTOINIT=0`. It never runs for `pi -m FILE...` mounts, with
`PI_ALLOW_GIT=0` (`.git` hidden), or in the fixed Pi home.

## Context compression (`billion-context`)

In-process Pi extension (no proxy/port). Adds `compress`, `decompress`, `search_context`,
`acp_status` plus `acp_delegate*` sub-agents, and **cancels Pi's own auto-compaction** while it
carries a session. State is pointed into the persistent home:

```
BILI_SESSIONS_DIR=/home/hostuser/.pi/agent/billion-context
BILI_CONFIG_FILE=/home/hostuser/.pi/agent/billion-context.json
```

In-session: `/acp` (context state), `/acp-cache` (prefix-cache hit rate). To turn **off**
delegate/sub-agent tools but keep compression, put this in `~/.pi/agent/billion-context.json`:

```json
{
  "providers": {},
  "pi": {
    "subagents": false
  }
}
```

A matching guard in `~/.pi/agent/APPEND_SYSTEM.md` helps the model respect it, e.g.:

> **Subagents and delegation** Do not start subagents or parallel model requests since most of
> the time this is running a local model which is limited. Run everything sequentially in the
> main session.

Compression costs model calls; a healthy session should still show 95–97% prefix-cache hit rate. To remove:
`pi remove npm:billion-context` (then `compaction.enabled: true` is correct again).

## npm cache

The wrapper sets `npm_config_cache=/opt/pi-packages/npm-cache` (inside the package volume) so
update checks no longer create `~/.npm` in the Pi home. Clean up once: `rm -rf ~/pi-home/.npm`;
clear from inside Pi: `npm cache clean --force`.

## How It Works (containers and paths)

Without `-m`, one fixed container per home (`pi-home-<hash>`); with `pi -m`, one per project
(`pi-<md5-hash>`). Project path = directory name + first 6 chars of the directory's MD5
(e.g. `/my-project_a1b2c3`); file-selected runs use `pi-files-...` with a hash of the file list.
`~/.pi/agent` is shared across containers; sessions are kept per context
(`~/.pi/agent/sessions/--<container-path>--`), and a temporary sessions root containing only the
active subdirectory is mounted over `~/.pi/agent/sessions` inside the container.

### Directory structure

```
~/.pi/
├── mounts.conf             # permanent extra mounts (optional)
├── agent/
│   ├── settings.json       # privacy, compaction, packages
│   ├── APPEND_SYSTEM.md    # persistent system-prompt addendum
│   ├── mcp.json            # MCP servers (built-in MCP)
│   ├── web-search.json     # SearXNG for pi-web-access
│   ├── auth.json           # provider credentials (created by /login)
│   ├── skills/llm-wiki/    # global on-demand wiki skill
│   └── sessions/--<project>--/
└── settings.json           # legacy path (unused)
```

The fixed working home lives outside this tree at `~/pi-home` (host).

## SearXNG details

`~/.pi/agent/web-search.json` pins `searchRouting.providers: ["searxng"]` (no external fallback)
and `ssrf.allowRanges` contains the narrow `192.168.178.2/32` entry required for the private
address. The instance must expose JSON (`json` under `search.formats` in SearXNG's `settings.yml`):

```bash
curl -sf 'http://192.168.178.2:4000/search?q=test&format=json' | jq '.results | length'
```

For hosted fallback use `"provider": "auto"` — queries may then leave your network. Existing
`web-search.json` files are never overwritten; update or delete old addresses manually.
If you prefer the lighter `@juicesharp/rpiv-web-tools`, remove `pi-web-access` first (duplicate
`web_search` tools); a config template is in `examples/pi/rpiv-web-tools/config.json`.

## File ignoring internals

Hiding is done by bind-mounting `/dev/null` (files) or an empty directory (directories);
`.gitignore`-style patterns are not evaluated. Add more exclusions to `PI_DEFAULT_IGNORED_FILES`
in the `pi` script, or keep secrets outside the project. `pi --show-hidden -m` removes only the
project-relative ignore mounts for one full-project run (selective file mounts unaffected;
overrides `PI_ALLOW_GIT=0`; hidden paths may contain credentials).

## MCP alternative

Pi 1.x has built-in MCP. If you prefer `pi-mcp-extension`: install it and disable the built-in
(`"extensions": ["-builtin:mcp"]` in settings.json); keep only one active.
Stdio/HTTP examples: [`examples/pi/agent/mcp.example.json`](../examples/pi/agent/mcp.example.json).

## Legacy migrations

- The legacy `@mariozechner/pi-coding-agent` volume install is replaced by `@earendil-works/pi-coding-agent`.
- An old `~/.pi/settings.json` is migrated to `~/.pi/agent/settings.json`.
- A `/share` patch from an older wrapper version is reverted automatically (one-time Pi reinstall).
- A managed `mounts.conf` entry still pointing to `~/documents/pi-home` is updated once to `~/pi-home`; data is not moved automatically.
- `~/.pi` created by an old root-based run: `sudo chown -R $(whoami):$(id -gn) ~/.pi`.
