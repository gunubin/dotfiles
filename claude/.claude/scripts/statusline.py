#!/usr/bin/env python3
"""Claude Code のステータスライン

Claude Code が stdin で渡す JSON だけを使って2行を表示する。

    1行目（丸い帯）:  dotfiles   main M1  +156 -23
    2行目:            12% 120K/1M   91%  Opus 5.5 high  #02de19d9
                     （週間枠はペースが速いとき、5時間枠は使用率が高いときだけ、使用率の後ろに帯で出る）

幅が足りないときは優先度の低い項目から外す。
NO_COLOR か STATUSLINE_NO_COLOR を設定すると色を付けない。
データの仕様: https://code.claude.com/docs/en/statusline#available-data
"""

import json
import math
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
OVERLAY0 = (108, 112, 134)
BASE = (30, 30, 46)
CRUST = (17, 17, 27)

# 表示要素ごとの色（配色を変えるときはここだけ差し替える）
DIR_COLOR = LAVENDER
BRANCH_COLOR = SKY
DIFF_COLOR = GREEN
MODEL_COLOR = MAUVE
CACHE_COLOR = GREEN
DIM_COLOR = SURFACE2

# 進捗バーのパステルグラデーション（ティール→ラベンダー→ピンク→ピーチ）
PROGRESS_GRADIENT = [TEAL, LAVENDER, PINK, PEACH]
PROGRESS_WIDTH = 15
FIVE_HOUR_SHOW_FROM = 50  # 5時間枠はこの使用率（%）以上のときだけ出す
WEEKLY_PACE_MARGIN = 5    # 週間枠は使用率が週の経過割合をこのポイント以上超えたときだけ出す
WEEK_SECONDS = 7 * 24 * 60 * 60
PROGRESS_EMPTY_COLOR = OVERLAY0  # 空きの枠は暗すぎると見えないので少し明るく

# 帯の背景の濃さ（暗い背景色に元の色をどれだけ混ぜるか。0 で背景色、1 で元の色）
LINE1_PILL_STRENGTH = 0.33  # 1行目: 2行目より濃いが、明るい文字が読める暗さの帯
SOFT_PILL_STRENGTH = 0.18   # 2行目: 背景が目立たない帯
LINE1_TEXT_LIGHTEN = 0.2   # 1行目の文字: 帯の色を白にこの割合だけ寄せる（読みやすさの比 4.7〜5.0）

# ========== アイコン（Nerd Font） ==========
ICON_FOLDER = ''
ICON_BRANCH = ''
ICON_CACHE = ''
ICON_FAST = '⚡'
# 進捗バー（Nerd Font の nf-pl 系 progress 記号）
PROGRESS_FILLED = {'left': '\uee03', 'middle': '\uee04', 'right': '\uee05'}
PROGRESS_EMPTY = {'left': '\uee00', 'middle': '\uee01', 'right': '\uee02'}
PILL_LEFT = ''
PILL_RIGHT = ''

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


def tint(text, rgb):
    """帯の中で使う文字色。背景色を消さないよう reset しない"""
    return f'{fg(rgb)}{text}'


def pill(text, rgb, text_rgb=CRUST):
    """丸い端の帯。text の中の色は tint() で付ける。色なしのときは両端を空白にする"""
    if NO_COLOR:
        return f' {text} '
    return f'{fg(rgb)}{PILL_LEFT}{bg(rgb)}{fg(text_rgb)}{text}{reset()}{fg(rgb)}{PILL_RIGHT}{reset()}'


def mute(rgb, strength):
    """暗い背景色に rgb を strength の割合で混ぜた色"""
    return tuple(round(b + (c - b) * strength) for b, c in zip(BASE, rgb))


def line1_pill(text, rgb):
    """1行目の帯: 暗めの色で塗り、文字は同じ色味の明るいパステル"""
    text_rgb = tuple(round(c + (255 - c) * LINE1_TEXT_LIGHTEN) for c in rgb)
    return pill(text, mute(rgb, LINE1_PILL_STRENGTH), text_rgb)


