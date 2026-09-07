#!/usr/bin/env python3
"""過去の Claude Code セッションログ(~/.claude/projects/**/*.jsonl)を内容で検索する。

使い方:
    search-sessions.py <キーワード> [キーワード...] [オプション]

オプション:
    --any             キーワードのいずれかを含めばヒット(既定は全部含む)
    --all-projects    全プロジェクトを横断検索(既定はカレントプロジェクトのみ)
    --project PATH    検索対象プロジェクトの作業ディレクトリ
    --limit N         表示する候補数(既定 5)
    --json            結果を JSON で出力
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
EDIT_TOOLS = {"Write", "Edit", "NotebookEdit", "MultiEdit"}


def encode_project_dir(cwd: str) -> str:
    """Claude Code のプロジェクトディレクトリ名エンコード(非英数字を - に置換)。"""
    return re.sub(r"[^A-Za-z0-9]", "-", cwd)


def resolve_project_dirs(project: str | None, all_projects: bool) -> list[Path]:
    if all_projects:
        return sorted(p for p in PROJECTS_DIR.iterdir() if p.is_dir())
    cwd = os.path.abspath(project or os.getcwd())
    candidate = PROJECTS_DIR / encode_project_dir(cwd)
    if candidate.is_dir():
        return [candidate]
    # エンコード規則が違う場合はログ内の cwd フィールドで突き合わせる
    for d in sorted(PROJECTS_DIR.iterdir()):
        if not d.is_dir():
            continue
        for f in d.glob("*.jsonl"):
            try:
                with f.open(encoding="utf-8", errors="ignore") as fh:
                    for line in fh:
                        rec = json.loads(line)
                        if rec.get("cwd") == cwd:
                            return [d]
                        break
            except Exception:
                continue
    return []


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            x.get("text", "") for x in content if isinstance(x, dict) and x.get("type") == "text"
        )
    return ""


def scan(path: Path, keywords: list[str], match_any: bool) -> dict | None:
    raw = path.read_bytes().decode("utf-8", errors="ignore")
    lowered = raw.lower()
    hits = {kw: lowered.count(kw.lower()) for kw in keywords}
    matched = [kw for kw, n in hits.items() if n > 0]
    if match_any:
        if not matched:
            return None
    elif len(matched) != len(keywords):
        return None

    branches: set[str] = set()
    edited: dict[str, int] = {}
    prompts: list[tuple[str, str]] = []  # (timestamp, text)
    first_prompt = ""
    timestamps: list[str] = []
    cwd = ""

    for line in raw.splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        if rec.get("gitBranch"):
            branches.add(rec["gitBranch"])
        if rec.get("cwd") and not cwd:
            cwd = rec["cwd"]
        if rec.get("timestamp"):
            timestamps.append(rec["timestamp"])
        content = rec.get("message", {}).get("content")
        if rec.get("type") == "user":
            t = text_of(content).strip()
            # ツール結果・system-reminder・スキル展開などのノイズを除く
            if t and not t.startswith("<") and "system-reminder" not in t[:120]:
                if not first_prompt:
                    first_prompt = t
                low = t.lower()
                if any(kw.lower() in low for kw in keywords):
                    prompts.append((rec.get("timestamp", "")[:16], t))
        if isinstance(content, list):
            for x in content:
                if isinstance(x, dict) and x.get("type") == "tool_use" and x.get("name") in EDIT_TOOLS:
                    fp = x.get("input", {}).get("file_path", "")
                    if fp:
                        edited[fp] = edited.get(fp, 0) + 1

    return {
        "session_id": path.stem,
        "project_dir": path.parent.name,
        "cwd": cwd,
        "started_at": timestamps[0][:16] if timestamps else "",
        "ended_at": timestamps[-1][:16] if timestamps else "",
        "branches": sorted(branches),
        "hits": hits,
        "score": sum(hits.values()),
        "first_prompt": first_prompt,
        "matched_prompts": prompts,
        "edited_files": sorted(edited.items(), key=lambda kv: -kv[1]),
    }


def truncate(s: str, n: int) -> str:
    s = " ".join(s.split())
    return s if len(s) <= n else s[:n] + "…"


def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("keywords", nargs="+")
    ap.add_argument("--any", dest="match_any", action="store_true")
    ap.add_argument("--all-projects", action="store_true")
    ap.add_argument("--project")
    ap.add_argument("--limit", type=int, default=5)
    ap.add_argument("--json", dest="as_json", action="store_true")
    args = ap.parse_args()

    dirs = resolve_project_dirs(args.project, args.all_projects)
    if not dirs:
        print("該当するプロジェクトのセッションログが見つかりません。", file=sys.stderr)
        return 1

    results = []
    for d in dirs:
        for f in sorted(d.glob("*.jsonl")):
            try:
                r = scan(f, args.keywords, args.match_any)
            except Exception as e:  # 壊れたログはスキップ
                print(f"skip {f.name}: {e}", file=sys.stderr)
                continue
            if r:
                results.append(r)

    results.sort(key=lambda r: (-r["score"], r["ended_at"]))
    results = results[: args.limit]

    if args.as_json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 0

    if not results:
        print("ヒットなし。キーワードを短く/別表現にするか --any を試してください。")
        return 0

    for i, r in enumerate(results, 1):
        print(f"### 候補{i}: {r['session_id']}  (score={r['score']})")
        print(f"- 期間: {r['started_at']} 〜 {r['ended_at']}")
        print(f"- cwd: {r['cwd']}")
        if r["branches"]:
            print(f"- ブランチ: {', '.join(r['branches'])}")
        print(f"- キーワード出現: {r['hits']}")
        if r["first_prompt"]:
            print(f"- 冒頭プロンプト: {truncate(r['first_prompt'], 160)}")
        for ts, t in r["matched_prompts"][:3]:
            print(f"- 該当プロンプト({ts}): {truncate(t, 160)}")
        if r["edited_files"]:
            print("- 編集ファイル(上位):")
            for fp, n in r["edited_files"][:8]:
                print(f"    {fp} ({n})")
        print(f"- 復元: cd {r['cwd'] or '<project>'} && claude --resume {r['session_id']}")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
