/*
 * pane-dim.glsl - tmux のアクティブでない pane を、ぼかして暗く沈めるシェーダー
 *
 * tmux は 1 マスに 1 色しか持てず、プログラムが色を指定した文字は window-style で暗くできない。
 * そこで描き終わった画面にこのシェーダーで効果をかけ、文字の色に関係なく沈める。
 *
 * 非アクティブな部分にかける効果:
 *   - すりガラス越しのようにぼかす
 *   - 濃い紺を重ねて暗くする
 *   - 画面の端ほど、さらに暗くする
 *   - アクティブな pane の周りに影を落とす（アクティブな pane が浮き上がって見える）
 * pane を切り替えると、アクティブになった pane が FADE 秒かけて明るくなる。
 * 切り替えは、カーソルが別の pane に移ったことで見分ける（シェーダーには前の pane の位置が
 * わからないので、暗くなる側はすぐ切り替わる）。
 *
 * アクティブな pane の位置は、tmux がステータスバー右端の4マスの色にして渡す
 * （~/.config/tmux/scripts/pane-marker.sh）。目印の値が読めないときは何もしない。
 * 4マスは周りの色で塗りつぶして見えなくする。余白も塗り直す（mainImage の中のコメントを参照）。
 *
 * 前提:
 *   - ステータスバーは上（status-position top）
 *   - Ghostty の window-padding-color = extend-always（画面の角の余白が右上のマスの色になる）
 *   - window-padding-balance = true（余白が左右に均等に付く。上の余白は画面の色から測る）
 *   - window-colorspace は既定の srgb（画面の色が Display P3 に変換されて渡される）
 */

// ========== 設定 ==========
const float DIM = 0.4;                     // 重ねる色の濃さ（0 で重ねない、1 で塗りつぶす）
const vec3 SHADE = vec3(0.03, 0.03, 0.06); // 重ねる色（濃い紺）
const float BLUR = 1.5;                    // ぼかしの半径（px）
const float EDGE_DIM = 0.35;               // 画面の端でさらに暗くする割合
const float EDGE_WIDTH = 0.12;             // 端の暗さが広がる幅（画面の短辺に対する比）
const float SHADOW = 0.35;                 // アクティブな pane の周りの影の濃さ
const float SHADOW_WIDTH = 30.0;           // 影が広がる幅（px）
const float FADE = 0.2;                    // 切り替えでアクティブな pane が明るくなるまでの秒数
const float MAGIC = 165.0;                 // pane-marker.sh の目印の値
// ==========================

// 画面の色は、Ghostty が sRGB から Display P3 に変換して渡してくる（macOS の既定）。
// 目印の値を読むために sRGB へ戻す
vec3 toLinear(vec3 c) {
    vec3 lo = c / 12.92;
    vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
    return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 toSrgb(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    vec3 lo = c * 12.92;
    vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
    return mix(lo, hi, step(vec3(0.0031308), c));
}

// 線形の Display P3 を線形の sRGB にする（行ごとに書いている。v * P3_TO_SRGB で使う）
const mat3 P3_TO_SRGB = mat3(
    1.2249401, -0.2249404, 0.0000000,
    -0.0420569, 1.0420571, 0.0000000,
    -0.0196376, -0.0786361, 1.0982735
);

// px 位置の色を、0〜255 の値で読む（Ghostty の座標は左上が原点）
vec3 readBytes(vec2 topLeftPx) {
    vec3 c = texture(iChannel0, topLeftPx / iResolution.xy).rgb;
    c = toSrgb(toLinear(c) * P3_TO_SRGB);
    return floor(c * 255.0 + 0.5);
}

// 目印の4マスを読む。読めたら true
// 横方向の値（列数・pane の左・pane の幅）は 255 を超えるので、上位と下位の2つから組み立てる
bool readMarker(out vec3 m1, out vec3 m2, out vec3 m3, out vec3 m4, out float padX) {
    m1 = readBytes(vec2(iResolution.x - 0.5, 0.5));
    float cw = m1.r, cols = m1.g * 256.0 + m1.b;
    padX = floor((iResolution.x - cols * cw) * 0.5);
    float rightEdge = iResolution.x - padX;
    m2 = readBytes(vec2(rightEdge - 1.5 * cw, 0.5));
    m3 = readBytes(vec2(rightEdge - 2.5 * cw, 0.5));
    m4 = readBytes(vec2(rightEdge - 3.5 * cw, 0.5));
    return cw >= 4.0 && m2.r >= 4.0 && cols >= 4.0 && padX >= 0.0 && abs(m4.b - MAGIC) < 2.5;
}

// 3x3 のぼかし
vec3 blurred(vec2 uv, float radius) {
    vec2 texel = radius / iResolution.xy;
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float weight = x == 0 && y == 0 ? 4.0 : (x == 0 || y == 0 ? 2.0 : 1.0);
            sum += texture(iChannel0, uv + vec2(x, y) * texel).rgb * weight;
            total += weight;
        }
    }
    return sum / total;
}

