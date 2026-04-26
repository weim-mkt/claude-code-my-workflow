#!/usr/bin/env bash
# Claude Code statusLine — mirrors ~/.claude/statusline-command.sh
# Segments: directory → git branch+status → model → effort → context % → time

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')

# Effort level: prefer input JSON, fall back to user settings.json
effort=$(echo "$input" | jq -r '.effortLevel // .effort_level // .model.effort // empty' 2>/dev/null)
if [ -z "$effort" ] && [ -f "$HOME/.claude/settings.json" ]; then
  effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

# Directory: truncate to 3 segments, prefer repo-relative
dir_display=""
if [ -n "$cwd" ]; then
  if [ -n "$project_dir" ] && [ "$project_dir" != "null" ] && [[ "$cwd" == "$project_dir"* ]]; then
    rel="${cwd#$project_dir}"
    rel="${rel#/}"
    project_name=$(basename "$project_dir")
    if [ -z "$rel" ]; then
      dir_display="$project_name"
    else
      dir_display="$project_name/$rel"
    fi
  else
    dir_display="$cwd"
  fi
  seg_count=$(echo "$dir_display" | tr -cd '/' | wc -c)
  if [ "$seg_count" -gt 2 ]; then
    dir_display="…/$(echo "$dir_display" | rev | cut -d'/' -f1-3 | rev)"
  fi
fi

# Git branch + status
git_info=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    modified=$(git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged=$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    status_str=""
    [ "$staged" -gt 0 ]    && status_str="${status_str}+${staged}"
    [ "$modified" -gt 0 ]  && status_str="${status_str}!${modified}"
    [ "$untracked" -gt 0 ] && status_str="${status_str}?${untracked}"
    if [ -n "$status_str" ]; then
      git_info=" $branch $status_str"
    else
      git_info=" $branch"
    fi
  fi
fi

# Time
time_str=$(date +%H:%M)

# Context usage
ctx_str=""
if [ -n "$used_pct" ]; then
  ctx_str=$(printf " ctx:%.0f%%" "$used_pct")
fi

# Output with ANSI colors
printf '\033[36m%s\033[0m' "$dir_display"
[ -n "$git_info" ] && printf ' \033[35m%s\033[0m' "$git_info"
[ -n "$model" ]    && printf ' \033[33m%s\033[0m' "$model"
[ -n "$effort" ]   && printf ' \033[32meffort:%s\033[0m' "$effort"
[ -n "$ctx_str" ]  && printf '\033[33m%s\033[0m' "$ctx_str"
printf ' \033[2;37m%s\033[0m' "$time_str"
printf '\n'
