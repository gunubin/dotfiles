#!/usr/bin/env python3
"""Claude Code のセッション一覧を fzf 表示用 TSV として出力する。

claude-resume.sh から呼ばれる。出力は 1 行 1 セッションの TSV:

    <表示文字列(ANSI色付き)>\t<session_id>\t<cwd>\t<pane_id>\t<jsonl_path>

pane_id は「そのセッションが今 tmux pane で起動中」の場合のみ入る（空なら終了済み）。
判定は ~/.claude/sessions/<pid>.json（Claude Code 本体が書く）の sessionId と tmux 座標を、
プロセス生存(kill -0)と tmux 上の pane 実在の両方で突き合わせる。

表示日時にファイルの mtime は使わない。mtime はセッション終了後も別要因で更新され、
実際の作業時刻から数日ずれることがあるため、ログ内の「最後のユーザープロンプト」の
timestamp を採用する。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
SESSIONS_DIR = Path.home() / ".claude" / "sessions"

HEAD_LINES = 200        # ai-title・冒頭プロンプトはこの範囲に出る
TAIL_BYTES = 512 * 1024  # 最終プロンプトを探す末尾の読み取り量

C_RESET = "\033[0m"
C_LIVE = "\033[32m"
C_DEAD = "\033[90m"
C_TIME = "\033[36m"
C_PANE = "\033[35m"
C_DIR = "\033[34m"
C_TITLE = "\033[33m"
C_PROMPT = "\033[90m"


def char_width(c: str) -> int:
    return 2 if unicodedata.east_asian_width(c) in "WF" else 1


def cell(s: str, width: int) -> str:
    """全角を 2 桁と数え、width 桁ちょうどに切り詰め/右詰めする。

    width に収まりきる文字列は切らない。溢れる場合だけ、省略記号 1 桁分を
    確保するために末尾を削る。
    """
    chars: list[str] = []
    w = 0
    for c in s:
        cw = char_width(c)
        if w + cw > width:
            while w + 1 > width and chars:
                w -= char_width(chars.pop())
            return "".join(chars) + "…" + " " * max(0, width - w - 1)
        chars.append(c)
        w += cw
    return "".join(chars) + " " * max(0, width - w)


def flatten(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            x.get("text", "")
            for x in content
            if isinstance(x, dict) and x.get("type") == "text"
        )
    return ""


def is_real_prompt(rec: dict) -> str:
    """ユーザーが実際に打ったプロンプトなら本文を返す。それ以外は空文字。"""
    if rec.get("type") != "user" or rec.get("isMeta"):
        return ""
    t = " ".join(flatten(rec.get("message", {}).get("content")).split())
    # ツール結果・system-reminder・スキル展開などのラッパーを除く
    if not t or t.startswith("<") or "system-reminder" in t[:120]:
        return ""
    return t


def existing_panes() -> set[str]:
    try:
        out = subprocess.run(
            ["tmux", "list-panes", "-a", "-F", "#{pane_id}"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        return set(out.split())
    except Exception:
        return set()


def session_meta() -> tuple[dict[str, str], dict[str, str]]:
    """~/.claude/sessions/*.json から (session_id->pane_id, session_id->name) を作る。

    pane_id はプロセスが生存し pane も実在するものだけ。name は tmux ウィンドウ名などの
    由来が derived（自動連番）でないものだけをタイトル候補として拾う。
    """
    live: dict[str, str] = {}
    names: dict[str, str] = {}
    if not SESSIONS_DIR.is_dir():
        return live, names
    panes = existing_panes()
    for f in SESSIONS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
        except Exception:
            continue
        sid = d.get("sessionId")
        if not sid:
            continue
        if d.get("name") and d.get("nameSource") != "derived":
            names[sid] = d["name"]
        pid, tmux_pos = d.get("pid"), d.get("tmux")
        if not pid or not tmux_pos:
            continue
        try:
            os.kill(int(pid), 0)  # 生存確認（シグナルは送らない）
        except (OSError, ValueError):
            continue
        pane = str(tmux_pos).rsplit(".", 1)[-1]
        if pane in panes:
            live[sid] = pane
    return live, names


def scan_head(path: Path) -> dict:
    title, first_prompt, cwd, first_ts = "", "", "", ""
    with path.open(encoding="utf-8", errors="ignore") as fh:
        for i, line in enumerate(fh):
            if i >= HEAD_LINES:
                break
            if not line.strip():
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("type") == "ai-title" and rec.get("aiTitle"):
                title = rec["aiTitle"]  # 後に出たものほど新しいので上書き
            if not cwd and rec.get("cwd"):
                cwd = rec["cwd"]
            if not first_prompt:
                t = is_real_prompt(rec)
                if t:
                    first_prompt, first_ts = t, rec.get("timestamp", "")
    return {"title": title, "first_prompt": first_prompt, "cwd": cwd, "first_ts": first_ts}


def scan_tail(path: Path, size: int) -> str:
    """末尾から「最後のユーザープロンプト」の timestamp を探す。無ければ最後の timestamp。"""
    with path.open("rb") as fh:
        if size > TAIL_BYTES:
            fh.seek(-TAIL_BYTES, os.SEEK_END)
            fh.readline()  # 途中で切れた先頭行を捨てる
        chunk = fh.read().decode("utf-8", errors="ignore")
    last_prompt_ts, last_ts = "", ""
    for line in chunk.splitlines():
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        if rec.get("timestamp"):
            last_ts = rec["timestamp"]
            if is_real_prompt(rec):
                last_prompt_ts = rec["timestamp"]
    return last_prompt_ts or last_ts


def to_local(iso: str) -> datetime | None:
    if not iso:
        return None
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return None


WEEKDAYS = "月火水木金土日"


def rel_time(dt: datetime) -> str:
    """「3分前」「3日前(木) 15:12」のような相対表記にする。

    日をまたいだものには曜日を添える（表示範囲が 7 日なら曜日が一意に定まり、
    「木曜にやったやつ」という記憶から辿れるため）。
    """
    now = datetime.now(dt.tzinfo)
    sec = (now - dt).total_seconds()
    wd = WEEKDAYS[dt.weekday()]
    if sec < 0:
        return f"{dt:%m/%d}({wd}) {dt:%H:%M}"
    if sec < 60:
        return "たった今"
    if sec < 3600:
        return f"{int(sec // 60)}分前"
    days = (now.date() - dt.date()).days
    if days == 0:
        return f"{int(sec // 3600)}時間前"
    if days == 1:
        return f"昨日({wd}) {dt:%H:%M}"
    if days < 7:
        return f"{days}日前({wd}) {dt:%H:%M}"
    return f"{dt:%m/%d}({wd}) {dt:%H:%M}"


def encode_project_dir(cwd: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "-", cwd)


def collect(scope: str, cwd: str, days: int) -> list[dict]:
    if scope == "current":
        d = PROJECTS_DIR / encode_project_dir(os.path.abspath(cwd))
        dirs = [d] if d.is_dir() else []
    else:
        dirs = sorted(p for p in PROJECTS_DIR.iterdir() if p.is_dir()) if PROJECTS_DIR.is_dir() else []

    cutoff = datetime.now(timezone.utc).timestamp() - days * 86400 if scope == "all" else 0.0
    live, names = session_meta()
    rows = []
    for d in dirs:
        for f in d.glob("*.jsonl"):
            try:
                size = f.stat().st_size
                # mtime は実作業時刻からずれるが、明らかに古いファイルを弾く粗いフィルタには使える
                if scope == "all" and f.stat().st_mtime < cutoff - 86400:
                    continue
                head = scan_head(f)
                ts = scan_tail(f, size)
            except OSError:
                continue
            if not head["first_prompt"] and not head["title"]:
                continue
            dt = to_local(ts) or to_local(head["first_ts"])
            if dt is None:
                continue
            if scope == "all" and dt.timestamp() < cutoff:
                continue
            sid = f.stem
            rows.append({
                "sid": sid,
                "jsonl": str(f),
                "dt": dt,
                "cwd": head["cwd"] or str(d),
                "pane": live.get(sid, ""),
                "title": head["title"] or names.get(sid, ""),
                "prompt": head["first_prompt"],
            })
    rows.sort(key=lambda r: r["dt"], reverse=True)
    return rows


def render(rows: list[dict], scope: str) -> str:
    lines = []
    for r in rows:
        mark = f"{C_LIVE}●{C_RESET}" if r["pane"] else f"{C_DEAD}○{C_RESET}"
        pane_col = f"{C_PANE}{r['pane']:<4}{C_RESET}" if r["pane"] else " " * 4
        cols = [mark, f"{C_TIME}{cell(rel_time(r['dt']), 15)}{C_RESET}", pane_col]
        if scope == "all":
            cols.append(f"{C_DIR}{cell(Path(r['cwd']).name, 24)}{C_RESET}")
        if r["title"]:
            cols.append(f"{C_TITLE}{cell(r['title'], 37)}{C_RESET}")
        else:
            # タイトル未生成のセッションは冒頭プロンプトを手がかりとして出す
            cols.append(f"{C_PROMPT}{cell(r['prompt'] or '(untitled)', 37)}{C_RESET}")
        lines.append("\t".join([" ".join(cols), r["sid"], r["cwd"], r["pane"], r["jsonl"]]))
    return "\n".join(lines)



# --- recap（fzf プレビュー） -------------------------------------------------

EDIT_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

R_TITLE = "\033[1;33m"
R_META = "\033[90m"
R_SEC = "\033[36m"
R_USER = "\033[42;30m"
R_ASSIST = "\033[48;5;208;30m"


def wrap(s: str, width: int, indent: str = "  ") -> str:
    """全角を 2 桁と数えて width に折り返す。"""
    out = []
    for para in s.split("\n"):
        cur, w = indent, len(indent)
        for ch in para:
            cw = 2 if unicodedata.east_asian_width(ch) in "WF" else 1
            if w + cw > width:
                out.append(cur)
                cur, w = indent, len(indent)
            cur += ch
            w += cw
        out.append(cur)
    return "\n".join(out)


def scan_full(path: Path) -> dict:
    """recap 用にログ全体を 1 回だけ走査する。"""
    title = branch = cwd = ""
    first = last = None          # (timestamp, text)
    edits: dict[str, int] = {}
    convo: list[tuple[str, str, str]] = []  # (role, timestamp, text)
    with path.open(encoding="utf-8", errors="ignore") as fh:
        for line in fh:
            if not line.strip():
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            rtype = rec.get("type")
            if rtype == "ai-title" and rec.get("aiTitle"):
                title = rec["aiTitle"]
            if not cwd and rec.get("cwd"):
                cwd = rec["cwd"]
            if not branch and rec.get("gitBranch"):
                branch = rec["gitBranch"]
            ts = rec.get("timestamp", "")
            if rtype == "user":
                t = is_real_prompt(rec)
                if t:
                    if first is None:
                        first = (ts, t)
                    last = (ts, t)
                    convo.append(("user", ts, t))
            elif rtype == "assistant":
                content = rec.get("message", {}).get("content")
                t = " ".join(flatten(content).split())
                if t:
                    convo.append(("assistant", ts, t))
                if isinstance(content, list):
                    for x in content:
                        if isinstance(x, dict) and x.get("type") == "tool_use" and x.get("name") in EDIT_TOOLS:
                            fp = x.get("input", {}).get("file_path", "")
                            if fp:
                                edits[fp] = edits.get(fp, 0) + 1
    return {
        "title": title, "branch": branch, "cwd": cwd,
        "first": first, "last": last,
        "edits": sorted(edits.items(), key=lambda kv: -kv[1]),
        "convo": convo,
    }


def fmt_ts(iso: str, fmt: str = "%m/%d %H:%M") -> str:
    dt = to_local(iso)
    return dt.strftime(fmt) if dt else "?"


def fmt_rel(iso: str) -> str:
    dt = to_local(iso)
    return rel_time(dt) if dt else "?"


def recap(path: Path, width: int, names: dict[str, str]) -> str:
    d = scan_full(path)
    body = width - 2
    out = []

    title = d["title"] or names.get(path.stem, "") or "(untitled)"
    out.append(f"{R_TITLE}{title}{C_RESET}")

    meta = Path(d["cwd"]).name if d["cwd"] else "?"
    if d["branch"]:
        meta += f" [{d['branch']}]"
    if d["first"]:
        f_dt, l_dt = to_local(d["first"][0]), to_local(d["last"][0]) if d["last"] else None
        if f_dt:
            meta += "  " + f_dt.strftime("%Y-%m-%d %H:%M")
            if l_dt and l_dt != f_dt:
                same_day = l_dt.date() == f_dt.date()
                meta += " - " + l_dt.strftime("%H:%M" if same_day else "%Y-%m-%d %H:%M")
    out.append(f"{R_META}{meta}{C_RESET}\n")

    if d["first"]:
        out.append(f"{R_SEC}▶ 最初の依頼{C_RESET}")
        out.append(wrap(d["first"][1][:600], body))
        out.append("")
    if d["last"] and d["last"] is not d["first"]:
        out.append(f"{R_SEC}▶ 最後の指示{C_RESET}  {R_META}{fmt_rel(d['last'][0])}{C_RESET}")
        out.append(wrap(d["last"][1][:600], body))
        out.append("")
    if d["edits"]:
        out.append(f"{R_SEC}▶ 編集ファイル{C_RESET}")
        base = d["cwd"] or ""
        home = str(Path.home())
        for fp, n in d["edits"][:8]:
            if base and fp.startswith(base + "/"):
                rel = fp[len(base) + 1:]
            elif fp.startswith(home + "/"):
                rel = "~/" + fp[len(home) + 1:]
            else:
                rel = fp
            out.append(f"  {cell(rel, body - 6)} {R_META}({n}){C_RESET}")
        if len(d["edits"]) > 8:
            out.append(f"{R_META}  ... 他 {len(d['edits']) - 8} 件{C_RESET}")
        out.append("")

    out.append(f"{R_META}{'-' * min(width, 60)}{C_RESET}")
    out.append(f"{R_SEC}▶ 会話ログ（新しい順）{C_RESET}\n")
    for role, ts, text in reversed(d["convo"][-20:]):
        label = f"{R_USER} USER {C_RESET}" if role == "user" else f"{R_ASSIST} CLAUDE {C_RESET}"
        out.append(f"{label} {R_META}{fmt_rel(ts)}{C_RESET}")
        out.append(wrap(text[:400], body))
        out.append("")
    return "\n".join(out)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scope", choices=["current", "all"], default="current")
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--recap", help="このセッションログの recap を出力する（fzf プレビュー用）")
    ap.add_argument("--width", type=int, default=int(os.environ.get("FZF_PREVIEW_COLUMNS") or 80))
    args = ap.parse_args()

    if args.recap:
        path = Path(args.recap)
        if not path.is_file():
            return 0
        _, names = session_meta()
        print(recap(path, max(40, args.width), names))
        return 0

    rows = collect(args.scope, args.cwd, args.days)
    if rows:
        print(render(rows, args.scope))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
