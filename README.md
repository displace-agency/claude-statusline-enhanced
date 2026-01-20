# Claude Code Enhanced Statusline

A beautiful, informative statusline for Claude Code that displays real-time metrics about your conversation, including token usage, costs, cache efficiency, and more.

## Features

- **Token Usage**: Real-time token consumption with K/M formatting (e.g., "122.7K tokens")
- **Cost Tracking**: Shows API pricing and Max 20x monthly amortization with clear labels
- **Cache Efficiency**: Displays cache hit rate percentage in parentheses
- **Message Count**: Track number of messages with full "messages" label
- **Session Duration**: Precise timing with "time:" prefix including seconds (format: 1h 23m 45s)
- **Context Remaining**: Monitor available context with "context:" prefix and "left" indicator
- **Clean Design**: Consistent gray text with white bullet separators for readability
- **Git Integration**: Shows current branch, status, and sync info

## Preview

```
~/project on main •
[Sonnet 4.5 • 150 messages • time: 1h 23m 45s • 153.5K tokens (92% cached) • API $4.11 • Max 20x $0.34 • context: 52K left]
```

## Design Philosophy

The statusline follows a clean, minimal design philosophy:

- **Consistency**: All metrics use gray text for a unified, non-distracting appearance
- **Clarity**: Clear labels like "time:", "context:", and "messages" remove ambiguity
- **Precision**: Includes seconds in duration for accurate session tracking
- **Visual Hierarchy**: White bullet separators provide clear metric boundaries
- **Readability**: K/M suffixes prevent number clutter while maintaining accuracy

This design keeps you informed without pulling focus from your actual work.

## Metrics Explained

| Metric | Description | Display Format |
|--------|-------------|----------------|
| **Model** | Current Claude model (Sonnet/Opus/Haiku) | Gray text |
| **Messages** | Total messages in conversation | Gray text with white bullet separator |
| **Duration** | Actual elapsed time (first to last message) | Gray text (format: Xh Ym Zs, Ym Zs, or Zs) |
| **Tokens** | Total tokens consumed (K/M formatted) | Gray text |
| **Cache %** | Percentage of tokens from cache | Gray text in parentheses |
| **API Cost** | What this would cost on API pricing | Gray text with "API" label |
| **Max 20x Cost** | Monthly amortization value (API ÷ 12) | Gray text with "Max 20x" label |
| **Context Left** | Remaining context with "context:" prefix | Gray text with "left" suffix |

## Installation

### Requirements

- **jq**: JSON processor
- **bc**: Calculator for arithmetic
- macOS/Linux/WSL environment

Install dependencies:

```bash
# macOS
brew install jq bc

# Ubuntu/Debian
sudo apt-get install jq bc

# Fedora/RHEL
sudo dnf install jq bc
```

### Setup

1. **Clone the repository:**

```bash
git clone https://github.com/displace-agency/claude-statusline-enhanced.git
cd claude-statusline-enhanced
```

2. **Install the script:**

```bash
# Copy to Claude config directory
cp statusline.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

3. **Configure Claude Code:**

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/YOUR_USERNAME/.claude/statusline-command.sh"
  }
}
```

**Important:** Replace `YOUR_USERNAME` with your actual username, or use the full path from step 2.

4. **Restart Claude Code**

The statusline will appear at the top of your terminal on the next conversation.

## Configuration

### Max 20x Cost Calculation

The "Max 20x" cost uses monthly amortization: `API Cost ÷ 12`

This is based on the actual value multiplier of the Max 20x plan:
- Max 20x subscription: **$200/month**
- Maximum API value: **$2,400/month** (50 sessions × $48 max per session)
- Actual multiplier: **12x** ($2,400 ÷ $200)

This shows what fraction of your $200 monthly subscription each session represents. You can adjust this multiplier in the script if you're on a different plan:

- **Max 5x plan**: Change `/12` to `/3` (based on lower value multiplier)
- **Pro plan**: Change `/12` to `/1` (no multiplier)
- **Custom**: Set your own divisor based on your plan's value ratio

### Color Customization

The statusline uses a clean, minimal design with consistent gray text and white bullet separators. Colors are defined using ANSI escape codes:

**Current Design:**
- Metrics text: `\033[90m` - Bright Black (Gray)
- Bullet separators: `\033[37m` - White
- Git directory: `\033[32m` - Green
- Git branch: `\033[35m` - Magenta
- Git sync: `\033[36m` - Cyan

**Other Available Colors:**
- `\033[31m` - Red
- `\033[33m` - Yellow
- `\033[34m` - Blue
- `\033[1;37m` - Bold White

Modify the color codes in `statusline.sh` to match your preferences. The current design prioritizes consistency and readability with a subdued color palette that doesn't distract from your work.

## How It Works

The statusline script:

1. Receives JSON data from Claude Code via stdin containing all session metrics
2. Extracts token usage, costs, and context data from the `context_window` and `cost` fields
3. Counts messages by parsing the transcript file
4. **Calculates actual elapsed time** from first to last message timestamps (not wall-clock time, so pauses/idle time don't inflate the duration)
5. Formats duration, tokens, and context with K/M suffixes for readability
6. Calculates cache hit rate and Max 20x monthly amortization (API cost ÷ 12)
7. Displays all metrics with consistent gray text and white bullet separators
8. Updates automatically on every message in the conversation

**Important Notes:**
- **Model Display**: Shows your *current* model (e.g., "Haiku 4.5")
- **Cost Accumulation**: Costs accumulate across *all* models used in the session
  - If you switched from Sonnet → Haiku, costs reflect both
  - This is why you might see high costs with Haiku displayed
- **Time Calculation**: Uses message timestamps, not wall-clock time
  - Only counts time from first to last message
  - Doesn't inflate with long pauses or idle periods

## Troubleshooting

### Statusline not showing

1. Verify the script is executable:
   ```bash
   ls -l ~/.claude/statusline-command.sh
   ```

2. Check settings.json path is correct:
   ```bash
   cat ~/.claude/settings.json
   ```

3. Test the script manually:
   ```bash
   echo '{"workspace":{"current_dir":"'"$(pwd)"'"},"model":{"display_name":"Sonnet 4.5"},"transcript_path":"test.jsonl"}' | ~/.claude/statusline-command.sh
   ```

### Dependencies missing

```bash
# Check if jq is installed
which jq

# Check if bc is installed
which bc
```

### Colors not displaying

Some terminals may not support ANSI color codes. Try a different terminal or update your terminal emulator.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Ideas for Improvement

- [ ] Add tokens/minute burn rate
- [ ] Add average cost per message
- [ ] Support for custom pricing configurations
- [ ] Configuration file for easy customization
- [ ] Windows PowerShell version
- [ ] Weekly/monthly usage summaries
- [ ] Export session metrics to CSV/JSON
- [ ] Configurable cache efficiency thresholds with color indicators

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- Inspired by [claude-code-statusline](https://github.com/levz0r/claude-code-statusline)
- Built for the Claude Code community

## Support

If you find this helpful, please star the repository!

For issues or questions, please [open an issue](https://github.com/displace-agency/claude-statusline-enhanced/issues).

---

**Note:** This is a community project and is not officially affiliated with Anthropic.
