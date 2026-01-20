#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Debug: save input to file for troubleshooting (uncomment to debug)
# echo "$input" > /tmp/statusline-debug.json

# Extract values
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
transcript_path=$(echo "$input" | jq -r '.transcript_path')

# Extract token and cost data directly from Claude Code's provided data
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
context_used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
context_remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // 0')
context_limit=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
total_cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
session_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Use full path (replace home with ~)
dir="${cwd/#$HOME/~}"

# Calculate metrics from Claude Code's provided data
tokens=""
api_cost=""
sub_cost=""
message_count=""
session_duration=""

# Count messages from transcript if available
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    message_count=$(jq -rs '[.[] | select(.type == "user" or .type == "assistant")] | length' "$transcript_path" 2>/dev/null)
fi

# Format session duration from milliseconds
if [ "$session_duration_ms" -gt 0 ]; then
    duration_sec=$((session_duration_ms / 1000))
    if [ "$duration_sec" -ge 3600 ]; then
        hours=$((duration_sec / 3600))
        minutes=$(((duration_sec % 3600) / 60))
        seconds=$((duration_sec % 60))
        session_duration="${hours}h ${minutes}m ${seconds}s"
    elif [ "$duration_sec" -ge 60 ]; then
        minutes=$((duration_sec / 60))
        seconds=$((duration_sec % 60))
        session_duration="${minutes}m ${seconds}s"
    else
        session_duration="${duration_sec}s"
    fi
fi

# Calculate total tokens
if [ "$total_input" -gt 0 ] || [ "$total_output" -gt 0 ]; then
        input_tok=$total_input
        cache_read_tok=$cache_read
        cache_write_tok=$cache_create
        output_tok=$total_output

    # Calculate total tokens
    token_sum=$((input_tok + cache_read_tok + cache_write_tok + output_tok))

    # Format tokens with K/M suffix for readability
    if [ "$token_sum" -ge 1000000 ]; then
        tokens=$(echo "scale=1; $token_sum / 1000000" | bc)
        tokens="${tokens}M"
    elif [ "$token_sum" -ge 1000 ]; then
        tokens=$(echo "scale=1; $token_sum / 1000" | bc)
        tokens="${tokens}K"
    else
        tokens="${token_sum}"
    fi

    # Calculate cache hit rate percentage
    if [ "$token_sum" -gt 0 ]; then
        cache_hit_rate=$(echo "scale=0; ($cache_read_tok * 100) / $token_sum" | bc)
        if [ "$cache_hit_rate" -gt 0 ]; then
            cache_info="${cache_hit_rate}% cached"
        fi
    fi

    # Use provided API cost or calculate it
    if [ "$(echo "$total_cost_usd > 0" | bc)" -eq 1 ]; then
        api_cost=$(printf "\$%.2f" "$total_cost_usd")
        # Calculate approximate subscription equivalent (API cost / 20 for Max 20x plan)
        sub_calc=$(echo "scale=4; $total_cost_usd / 20" | bc)
        sub_cost=$(printf "\$%.2f" "$sub_calc")
    fi

    # Calculate context remaining
    if [ "$context_limit" -gt 0 ]; then
        context_remaining=$((context_limit * context_remaining_pct / 100))
        if [ "$context_remaining" -ge 1000 ]; then
            context_fmt=$(echo "scale=0; $context_remaining / 1000" | bc)
            context_left="${context_fmt}K"
        else
            context_left="${context_remaining}"
        fi
    fi
fi

