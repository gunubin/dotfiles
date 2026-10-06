#!/usr/bin/env python3
"""待ちで止まっているセッションを Obsidian の端末別ノートに一覧化する Stop hook。

Claude の最後の発言に「待ち: 〜」の行があればそのセッションを登録・更新し、
なければ一覧から外す。状態は端末ローカルの JSON に持ち、
Obsidian 側の Markdown は毎回 JSON から作り直す（端末ごとに別ファイルなので git で衝突しない）。
"""

import fcntl
import json
import os
import re
import socket
import subprocess
import sys
from datetime import datetime
from pathlib import Path

VAULT = Path.home() / "Documents/notes"
NOTE_DIR = VAULT / "000_Inbox/Sessions"
STATE = Path.home() / ".claude/session-waits.json"
LOCK = STATE.with_suffix(".lock")
WAIT_LINE = re.compile(r"^\s*(?:\*\*)?待ち(?:\*\*)?\s*[:：]\s*(.+?)\s*$", re.MULTILINE)


def last_assistant_text(data: dict) -> str:
    text = data.get("last_assistant_message")
    if isinstance(text, str) and text:
        return text
    path = data.get("transcript_path")
    if not path or not os.path.exists(path):
        return ""
    last = ""
    with open(path) as f:
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") != "assistant":
                continue
            content = entry.get("message", {}).get("content", [])
            texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
            if texts:
                last = "\n".join(texts)
    return last


def repo_name(cwd: str) -> str:
    try:
        root = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    except Exception:
        root = ""
    return Path(root or cwd).name


def render(host: str, waits: dict) -> str:
    lines = [f"# {host} の待ちセッション", ""]
    if not waits:
        lines.append("待ちのセッションはありません。")
    for sid, w in sorted(waits.items(), key=lambda kv: kv[1]["updated"], reverse=True):
        lines.append(f"- [ ] **{w['repo']}** {w['wait']}")
        lines.append(f"\t- {w['updated']} · `{w['cwd']}`")
        lines.append(f"\t- `claude --resume {sid}`")
    lines.append("")
    return "\n".join(lines)


def write_atomic(path: Path, text: str) -> None:
    # 書きかけのファイルを他のセッションに読ませないよう、一時ファイルに書いてから置き換える
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def main() -> None:
    data = json.load(sys.stdin)
    sid = data.get("session_id")
    if not sid:
        return
    cwd = data.get("cwd") or os.getcwd()
    matches = WAIT_LINE.findall(last_assistant_text(data))

    # 複数セッションの Stop hook が同時に走っても更新が消えないよう、読み書き全体をロックする
    with open(LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        update(sid, cwd, matches)


def update(sid: str, cwd: str, matches: list[str]) -> None:
    try:
        waits = json.loads(STATE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        waits = {}

    if matches:
        waits[sid] = {
            "wait": matches[-1][:200],
            "repo": repo_name(cwd),
            "cwd": cwd.replace(str(Path.home()), "~"),
            "updated": datetime.now().strftime("%Y-%m-%d %H:%M"),
        }
    elif sid in waits:
        del waits[sid]
    else:
        return

    write_atomic(STATE, json.dumps(waits, ensure_ascii=False, indent=1))
    if VAULT.is_dir():
        host = socket.gethostname().split(".")[0]
        NOTE_DIR.mkdir(parents=True, exist_ok=True)
        write_atomic(NOTE_DIR / f"{host}.md", render(host, waits))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # hook の失敗でセッションを止めない
        print(f"session-waits: {e}", file=sys.stderr)
