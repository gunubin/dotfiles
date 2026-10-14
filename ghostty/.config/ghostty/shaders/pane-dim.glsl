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
 *
 * tmux の popup（tmux-toggle-popup）が開いているときは、pane の代わりに popup を主役にする:
 *   - popup の外側を、pane のときより強くぼかして暗くする（モーダルの背景のように）
 *   - popup の下に影を落とし、縁をタブの色でうっすら光らせる
 *   - 開いた直後は POPUP_FADE 秒かけて背景が沈む
 *
 * そのほかの演出:
 *   - コピーモード中は、アクティブな pane の内側の縁をラベンダー色でうっすら光らせる
 *   - ズーム中は、画面の外周を黄色でうっすら光らせ続ける
 *   - アクティブな pane で直前のコマンドが失敗したら、その pane の内側の縁を赤く光らせる
 *   - どこかの Claude が処理中なら、画面の右上で Claude のキャラ（起動画面のロゴ）が動く。
 *     足踏み・左右に歩く・跳ねる・きょろきょろ・手を振る、を MASCOT_ACTION 秒ごとに入れ替える
 *   - prefix を押してから次のキーまでの間、画面の外周をタブの色で光らせる
 * 切り替えは、カーソルが別の pane に移ったことで見分ける（シェーダーには前の pane の位置が
 * わからないので、暗くなる側はすぐ切り替わる）。
 *
 * アクティブな pane と popup の位置などは、tmux がステータスバー右端の12マスの色にして渡す
 * （~/.config/tmux/scripts/pane-marker.sh。値の入れ方もそちらに書いている）。
 * 目印の値が読めないときは何もしない。12マスは周りの色で塗りつぶして見えなくする。余白も塗り直す（mainImage の中のコメントを参照）。
 *
 * 前提:
 *   - ステータスバーは上（status-position top）
 *   - Ghostty の window-padding-color = extend-always（画面の角の余白が右上のマスの色になる）
 *   - 余白の幅と高さは、目印の色の境目から測る（全画面ではメニューバーの裏の分も余白になるため）
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
const float POPUP_BLUR = 2.5;              // popup の背景のぼかしの半径（px）
const float POPUP_DIM = 0.55;              // popup の背景に重ねる色の濃さ
const float POPUP_SHADOW = 0.6;            // popup の影の濃さ
const float POPUP_SHADOW_WIDTH = 40.0;     // popup の影が広がる幅（px）
const float POPUP_SHADOW_OFFSET = 12.0;    // popup の影を下にずらす量（px）
const float POPUP_GLOW = 0.35;             // popup の縁の光の強さ
const float POPUP_GLOW_WIDTH = 16.0;       // popup の縁の光が広がる幅（px）
const float POPUP_FADE = 0.2;              // popup を開いてから背景が沈みきるまでの秒数
const vec3 COPY_COLOR = vec3(0.71, 0.75, 1.0); // コピーモード中の縁の光の色（catppuccin Mocha の lavender）
const float COPY_GLOW = 0.35;              // コピーモード中の縁の光の強さ
const float COPY_WIDTH = 28.0;             // コピーモードの光が pane の縁から内側へ広がる幅（px）
const vec3 ZOOM_COLOR = vec3(0.98, 0.89, 0.69); // ズーム中の外周の光の色（catppuccin Mocha の yellow）
const float ZOOM_GLOW = 0.25;              // ズーム中の外周の光の強さ
const vec3 FAILED_COLOR = vec3(0.95, 0.55, 0.66); // コマンド失敗の縁の光の色（catppuccin Mocha の red）
const float FAILED_GLOW = 0.4;             // コマンド失敗の縁の光の強さ
const vec3 MASCOT_COLOR = vec3(0.85, 0.47, 0.34); // Claude のキャラの色（Claude のオレンジ）
const vec2 MASCOT_PIXEL = vec2(8.0, 12.0); // キャラのドット1つの大きさ（px）。端末の半角ブロックに合わせて縦長
const float MASCOT_MARGIN = 24.0;          // キャラと画面の右端・ステータスバーとの間（px）
const float MASCOT_STEP = 0.25;            // 足を踏みかえる間隔（秒）
const float MASCOT_ACTION = 5.0;           // 動きを入れ替える間隔（秒）
const float MASCOT_WALK = 160.0;           // 左右に歩くときに進む距離（px）
const float MASCOT_JUMP = 24.0;            // 跳ねる高さ（px）
const float MASCOT_HOP = 0.6;              // 1回跳ねる長さ（秒）
const float MASCOT_WAVE = 0.3;             // 手を上げ下げする間隔（秒）
const float MASCOT_BLINK_EVERY = 3.2;      // まばたきの間隔（秒）
const float MASCOT_BLINK = 0.15;           // 目を閉じている長さ（秒）
const float PREFIX_GLOW = 0.5;             // prefix を押したときの外周の光の強さ
const float PREFIX_WIDTH = 24.0;           // prefix の光が外周から広がる幅（px）
const float MARKER_CELLS = 12.0;           // pane-marker.sh が出す目印のマスの数
const float MAGIC = 2730.0;                // pane-marker.sh の目印の値
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

