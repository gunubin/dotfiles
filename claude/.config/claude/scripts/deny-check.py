#!/usr/bin/env python3
"""
Claude Code Hook: Bash Command Validator (PreToolUse)

settings.json の deny リストを読み込み、チェインコマンド（&&, ;, ||）も
分割して各セグメントを検証する。

Exit code:
  0 = 許可
  2 = ブロック（stderrをClaudeに返す）
"""

import json
import re
import sys
from fnmatch import fnmatch
from pathlib import Path

# settings.json の deny に加えて、直接ブロックしたいパターン
_EXTRA_DENY_PATTERNS = [
    (r"\bcurl\b.*\|\s*(?:bash|sh|zsh)\b", "curl | bash はブロックされました"),
    (r"\bwget\b.*\|\s*(?:bash|sh|zsh)\b", "wget | bash はブロックされました"),
]

SETTINGS_PATH = Path.home() / ".claude" / "settings.json"


def _load_deny_patterns() -> list[str]:
    """settings.json から Bash(...) の deny パターンを抽出"""
    try:
        settings = json.loads(SETTINGS_PATH.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return []

    deny_list = settings.get("permissions", {}).get("deny", [])
    patterns = []
    for entry in deny_list:
        if isinstance(entry, str) and entry.startswith("Bash(") and entry.endswith(")"):
            patterns.append(entry[5:-1])  # "Bash(...)" -> "..."
    return patterns


def _split_chained(command: str) -> list[str]:
    """&&, ;, || でコマンドを分割（パイプは分割しない）"""
    segments = re.split(r"\s*(?:&&|;|\|\|)\s*", command)
    return [s.strip() for s in segments if s.strip()]


def _matches_glob(command: str, pattern: str) -> bool:
    """settings.json の glob パターン（:* 等）とマッチ"""
    if pattern.endswith(":*"):
        prefix = pattern[:-2]
        return command.startswith(prefix)
    return fnmatch(command, pattern)


def _validate_command(command: str) -> list[str]:
    deny_patterns = _load_deny_patterns()
    issues = []

    segments = [command] + _split_chained(command)

    for segment in segments:
        # settings.json deny パターン
        for pattern in deny_patterns:
            if _matches_glob(segment, pattern):
                issues.append(f"拒否パターンにマッチ: '{segment}' (パターン: '{pattern}')")
                return issues  # 1つ見つかれば即終了

        # 追加の正規表現パターン
        for regex, message in _EXTRA_DENY_PATTERNS:
            if re.search(regex, segment):
                issues.append(message)
                return issues

    return issues


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    if input_data.get("tool_name") != "Bash":
        sys.exit(0)

    command = input_data.get("tool_input", {}).get("command", "")
    if not command:
        sys.exit(0)

    issues = _validate_command(command)
    if issues:
        for message in issues:
            print(f"• {message}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