def soft_pill(text, rgb):
    """2行目の帯: 背景は暗い背景色に薄く混ぜた色、文字は rgb"""
    return pill(text, mute(rgb, SOFT_PILL_STRENGTH), rgb)


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
    """Nerd Font の進捗バー記号で描く。両端は丸く、空きは枠だけになる"""
    # 切り上げて、少しでも使っていれば1マス目を光らせる
    filled = math.ceil(PROGRESS_WIDTH * percentage / 100)
    bar = ''
    for i in range(PROGRESS_WIDTH):
        part = 'left' if i == 0 else 'right' if i == PROGRESS_WIDTH - 1 else 'middle'
        if i < filled:
            color = RED if percentage >= 90 else gradient_color(i / (PROGRESS_WIDTH - 1))
            bar += tint(PROGRESS_FILLED[part], color)
        else:
            bar += tint(PROGRESS_EMPTY[part], PROGRESS_EMPTY_COLOR)
    return bar


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
    diff = line1_pill(f'+{added} -{removed}', DIFF_COLOR) if added or removed else ''

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
            (3, line1_pill(f'{ICON_FOLDER} {dir_name}', DIR_COLOR)),
            (2, line1_pill(branch_text, BRANCH_COLOR) if branch_text else ''),
            (1, diff),
        ]
        line = ' '.join(text for _, text in segments if text)
        if display_width(line) <= width:
            return line
    return fit(segments, width, ' ')


def build_model(data):
    """モデル名の帯と、既定と違う状態（fast mode / effort / thinking off）"""
    parts = [shorten_model_name((data.get('model') or {}).get('display_name') or 'Unknown')]
    if data.get('fast_mode'):
        parts.append(ICON_FAST)
    effort = (data.get('effort') or {}).get('level')
    if effort and effort != 'medium':
        parts.append(effort)
    model = soft_pill(' '.join(parts), MODEL_COLOR)
    # thinking off は警告なので赤い帯を別に付ける
    if (data.get('thinking') or {}).get('enabled') is False:
        model += ' ' + soft_pill('!t', RED)
    return model


def build_five_hour(window):
    """5時間枠: 上限が近いときだけ、使用率とリセットまでの時間を帯で出す"""
    if not window or window.get('used_percentage') is None:
        return ''
    percentage = window['used_percentage']
    if percentage < FIVE_HOUR_SHOW_FROM:
        return ''
    text = f'5h {percentage:.0f}%'
    if window.get('resets_at'):
        text += f' {format_remaining(window["resets_at"])}'
    return soft_pill(text, usage_color(percentage))


def build_seven_day(window):
    """週間枠: 週の経過割合より使用率が先に進んでいる（ペースが速い）ときだけ帯で出す"""
    if not window or window.get('used_percentage') is None or not window.get('resets_at'):
        return ''
    percentage = window['used_percentage']
    elapsed = 100 * (1 - (window['resets_at'] - time.time()) / WEEK_SECONDS)
    if percentage < elapsed + WEEKLY_PACE_MARGIN:
        return ''
    # ペースが速いこと自体が注意なので、90% 未満でもピーチにする
    return soft_pill(f'7d {percentage:.0f}%', RED if percentage >= 90 else PEACH)


def build_line2(data, width):
    context = data.get('context_window') or {}
    # 使用率はセッション開始直後や /compact 直後に null になるが、バーは常に出したいので 0% として描く
    percentage = min(100, round(context.get('used_percentage') or 0))
    context_part = f'{progress_bar(percentage)} {tint(f"{percentage}%", usage_color(percentage))}'
    size = context.get('context_window_size')
    if size:
        used = context.get('total_input_tokens') or 0
        context_part += ' ' + tint(f'{format_tokens(used)}/{format_tokens(size)}', TEXT)
    context_part += reset()

    rate_limits = data.get('rate_limits') or {}
    five_hour = build_five_hour(rate_limits.get('five_hour'))
    seven_day = build_seven_day(rate_limits.get('seven_day'))

    hit_ratio = (data.get('prompt_cache') or {}).get('hit_ratio')
    cache = soft_pill(f'{ICON_CACHE} {hit_ratio * 100:.0f}%', CACHE_COLOR) if hit_ratio is not None else ''

    session_id = data.get('session_id') or ''
    session = paint(f'#{session_id[:8]}', DIM_COLOR) if session_id else ''

    segments = [
        (7, context_part),
        (4, seven_day),
        (6, five_hour),
        (2, cache),
        (5, build_model(data) + (' ' + session if session else '')),
    ]
    return fit(segments, width, ' ')


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
