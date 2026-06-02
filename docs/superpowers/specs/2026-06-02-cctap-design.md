# cctap — Design

**Status:** Draft
**Date:** 2026-06-02
**Author:** jcong830

## 1. Problem

When running multiple Claude Code (CC) sessions in parallel, it's easy to miss the moment when one session finishes its turn, asks for confirmation, or crashes. The user has to manually rotate through terminal windows to spot which one is idle. There is currently no in-tree mechanism to push attention back to the user.

## 2. Goal

Build a small macOS-only tool, **cctap**, that surfaces a native notification banner the moment a CC session needs attention, and lets the user click the banner to jump back to that exact Warp tab.

Concretely:

1. Notify when a CC session **finishes a turn** (Stop hook).
2. Notify when a CC session **needs user input** (Notification hook — permission prompts, idle waits).
3. Notify when a CC session **terminates abnormally** (SessionEnd hook with non-normal reason).
4. Identify *which* session via the working directory and a snippet of the most recent user message.
5. Skip notification if the user is already focused on that exact Warp tab.
6. Click the banner to bring that Warp tab to the foreground.
7. Ship as a Homebrew tap so install is `brew install jcong830/tap/cctap`.

## 3. Non-goals

- Cross-terminal support (iTerm2, Apple Terminal, VSCode). MVP is Warp-only; tab-focus is Warp-specific.
- Cross-platform (Linux, Windows).
- Push to phone / Slack / IM. Local macOS banner only.
- Per-session sound customization. All notifications are silent.
- Replacing or competing with existing hooks (`dcc`, `pii-detector`). cctap appends to the user's hooks array; it never overwrites others.

## 4. User Decisions (locked)

| Decision | Choice |
|---|---|
| Delivery channel | macOS native notifications via `terminal-notifier` |
| Trigger events | `Stop` + `Notification` + `SessionEnd` (abnormal reasons only) |
| Notification content | Project dir name + event type + recent user message summary |
| Click action | Focus the matching Warp tab |
| Sound | Silent (banner only) |
| Skip-when-focused | Yes — if the current Warp tab's working directory matches the event's cwd, no notification is sent |
| Distribution | Homebrew tap (`jcong830/homebrew-tap`) |

## 5. Architecture

A single entrypoint `bin/cctap` (bash) dispatches on its first argument:

- `stop` / `notification` / `session-end` — hook handlers (called by CC)
- `install` / `uninstall` — settings.json mutation
- `doctor` — environment self-check
- `test-notify` — fire a synthetic notification for manual smoke testing

Helper modules live in `lib/`, kept small and independently sourceable so they can be unit-tested with bats.

### 5.1 Repo layout

```
cctap/
├── bin/
│   └── cctap                  # entrypoint, ~150 LoC bash
├── lib/
│   ├── focus_check.sh         # osascript: is the frontmost Warp tab's cwd == event cwd?
│   ├── focus_warp.sh          # osascript: bring the Warp tab matching <cwd> to front
│   ├── transcript.sh          # jq pipeline: extract last user message snippet from transcript JSONL
│   └── notify.sh              # wrapper around terminal-notifier
├── share/
│   └── install/
│       ├── hooks-snippet.json # the three hook entries to merge into ~/.claude/settings.json
│       └── merge_hooks.sh     # idempotent jq-based merge
├── test/
│   ├── unit/                  # bats tests for lib/
│   ├── integration/           # fixture-driven dispatch tests with a fake terminal-notifier on $PATH
│   └── fixtures/              # sample hook payloads (stop, notification, session-end)
├── Formula/cctap.rb           # mirrored into homebrew-tap repo
└── README.md
```

The Homebrew tap repo (`homebrew-tap`) carries the canonical `cctap.rb`; the in-tree `Formula/cctap.rb` is a development convenience and CI artifact.

### 5.2 Data flow (Stop event)

```
CC hook fires with stdin JSON: {session_id, transcript_path, cwd, ...}
    │
    ▼
bin/cctap stop
    │
    ├─ parse payload (jq) → cwd, transcript_path, session_id
    ├─ focus_check.sh "$cwd"   → exit 0 silently if Warp's frontmost tab matches
    ├─ transcript.sh "$transcript_path" → last user message, truncated to ~60 chars
    ├─ assemble:
    │     title    = "$(basename $cwd) · 已完成"
    │     subtitle = "$user_msg_summary"
    │     message  = "Claude 已结束本轮"
    └─ notify.sh:
          terminal-notifier
            -title $title -subtitle $subtitle -message $message
            -group "cctap:$cwd"      # same-session notifications replace, not stack
            -sender com.warp.Warp    # icon attribution
            -execute "lib/focus_warp.sh '$cwd'"
```

### 5.3 Event-specific differences