// 上の余白の高さを測る。全画面ではメニューバーの裏の分も余白になり、高さを計算では求められない。
// 一番右の列を上からたどると、余白とステータスバーの行は目印の1マス目の色で、その下の行で色が変わる。
// その境目を二分探索で探し、ステータスバーの行の高さを引く
float findPadTop(float x, float ch) {
    vec3 marker = texture(iChannel0, vec2(x, 0.5) / iResolution.xy).rgb;
    float lo = 0.0;                     // ここまでは目印の色
    float hi = iResolution.y * 0.5;     // ここは目印の色ではない
    for (int i = 0; i < 12; i++) {
        float mid = floor((lo + hi) * 0.5);
        vec3 c = texture(iChannel0, vec2(x, mid + 0.5) / iResolution.xy).rgb;
        if (distance(c, marker) < 0.004) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return max(0.0, hi - ch);
}

// 長方形の内側なら true
bool insideRect(vec2 p, vec2 rectMin, vec2 rectMax) {
    return all(greaterThanEqual(p, rectMin)) && all(lessThan(p, rectMax));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // 1マス目は右上の角の余白から読む（余白はそのマスの色に塗られている）
    // 2〜4マス目は、右端から 1.5〜3.5 マス左の、いちばん上の余白から読む
    vec3 m1, m2, m3, m4;
    float padX;
    if (!readMarker(m1, m2, m3, m4, padX)) {
        return;
    }
    float cw = m1.r, ch = m2.r, cols = m1.g * 256.0 + m1.b;
    float rightEdge = iResolution.x - padX;
    float rows = m2.g;
    float padY = findPadTop(rightEdge - 0.5 * cw, ch);

    // このピクセルが何列目・何行目のマスか（左上が 0, 0）
    vec2 px = fragCoord;
    vec2 gridMin = vec2(padX, padY);
    vec2 gridMax = gridMin + vec2(cols, rows) * vec2(cw, ch);
    vec2 cell = (clamp(px, gridMin, gridMax - 0.5) - gridMin) / vec2(cw, ch);

    // 余白の塗り方。Ghostty の設定では端のマスの色に塗られているが、模様は伸びないので
    // pane の境目の縦線などが余白の手前で途切れ、帯のように見える。
    //   - 上の余白: 背景の色にする（タブの色が伸びないように）。背景の色は目印の左隣（時計の後ろの空白）から取る
    //   - 左右と下の余白: 一番端の 1 ピクセルをそのまま伸ばし、線を画面の端まで届かせる
    bool inPadding = any(lessThan(px, gridMin)) || any(greaterThanEqual(px, gridMax));
    vec2 background = vec2(rightEdge - 4.5 * cw, padY + 0.5 * ch);
    vec2 onGrid = clamp(px, gridMin, gridMax - 0.5);
    if (inPadding) {
        vec2 from = px.y < gridMin.y ? background : onGrid;
        fragColor = texture(iChannel0, from / iResolution.xy);
    }

    // ステータスバーの行: 目印の4マスを、左隣のマスの色で塗りつぶす
    if (cell.y < 1.0) {
        if (!inPadding && px.x >= rightEdge - 4.0 * cw) {
            fragColor = texture(iChannel0, vec2(background.x, px.y) / iResolution.xy);
        }
        return;
    }

    // アクティブな pane は、上の見出しの行と左右下の枠線まで含めて沈めない
    float left = m3.r * 256.0 + m3.g, top = m2.b, width = m4.r * 256.0 + m4.g, height = m3.b;
    vec2 activeMin = gridMin + vec2(left - 1.0, top - 1.0) * vec2(cw, ch);
    vec2 activeMax = gridMin + vec2(left + width + 1.0, top + height + 1.0) * vec2(cw, ch);

    // 沈める強さ。非アクティブは 1、アクティブは 0。
    // 切り替えた直後（前のカーソルがアクティブな pane の外）は、アクティブな pane も 1 から 0 へ下げていく
    // 余白は隣のマスと同じ扱いにする（画面の端に接した pane の外側の余白を、その pane に含める）
    float amount = 1.0;
    if (insideRect(onGrid, activeMin, activeMax)) {
        float since = iTime - iTimeCursorChange;
        bool switched = !insideRect(iPreviousCursor.xy, activeMin, activeMax)
            && insideRect(iCurrentCursor.xy, activeMin, activeMax);
        amount = switched ? 1.0 - smoothstep(0.0, FADE, since) : 0.0;
    }
    if (amount <= 0.0) {
        return;
    }

    // ぼかし（余白は塗り直したので、ぼかさない）
    vec3 color = inPadding ? fragColor.rgb : mix(fragColor.rgb, blurred(uv, BLUR), amount);

    // 濃い紺を重ねる。画面の端ほど濃くする
    vec2 fromEdge = min(px, iResolution.xy - px);
    float edge = exp(-min(fromEdge.x, fromEdge.y) / (EDGE_WIDTH * min(iResolution.x, iResolution.y)));
    color = mix(color, SHADE, min(1.0, DIM + EDGE_DIM * edge) * amount);

    // アクティブな pane の周りの影
    vec2 outside = max(activeMin - onGrid, onGrid - activeMax);
    float dist = length(max(outside, 0.0));
    color = mix(color, SHADE, SHADOW * exp(-dist / SHADOW_WIDTH) * amount);

    fragColor.rgb = color;
}
