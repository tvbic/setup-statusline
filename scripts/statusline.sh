#!/bin/bash
# statusline.sh - Claude Code status line script for macOS/Linux
input=$(cat)

# ---------------------------------------------------------------------------
# 取得目錄資訊
# ---------------------------------------------------------------------------
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
current_dir=$(basename "$cwd")

# ---------------------------------------------------------------------------
# Context Window 剩餘容量
# ---------------------------------------------------------------------------
remain_percent=$(echo "$input" | jq -r '.context_window.remaining_percentage // 100')

# ---------------------------------------------------------------------------
# 模型名稱（簡化顯示）
# ---------------------------------------------------------------------------
model_id=$(echo "$input" | jq -r '.model.id // "unknown"')
case "$model_id" in
    *"opus-4-6"*)   model_display="Opus 4.6"   ;;
    *"opus-4-5"*)   model_display="Opus 4.5"   ;;
    *"sonnet-4-6"*) model_display="Sonnet 4.6" ;;
    *"sonnet-4-5"*) model_display="Sonnet 4.5" ;;
    *"sonnet-4"*)   model_display="Sonnet 4"   ;;
    *"opus-4"*)     model_display="Opus 4"     ;;
    *"haiku-4-5"*)  model_display="Haiku 4.5"  ;;
    *"sonnet-3-7"*) model_display="Sonnet 3.7" ;;
    *"sonnet-3-5"*) model_display="Sonnet 3.5" ;;
    *"opus-3"*)     model_display="Opus 3"     ;;
    *)              model_display=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"') ;;
esac

# ---------------------------------------------------------------------------
# Rate-limit：從 API 快取取得 (每 15 秒更新)
# ---------------------------------------------------------------------------
secs_to_dhm() {
    local total=$1
    local d=$(( total / 86400 ))
    local h=$(( (total % 86400) / 3600 ))
    local m=$(( (total % 3600) / 60 ))
    local out=""
    [ "$d" -gt 0 ] && out="${d}d"
    [ "$h" -gt 0 ] && out="${out}${h}h"
    [ "$m" -gt 0 ] && out="${out}${m}m"
    [ -z "$out" ] && out="0m"
    echo "$out"
}

CACHE_PATH="$HOME/.claude/rate-limit-cache.json"
CACHE_MAX_AGE=15
rate_segment=""

# 判斷快取是否過期
need_refresh=true
if [ -f "$CACHE_PATH" ]; then
    cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_PATH" 2>/dev/null || stat -f %m "$CACHE_PATH" 2>/dev/null) ))
    if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
        need_refresh=false
    fi
fi

# 過期則呼叫 API 更新快取
if $need_refresh; then
    CRED_PATH="$HOME/.claude/.credentials.json"
    if [ -f "$CRED_PATH" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CRED_PATH" 2>/dev/null)
        if [ -n "$token" ]; then
            raw=$(curl -s --max-time 5 \
                -H "Authorization: Bearer $token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
            if [ -n "$raw" ]; then
                echo "$raw" > "$CACHE_PATH"
            fi
        fi
    fi
fi

# 讀取快取並組合 rate-limit 顯示
if [ -f "$CACHE_PATH" ]; then
    now=$(date +%s)

    util_5h=$(jq -r '.five_hour.utilization // empty' "$CACHE_PATH" 2>/dev/null)
    reset_5h=$(jq -r '.five_hour.resets_at // empty' "$CACHE_PATH" 2>/dev/null)

    util_7d=$(jq -r '.seven_day.utilization // empty' "$CACHE_PATH" 2>/dev/null)
    reset_7d=$(jq -r '.seven_day.resets_at // empty' "$CACHE_PATH" 2>/dev/null)

    if [ -n "$util_5h" ] && [ -n "$util_7d" ]; then
        pct_5h=$(( 100 - ${util_5h%.*} ))
        pct_7d=$(( 100 - ${util_7d%.*} ))

        rem_5h=""
        if [ -n "$reset_5h" ]; then
            reset_epoch=$(date -d "$reset_5h" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${reset_5h%%.*}" +%s 2>/dev/null)
            if [ -n "$reset_epoch" ]; then
                secs_left=$(( reset_epoch - now ))
                [ "$secs_left" -lt 0 ] && secs_left=0
                rem_5h="($(secs_to_dhm $secs_left))"
            fi
        fi

        rem_7d=""
        if [ -n "$reset_7d" ]; then
            reset_epoch=$(date -d "$reset_7d" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${reset_7d%%.*}" +%s 2>/dev/null)
            if [ -n "$reset_epoch" ]; then
                secs_left=$(( reset_epoch - now ))
                [ "$secs_left" -lt 0 ] && secs_left=0
                rem_7d="($(secs_to_dhm $secs_left))"
            fi
        fi

        rate_segment=$(printf "5h:%d%%%s 7d:%d%%%s" "$pct_5h" "$rem_5h" "$pct_7d" "$rem_7d")
    fi
fi

# ---------------------------------------------------------------------------
# Git 分支
# ---------------------------------------------------------------------------
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    [ -n "$branch" ] && git_info=$(printf " git:(%s)" "$branch")
fi

# ---------------------------------------------------------------------------
# 組合輸出
# ---------------------------------------------------------------------------
if [ -n "$rate_segment" ]; then
    printf "Remaining: %d%% | %s | %s | %s%s" "$remain_percent" "$rate_segment" "$model_display" "$current_dir" "$git_info"
else
    printf "Remaining: %d%% | %s | %s%s" "$remain_percent" "$model_display" "$current_dir" "$git_info"
fi