# Get git branch if in a git repo
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)

    # Check for upstream tracking and commits ahead/behind
    upstream=""
    if git -C "$cwd" rev-parse --abbrev-ref @{u} > /dev/null 2>&1; then
        ahead=$(git -C "$cwd" rev-list --count @{u}..HEAD 2>/dev/null)
        behind=$(git -C "$cwd" rev-list --count HEAD..@{u} 2>/dev/null)

        if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
            upstream="↑${ahead}↓${behind}"
        elif [ "$ahead" -gt 0 ]; then
            upstream="↑${ahead}"
        elif [ "$behind" -gt 0 ]; then
            upstream="↓${behind}"
        fi
    fi

    # Check git status
    if ! git -C "$cwd" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null || \
       ! git -C "$cwd" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
        git_status="!"
        git_color="31"  # red
    elif [ -n "$(git -C "$cwd" -c core.useBuiltinFSMonitor=false ls-files --others --exclude-standard 2>/dev/null)" ]; then
        git_status="?"
        git_color="32"  # green
    else
        git_status=""
        git_color=""
    fi

    if [ -n "$branch" ]; then
        # Build the output with branch, optional upstream, optional status
        output="\033[32m${dir}\033[0m on \033[35m${branch}\033[0m"

        if [ -n "$upstream" ]; then
            output="${output}\033[36m${upstream}\033[0m"
        fi

        if [ -n "$git_status" ]; then
            output="${output}\033[${git_color}m${git_status}\033[0m"
        fi

        output="${output}\n[\033[90m${model}\033[0m"

        # Message count and duration
        if [ -n "$message_count" ] && [ "$message_count" -gt 0 ]; then
            output="${output} \033[37m•\033[0m \033[90m${message_count} messages\033[0m"
        fi
        if [ -n "$session_duration" ]; then
            output="${output} \033[37m•\033[0m \033[90mtime: ${session_duration}\033[0m"
        fi

        # Tokens with better formatting
        if [ -n "$tokens" ]; then
            output="${output} \033[37m•\033[0m \033[90m${tokens} tokens"

            # Cache info if significant
            if [ -n "$cache_info" ]; then
                output="${output} (${cache_info})"
            fi
            output="${output}\033[0m"
        fi

        # Costs with clear labels
        if [ -n "$api_cost" ] && [ -n "$sub_cost" ]; then
            output="${output} \033[37m•\033[0m \033[90mAPI ${api_cost}\033[0m \033[37m•\033[0m \033[90mSub ${sub_cost}\033[0m"
        elif [ -n "$api_cost" ]; then
            output="${output} \033[37m•\033[0m \033[90m${api_cost}\033[0m"
        fi

        # Context remaining if available
        if [ -n "$context_left" ]; then
            output="${output} \033[37m•\033[0m \033[90mcontext: ${context_left} left\033[0m"
        fi

        output="${output}]"
        printf "%b" "$output"
    else
        output="\033[32m${dir}\033[0m\n[\033[90m${model}\033[0m"

        # Message count and duration
        if [ -n "$message_count" ] && [ "$message_count" -gt 0 ]; then
            output="${output} \033[37m•\033[0m \033[90m${message_count} messages\033[0m"
        fi
        if [ -n "$session_duration" ]; then
            output="${output} \033[37m•\033[0m \033[90mtime: ${session_duration}\033[0m"
        fi

        # Tokens with better formatting
        if [ -n "$tokens" ]; then
            output="${output} \033[37m•\033[0m \033[90m${tokens} tokens"

            # Cache info if significant
            if [ -n "$cache_info" ]; then
                output="${output} (${cache_info})"
            fi
            output="${output}\033[0m"
        fi

        # Costs with clear labels
        if [ -n "$api_cost" ] && [ -n "$sub_cost" ]; then
            output="${output} \033[37m•\033[0m \033[90mAPI ${api_cost}\033[0m \033[37m•\033[0m \033[90mSub ${sub_cost}\033[0m"
        elif [ -n "$api_cost" ]; then
            output="${output} \033[37m•\033[0m \033[90m${api_cost}\033[0m"
        fi

        # Context remaining if available
        if [ -n "$context_left" ]; then
            output="${output} \033[37m•\033[0m \033[90mcontext: ${context_left} left\033[0m"
        fi

        output="${output}]"
        printf "%b" "$output"
    fi
else
    output="\033[32m${dir}\033[0m\n[\033[90m${model}\033[0m"

    # Message count and duration
    if [ -n "$message_count" ] && [ "$message_count" -gt 0 ]; then
        output="${output} \033[37m•\033[0m \033[90m${message_count} messages\033[0m"
    fi
    if [ -n "$session_duration" ]; then
        output="${output} \033[37m•\033[0m \033[90mtime: ${session_duration}\033[0m"
    fi

    # Tokens with better formatting
    if [ -n "$tokens" ]; then
        output="${output} \033[37m•\033[0m \033[90m${tokens} tokens"

        # Cache info if significant
        if [ -n "$cache_info" ]; then
            output="${output} (${cache_info})"
        fi
        output="${output}\033[0m"
    fi

    # Costs with clear labels
    if [ -n "$api_cost" ] && [ -n "$sub_cost" ]; then
        output="${output} \033[37m•\033[0m \033[90mAPI ${api_cost}\033[0m \033[37m•\033[0m \033[90mSub ${sub_cost}\033[0m"
    elif [ -n "$api_cost" ]; then
        output="${output} \033[37m•\033[0m \033[90m${api_cost}\033[0m"
    fi

    # Context remaining if available
    if [ -n "$context_left" ]; then
        output="${output} \033[37m•\033[0m \033[90mcontext: ${context_left} left\033[0m"
    fi

    output="${output}]"
    printf "%b" "$output"
fi
