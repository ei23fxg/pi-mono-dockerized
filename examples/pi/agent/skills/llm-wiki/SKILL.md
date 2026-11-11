---
name: llm-wiki
description: Build, extend, query, and lint a persistent LLM-maintained Markdown wiki from raw sources. Use when the user asks to create an LLM wiki, ingest articles or notes into a wiki, query an existing wiki, or run a wiki health check.
---

# LLM Wiki

This skill implements the pattern described by Andrej Karpathy in
<https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>:
instead of retrieving raw documents again for every question, maintain a
persistent, interlinked Markdown wiki that is compiled once and kept current.

Use this skill only when the user explicitly wants a wiki. Do not create one
for an ordinary question.

## Default layout

Create this inside the current project unless the user chooses another place:

```
llm-wiki/
├── SCHEMA.md          # conventions for this wiki (co-evolve with the user)
├── raw/               # immutable source material; never edit these files
│   └── assets/        # downloaded images and attachments
└── wiki/
    ├── index.md       # content catalogue: every page + one-line summary
    ├── log.md         # append-only chronological journal
    ├── overview.md    # evolving synthesis / entry point
    ├── sources/       # one summary page per raw source
    ├── entities/      # people, organisations, products, places, …
    └── concepts/      # topics, themes, methods, comparisons, …
```

If the project already has a wiki, read `SCHEMA.md`, `wiki/index.md`, and the
last entries in `wiki/log.md` before changing anything.

## First setup

1. Confirm the domain, the wiki location, and which raw sources are in scope.
2. Create the directories above.
3. Write `SCHEMA.md` together with the user. It should define:
   - the domain and the questions the wiki should answer;
   - page types and naming rules;
   - frontmatter fields and link conventions;
   - how contradictions and uncertainty are recorded;
   - what counts as a source and what must never be ingested.
4. Add an `overview.md` that states the current scope and open questions.
5. Keep `index.md` and `log.md` up to date from the first ingest onward.

## Ingest

When the user drops a source into `raw/` or asks to process one:

1. Read the source completely. For PDFs or web pages, use `fetch_content` if a
   local copy is unavailable, then save the readable text under `raw/`.
2. Discuss the key takeaways, uncertainties, and contradictions with the user.
3. Write a source summary page under `wiki/sources/` with a link back to the
   raw file.
4. Update every affected entity and concept page. A single source may touch
   10–15 pages.
5. Note contradictions explicitly, with links to both claims.
6. Update `wiki/index.md`.
7. Append a log entry in the form:

   ```
   ## [YYYY-MM-DD] ingest | Source title
   - files touched: …
   - key change: …
   ```

8. Re-read the changed pages and fix broken links. Do not touch `raw/`.

Prefer one source at a time unless the user asks for a batch. Ask before
deleting or renaming existing pages.

## Query

1. Read `wiki/index.md` first.
2. Open only the pages that look relevant; follow links as needed.
3. Answer with citations to wiki pages, and to raw sources where appropriate.
4. If the answer is a useful comparison, analysis, or synthesis, offer to file
   it back into the wiki as a new page. Update the index and log if the user
   agrees.

Do not answer from the raw sources alone when the wiki already covers the
topic; the wiki is the curated layer.

## Lint

When asked to health-check the wiki, look for:

- contradictions between pages;
- claims superseded by newer sources;
- orphan pages with no inbound links;
- concepts mentioned repeatedly but missing their own page;
- missing cross-references;
- gaps that could be filled with a targeted web search;
- stale `updated` dates and missing source links.

Report findings as a prioritized list. Fix safe issues (links, index, log)
directly; ask before rewriting substantive claims.

## Conventions

- Every page starts with YAML frontmatter:

  ```yaml
  ---
  title: Page title
  type: source | entity | concept | overview
  updated: YYYY-MM-DD
  sources: [../raw/example.md]
  tags: [example]
  ---
  ```

- Use relative Markdown links between pages.
- Cite raw sources with a relative link, for example
  `[Smith 2025](../../raw/smith-2025.md)`.
- Mark uncertainty as `> **Uncertain:** …` and contradictions as
  `> **Conflict:** …`.
- Keep pages focused; split a page when it starts covering several concepts.
- The wiki is a Git-friendly directory of Markdown. Suggest a commit after a
  substantial ingest or lint pass.

## Optional automation

For a fully automated codebase wiki, the user can additionally install
OpenWiki (`pi install npm:openwiki`). This skill is intentionally lightweight
and works on any kind of source material.
