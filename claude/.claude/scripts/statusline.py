#!/usr/bin/env python3
"""Claude Code のステータスライン

Claude Code が stdin で渡す JSON だけを使って2行を表示する。

    1行目（丸い帯）:  dotfiles   main M1  +156 -23
    2行目:           █▒▒▒▒▒▒▒▒▒ 12% 120K/1M · 5h 38% 2h10m · 7d 41% ·  91% · Opus 5.5 high #02de19d9

幅が足りないときは優先度の低い項目から外す。
NO_COLOR か STATUSLINE_NO_COLOR を設定すると色を付けない。
データの仕様: https://code.claude.com/docs/en/statusline#available-data
"""

import json
import os
import re
import shutil
import subprocess
import sys
import time
import unicodedata

# ========== 配色（Catppuccin Mocha） ==========
PINK = (245, 194, 231)
MAUVE = (203, 166, 247)
RED = (243, 139, 168)
PEACH = (250, 179, 135)
YELLOW = (249, 226, 175)
GREEN = (166, 227, 161)
TEAL = (148, 226, 213)
SKY = (137, 220, 235)
LAVENDER = (180, 190, 254)
TEXT = (205, 214, 244)
SURFACE2 = (88, 91, 112)
CRUST = (17, 17, 27)

# 表示要素ごとの色（配色を変えるときはここだけ差し替える）
DIR_COLOR = PINK
BRANCH_COLOR = SKY
DIFF_COLOR = GREEN
MODEL_COLOR = MAUVE
CACHE_COLOR = GREEN
DIM_COLOR = SURFACE2

# 進捗バーのパステルグラデーション（ティール→ラベンダー→ピンク→ピーチ）
PROGRESS_GRADIENT = [TEAL, LAVENDER, PINK, PEACH]
PROGRESS_WIDTH = 10

# ========== アイコン（Nerd Font） ==========
ICON_FOLDER = ''
ICON_BRANCH = ''
ICON_CACHE = ''
ICON_FAST = '⚡'
PILL_LEFT = ''
PILL_RIGHT = ''
SEPARATOR = ' · '

NO_COLOR = bool(os.environ.get('NO_COLOR') or os.environ.get('STATUSLINE_NO_COLOR'))


# ========== 色付け ==========

def fg(rgb):
    return '' if NO_COLOR else f'\033[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m'


def bg(rgb):
    return '' if NO_COLOR else f'\033[48;2;{rgb[0]};{rgb[1]};{rgb[2]}m'


def reset():
    return '' if NO_COLOR else '\033[0m'


def paint(text, rgb):
    return f'{fg(rgb)}{text}{reset()}'


def pill(text, rgb):
    """丸い端の帯。色なしのときは両端を空白にする"""
    if NO_COLOR:
        return f' {text} '
    return f'{fg(rgb)}{PILL_LEFT}{bg(rgb)}{fg(CRUST)}{text}{reset()}{fg(rgb)}{PILL_RIGHT}{reset()}'


def gradient_color(position):
    """グラデーションの position（0.0〜1.0）の位置の色"""
    scaled = max(0.0, min(1.0, position)) * (len(PROGRESS_GRADIENT) - 1)
    index = min(int(scaled), len(PROGRESS_GRADIENT) - 2)
    t = scaled - index
    start, end = PROGRESS_GRADIENT[index], PROGRESS_GRADIENT[index + 1]
    return tuple(round(a + (b - a) * t) for a, b in zip(start, end))


def usage_color(percentage):
    """使用率の色: 90%以上は赤、70%以上はピーチ、それ未満はバーの先端と同じ色"""
    if percentage >= 90:
        return RED
    if percentage >= 70:
        return PEACH
    return gradient_color(percentage / 100)


def progress_bar(percentage):
    filled = int(PROGRESS_WIDTH * percentage / 100)
    if percentage >= 90:
        bar = paint('█' * filled, RED)
    else:
        bar = ''.join(paint('█', gradient_color(i / (PROGRESS_WIDTH - 1))) for i in range(filled))
    return bar + paint('▒' * (PROGRESS_WIDTH - filled), DIM_COLOR)


# ========== 幅 ==========

def display_width(text):
    """色のエスケープを除いた表示幅（全角は2）"""
    plain = re.sub(r'\x1b\[[0-9;]*m', '', text)
    return sum(2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1 for c in plain)


def terminal_width():
    """Claude Code が渡す COLUMNS を使う。右端に1文字余白を残す"""
    try:
        return int(os.environ['COLUMNS']) - 1
    except (KeyError, ValueError):
        return shutil.get_terminal_size((80, 24)).columns - 1


def fit(segments, width, join):
    """segments は (優先度, 文字列) のリスト。収まるまで優先度の低い順に外す"""
    kept = [s for s in segments if s[1]]
    while kept and display_width(join.join(text for _, text in kept)) > width:
        lowest = min(range(len(kept)), key=lambda i: kept[i][0])
        kept.pop(lowest)
    return join.join(text for _, text in kept)


# ========== 書式 ==========

def format_tokens(tokens):
    if tokens >= 1_000_000:
        value = tokens / 1_000_000
        return f'{value:.0f}M' if value == int(value) else f'{value:.1f}M'
    if tokens >= 1000:
        return f'{tokens / 1000:.0f}K'
    return str(tokens)


def format_remaining(resets_at):
    """リセットまでの残り時間（例: 2h10m, 45m）"""
    minutes = max(0, int((resets_at - time.time()) / 60))
    if minutes >= 60:
        return f'{minutes // 60}h{minutes % 60:02d}m'
    return f'{minutes}m'


