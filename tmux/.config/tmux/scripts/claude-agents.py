#!/usr/bin/env python3
"""実行中の Claude Code セッションを一覧し、選んだ pane へ移動する TUI。

prefix + C-a（Ghostty: cmd+s）で tmux の display-popup 内に開く。
左にセッションのカード、右に選択中 pane のライブ画面を出し、1 秒ごとに更新する。

状態は ~/.claude/pane-state.json（tmux-state.sh が Claude Code の hook で書く）から読む。
done はタブのアイコン（@claude_status）が残っている＝まだ見ていないものだけ強調する。
並び順: 回答待ち → 未読の完了 → 処理中 → その他、同じ状態の中では更新が新しい順。

curses は使わない。curses は文字幅を libc の wcwidth で数えるため、tmux 側で
2 桁として描く Nerd Font アイコン（tmux.conf の codepoint-widths）とずれる。
1 行ずつ絶対位置で書き直すことで、幅の解釈違いが次の行に波及しないようにしている。
"""

from __future__ import annotations

import json
import os
import re
import select
import subprocess
import sys
import termios
import time
import tty
import unicodedata
from pathlib import Path

STATE_FILE = Path.home() / ".claude" / "pane-state.json"

ICON_WORKING = "\U000F06A9"  # 󰚩
ICON_WAITING = "\U000F051F"  # 󰔟
ICON_DONE = "\U000F012C"     # 󰄬
WIDE_ICONS = {ICON_WORKING, ICON_WAITING, ICON_DONE}

