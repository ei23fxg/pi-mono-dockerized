# Example Pi configuration

This directory mirrors the user-level Pi agent directory (`~/.pi/agent`).
The wrapper seeds these files automatically when a file is missing; existing
files are never overwritten. You can also copy them by hand:

```bash
mkdir -p ~/.pi/agent
cp -r examples/pi/agent/. ~/.pi/agent/
```

## Contents

| Path | Purpose |
|---|---|
| `agent/settings.json` | Privacy defaults, automatic compaction, default packages |
| `agent/mcp.json` | Empty user-level MCP server list (built-in MCP support) |
| `agent/mcp.example.json` | Copy-ready MCP server examples |
| `agent/web-search.json` | `pi-web-access` configured for the local SearXNG |
| `agent/skills/llm-wiki/SKILL.md` | Global, on-demand LLM-wiki skill |
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

to start Pi and execute `/web` immediately. Alternatively start Pi normally
and enter `/web`; the command prints a local URL. The wrapper always uses Docker host networking
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
