# Example Pi configuration

This directory mirrors the user-level Pi agent directory (`~/.pi/agent`) and
the wrapper-level mount config. The wrapper seeds these files automatically
when a file is missing; existing files are never overwritten. You can also copy
them by hand:

```bash
mkdir -p ~/.pi/agent
cp -r examples/pi/agent/. ~/.pi/agent/
cp examples/pi/mounts.conf ~/.pi/mounts.conf
```

## Contents

| Path | Purpose |
|---|---|
| `agent/settings.json` | Privacy defaults, automatic compaction, default packages |
| `agent/mcp.json` | Empty user-level MCP server list (built-in MCP support) |
| `agent/mcp.example.json` | Copy-ready MCP server examples |
| `agent/web-search.json` | `pi-web-access` configured for the local SearXNG |
| `agent/APPEND_SYSTEM.md` | Persistent system-prompt addendum |
| `agent/skills/llm-wiki/SKILL.md` | Global, on-demand LLM-wiki skill |
| `mounts.conf` | Optional permanent extra mounts (`host:container[:ro]`) |
| `rpiv-web-tools/config.json` | Optional SearXNG config for `@juicesharp/rpiv-web-tools` |

## Defaults

`settings.json` contains:

- `enableInstallTelemetry: false` and `enableAnalytics: false`
- `compaction.enabled: true` (automatic compaction)
- `defaultProjectTrust: "never"` (project-provided extensions/skills stay off)
- `packages`: `pi-web-access` and `pi-webapp`

The wrapper additionally enforces `PI_TELEMETRY=0` and
`PI_WEB_SENTRY_ENABLED=false`. Update checks stay enabled so Pi can show new
versions. `/share` and `/bug` remain available as manual actions.

## Extra mounts and system prompt

`mounts.conf` holds permanent extra mounts. The wrapper also manages one
entry for the fixed Pi working home (`~/documents/pi-home` by default, mounted
at `/home/hostuser/pi-home`); Pi starts there unless `pi -m` mounts the current
project. Active user lines are mounted into every container on the next start:

```text
~/shared:/shared:ro
/srv/data:/data
```

`APPEND_SYSTEM.md` is appended to Pi's system prompt for every session. For a
complete replacement use `~/.pi/agent/SYSTEM.md`; for project-specific
instructions use a project-root `AGENTS.md` (project `.pi` files are hidden by
the wrapper).

With `pi -m DATEI...` only the listed files are mounted, at their relative
paths, instead of the whole current directory. This is useful for focused
work or for explicitly mounting a normally hidden file. Existing files are
consumed until the first option/non-file/`--`; use `--` before a prompt that
could be mistaken for a file name.

## MCP

Pi 1.x has built-in MCP support. Add servers with:

```bash
pi mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem .
pi mcp list
```

or edit `~/.pi/agent/mcp.json`. See `agent/mcp.example.json` for stdio and
HTTP examples. The separate `pi-mcp-extension` package is not required; if you
prefer it, install it and disable Pi's built-in MCP (see below).

## Search and web access

`pi-web-access` is installed by default and configured for:

```
http://192.168.178.2:4000
```

The config routes searches exclusively through `searxng`, so they stay on your network and never fall back to a hosted provider.
The `ssrf.allowRanges` entry allows this private IP. Check the instance:

```bash
curl -sf 'http://192.168.178.2:4000/search?q=test&format=json' | jq '.results | length'
```

SearXNG must have `json` enabled under `search.formats` in its `settings.yml`.

If you prefer the lighter `@juicesharp/rpiv-web-tools` package instead, remove
`pi-web-access` first so you do not end up with two `web_search` tools:

```bash
pi remove npm:pi-web-access
pi install npm:@juicesharp/rpiv-web-tools
mkdir -p ~/.config/rpiv-web-tools
cp examples/pi/rpiv-web-tools/config.json ~/.config/rpiv-web-tools/config.json
```

## LLM wiki

The `llm-wiki` skill is global and loads only when you ask for it:

```text
/skill:llm-wiki create an LLM wiki for this research topic
```

For automated codebase documentation, OpenWiki is an optional alternative:

```bash
pi install npm:openwiki
```

Then ask Pi to initialize or update the repository wiki. OpenWiki and the
skill can coexist; the skill is the lightweight, on-demand option.

## Web UI

`pi-webapp` is installed by default. Run

```bash
pi web
```

to start Pi in the fixed Pi home and execute `/web` immediately. Use
`pi -m web` to open the Web UI for the current project. Alternatively start Pi
normally and enter `/web`; the command prints a local URL. The wrapper always uses Docker host networking
(`--network host`) so the container's `127.0.0.1` is reachable from a browser on
the same Linux host. Git is enabled by default, including the pi-webapp Git
panel; set `PI_ALLOW_GIT=0` to hide `.git`, `.gitignore`, and `.gitmodules`.
Give Git an identity via your host `git config --global user.name/user.email`
or `PI_GIT_NAME` / `PI_GIT_EMAIL`.

## Optional: replace built-in MCP

If you want the feature set of `pi-mcp-extension` instead of Pi's built-in MCP:

```json
{
  "packages": ["npm:pi-mcp-extension@1.15.0"],
  "extensions": ["-builtin:mcp"]
}
```

Keep only one of them active to avoid duplicate MCP tools.