| Event | Title suffix | Subtitle source | Message |
|---|---|---|---|
| `stop` | `· 已完成` | last user message in transcript | `Claude 已结束本轮` |
| `notification` | `· 待确认` | the `message` field in the hook payload itself (e.g. "Claude needs your permission to use Bash") | (empty — subtitle already carries the reason) |
| `session-end` (abnormal) | `· 异常退出` | last user message in transcript | `原因: $reason` |

`session-end` is filtered: skip when `reason ∈ {clear, logout}` (these are normal lifecycle endings the user initiated). Treat `prompt_input_exit`, `other`, and anything else as worth notifying.

### 5.4 Warp focus mechanism

`focus_check.sh "$cwd"` runs:

```applescript
tell application "Warp"
    if not frontmost then return "no"
    set wd to working directory of selected tab of front window
    if wd starts with "$cwd" then return "yes" else return "no"
end tell
```

Exit code 0 = "yes, skip notification".

`focus_warp.sh "$cwd"` runs:

```applescript
tell application "Warp"
    activate
    repeat with w in windows
        repeat with t in tabs of w
            if (working directory of t) starts with "$cwd" then
                set index of w to 1
                set selected of t to true
                return
            end if
        end repeat
    end repeat
end tell
```

Fallback when no tab matches: just `activate Warp`. README documents this as best-effort — Warp's AppleScript dictionary changes between versions and we cannot guarantee tab-level focus on every release.

## 6. Reliability

cctap runs inside CC's main loop. The contract:

- **All hook paths exit 0**, even on internal failure. CC must never break because the notifier broke.
- **All hook paths return in ≤ 1s.** Heavy work (e.g. transcript parsing) has a hard timeout; on timeout, degrade to title-only.
- **No stdout writes**, only stderr, to avoid polluting the hook protocol.

| Failure | Behavior |
|---|---|
| `terminal-notifier` missing | stderr warning, exit 0. `doctor` flags as fatal. Brew formula declares it as a runtime dependency, so this should not happen in practice. |
| `jq` missing | same as above. |
| `transcript_path` unreadable / malformed | subtitle degrades to empty; notification still fires. |
| Warp AppleScript fails (permission denied, version mismatch) | `focus_check` returns "no match", notification fires as normal; `focus_warp` degrades to a bare `activate Warp`. |
| Hook payload JSON malformed | exit 0, log to stderr. |
| Anything else | `trap` catches it, exit 0. |

Logs go to `~/.cache/cctap/cctap.log` with simple size-based rotation (truncate to last 1000 lines on each run if > 1 MB). `cctap doctor` tails recent entries.

## 7. Install / uninstall

`brew install jcong830/tap/cctap` puts `cctap` on PATH and installs the runtime deps (`terminal-notifier`, `jq`).

`cctap install`:

1. Back up `~/.claude/settings.json` to `~/.claude/backups/settings.<timestamp>.json`.
2. Merge `share/install/hooks-snippet.json` into the existing `hooks` object using jq. The three new entries (Stop, Notification, SessionEnd) are **appended** to their matching arrays, preserving every other hook the user already has (`dcc`, `pii-detector`, etc.).
3. Idempotent: if a cctap entry already exists for that event, skip it.
4. Print a checklist of permissions to grant: System Settings → Privacy & Security → Automation → Terminal/Warp → allow controlling Warp and System Events.
5. Run `cctap doctor` automatically to confirm everything works.

`cctap uninstall`:

1. Back up settings.json the same way.
2. Remove only the cctap entries (matched by command string containing `cctap`), leaving the rest untouched.
3. Print `brew uninstall cctap` as the next step.

## 8. Testing

| Layer | Tooling | Coverage |
|---|---|---|
| Unit | bats-core | transcript parsing, cwd-prefix matching, string truncation, the jq merge expression for settings.json |
| Integration | bats + a fake `terminal-notifier` injected on `$PATH` that records its argv | end-to-end dispatch from `cctap stop < payload.json`: correct title/subtitle/message/group/execute, no stdout, exit 0 |
| Manual smoke | `cctap doctor`, `cctap test-notify` | banner actually appears; click focuses Warp; per-event titles look right |
| CI | GitHub Actions on `macos-latest`: bats suite + `brew test cctap` | runtime correctness + formula health |

All integration fixtures live in `test/fixtures/` as real payload JSON captured from running CC sessions (with PII scrubbed).

## 9. Open items deferred to implementation

- Exact jq expression for the idempotent merge — write it test-first in unit tests.
- Whether to colorize/format the `doctor` output — purely cosmetic, decide during implementation.
- Log rotation policy details — start with a simple "truncate to last N lines if file > 1 MB" and revisit if it proves noisy.

These are tactical, not architectural. They don't change any of the contracts above.

## 10. Future (out of scope for v1)

- Other terminals (iTerm2, Apple Terminal). Would require pluggable `focus_*` backends keyed off `$TERM_PROGRAM` or similar.
- Phone push via Bark / IM webhooks as a fallback when the laptop is idle.
- A "mute project X for the next 30 minutes" CLI subcommand.
- Different sounds per event severity (the user explicitly opted out for v1).
