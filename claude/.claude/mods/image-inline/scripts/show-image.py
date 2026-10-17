#!/usr/bin/env python3
"""tmux のポップアップの中に画像を描き、キーが押されるまで待つ。

Claude Code 本体は tmux の中で画像を本文に付けて描けない（tmux が画像を知らず、位置がずれる）ので、
mod は代わりにこのスクリプトを tmux のポップアップで走らせる。画像は kitty 画像プロトコルの
「Unicode プレースホルダ」方式で描く。画像を仮想配置で端末に送り、文字セル（U+10EEEE + 行・列の
結合文字）の上に端末が画像を重ねるので、ポップアップが閉じれば文字と一緒に消える。
"""
import base64
import sys
import termios
import tty

# kitty の rowcolumn-diacritics.txt の先頭 64 個（行・列の番号を表す結合文字）
DIACRITICS = [chr(c) for c in [
    0x0305, 0x030D, 0x030E, 0x0310, 0x0312, 0x033D, 0x033E, 0x033F, 0x0346, 0x034A, 0x034B, 0x034C, 0x0350, 0x0351,
    0x0352, 0x0357, 0x035B, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369, 0x036A, 0x036B, 0x036C, 0x036D,
    0x036E, 0x036F, 0x0483, 0x0484, 0x0485, 0x0486, 0x0487, 0x0592, 0x0593, 0x0594, 0x0595, 0x0597, 0x0598, 0x0599,
    0x059C, 0x059D, 0x059E, 0x059F, 0x05A0, 0x05A1, 0x05A8, 0x05A9, 0x05AB, 0x05AC, 0x05AF, 0x05C4, 0x0610, 0x0611,
    0x0612, 0x0613, 0x0614, 0x0615, 0x0616, 0x0617, 0x0657, 0x0658,
]]
PLACEHOLDER = '\U0010EEEE'
ESC = '\x1b'


def passthrough(sequence: str) -> str:
    """tmux の中なら DCS tmux; ... ST で包む（中の ESC は二重にする）。外ならそのまま"""
    import os
    if os.environ.get('TMUX'):
        return f'{ESC}Ptmux;{sequence.replace(ESC, ESC + ESC)}{ESC}\\'
    return sequence


def main() -> None:
    png, caption, columns, rows, image_id = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
    columns = max(1, min(len(DIACRITICS), columns))
    rows = max(1, min(len(DIACRITICS), rows))
    out = sys.stdout

    out.write(f'\n  {caption}\n\n')
    # 仮想配置（U=1）: 画像はカーソル位置ではなくプレースホルダのセルに結び付く
    path_b64 = base64.b64encode(png.encode()).decode()
    out.write(passthrough(f'{ESC}_Gf=100,t=f,a=T,U=1,q=2,i={image_id},c={columns},r={rows};{path_b64}{ESC}\\'))
    # 画像 ID は前景色（24bit）で伝える
    fg = f'{ESC}[38;2;{(image_id >> 16) & 255};{(image_id >> 8) & 255};{image_id & 255}m'
    for row in range(rows):
        cells = ''.join(PLACEHOLDER + DIACRITICS[row] + DIACRITICS[column] for column in range(columns))
        out.write(f'  {fg}{cells}{ESC}[39m\n')
    out.write(f'\n  {ESC}[2m何かキーを押すか、クリックすると閉じる{ESC}[0m')
    # マウスのクリックも入力として受け取る（押した・離したを報告させる）
    out.write(f'{ESC}[?1000h')
    out.flush()

    # キーかマウスの最初の 1 バイトが来るまで待つ
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        sys.stdin.buffer.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        out.write(f'{ESC}[?1000l')

    # 端末に残した画像データを捨てる
    out.write(passthrough(f'{ESC}_Ga=d,d=I,i={image_id},q=2{ESC}\\'))
    out.flush()


if __name__ == '__main__':
    main()