# Catppuccin Mocha
def fg(hex_: str) -> str:
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[38;2;{r};{g};{b}m"


def bg(hex_: str) -> str:
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[48;2;{r};{g};{b}m"


RESET = "\033[0m"
BOLD = "\033[1m"
TEXT = fg("#cdd6f4")
SUBTEXT = fg("#a6adc8")
OVERLAY = fg("#6c7086")
SURFACE = fg("#45475a")
BLUE = fg("#89b4fa")
YELLOW = fg("#f9e2af")
PEACH = fg("#fab387")
MAUVE = fg("#cba6f7")
SEL_BG = bg("#313244")

STATUS_STYLE = {
    # status: (順位, アイコン, 色, ラベル)
    "waiting": (0, ICON_WAITING, YELLOW, "回答待ち"),
    "done": (1, ICON_DONE, PEACH, "完了"),
    "working": (2, ICON_WORKING, BLUE, "処理中"),
    "idle": (3, "·", OVERLAY, ""),
}

CLAUDE_CMD = re.compile(r"^(\d+\.\d+\.\d+|claude|node)$")
ANSI = re.compile(r"\x1b\[[0-9;:?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")

DATA_INTERVAL = 1.0


# --- 文字幅 -------------------------------------------------------------------

def char_width(c: str) -> int:
    if c in WIDE_ICONS:
        return 2
    if unicodedata.combining(c):
        return 0
    return 2 if unicodedata.east_asian_width(c) in "WF" else 1


def text_width(s: str) -> int:
    return sum(char_width(c) for c in s)


def fit(s: str, width: int) -> str:
    """表示幅 width に切り詰め（溢れたら … を付け）、足りなければ空白で埋める。"""
    if width <= 0:
        return ""
    if text_width(s) <= width:
        return s + " " * (width - text_width(s))
    out, w = [], 0
    for c in s:
        cw = char_width(c)
        if w + cw > width - 1:
            break
        out.append(c)
        w += cw
    return "".join(out) + "…" + " " * (width - 1 - w)


def fit_ansi(s: str, width: int) -> str:
    """ANSI エスケープを保ったまま表示幅 width に切り詰める（プレビュー用）。"""
    out, w, i = [], 0, 0
    while i < len(s):
        m = ANSI.match(s, i)
        if m:
            out.append(m.group())
            i = m.end()
            continue
        cw = char_width(s[i])
        if w + cw > width:
            break
        out.append(s[i])
        w += cw
        i += 1
    return "".join(out) + RESET + " " * (width - w)


def rel_time(ts: float | None) -> str:
    if not ts:
        return ""
    sec = max(0, int(time.time() - ts))
    if sec < 60:
        return "now"
    if sec < 3600:
        return f"{sec // 60}m"
    if sec < 86400:
        return f"{sec // 3600}h"
    return f"{sec // 86400}d"


# --- データ -------------------------------------------------------------------

def tmux(*args: str) -> str:
    r = subprocess.run(["tmux", *args], capture_output=True, text=True)
    return r.stdout


def load_agents() -> list[dict]:
    try:
        state = json.loads(STATE_FILE.read_text())
    except (OSError, ValueError):
        state = {}

    fmt = "\t".join([
        "#{pane_id}", "#{pane_current_command}", "#{session_name}",
        "#{window_index}.#{pane_index}", "#{window_name}", "#{pane_current_path}",
        "#{@claude_status}",
    ])
    agents = []
    for line in tmux("list-panes", "-a", "-F", fmt).splitlines():
        parts = line.split("\t")
        if len(parts) != 7:
            continue
        pane, cmd, sess, loc, wname, path, icon = parts
        s = state.get(pane)
        # Claude Code が終了済みの pane（SessionEnd が来なかった場合）は除外する
        if not s or not CLAUDE_CMD.match(cmd):
            continue
        status = s.get("status", "idle")
        if status == "done" and icon != ICON_DONE:
            status = "idle"  # タブのアイコンが消えている＝もう見た
        if status not in STATUS_STYLE:
            status = "idle"
        agents.append({
            "pane": pane,
            "status": status,
            "name": os.path.basename(path) or path,
            "loc": f"{sess}:{loc}",
            "window": wname,
            "path": path.replace(str(Path.home()), "~", 1),
            "prompt": " ".join((s.get("prompt") or "").split()),
            "ts": s.get("ts"),
        })
    agents.sort(key=lambda a: (STATUS_STYLE[a["status"]][0], -(a["ts"] or 0)))
    return agents


def capture(pane: str) -> list[str]:
    lines = tmux("capture-pane", "-ep", "-t", pane).split("\n")
    while lines and not ANSI.sub("", lines[-1]).strip():
        lines.pop()
    return lines


# --- 描画 ---------------------------------------------------------------------

def render(agents: list[dict], sel: int, preview: list[str], cols: int, rows: int) -> str:
    left_w = max(28, min(48, cols * 36 // 100))
    right_w = cols - left_w - 3
    body_h = rows - 2  # 最終行はフッター、1 行余白

    # 左: カード（1 枚 3 行）
    left: list[str] = []
    if not agents:
        left = ["", f"  {OVERLAY}実行中の Claude Code はありません{RESET}"]
    card_h = 3
    top = max(0, (sel + 1) * card_h - body_h)  # 選択カードが見える位置までスクロール
    for i, a in enumerate(agents):
        order, icon, color, label = STATUS_STYLE[a["status"]]
        selected = i == sel
        base = SEL_BG if selected else ""
        bar = f"{MAUVE}▌" if selected else " "
        when = rel_time(a["ts"])
        head_w = left_w - 6 - text_width(when)
        line1 = (f"{base}{bar}{color}{icon}{' ' if icon in WIDE_ICONS else '  '}"
                 f"{TEXT}{BOLD if selected else ''}{fit(a['name'], head_w)}{RESET}{base}"
                 f" {OVERLAY}{when} {RESET}")
        sub = a["prompt"] or a["window"]
        num = str(i + 1) if i < 9 else " "
        line2 = (f"{base}{bar}{SURFACE}{num}  {SUBTEXT if selected else OVERLAY}"
                 f"{fit(sub, left_w - 4)}{RESET}")
        left += [line1, line2, ""]
    left = left[top:top + body_h]

    # 右: 選択中 pane の画面
    right: list[str] = []
    if agents:
        a = agents[sel]
        _, icon, color, label = STATUS_STYLE[a["status"]]
        title = f"{a['loc']}  {a['window']}"
        right.append(f"{color}{BOLD}{label}{RESET} {SUBTEXT}{fit(title, right_w - text_width(label) - 1)}{RESET}")
        right.append(f"{OVERLAY}{fit(a['path'], right_w)}{RESET}")
        right.append(f"{SURFACE}{'─' * right_w}{RESET}")
        avail = body_h - len(right)
        right += [fit_ansi(l, right_w) for l in preview[-avail:]] if avail > 0 else []

    out = ["\033[?2026h"]  # 同期出力（対応端末でちらつきを抑える）
    for y in range(body_h):
        l = left[y] if y < len(left) else ""
        r = right[y] if y < len(right) else ""
        out.append(f"\033[{y + 1};1H{l}\033[{y + 1};{left_w + 1}H{RESET} {SURFACE}│{RESET} {r}\033[K")
    keys = f"{TEXT}↵{OVERLAY} 移動  {TEXT}j/k{OVERLAY} 選択  {TEXT}1-9{OVERLAY} 直接移動  {TEXT}q{OVERLAY} 閉じる"
    out.append(f"\033[{rows - 1};1H\033[K\033[{rows};1H {keys}{RESET}\033[K")
    out.append("\033[?2026l")
    return "".join(out)


# --- メイン -------------------------------------------------------------------

def read_key(fd: int, timeout: float) -> str | None:
    r, _, _ = select.select([fd], [], [], timeout)
    if not r:
        return None
    b = os.read(fd, 1)
    if b == b"\x1b":
        r, _, _ = select.select([fd], [], [], 0.03)
        if not r:
            return "esc"
        seq = os.read(fd, 8)
        return {b"[A": "up", b"[B": "down", b"OA": "up", b"OB": "down"}.get(seq[:2], "")
    return b.decode(errors="ignore")


def focus(pane: str) -> None:
    sess = tmux("display-message", "-p", "-t", pane, "#{session_name}").strip()
    win = tmux("display-message", "-p", "-t", pane, "#{window_id}").strip()
    subprocess.run(["tmux", "switch-client", "-t", sess], capture_output=True)
    subprocess.run(["tmux", "select-window", "-t", win], capture_output=True)
    subprocess.run(["tmux", "select-pane", "-t", pane], capture_output=True)


def main() -> int:
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    write = lambda s: (sys.stdout.buffer.write(s.encode()), sys.stdout.buffer.flush())
    target = None
    try:
        tty.setcbreak(fd)
        # cmd+s が送る C-s（XOFF）で出力が止まらないよう、フロー制御を切る
        attrs = termios.tcgetattr(fd)
        attrs[0] &= ~termios.IXON
        termios.tcsetattr(fd, termios.TCSADRAIN, attrs)
        # 自動折り返しを止める（端末と幅の解釈が違う文字があっても次の行に溢れない）
        write("\033[?1049h\033[?25l\033[?7l\033[2J")
        agents: list[dict] = []
        sel_pane = None
        last_load = 0.0
        while True:
            now = time.monotonic()
            if now - last_load >= DATA_INTERVAL:
                agents = load_agents()
                last_load = now
            panes = [a["pane"] for a in agents]
            sel = panes.index(sel_pane) if sel_pane in panes else 0
            sel_pane = panes[sel] if panes else None
            cols, rows = os.get_terminal_size()
            preview = capture(sel_pane) if sel_pane else []
            write(render(agents, sel, preview, cols, rows))

            key = read_key(fd, max(0.05, DATA_INTERVAL - (time.monotonic() - last_load)))
            if key is None:
                continue
            # C-a: もう一度 cmd+s（C-s C-a）を押したら閉じる。C-s 単体は無視する
            if key in ("q", "esc", "\x03", "\x01"):
                break
            if key in ("j", "down") and panes:
                sel_pane = panes[min(sel + 1, len(panes) - 1)]
            elif key in ("k", "up") and panes:
                sel_pane = panes[max(sel - 1, 0)]
            elif key in ("\r", "\n") and sel_pane:
                target = sel_pane
                break
            elif key.isdigit() and key != "0" and int(key) <= len(panes):
                target = panes[int(key) - 1]
                break
    finally:
        write("\033[?7h\033[?25h\033[?1049l")
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    if target:
        focus(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
