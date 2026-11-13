# TODO — pi-mono-dockerized: Plan-Modus, Quality Gate, Git-Checkpointing

Ausgangspunkt: `ade4c6a "fix"` (= `origin/main`). Umsetzung in einem Commit pro
Teilschritt (`git log`), Prüfungen: `bash -n`, `shellcheck` 0.10.0 (0 Meldungen),
generiertes Dockerfile per Fake-Docker gerendert, Auto-Init gegen Fake-`pi` getestet.

---

### Phase 1: Werkzeuge & Addons vorinstallieren

- [x] **1.1. Grundwerkzeuge im Container sicherstellen**
  * Soll: `git`, `curl` sowie Compiler/Linter für die Sprachen sind im Image.
  * Umgesetzt/geprüft: Das eingebettete Dockerfile (`pi:170-181`) bringt bereits
    `git`, `gh`, `curl`, `wget`, `make`, `gcc/g++`, `cmake`, `clang/lld`,
    `python3` + uv, `golang`, `php-cli`/Composer, Rust (rustup inkl. `rustfmt`/`clippy`)
    und `node` 22 mit. Ergänzt: **`shellcheck`** (bislang gab es für Shell-Aufgaben
    kein Prüfwerkzeug) — `PI_BUILD_STAMP` 5 → 6, bestehende Setups bauen beim nächsten
    Start automatisch neu.
- [x] **1.2. Plan-Modus Addon installieren**
  * Umgesetzt als Default-Paket des Wrappers statt `RUN npm install -g` im Dockerfile:
    Pi-Pakete leben im persistenten `~/.pi` (`pi install`), nicht im Image — sonst keine
    Updates über `pi update --extensions` und für jedes Upgrade ein Image-Rebuild.
    `@narumitw/pi-plan-mode` (aktuell 0.60.1, benötigt Pi ≥ 0.80.6; installiert ist 1.5.2)
    in `PI_DEFAULT_PACKAGE_NAMES`, `PI_PACKAGES_STAMP="2026-11-13-planmode"` → bestehende
    Volumes bekommen das Paket beim nächsten Start. `pi-webapp` war schon Default.
    Nebenbei: Pin/Skip-Auswertung konnte Scoped-Namen nicht (`%%@*` schnitt den Scope ab) —
    Name/Version werden jetzt am letzten `@` getrennt.

---

### Phase 2: Git-Automatik beim Start

- [x] **2.1. Git-Auto-Init im Startup verankern**
  * Kein `entrypoint.sh` in diesem Repo: der vom Wrapper gebaute Container-Befehl
    (`pi:770-776`) ist der Einstieg. Dort, vor `exec pi`:
    `git init -q && git add -A && git commit -qm 'checkpoint: initial workspace snapshot'`.
  * Bedingungen: nur voller Projekt-Mount (`pi -m` ohne Dateiargumente), nur wenn `.git`
    sichtbar ist (`PI_ALLOW_GIT=1`), abschaltbar mit `PI_GIT_AUTOINIT=0`.
  * Identität wird jetzt immer durchgereichen (`GIT_AUTHOR_*`/`GIT_COMMITTER_*`), Fallback
    `Pi Agent <agent@pi.dev>` — ohne Identität scheitert jeder Commit im Container.
  * Getestet (Fake-`pi`, generierten Befehl ausgeführt): Snapshot + `.gitignore`
    eingehalten, bestehendes Repo unverändert, bei selektivem Mount / `PI_ALLOW_GIT=0` /
    `PI_GIT_AUTOINIT=0` kein Repo, leeres Projekt startet trotzdem.
- [x] **2.2. Port für `pi-webapp` exposen**
  * Erledigt/obsolet: es gibt kein Compose und kein `-p` — der Wrapper läuft immer mit
    `--network host`, und `pi-webapp` bindet Loopback auf einem frei gewählten Port
    (nicht 3000). Eine Mapping-Zeile wäre wirkungslos. README (Web-UI) sagt das jetzt
    explizit, damit es nicht als fehlend gelesen wird.

---

### Phase 3: Quality Gate & To-Do-Workflow im System Prompt

- [x] **3.1. Arbeitsregeln für To-Dos definieren**
  * Verankert in `examples/pi/agent/APPEND_SYSTEM.md` (Abschnitt „Working loop“):
    `TODO.md` im Projekt-Root mit `- [ ]`, Start mit `- [~]`, fertig mit `- [x]`,
    erledigte Einträge behalten. Dazu: `/plan` vor nicht-trivialen Änderungen.
- [x] **3.2. Das Quality Gate verankern**
  * Selber Block: vor jedem `- [x]` das passende Prüfkommando via bash
    (`bash -n`, `shellcheck`, `tsc --noEmit`, `cargo check`, `pytest`), `[x]` nur bei
    Exit-Code 0, sonst fixen und erneut prüfen. `shellcheck` dafür jetzt im Image (1.1).
- [x] **3.3. Git-Checkpoints nach Teilschritten**
  * Selber Block: `git add -A && git commit -m "checkpoint: …"` nach jedem grünen Schritt;
    die Auto-Init-Basis liefert 2.1.
  * Hinweis für Bestandssetups: Seeds werden nur bei fehlender Datei geschrieben — ein
    bestehendes `~/.pi/agent/APPEND_SYSTEM.md` behält seinen Inhalt, der Block muss also
    übernommen werden (README, Abschnitt „Default Pi setup“). Plan-Mode kommt dort
    automatisch (Stamp-Bump aus 1.2). Ein `planModeOn`-Key existiert nicht und wurde nie
    gesedet.

---

### Phase 4: Überprüfung im Browser (`pi-webapp`) — auf diesem Host nicht möglich

Hier gibt es kein Docker (nur ein Fake-Docker für die Wrapper-Tests oben), deshalb sind
die vier Punkte Handarbeit am Docker-Host:

- [ ] **4.1. Testlauf starten** — erst Image-Rebuild wegen Stamp 6 (beim ersten `pi`
      automatisch), danach `pi web` bzw. `pi -m web`; die gedruckte
      `http://127.0.0.1:<port>/#<token>`-URL im Browser öffnen (Port ist nicht 3000).
- [ ] **4.2. Plan-Modus testen** — `/plan "Erstelle ein kleines Python-CLI-Tool mit Tests"`:
      Pi erkundet nur lesend, `edit`/`write` sind blockiert; `/plan exit` beendet den Modus.
- [ ] **4.3. Ausführung freigeben & Workbench beobachten** — nach der Freigabe in der
      Web-App die entstehende `TODO.md` ansehen: Häkchen `- [~]` → `- [x]`, Prüfkommando
      via bash, danach `git log` mit `checkpoint: …`-Commits.
- [ ] **4.4. Nebenbefund prüfen** — `/plan` in der Slash-Command-Liste sichtbar?
      Start in einem Ordner ohne Repo: `git log` zeigt „checkpoint: initial workspace snapshot“?