def shorten_model_name(model):
    """"Claude Opus 5.5 (1M context)" → "Opus 5.5·1M" """
    name = re.sub(r'^Claude\s+', '', model, flags=re.IGNORECASE)
    m = re.match(r'^([\d.]+)\s+(Haiku|Sonnet|Opus)', name, re.IGNORECASE)
    if m:
        name = f'{m.group(2)} {m.group(1)}'
    m = re.search(r'[\[(（]?\s*(\d+M)(?:\s+context)?\s*[\])）]?\s*$', name, re.IGNORECASE)
    if m:
        name = f'{name[:m.start()].strip()}·{m.group(1).upper()}'
    return name


def git_info(directory):
    """(ブランチ名, 変更ファイル数)。git 管理外なら (None, 0)"""
    try:
        result = subprocess.run(
            ['git', '--no-optional-locks', 'status', '--porcelain', '--branch'],
            cwd=directory, capture_output=True, text=True, timeout=1,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None, 0
    if result.returncode != 0:
        return None, 0

    lines = result.stdout.rstrip('\n').split('\n') if result.stdout.strip() else []
    branch = None
    # "## main...origin/main [ahead 1]" / "## No commits yet on main" / "## HEAD (no branch)"
    if lines and lines[0].startswith('## '):
        header = lines.pop(0)[3:]
        if header.startswith('No commits yet on '):
            branch = header[len('No commits yet on '):]
        elif not header.startswith('HEAD (no branch)'):
            branch = header.split('...')[0]
    modified = sum(1 for line in lines if line.startswith((' M', 'M')))
    return branch, modified


# ========== 各行 ==========

def build_line1(data, width):
    workspace = data.get('workspace') or {}
    current_dir = workspace.get('current_dir') or data.get('cwd') or '.'
    branch, modified = git_info(current_dir)

    cost = data.get('cost') or {}
    added = cost.get('total_lines_added') or 0
    removed = cost.get('total_lines_removed') or 0
    diff = pill(f'+{added} -{removed}', DIFF_COLOR) if added or removed else ''

    dir_name = os.path.basename(current_dir.rstrip('/')) or current_dir

    # ブランチ名は幅に余裕があれば省略しない。足りなければ 20 → 10 文字に縮める
    for limit in (None, 20, 10):
        shown = branch
        if branch and limit and len(branch) > limit:
            shown = branch[:limit - 1] + '…'
        branch_text = ''
        if shown:
            branch_text = f'{ICON_BRANCH} {shown}' + (f' M{modified}' if modified else '')
        segments = [
            (3, pill(f'{ICON_FOLDER} {dir_name}', DIR_COLOR)),
            (2, pill(branch_text, BRANCH_COLOR) if branch_text else ''),
            (1, diff),
        ]
        line = ' '.join(text for _, text in segments if text)
        if display_width(line) <= width:
            return line
    return fit(segments, width, ' ')


def build_model(data):
    """モデル名と、既定と違う状態（fast mode / effort / thinking off）"""
    model = shorten_model_name((data.get('model') or {}).get('display_name') or 'Unknown')
    badges = []
    if data.get('fast_mode'):
        badges.append(paint(ICON_FAST, YELLOW))
    effort = (data.get('effort') or {}).get('level')
    if effort and effort != 'medium':
        badges.append(paint(effort, TEAL))
    if (data.get('thinking') or {}).get('enabled') is False:
        badges.append(paint('!t', RED))
    return ' '.join([paint(model, MODEL_COLOR)] + badges)


def build_rate_limit(label, window):
    if not window or window.get('used_percentage') is None:
        return ''
    percentage = window['used_percentage']
    text = paint(f'{label} {percentage:.0f}%', usage_color(percentage))
    if label == '5h' and window.get('resets_at'):
        text += ' ' + paint(format_remaining(window['resets_at']), DIM_COLOR)
    return text


def build_line2(data, width):
    context = data.get('context_window') or {}
    percentage = context.get('used_percentage')
    context_text = ''
    tokens_text = ''
    if percentage is not None:
        percentage = min(100, round(percentage))
        context_text = f'{progress_bar(percentage)} {paint(f"{percentage}%", usage_color(percentage))}'
        size = context.get('context_window_size')
        if size:
            used = context.get('total_input_tokens') or 0
            tokens_text = paint(f'{format_tokens(used)}/{format_tokens(size)}', TEXT)

    rate_limits = data.get('rate_limits') or {}
    five_hour = build_rate_limit('5h', rate_limits.get('five_hour'))
    seven_day = build_rate_limit('7d', rate_limits.get('seven_day'))

    hit_ratio = (data.get('prompt_cache') or {}).get('hit_ratio')
    cache = paint(f'{ICON_CACHE} {hit_ratio * 100:.0f}%', CACHE_COLOR) if hit_ratio is not None else ''

    session_id = data.get('session_id') or ''
    session = paint(f'#{session_id[:8]}', DIM_COLOR) if session_id else ''

    # 使用率とトークン数は空白でつなぎ、他の項目は · で区切る
    context_part = ' '.join(t for t in (context_text, tokens_text) if t)
    segments = [
        (7, context_part),
        (6, five_hour),
        (3, seven_day),
        (2, cache),
        (5, build_model(data) + (' ' + session if session else '')),
    ]
    return fit(segments, width, SEPARATOR)


def main():
    try:
        data = json.loads(sys.stdin.read() or '{}')
    except json.JSONDecodeError:
        data = {}

    width = terminal_width()
    for line in (build_line1(data, width), build_line2(data, width)):
        if line:
            print(line)


if __name__ == '__main__':
    main()