// px 位置のマスに入っている値（0〜4095）を読む（Ghostty の座標は左上が原点）。
// 各チャンネルは 16 段階で、段階の真ん中の値で入っているので、16 で割って切り捨てる
float readValue(vec2 px) {
    vec3 c = texture(iChannel0, px / iResolution.xy).rgb;
    c = toSrgb(toLinear(c) * P3_TO_SRGB);
    vec3 n = clamp(floor(c * 255.0 / 16.0), 0.0, 15.0);
    return n.r * 256.0 + n.g * 16.0 + n.b;
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

// 目印の1マス目の色が、start から dir の向きにどこまで続くかを二分探索で探す。
// 続く最後の位置（px）を返す。end は1マス目の色ではない位置
float findMarkerEnd(vec2 start, vec2 end) {
    vec3 marker = texture(iChannel0, start / iResolution.xy).rgb;
    float lo = 0.0;  // ここまでは1マス目の色（start からの割合）
    float hi = 1.0;  // ここは1マス目の色ではない
    for (int i = 0; i < 12; i++) {
        float mid = (lo + hi) * 0.5;
        vec3 c = texture(iChannel0, mix(start, end, mid) / iResolution.xy).rgb;
        if (distance(c, marker) < 0.004) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return hi;
}

// 長方形までの距離（px）。内側は 0
float rectDistance(vec2 p, vec2 rectMin, vec2 rectMax) {
    return length(max(max(rectMin - p, p - rectMax), 0.0));
}

// 長方形の枠からの距離（内側も外側も正の値）
float edgeDistance(vec2 p, vec2 rectMin, vec2 rectMax) {
    float outside = rectDistance(p, rectMin, rectMax);
    if (outside > 0.0) {
        return outside;
    }
    vec2 toMin = p - rectMin;
    vec2 toMax = rectMax - p;
    return min(min(toMin.x, toMax.x), min(toMin.y, toMax.y));
}

// Claude のキャラのドット絵（Claude Code の起動画面のロゴ ▐▛███▜▌ を半角ブロック単位で並べたもの）。
// 横 18 ドット × 縦 5 ドット。各行のビット i が左から i 番目のドット
const uint MASCOT_ROW0 = 0x7ff8u;        // ...############...
const uint MASCOT_EYES = 0x6fd8u;        // ...##.######.##...（目は穴）
const uint MASCOT_EYES_LEFT = 0x77e8u;   // ...#.######.###...（左を見る）
const uint MASCOT_EYES_RIGHT = 0x5fb8u;  // ...###.######.#...（右を見る）
const uint MASCOT_ROW2 = 0x1fffeu;       // .################.（両腕）
const uint MASCOT_ROW3 = 0x7ff8u;        // ...############...
const uint MASCOT_LEGS_A = 0x2850u;      // ....#.#....#.#....
const uint MASCOT_LEGS_B = 0x5028u;      // ...#.#......#.#...
const uint MASCOT_LEGS_JUMP = 0x3030u;   // ....##......##....（跳んでいる間は足を縮める）
const uint MASCOT_ROW0_HAND = 0x37ff8u;  // ...############.##（右手を高く上げる）
const uint MASCOT_ROW1_ARM = 0x3efd8u;   // ...##.######.#####（右腕を上げる）
const uint MASCOT_ROW2_WAVE = 0x7ffeu;   // .##############...（上げた右腕の元の位置が空く）

float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// p がキャラのドットの上なら true。origin は足踏みしているときのキャラの左上
bool mascotAt(vec2 p, vec2 origin) {
    // 動きの種類。0: 足踏み / 1: 左右に歩く / 2: 跳ねる / 3: きょろきょろ / 4: 手を振る
    float segment = floor(iTime / MASCOT_ACTION);
    int action = int(hash1(segment) * 5.0);
    float t = iTime - segment * MASCOT_ACTION;
    bool stepB = mod(floor(iTime / MASCOT_STEP), 2.0) >= 1.0;
    bool blinking = mod(iTime, MASCOT_BLINK_EVERY) < MASCOT_BLINK;

    uint row0 = MASCOT_ROW0;
    uint row1 = blinking ? MASCOT_ROW0 : MASCOT_EYES;
    uint row2 = MASCOT_ROW2;
    uint legs = stepB ? MASCOT_LEGS_B : MASCOT_LEGS_A;

    if (action == 1) {
        // 左へ歩いて戻ってくる
        origin.x -= MASCOT_WALK * (0.5 - 0.5 * cos(6.2831853 * t / MASCOT_ACTION));
    } else if (action == 2) {
        float hop = abs(sin(3.1415927 * t / MASCOT_HOP));
        origin.y -= MASCOT_JUMP * hop;
        legs = hop > 0.2 ? MASCOT_LEGS_JUMP : MASCOT_LEGS_A;
    } else if (action == 3) {
        // 左を見る → 右を見る → 前を見る を繰り返す。足は止める
        float look = mod(t, 2.4);
        if (!blinking) {
            row1 = look < 0.8 ? MASCOT_EYES_LEFT : (look < 1.6 ? MASCOT_EYES_RIGHT : MASCOT_EYES);
        }
        legs = MASCOT_LEGS_A;
    } else if (action == 4) {
        // 右手を振る。足は止める
        bool high = mod(floor(t / MASCOT_WAVE), 2.0) >= 1.0;
        row0 = high ? MASCOT_ROW0_HAND : MASCOT_ROW0;
        if (!blinking) {
            row1 = MASCOT_ROW1_ARM;
        } else {
            row1 = MASCOT_ROW0 | (MASCOT_ROW1_ARM & ~MASCOT_EYES);
        }
        row2 = MASCOT_ROW2_WAVE;
        legs = MASCOT_LEGS_A;
    }

    vec2 spot = floor((p - origin) / MASCOT_PIXEL);
    if (spot.x < 0.0 || spot.x >= 18.0 || spot.y < 0.0 || spot.y >= 5.0) {
        return false;
    }
    int y = int(spot.y);
    uint row = y == 0 ? row0 : (y == 1 ? row1 : (y == 2 ? row2 : (y == 3 ? MASCOT_ROW3 : legs)));
    return ((row >> uint(spot.x)) & 1u) == 1u;
}

// 長方形の内側なら true
bool insideRect(vec2 p, vec2 rectMin, vec2 rectMax) {
    return all(greaterThanEqual(p, rectMin)) && all(lessThan(p, rectMax));
}

// 非アクティブな pane を沈める
void applyPanes(inout vec4 fragColor, vec2 uv, vec2 px, bool inPadding, vec2 onGrid, vec2 gridMin, vec2 cellSize,
                float left, float top, float width, float height) {
    // アクティブな pane は、上の見出しの行と左右下の枠線まで含めて沈めない
    vec2 activeMin = gridMin + vec2(left - 1.0, top - 1.0) * cellSize;
    vec2 activeMax = gridMin + vec2(left + width + 1.0, top + height + 1.0) * cellSize;

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
    float dist = rectDistance(onGrid, activeMin, activeMax);
    color = mix(color, SHADE, SHADOW * exp(-dist / SHADOW_WIDTH) * amount);

    fragColor.rgb = color;
}

// popup の外側を沈め、popup に影と縁の光を付ける。noBlur は余白とステータスバーの行（目印の色がにじまないよう、ぼかさない）
void applyPopup(inout vec4 fragColor, vec2 uv, vec2 px, bool noBlur, vec2 gridMin, vec2 cellSize,
                float cols, float rows, float popupW, float popupH, vec3 glowColor) {
    // tmux（3.8）は popup を画面の中央に置く。ステータスバーの行も含めた画面全体で計算する
    //   左端 = (列数 - 1) / 2 - 幅 / 2
    //   下端 = (行数 - 1) / 2 + 高さ / 2 で、上端はそこから高さを引いた位置（どれも整数の割り算）
    // 画面全体の画像で、70% の popup（59 行の画面で 41 行）の位置を測って確かめた
    vec2 popupCell = vec2(floor((cols - 1.0) / 2.0) - floor(popupW / 2.0),
                          floor((rows - 1.0) / 2.0) + floor(popupH / 2.0) - popupH);
    vec2 popupMin = gridMin + popupCell * cellSize;
    vec2 popupMax = popupMin + vec2(popupW, popupH) * cellSize;
    if (insideRect(px, popupMin, popupMax)) {
        return;
    }

    // 開いた直後（前のカーソルが popup の外で、今のカーソルが中）は、背景を少しずつ沈める
    float since = iTime - iTimeCursorChange;
    bool opened = !insideRect(iPreviousCursor.xy, popupMin, popupMax)
        && insideRect(iCurrentCursor.xy, popupMin, popupMax);
    float amount = opened ? smoothstep(0.0, POPUP_FADE, since) : 1.0;

    vec3 color = noBlur ? fragColor.rgb : mix(fragColor.rgb, blurred(uv, POPUP_BLUR), amount);

    // 濃い紺を重ねる。画面の端ほど濃くする
    vec2 fromEdge = min(px, iResolution.xy - px);
    float edge = exp(-min(fromEdge.x, fromEdge.y) / (EDGE_WIDTH * min(iResolution.x, iResolution.y)));
    color = mix(color, SHADE, min(1.0, POPUP_DIM + EDGE_DIM * edge) * amount);

    // 下にずらした影
    vec2 shadowOffset = vec2(0.0, POPUP_SHADOW_OFFSET);
    float shadowDist = rectDistance(px, popupMin + shadowOffset, popupMax + shadowOffset);
    color = mix(color, SHADE, POPUP_SHADOW * exp(-shadowDist / POPUP_SHADOW_WIDTH) * amount);

    // 縁の光
    float glowDist = rectDistance(px, popupMin, popupMax);
    color += glowColor * POPUP_GLOW * exp(-glowDist / POPUP_GLOW_WIDTH) * amount;

    fragColor.rgb = color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // 1マス目は右上の角の余白から読む（余白はそのマスの色に塗られている）
    vec2 corner = vec2(iResolution.x - 0.5, 0.5);
    float first = readValue(corner);
    float cw = floor(first / 64.0), ch = mod(first, 64.0);
    if (cw < 4.0 || ch < 4.0) {
        return;
    }

    // 右と上の余白は、1マス目の色が角からどこまで続くかで測る。
    // 横は2マス目で、縦はステータスバーの下の行で色が変わる
    vec2 leftward = vec2(iResolution.x - 3.0 * cw - 0.5, 0.5);
    float rightEdge = mix(corner.x, leftward.x, findMarkerEnd(corner, leftward)) + cw;
    vec2 downward = vec2(rightEdge - 0.5 * cw, iResolution.y * 0.5);
    vec2 column = vec2(rightEdge - 0.5 * cw, 0.5);
    float padY = max(0.0, mix(column.y, downward.y, findMarkerEnd(column, downward)) - ch);
    float padX = iResolution.x - rightEdge;

    // 2〜8マス目は、右端から 1.5〜7.5 マス左の、いちばん上の余白から読む
    float cols = readValue(vec2(rightEdge - 1.5 * cw, 0.5));
    float rows = readValue(vec2(rightEdge - 2.5 * cw, 0.5));
    float left = readValue(vec2(rightEdge - 3.5 * cw, 0.5));
    float top = readValue(vec2(rightEdge - 4.5 * cw, 0.5));
    float width = readValue(vec2(rightEdge - 5.5 * cw, 0.5));
    float height = readValue(vec2(rightEdge - 6.5 * cw, 0.5));
    if (readValue(vec2(rightEdge - 7.5 * cw, 0.5)) != MAGIC || cols < 4.0 || rows < 2.0) {
        return;
    }
    // 9〜10マス目は popup の大きさ（枠を含むマス数。開いていなければ 0）、11マス目はタブの色そのもの
    float popupW = readValue(vec2(rightEdge - 8.5 * cw, 0.5));
    float popupH = readValue(vec2(rightEdge - 9.5 * cw, 0.5));
    vec3 glowColor = texture(iChannel0, vec2(rightEdge - 10.5 * cw, 0.5) / iResolution.xy).rgb;
    // 12マス目は prefix・コピーモード・ズーム
    float flags = readValue(vec2(rightEdge - 11.5 * cw, 0.5));
    bool prefix = mod(flags, 2.0) >= 1.0;
    bool copyMode = mod(floor(flags / 2.0), 2.0) >= 1.0;
    bool zoomed = mod(floor(flags / 4.0), 2.0) >= 1.0;
    bool failed = mod(floor(flags / 8.0), 2.0) >= 1.0;
    bool claudeWorking = mod(floor(flags / 16.0), 2.0) >= 1.0;

    // このピクセルが何列目・何行目のマスか（左上が 0, 0）
    vec2 px = fragCoord;
    vec2 gridMin = vec2(padX, padY);
    vec2 gridMax = gridMin + vec2(cols, rows) * vec2(cw, ch);
    vec2 cell = (clamp(px, gridMin, gridMax - 0.5) - gridMin) / vec2(cw, ch);

    // 余白の塗り方。Ghostty の設定では端のマスの色に塗られているが、模様は伸びないので
    // pane の境目の縦線などが余白の手前で途切れ、帯のように見える。
    //   - 上の余白と、ステータスバーの行の横の余白: 背景の色にする（タブや目印の色が伸びないように）。
    //     背景の色は目印の左隣（時計の後ろの空白）から取る
    //   - それ以外の左右と下の余白: 一番端の 1 ピクセルをそのまま伸ばし、線を画面の端まで届かせる
    bool inPadding = any(lessThan(px, gridMin)) || any(greaterThanEqual(px, gridMax));
    vec2 background = vec2(rightEdge - (MARKER_CELLS + 0.5) * cw, padY + 0.5 * ch);
    vec2 onGrid = clamp(px, gridMin, gridMax - 0.5);
    if (inPadding) {
        vec2 from = onGrid.y < gridMin.y + ch ? background : onGrid;
        fragColor = texture(iChannel0, from / iResolution.xy);
    }

    // ステータスバーの行: 目印のマスを、左隣のマスの色で塗りつぶす
    bool statusRow = cell.y < 1.0;
    if (statusRow && !inPadding && px.x >= rightEdge - MARKER_CELLS * cw) {
        fragColor = texture(iChannel0, vec2(background.x, px.y) / iResolution.xy);
    }

    vec2 cellSize = vec2(cw, ch);
    if (popupW > 0.0) {
        applyPopup(fragColor, uv, px, inPadding || statusRow, gridMin, cellSize, cols, rows, popupW, popupH, glowColor);
    } else {
        if (!statusRow) {
            applyPanes(fragColor, uv, px, inPadding, onGrid, gridMin, cellSize, left, top, width, height);

            // コピーモード中は、アクティブな pane の内側の縁をラベンダー色でうっすら光らせる
            vec2 copyMin = gridMin + vec2(left, top) * cellSize;
            vec2 copyMax = gridMin + vec2(left + width, top + height) * cellSize;
            if (copyMode && insideRect(onGrid, copyMin, copyMax)) {
                float dist = edgeDistance(onGrid, copyMin, copyMax);
                fragColor.rgb += COPY_COLOR * COPY_GLOW * exp(-dist / COPY_WIDTH);
            }

            // 直前のコマンドが失敗したら、アクティブな pane の内側の縁を赤く光らせる
            if (failed && insideRect(onGrid, copyMin, copyMax)) {
                float dist = edgeDistance(onGrid, copyMin, copyMax);
                fragColor.rgb += FAILED_COLOR * FAILED_GLOW * exp(-dist / COPY_WIDTH);
            }
        }

        // ズーム中は、画面の外周を黄色でうっすら光らせ続ける
        if (zoomed) {
            vec2 fromEdge = min(px, iResolution.xy - px);
            fragColor.rgb += ZOOM_COLOR * ZOOM_GLOW * exp(-min(fromEdge.x, fromEdge.y) / PREFIX_WIDTH);
        }
    }

    // どこかの Claude が処理中なら、画面の右上（ステータスバーのすぐ下）でキャラが動く
    if (claudeWorking) {
        vec2 mascotOrigin = vec2(gridMax.x - MASCOT_MARGIN - 18.0 * MASCOT_PIXEL.x, gridMin.y + ch + MASCOT_MARGIN * 0.5 + MASCOT_JUMP);
        if (mascotAt(px, mascotOrigin)) {
            fragColor.rgb = MASCOT_COLOR;
        }
    }

    // prefix を押している間は、画面の外周を光らせる
    if (prefix) {
        vec2 fromEdge = min(px, iResolution.xy - px);
        fragColor.rgb += glowColor * PREFIX_GLOW * exp(-min(fromEdge.x, fromEdge.y) / PREFIX_WIDTH);
    }
}
