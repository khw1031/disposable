---
title: Schedule coding-agent runs in the Herdr desktop app
summary: A Herdr mod that starts a coding agent with a set first message at a set time, from Herdr's own timer or from a machine's crontab, on this computer or a connected machine, through a sidebar row and a jobs tab.
type: recipe
mode: local
device: mac
language: en
license: CC0-1.0
maintainers: khw1031
author: khw1031
added: 2026-11-18
cost: Free to build and run. Each run uses your coding agent's own plan or API credits.
tags: herdr, herdr-mod, scheduler, crontab, coding-agent, claude-code, automation
origin: https://github.com/khw1031/herdr-share/tree/main/job-scheduler
---

## Before you start

- The Herdr desktop app on macOS (used with Herdr 0.1.16) and a coding agent you run in it. The default agent command is `claude`. In Machine mode the first message is passed as the command's last argument, the way `claude "<task>"` takes it.
- For Machine mode: `crontab` on the machine that runs the job, and herdr-core's `hc` at `$HOME/.local/bin/hc` there.
- To see the jobs saved on your other Herdr machines: `python3` on those machines.
- A project folder the agent has already opened and trusted once. Agents stop at a folder-trust prompt in a new folder, and Claude asks every time in the home folder.

## Quick start

1. Open Herdr and start your coding agent in a terminal there.
2. Ask it to add `herdr.dev/mods/khw1031/job-scheduler`. It reads the files and tells you what they run, then copies the mod into `~/.config/herdr-app/mods/`. It puts the mod in a cloned layout's sidebar footer and runs `herdr-app check`. To build it from scratch instead, give your agent the Rebuild section below.
3. Click "Scheduled jobs" at the bottom of the sidebar, then "+ Add job". Fill in a name, time and days, folder, agent command and first message, pick App or Machine, and Save.

## Rebuild

Build one Herdr mod named `job-scheduler` in `~/.config/herdr-app/mods/job-scheduler/`. Read `~/.config/herdr-app/AGENTS.md` and `herdr.d.ts` first. Use `theme()` colors only, `cx.timer` (never `setTimeout`), and `if (checking()) return;` before any timer or side effect in `init`. Split the code into five files:

- `main.js`: the `View`;
- `sidebar.js`: the footer;
- `core.js`: storage, schedule times, App runs, crontab, opening the tab;
- `api.js`: one `mutate()` used by the screen and the API, plus the request handler;
- `catalog.js`: the reader for other machines.

