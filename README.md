# Claude Code Enhanced Statusline

A two-line statusline for Claude Code built around one question: **how much of my plan have I already spent, and what is spending it?**

It reads the rate-limit figures Claude Code passes to the statusline, so the percentages are the real ones from your plan, not an estimate.

## Preview

```
~/websites/my-site · Opus 5 1M · high · think
ctx ▓▓▓░░░░░░░ 31% of 500K · 5h 12% ↻2h41m · week 38% ↻3d14h · here +4%
```

## What it shows

**Line 1 — where you are and what is running**

| Field | Meaning |
|---|---|
| Directory | Working directory, `~` shortened |
| Model | Current model, `1M` kept when on the long-context variant |
| Effort | Effort level, when set |
| `think` | Shown when extended thinking is on |

**Line 2 — the four numbers that should change your behaviour**

| Field | Meaning |
|---|---|
| `ctx` | Context used, as a bar and a percentage. Measured against `autoCompactWindow` when you have set one, otherwise the model's window |
| `5h` | Five-hour rate limit used, with time until it resets |
| `week` | Weekly rate limit used, with time until it resets |
| `here` | **Weekly percent burned since this session opened.** The one number that tells you what the current conversation is costing |

Colour is the same everywhere: green under 60%, amber 60-85%, red above.

## What it deliberately leaves out

Earlier versions showed API dollar cost, a Max 20x amortization, message count, session duration and lines changed. All of it is gone.

On a subscription plan the dollar figure is not what runs out — the percentage is. Showing a cost in dollars invites you to reason about the wrong number. Message counts and durations are activity, not consumption; a short conversation over a large codebase costs far more than a long one over a small file.

## The `here` metric

`here` is the point of the whole thing. Context is re-sent on every message, so a conversation gets more expensive the longer it runs, even when the questions stay small. `here` makes that visible: when it climbs quickly, the fix is usually to finish and open a fresh session rather than to ask less.

It is stored per session under `~/.claude/.statusline-sessions/`, one small file per session, pruned automatically after 14 days. If the weekly counter resets mid-session, the baseline re-anchors instead of pinning at zero.

## Installation

### Requirements

`bash` and `jq`.

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Fedora/RHEL
sudo dnf install jq
```

### Setup

```bash
git clone https://github.com/displace-agency/tool-claude-statusline-enhanced.git
cd tool-claude-statusline-enhanced
chmod +x statusline.sh
```

Point Claude Code at it in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/tool-claude-statusline-enhanced/statusline.sh"
  }
}
```

Use an absolute path. Restart Claude Code, or start a new session, to pick it up.

### Updating

```bash
cd /path/to/tool-claude-statusline-enhanced
git pull
```

No other step. The settings entry keeps pointing at the same file.

## Recommended companion setting

```json
{
  "autoCompactWindow": 200000
}
```

`autoCompactWindow` caps how large a conversation grows before Claude Code compacts it. A high value means every message re-sends a very large context. Setting it lower is usually the single biggest reduction in consumption available, and the statusline's `ctx` bar measures against it so you can see the effect.

## Troubleshooting

**Statusline is blank.** The script exits quietly when it cannot parse the payload, so nothing renders rather than showing a broken line. Check `jq` is installed and on `PATH`.

**Rate limit fields missing.** `5h` and `week` are hidden when the payload does not carry them. Older Claude Code versions do not send them; update Claude Code.

**Inspect the payload.** Run with `STATUSLINE_DEBUG=1` set and the raw JSON is written to `/tmp/statusline-payload.json`. Read that file rather than guessing at field names.

## Licence

MIT. See `LICENSE`.