Also add three 24×24 stroke icons (`clock.svg`, `settings.svg`, `plus.svg`; Herdr's `workspace-chrome` ships the same Lucide files) and `mod.json` `{ "place": "none" }`.

### Two views from one mod

- `props().view === "sidebar"` draws the sidebar footer. Anything else draws the "Scheduled jobs" tab.
- Placement: clone Herdr's `main` layout (`layout.clone`). Replace the sidebar footer block `{ "mod": "workspace-chrome", "props": { "footer": true } }` (69px) with `{ "mod": "job-scheduler", "props": { "view": "sidebar" } }` at 101px.
- **Footer.** `chrome` background, a 1px `border` line on top, padding 8/4/8, 13px text. Three 28px rows (radius 8, a 14px icon, `muted` text; on hover `hover` background and `foreground` text):
  - "Scheduled jobs": opens the tab, or goes to the one already open (`tab.new {mod: "job-scheduler", name: "Scheduled jobs"}`). It shows a red `blocked` badge counting jobs that need attention, then the total in `dim`;
  - "Settings": `run("app.settings")`, with a 6px `accent` dot when `updates().app.ready`;
  - "Add machine": `mod.open {name: "machine-add"}`, in `dim`.

  Below 160px sidebar width, each row is a 32px icon cell with a tooltip, and the marks become dots on the icon.
- **Tab.** Its parts, top to bottom:
  - a header "Scheduled jobs" with the buttons "Refresh lists" and "+ Add job";
  - machine chips: "All", then each of `machines()`, with a status dot (`done` ready, `working` loading, `blocked` unavailable) and a job count;
  - the add form;
  - cards for the jobs saved here;
  - read-only sections for other machines' saved jobs;
  - when one machine is selected, its `crontab -l` (comments dropped) with Refresh;
  - "Recent runs (app mode)", the last 8.

### A job

Store jobs in shared state `job-scheduler/jobs` as `{ id: "job-<ms>", name, machine (null = this computer), type: "repeat" | "once", time "HH:MM", days [0..6] (0 = Sunday) | date "YYYY-MM-DD", mode: "app" | "machine", folder, agent, task, enabled, createdAt, lastSlot, lastRunAt, done? }`.

Other shared keys:

- `job-scheduler/runs`: 30 kept;
- `job-scheduler/version`: a counter, raised on every save;
- `job-scheduler/focus`: the sidebar asking the tab to show something;
- `job-scheduler/api-lock` and `job-scheduler/api-claim`.

**Form fields:**

- Name;
- Type: Repeat or Once;
- Date (Once, default tomorrow), Time (default 09:00), Days (seven 30px chips Su…Sa, all on);
- Run mode: App or Machine;
- Folder (required);
- Agent command (default `claude`);
- Task (the first message).

**Card:**

- name, mode and state badges (Done / On / Off);
- "Daily 09:00 · next MM.DD(Dd) HH:MM · last run …";
- crontab state for Machine jobs, "Missed: … (the app was closed)";
- "Last run: <status>" with "Open tab";
- "Saved in: This computer · Runs on: <machine>", then agent · folder, then task;
- the buttons Run now, Turn off / Turn on, Skip missed run, Delete.

### Saving (one `mutate(action, id, input, expectedVersion)` for the form and the API)

1. Refuse when `job-scheduler/api-lock` is set. Otherwise set it, and clear it in `finally`.
2. Refuse when `expectedVersion` is not the current version.
3. Validate the job:
   - known fields only;
   - `name`, `folder`, `agent` and `task` must be non-empty; `name` ≤120, `task` ≤100,000;
   - `machine` is null or a string, and `mode` and `type` must be known;
   - `time` is HH:MM;
   - Repeat needs unique days 0–6. Once needs a real date in the future;
   - agent commands with `--dangerously-bypass…` or `--permission-mode bypassPermissions` are refused, and a `codex` command must include `--no-daemon`;
   - an optional `timezone` must give the same `date +%z` on the run machine, or the save fails (it never converts);
   - resolve the folder on the run machine with `exec("sh", ["-c", 'p="$1"; case "$p" in "~"|"~/"*) p="$HOME${p#"~"}";; esac; [ -d "$p" ] && cd "$p" && pwd -P', "sh", folder], { on: machine })`, and fail if it does not exist.
4. Refuse a duplicate name on the same run machine. `update` cannot change machine or mode, and a changed time or days resets `lastSlot` and `done`.
5. Check the version again, since the folder check awaited.
6. Install or remove the crontab entry for Machine jobs (below).
7. Save the list and raise the version.

### App mode

Every 30 seconds each live copy, the footer and the tab, ticks. For each enabled App job, find the last scheduled time at or before now. Skip it when:

- it equals `lastSlot`;
- it is before `createdAt`;
- it is more than 10 minutes old.

Otherwise start it:

1. Write `lastSlot` and `lastRunAt` first, so a second copy skips it.
2. Split `agent` on spaces into `argv`.
3. Open the job in the run machine's space named "Jobs": `run("tab.new", { space, name, folder, argv, task, focus: false })`, or, when that space does not exist yet, `run("space.new", { name: "Jobs", tab: name, folder, argv, task, machine, focus: false })`. Create at most one Jobs space per machine per tick.
4. Add the run to recent runs.
5. Post `notify({ title: "Job started: <name>", action: space.select })`.

A Once job becomes `done` and off. Runs later than 10 minutes show as Missed. "Skip missed run" sets `lastSlot`. Run now does the same start with no slot, in either mode.

### Machine mode

1. Write `~/.herdr-jobs/<id>.sh` on the run machine with `exec("sh", ["-c", 'mkdir -p "$HOME/.herdr-jobs" && printf "%s" "$1" > "$HOME/.herdr-jobs/$2.sh" && chmod 700 "$HOME/.herdr-jobs/$2.sh"', "sh", script, id], { on })`. The script:
   - starts with `#!/bin/sh` and a `# herdr-job:<id>` comment;
   - for Once, `[ "$(date +%Y-%m-%d)" = '<date>' ] || exit 0`;
   - sets `NAME='j<last 6 digits of id>-'"$(date +%m%d%H%M)"`;
   - runs `"$HOME/.local/bin/hc" run --bg --no-parent --name "$NAME" --cwd '<folder>' <argv…> '<task>' >>"$HOME/.herdr-jobs/<id>.log" 2>&1`, with every value single-quoted;
   - for Once, ends by removing its own crontab line and `rm -f "$0"`.
2. Add the crontab line by keeping every other line: `{ crontab -l 2>/dev/null | grep -v "# herdr-job:$1\$"; printf "%s\n" "$2"; } | crontab -`. The line is `M H * * <days or *> /bin/sh "$HOME/.herdr-jobs/<id>.sh" # herdr-job:<id>`; for Once, `M H D Mo *`.
3. Turn off and Delete remove the line and the script. Turn on validates again and reinstalls.
4. macOS cron cannot edit crontab, so 90 seconds after a Once time the app removes the line itself and marks the job done.
5. To find a Machine run, take the newest terminal in `terminals()` whose name starts with `j<6 digits>-`. "Open tab" runs `terminal.keep {place: "tab"}`.

### Statuses and attention

"Last run" follows the agent's status:

- `working`: "Working", in `working`;
- `blocked`: "Needs you", in `blocked`;
- `done`: "Done", in `done`;
- `idle`: "Idle", in `idle`;
- none yet: "Started", in `dim`.

An App job's agent is the last tab named after the job in its Jobs space. A job needs attention when a run was missed or its agent is blocked.

### Other machines (read-only)

Every 60 seconds while the tab is open, run `exec("python3", ["-c", reader], { on: machine, timeout: 15000 })` on each named machine. The reader:

- opens `shared.json` in that Herdr home (`$HERDR_APP_HOME`, else `~/.config/herdr-app`);
- reads `job-scheduler/jobs`;
- prints `{ host, savedAt, jobs }`, with each task cut to 240 characters and the next run worked out in that machine's local time.

Show a failure apart from zero jobs, and keep the last list marked as old. Never copy or run those jobs.

### Agent API (protocol 1)

A caller creates `<appHome>/job-scheduler-api/<32 hex>.request.json`, holding `{ protocol: 1, request_id, action, id?, job?, expectedVersion? }`. It then runs `herdr-app do job-scheduler.api:<id>`. The command arrives through `nextCommand()` as `api:<id>`.

1. If a response already exists, do nothing.
2. Claim the id through shared `job-scheduler/api-claim`. While another id is claimed, answer `{ ok: false, error: "another API request is in progress" }`.
3. Answer in `<id>.response.json` with `writeTextFile(path, json, null)`.

Actions:

- `list`: version, jobs without task text but with `taskLength` and `nextRunAt`, and the machine's offset;
- `catalog`: `list` plus the other machines' lists;
- `get`: one full job;
- `add`, `update`, `enable`, `disable`, `remove`: these go through `mutate`.

### Check

`herdr-app check ~/.config/herdr-app/mods/job-scheduler` passes. It renders the tab only, so try the footer in the app.

Then:

- An App job two minutes ahead opens a tab in "Jobs" and posts "Job started".
- A Machine job adds a `# herdr-job:<id>` line to `crontab -l`, and Turn off removes it.
- A `list` request answers `"ok": true`.

## Limits

- Runs programs on your machines without asking each time: `sh`, `crontab`, `python3` on other machines, and `hc run --bg`, which starts an agent with your task while nobody watches. Read the files before you add it.
- Machine mode changes the run machine's crontab and writes `~/.herdr-jobs/<id>.sh`. The `.log` next to it is never deleted.
- App mode runs only while Herdr is open with the footer or the tab shown. Runs more than 10 minutes late are marked Missed, not run.
- Times are the run machine's local time. No time-zone conversion.
- Jobs are kept per Herdr app and do not sync between machines. Other machines' jobs are shown read-only.
- The agent command is split on spaces, so it cannot hold quoted arguments.
- Built and used on macOS with Herdr 0.1.16. Herdr changes quickly, so newer versions may need the rebuild instead of the files.
