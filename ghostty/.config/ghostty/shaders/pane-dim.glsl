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
 *   - Claude が処理中の pane では、その pane の左上で Claude のキャラ（起動画面のロゴ）が動く（見えている pane の最大4つ）。
 *     非アクティブな pane でも、キャラは暗くせずに描く。
 *     MASCOT_ACTION 秒ごとに動きを入れ替える。足踏み・左右に歩く・跳ねる・きょろきょろ・手を振る、と
 *     Claude Code の起動画面にある公式の 15 種類（落ちてくる・のぞく・歩いてくる・一回転・ウインクなど）。
 *     処理が長引くと、鍋をかき混ぜるシーン（これも公式）に変わる。
 *     ごくまれに、少し大きくなって足がたくさん生え、リアルな描写になって目が赤く光る化け物になる
 *     キー入力などでカーソルが動いている間は、アクティブな pane のキャラが速く足踏みする（走る）
 *   - Claude が入力待ちの pane では、キャラが公式の jump をくり返し、右隣に「！」を出す
 *   - Claude が終わった直後の pane では、キャラが公式の celebrate をくり返し、周りに紙吹雪が舞う
 *   - git push が成功した直後は、画面の上のほうに花火が上がる（ロケットが上がって弾ける）
 *   - prefix を押してから次のキーまでの間、画面の外周をタブの色で光らせる
 * 切り替えは、カーソルが別の pane に移ったことで見分ける（シェーダーには前の pane の位置が
 * わからないので、暗くなる側はすぐ切り替わる）。
 *
 * アクティブな pane と popup の位置などは、tmux がステータスバー右端の21マスの色にして渡す
 * （~/.config/tmux/scripts/pane-marker.sh。値の入れ方もそちらに書いている）。
 * 目印の値が読めないときは何もしない。21マスは周りの色で塗りつぶして見えなくする。余白も塗り直す（mainImage の中のコメントを参照）。
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
const float MASCOT_MARGIN = 40.0;          // キャラと pane の左端・上端との間（px）。上下左右でそろえる
const float MASCOT_STEP = 0.25;            // 足を踏みかえる間隔（秒）
const float MASCOT_ACTION = 5.0;           // 動きを入れ替える間隔（秒）
const float MASCOT_WALK = 160.0;           // 歩くときに右へ進む距離（px）
const float MASCOT_JUMP = 24.0;            // 跳ねる高さ（px）
const float MASCOT_HOP = 0.6;              // 1回跳ねる長さ（秒）
const float MASCOT_WAVE = 0.3;             // 手を上げ下げする間隔（秒）
const float MASCOT_BLINK_EVERY = 3.2;      // まばたきの間隔（秒）
const float MASCOT_BLINK = 0.15;           // 目を閉じている長さ（秒）
const float CLAWD_FRAME = 0.09;            // 公式の動きの 1 コマの長さ（秒）。公式（0.06 秒）の 1.5 倍
const vec3 MASCOT_DUST = vec3(0.73, 0.76, 0.87); // 着地の土ぼこりの色（catppuccin Mocha の subtext1）
const vec3 MASCOT_SHADOW = vec3(0.42, 0.44, 0.53); // 回るときの影の色（catppuccin Mocha の overlay0）
const float MONSTER_SLOT = 9.0;            // 化け物になるかを決める間隔（秒）。なったときは、この秒数のあいだ化け物でいる
const float MONSTER_CHANCE = 0.03;         // 間隔ごとに化け物になる確率（処理中に 5 分に 1 回くらい）
const vec2 COOK_PIXEL = vec2(8.0);         // 料理のシーンのドット1つの大きさ（px）
const float COOK_FRAME = 0.24;             // 料理のシーンの 1 コマの長さ（秒）。公式（0.16 秒）の 1.5 倍
const float PREFIX_GLOW = 0.5;             // prefix を押したときの外周の光の強さ
const float PREFIX_WIDTH = 24.0;           // prefix の光が外周から広がる幅（px）
const float MASCOT_RUN_STEP = 0.08;        // 走るときに足を踏みかえる間隔（秒）
const float MASCOT_RUN_AFTER = 0.3;        // カーソルが動いてから、走り続ける秒数
const vec3 MASCOT_ALERT = vec3(0.98, 0.89, 0.69); // 入力待ちの「！」の色（catppuccin Mocha の yellow）
const float MASCOT_ALERT_COL = 19.0;       // 「！」を出す列（キャラの右端から1ドットあける）
const float CONFETTI_HEIGHT = 360.0;       // 紙吹雪が舞う範囲の高さ（px）
const float CONFETTI_WIDTH = 320.0;        // 紙吹雪が舞う範囲の幅（px）。キャラの中心から左右に半分ずつ
const float CONFETTI_SIZE = 6.0;           // 紙吹雪の1枚の大きさ（px）
const float FIREWORK_PERIOD = 1.8;         // 花火が1つ上がって消えるまでの秒数
const float FIREWORK_RISE = 0.22;          // そのうちロケットが上がっている割合
const float FIREWORK_RADIUS = 320.0;       // 花火が広がる半径（px）
const float FIREWORK_BRIGHT = 1.6;         // 火花の明るさ
const float MARKER_CELLS = 21.0;           // pane-marker.sh が出す目印のマスの数
const float MAGIC = 2730.0;                // pane-marker.sh の目印の値
const vec2 NESS_PIXEL = vec2(3.0);         // ネスのドット1つの大きさ（px）。16 × 24 ドットで、キャラと同じ高さになる
const float NESS_STEP = 0.1;               // ネスが走るときに足を踏みかえる間隔（秒）
const float NESS_AFTER = 1.0;              // 最後にカーソルが動いてから、ネスが出続ける秒数
const float NESS_GAP = 48.0;               // 渡すときの、キャラの右端とネスの間（px）
const float NESS_TOSS = 0.9;               // プレゼントを1つ渡す間隔（秒）
const float NESS_ACTION = 3.0;             // 入力中のネスが動きを入れ替える間隔（秒）
const float NESS_RUN = 120.0;             // 入力中のネスが右へ走る距離（px）
// 並びは 0: なし / 1: 黒（輪郭・髪） / 2: 赤 / 3: ピンク / 4: 青 / 5: 白 / 6: 灰 / 7: 橙 / 8: 肌 / 9: 黄 / 10: 明るい灰 / 11: 水色 / 12: 暗い赤
const vec3 NESS_COLORS[13] = vec3[13](vec3(0.0), vec3(0.086, 0.094, 0.106), vec3(0.831, 0.224, 0.192), vec3(0.898, 0.663, 0.659), vec3(0.220, 0.325, 0.678), vec3(0.969), vec3(0.392, 0.400, 0.408), vec3(0.871, 0.631, 0.400), vec3(0.910, 0.769, 0.620), vec3(0.902, 0.847, 0.388), vec3(0.627, 0.635, 0.643), vec3(0.42, 0.62, 0.86), vec3(0.55, 0.16, 0.16));
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

// 長方形の内側なら true
bool insideRect(vec2 p, vec2 rectMin, vec2 rectMax) {
    return all(greaterThanEqual(p, rectMin)) && all(lessThan(p, rectMax));
}

// Claude のキャラのドット絵。Claude Code（2.1.300）の起動画面のアニメーションのデータを、
// 1 マスを 2 × 2 ドットに分けて並べたもの。横 18 ドット × 縦 6 ドットで、各行のビット i が左から i 番目のドット
// 腕と胴（上から4行）。腕の形ごとに4つ: down / up / one-up
const uint CLAWD_ARMS[12] = uint[12](0x8u, 0x8u, 0x3fffeu, 0xfff8u, 0x8u, 0x3000eu, 0x1fffcu, 0xfff8u, 0x8u, 0x30008u, 0x1fffeu, 0xfff8u);
// 目の行（上から2行）。目の形ごとに2つ: open / left / right / closed / wink
const uint CLAWD_EYES[10] = uint[10](0xfff0u, 0xdfd0u, 0xefe0u, 0xfff0u, 0xbfb0u, 0xfff0u, 0xfff0u, 0xfff0u, 0xfff0u, 0xffd0u);
// 閉じた目（まぶた）のドット。2行目のこのドットは、下半分を背景の色にする
const uint CLAWD_LIDS[5] = uint[5](0x0u, 0x0u, 0x0u, 0x3030u, 0x3000u);
// 足（下の2行）。足の形ごとに2つ: both / left / right
const uint CLAWD_FEET[6] = uint[6](0xa028u, 0x0u, 0x28u, 0x0u, 0xa000u, 0x0u);
// 一回転するときの向き（6行ずつ）: right-12 / right-30 / right-55 / right-75 / edge / back-105 / back-125 / back-150 / back / left-75 / left-55 / left-30 / left-12
const uint CLAWD_FACING[78] = uint[78](0xfff8u, 0xdfb8u, 0x3fffeu, 0xfff8u, 0xa028u, 0x0u, 0x7ff0u, 0x5f70u, 0xfff8u, 0x7ff0u, 0x5050u, 0x0u, 0x3fe0u, 0x2de0u, 0x3fe0u, 0x3fe0u, 0x28a0u, 0x0u, 0x1fc0u, 0x17c0u, 0x1fc0u, 0x1fc0u, 0x1040u, 0x0u, 0xf80u, 0xf80u, 0xf80u, 0xf80u, 0x880u, 0x0u, 0x1fc0u, 0x1fc0u, 0x1fc0u, 0x1fc0u, 0x1040u, 0x0u, 0x3fe0u, 0x3fe0u, 0x3fe0u, 0x3fe0u, 0x28a0u, 0x0u, 0x7ff0u, 0x7ff0u, 0xfff8u, 0x7ff0u, 0x5050u, 0x0u, 0xfff8u, 0xfff8u, 0x3fffeu, 0xfff8u, 0xa028u, 0x0u, 0x1fc0u, 0x1f40u, 0x1fc0u, 0x1fc0u, 0x1040u, 0x0u, 0x3fe0u, 0x3da0u, 0x3fe0u, 0x3fe0u, 0x28a0u, 0x0u, 0x7ff0u, 0x77d0u, 0xfff8u, 0x7ff0u, 0x5050u, 0x0u, 0xfff8u, 0xefd8u, 0x3fffeu, 0xfff8u, 0xa028u, 0x0u);
// 公式の動きのコマ。目 | 腕 << 3 | 足 << 5（向きのときは 128 | 向き）| (上下 + 3) << 12 | (左右 + 9) << 15 | 土ぼこり << 19 | 影 << 21
const uint CLAWD_SEQ[211] = uint[211](0xcc000u, 0x14c000u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0xcc000u, 0x14c000u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0x4b002u, 0x4b002u, 0x4b002u, 0x4b002u, 0x4b002u, 0x4b001u, 0x4b001u, 0x4b001u, 0x4b001u, 0x4b001u, 0x4b000u, 0xcc000u, 0x14c000u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0xcc000u, 0x14c000u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0x4c000u, 0x4c000u, 0x4c000u, 0x4000u, 0x1b008u, 0x1b008u, 0x1b000u, 0x1c000u, 0x33008u, 0x33008u, 0x33000u, 0x34000u, 0x4b008u, 0x4b008u, 0xcc000u, 0x14c000u, 0x4b000u, 0x4b001u, 0x4b001u, 0x4b002u, 0x4b002u, 0x4b001u, 0x4b001u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0x4e000u, 0x4d000u, 0x4d000u, 0x4d000u, 0x4d002u, 0x4d002u, 0x4d002u, 0x4d001u, 0x4d001u, 0x4d001u, 0x4d000u, 0x4d000u, 0x4c000u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0x4b000u, 0x4b003u, 0x4b000u, 0x48008u, 0x49008u, 0x49008u, 0x4a008u, 0x4a008u, 0x4b008u, 0xcc000u, 0x14c000u, 0x4b000u, 0x4b000u, 0x4b000u, 0x4b003u, 0x4b000u, 0x3002u, 0x1b022u, 0x1b022u, 0x23042u, 0x23042u, 0x2b022u, 0x2b022u, 0x33042u, 0x33042u, 0x3b022u, 0x3b022u, 0x43042u, 0x43042u, 0x4b002u, 0x4b002u, 0x4b000u, 0x4b000u, 0x4b003u, 0x4b000u, 0x3002u, 0x1b002u, 0x1b002u, 0x1b002u, 0x1b002u, 0x1b002u, 0x3002u, 0x3002u, 0x3002u, 0x23002u, 0x23002u, 0x23002u, 0x23002u, 0x33008u, 0x33008u, 0x4b008u, 0x4b008u, 0xcc000u, 0x14c000u, 0x4b000u, 0x4b004u, 0x4b004u, 0x4b004u, 0x4b004u, 0x4b004u, 0x4b000u, 0xcc003u, 0x14c003u, 0x14c003u, 0x4b001u, 0x4b001u, 0x4b001u, 0x4b001u, 0x4b000u, 0x4b000u, 0x4b003u, 0x4b000u, 0x4b020u, 0x4b020u, 0x4b040u, 0x4b040u, 0x4b020u, 0x4b020u, 0x4b040u, 0x4b040u, 0x4b020u, 0x4b040u, 0x4b008u, 0x4b008u, 0x4b008u, 0x4b000u, 0x4b00bu, 0x4b00bu, 0x4b00bu, 0x4b00bu, 0x14c003u, 0x14c003u, 0x4b003u, 0x4b003u, 0x4b000u, 0x4b000u, 0x4b003u, 0x4b000u, 0x4b080u, 0x4b081u, 0x4b082u, 0x4b083u, 0x4b084u, 0x4b085u, 0x4b086u, 0x4b087u, 0x4b088u, 0x4b088u, 0x4b087u, 0x4b086u, 0x4b085u, 0x4b084u, 0x4b089u, 0x4b08au, 0x4b08bu, 0x4b08cu, 0x4b000u, 0x4c000u, 0x4c000u, 0x24b008u, 0x44b082u, 0x44b084u, 0x44b086u, 0x44b088u, 0x44b086u, 0x44b084u, 0x44b08au, 0x24b008u, 0xcc000u, 0x14c000u, 0x4b000u);
// 動きごとの最初のコマと、コマ数: jump / look / celebrate / skip / spin / peekaboo / drop / waddle / peek / wink / boop / tap / sneeze / turn / coin-hop
const int CLAWD_SEQ_START[15] = int[15](0, 12, 23, 38, 52, 62, 83, 96, 115, 135, 141, 152, 166, 178, 197);
const int CLAWD_SEQ_LEN[15] = int[15](12, 11, 15, 14, 10, 21, 13, 19, 20, 6, 11, 14, 12, 19, 14);
const int CLAWD_JUMP = 0;
const int CLAWD_LOOK = 1;
const int CLAWD_CELEBRATE = 2;
const int CLAWD_SKIP = 3;
const int CLAWD_SPIN = 4;
const int CLAWD_PEEKABOO = 5;
const int CLAWD_DROP = 6;
const int CLAWD_WADDLE = 7;
const int CLAWD_PEEK = 8;
const int CLAWD_WINK = 9;
const int CLAWD_BOOP = 10;
const int CLAWD_TAP = 11;
const int CLAWD_SNEEZE = 12;
const int CLAWD_TURN = 13;
const int CLAWD_COIN_HOP = 14;
// 料理のシーン（横 44 × 縦 18 ドット、16 コマ）。1 ドット 4 ビットで、1 行を 6 つに分けて入れる。色は COOK_COLORS の番号（0 は描かない）
const uint COOK_PIXELS[1728] = uint[1728](0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x77700u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x77000u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x66u, 0x77u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x70066600u, 0x777u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6677700u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x60075000u, 0x66u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa080000u, 0x80a0u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x7770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x7700u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x770u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x66u, 0x7777u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x66600u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6677700u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x60075000u, 0x66u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80a00a00u, 0x80800u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x77u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x70000000u, 0x777u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x770066u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x7776600u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6660000u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x60000000u, 0x6u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x8008000u, 0xa08008u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x70000000u, 0x77u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x77u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x770006u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x7776660u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x660000u, 0x0u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x66000000u, 0x5u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80080800u, 0xa00a0u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x77000000u, 0x7u, 0x0u, 0x0u, 0x0u, 0x0u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x0u, 0x6000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11660000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x7777066u, 0x77000000u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6600u, 0x77700000u, 0x7u, 0x11110000u, 0x11111111u, 0x11101u, 0x660000u, 0x77000005u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa08000u, 0x80080au, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x77700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x77000000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x7700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x77770066u, 0x0u, 0x0u, 0x0u, 0x0u, 0x111000u, 0x600u, 0x77000000u, 0x0u, 0x11110000u, 0x11111111u, 0x11001u, 0x6000u, 0x77700000u, 0x7u, 0x11110000u, 0x11111111u, 0x1101u, 0x60000u, 0x77000000u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80a0000u, 0x8080u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x7700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x7777000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x6u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x111000u, 0x60u, 0x77000000u, 0x77u, 0x11110000u, 0x11111111u, 0x11001u, 0x600u, 0x70000000u, 0x7u, 0x11110000u, 0x11111111u, 0x1101u, 0x6000u, 0x50000u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80800800u, 0xa0800u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x7700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x777000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x6u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x111000u, 0x6u, 0x77000000u, 0x77u, 0x11110000u, 0x11111111u, 0x11001u, 0x60u, 0x70000000u, 0x7u, 0x11110000u, 0x11111111u, 0x1101u, 0x600u, 0x50000u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x8008000u, 0x80a00au, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x77700u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x77000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x6u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x111000u, 0x6u, 0x77077000u, 0x77u, 0x11110000u, 0x11111111u, 0x11001u, 0x60u, 0x777700u, 0x0u, 0x11110000u, 0x11111111u, 0x1101u, 0x5600u, 0x77000u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa00a0800u, 0x80080u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x7770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x7700u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x0u, 0x77u, 0x0u, 0x0u, 0x1110000u, 0x6u, 0x70000000u, 0x777u, 0x0u, 0x0u, 0x111000u, 0x6u, 0x77000u, 0x0u, 0x11110000u, 0x11111111u, 0x11001u, 0x60u, 0x777700u, 0x0u, 0x11110000u, 0x11111111u, 0x1101u, 0x5600u, 0x77000u, 0x0u, 0x11110000u, 0x11111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x11110000u, 0x11111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80a000u, 0x800808u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11000000u, 0x0u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x77000000u, 0x77u, 0x0u, 0x0u, 0x1110000u, 0x6u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x111000u, 0x60u, 0x7777000u, 0x0u, 0x11110000u, 0x11111111u, 0x11001u, 0x600u, 0x770000u, 0x0u, 0x11110000u, 0x11111111u, 0x1101u, 0x6000u, 0x0u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x8080000u, 0xa080u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x770u, 0x0u, 0x0u, 0x0u, 0x0u, 0x60000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x600000u, 0x0u, 0x77000000u, 0x7u, 0x0u, 0x0u, 0x11000000u, 0x0u, 0x70000000u, 0x7u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x66u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x111000u, 0x600u, 0x7777000u, 0x0u, 0x11110000u, 0x11111111u, 0x11001u, 0x6000u, 0x770000u, 0x0u, 0x11110000u, 0x11111111u, 0x1101u, 0x60000u, 0x5u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa0800800u, 0x80a00u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x77700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x77000000u, 0x0u, 0x0u, 0x0u, 0x6000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11660000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x0u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x70000066u, 0x7777007u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x77006600u, 0x77u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x70660000u, 0x5u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa00a000u, 0x808008u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x7770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x7700000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x7700000u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x6u, 0x77770000u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x70006660u, 0x7u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x77660000u, 0x77u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x66000000u, 0x7u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x80080a00u, 0x80080u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x7777000u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x66u, 0x77u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x70006600u, 0x777u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6660000u, 0x77u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x60000000u, 0x50006u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x808000u, 0xa00a08u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x98989800u, 0x989898u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu, 0x0u, 0x0u, 0x0u, 0x0u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x777000u, 0x0u, 0x0u, 0x0u, 0x66000u, 0x0u, 0x770000u, 0x0u, 0x0u, 0x0u, 0x11600000u, 0x0u, 0x0u, 0x0u, 0x0u, 0x0u, 0x11100000u, 0x66u, 0x77u, 0x0u, 0x0u, 0x0u, 0x1110000u, 0x70066600u, 0x777u, 0x0u, 0x11110000u, 0x11111111u, 0x111001u, 0x6600000u, 0x77u, 0x0u, 0x11110000u, 0x11111111u, 0x11101u, 0x60000000u, 0x50066u, 0x0u, 0x1110000u, 0x1111111u, 0x30001111u, 0x55555553u, 0x35555555u, 0x3u, 0x1110000u, 0x1111111u, 0x111u, 0x22222223u, 0x42222222u, 0x0u, 0x11111100u, 0x11111111u, 0x30000001u, 0x22222223u, 0x42222222u, 0x3u, 0x11111100u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222223u, 0x42222222u, 0x0u, 0x11110000u, 0x11111111u, 0x1u, 0x22222220u, 0x4222222u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0xa080000u, 0x80a0u, 0x0u, 0x1010000u, 0x1000000u, 0x1u, 0x89898900u, 0x898989u, 0x0u, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbbbbbu, 0xbbbbu);
// 料理のシーンの色: 体 / 鍋 / 鍋の縁と取っ手 / 鍋の影 / スープと泡 / スプーン / 湯気 / 炎（橙） / 炎（赤） / 炎（黄） / 台
const vec3 COOK_COLORS[12] = vec3[12](vec3(0.0), MASCOT_COLOR, vec3(0.373, 0.420, 0.478), vec3(0.580, 0.627, 0.690), vec3(0.275, 0.318, 0.376), vec3(0.914, 0.706, 0.298), vec3(0.745, 0.557, 0.361), vec3(0.604, 0.639, 0.678), vec3(0.961, 0.620, 0.043), vec3(0.937, 0.267, 0.267), vec3(0.992, 0.878, 0.278), vec3(0.420, 0.447, 0.502));


float hash1(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// Claude のキャラのポーズ。目・腕・足の形の番号（CLAWD_EYES などの並び）か、一回転中の向き（facing が 0 以上）。
// shift はずらす量（px）、clip は公式の動きのとき（元の位置の 18 × 6 ドットの外を描かない）
struct ClawdPose {
    int eyes;
    int arms;
    int feet;
    int facing;
    vec2 shift;
    int poof;
    int shadow;
    bool clip;
};

// 公式の動き seq の frame コマ目のポーズ（frame がコマ数を超えたら最後のコマのまま）
ClawdPose officialPose(int seq, int frame) {
    uint v = CLAWD_SEQ[CLAWD_SEQ_START[seq] + min(frame, CLAWD_SEQ_LEN[seq] - 1)];
    ClawdPose pose;
    bool turning = (v & 128u) != 0u;
    pose.facing = turning ? int(v & 15u) : -1;
    pose.eyes = int(v & 7u);
    pose.arms = int((v >> 3) & 3u);
    pose.feet = int((v >> 5) & 3u);
    // 上下と左右はマス単位（1 マス = 2 ドット）
    float offset = float((v >> 12) & 7u) - 3.0;
    float x = float((v >> 15) & 15u) - 9.0;
    pose.shift = vec2(x, offset) * 2.0 * MASCOT_PIXEL;
    pose.poof = offset > 0.0 ? int((v >> 19) & 3u) : 0;
    pose.shadow = int((v >> 21) & 3u);
    pose.clip = true;
    return pose;
}

// p がキャラのどこにあたるか。0: 何もない / 1: 体 / 2: 右隣の「！」 / 3: 土ぼこり / 4: 影。
// origin はキャラの左上、time はキャラごとにずらした時刻
int mascotAt(vec2 p, vec2 origin, float time, bool waiting, bool celebrating, bool running, bool catching) {
    int frame = int(time / CLAWD_FRAME);
    ClawdPose pose = ClawdPose(0, 0, 0, -1, vec2(0.0), 0, 0, false);
    if (celebrating) {
        pose = officialPose(CLAWD_CELEBRATE, frame % CLAWD_SEQ_LEN[CLAWD_CELEBRATE]);
    } else if (waiting) {
        pose = officialPose(CLAWD_JUMP, frame % CLAWD_SEQ_LEN[CLAWD_JUMP]);
    } else {
        // 動きの種類。0: 足踏み / 1: 左右に歩く / 2: 跳ねる / 3: きょろきょろ / 4: 手を振る / 5〜: 公式の動き（CLAWD_SEQ の並び）
        float segment = floor(time / MASCOT_ACTION);
        int action = int(hash1(segment) * float(5 + CLAWD_SEQ_LEN.length()));
        float t = time - segment * MASCOT_ACTION;
        float stepTime = running ? MASCOT_RUN_STEP : MASCOT_STEP;
        bool stepB = mod(floor(time / stepTime), 2.0) >= 1.0;
        if (running) {
            action = 0;
        }
        if (action >= 5) {
            // 公式の動きを一度流し、残りの時間は最後のポーズのまま立っている
            pose = officialPose(action - 5, int(t / CLAWD_FRAME));
        } else if (action == 0) {
            pose.feet = stepB ? 1 : 2;
        } else if (action == 1) {
            // 右へ歩いて戻ってくる（pane の左上にいるので、左へは行かない）
            pose.shift.x = MASCOT_WALK * (0.5 - 0.5 * cos(6.2831853 * t / MASCOT_ACTION));
            pose.feet = stepB ? 1 : 2;
        } else if (action == 2) {
            pose.shift.y = -MASCOT_JUMP * abs(sin(3.1415927 * time / MASCOT_HOP));
        } else if (action == 3) {
            // 左を見る → 右を見る → 前を見る を繰り返す
            float look = mod(t, 2.4);
            pose.eyes = look < 0.8 ? 1 : (look < 1.6 ? 2 : 0);
        } else {
            // 右手を振る
            pose.arms = mod(floor(t / MASCOT_WAVE), 2.0) >= 1.0 ? 2 : 0;
        }
    }
    // ネスからプレゼントを受け取ったら、バンザイする
    if (catching) {
        pose.arms = 1;
    }
    // 目を開けているときは、ときどきまばたきする
    if (pose.facing < 0 && pose.eyes == 0 && mod(time, MASCOT_BLINK_EVERY) < MASCOT_BLINK) {
        pose.eyes = 3;
    }

    // 右隣の「！」（入力待ちのとき）。2 ドット幅で、体と同じ高さに棒が 3 ドット、1 ドットあけて点
    vec2 home = floor((p - origin) / MASCOT_PIXEL);
    if (waiting && home.x >= MASCOT_ALERT_COL && home.x <= MASCOT_ALERT_COL + 1.0
        && home.y >= 0.0 && home.y <= 4.0 && home.y != 3.0) {
        return 2;
    }
    // 着地の土ぼこり。足元の左右から、外へ向かってもくもくと広がる（枠の外にもはみ出して描く）
    vec2 cellSize = 2.0 * MASCOT_PIXEL;
    if (pose.poof > 0) {
        float groundY = origin.y + 2.6 * cellSize.y;
        for (int side = 0; side < 2; side++) {
            // 左右の端のマスの真ん中から、外向きに
            float dir = side == 0 ? -1.0 : 1.0;
            float rootX = origin.x + (side == 0 ? 0.5 : 8.5) * cellSize.x;
            if (pose.poof == 1) {
                // 1コマ目: 足元に丸い煙がひとつ
                if (length(p - vec2(rootX + dir * 4.0, groundY)) < 7.0) {
                    return 3;
                }
            } else {
                // 2コマ目: 外へ流れて、小さな煙が3つに分かれる
                for (int k = 0; k < 3; k++) {
                    float fk = float(k);
                    vec2 puff = vec2(rootX + dir * (8.0 + 9.0 * fk), groundY - 3.0 * fk);
                    if (length(p - puff) < 6.0 - 1.2 * fk) {
                        return 3;
                    }
                }
            }
        }
    }
    // 公式の動きは、元の位置の 9 × 3 マスの中だけに描く（上から落ちてくる・下からのぞく・左から歩いてくる）
    if (pose.clip && (home.x < 0.0 || home.x >= 18.0 || home.y < 0.0 || home.y >= 6.0)) {
        return 0;
    }

    // 回るときの影（真ん中のマスの、いちばん下の行の下端）
    vec2 cell = (p - origin) / cellSize;
    if (floor(cell.y) == 2.0 && fract(cell.y) > 0.875) {
        float col = floor(cell.x);
        if (pose.shadow == 1 ? (col >= 3.0 && col <= 5.0) : (pose.shadow == 2 && col == 4.0)) {
            return 4;
        }
    }

    vec2 local = (p - origin - pose.shift) / MASCOT_PIXEL;
    vec2 spot = floor(local);
    if (spot.x < 0.0 || spot.x >= 18.0 || spot.y < 0.0 || spot.y >= 6.0) {
        return 0;
    }
    int y = int(spot.y);
    uint row;
    if (pose.facing >= 0) {
        row = CLAWD_FACING[pose.facing * 6 + y];
    } else if (y < 2) {
        row = CLAWD_ARMS[pose.arms * 4 + y] | CLAWD_EYES[pose.eyes * 2 + y];
    } else if (y < 4) {
        row = CLAWD_ARMS[pose.arms * 4 + y];
    } else {
        row = CLAWD_FEET[pose.feet * 2 + y - 4];
    }
    uint bit = 1u << uint(spot.x);
    if ((row & bit) == 0u) {
        return 0;
    }
    // 閉じた目は、目の行の下半分を背景の色にして線にする
    if (pose.facing < 0 && y == 1 && (CLAWD_LIDS[pose.eyes] & bit) != 0u && fract(local.y) >= 0.5) {
        return 0;
    }
    return 1;
}

// 料理のシーン（鍋をかき混ぜる）で、p にあたる色の番号（0 は何もない）。origin はシーンの左上
int cookingAt(vec2 p, vec2 origin, float time) {
    vec2 spot = floor((p - origin) / COOK_PIXEL);
    if (spot.x < 0.0 || spot.x >= 44.0 || spot.y < 0.0 || spot.y >= 18.0) {
        return 0;
    }
    int frame = int(time / COOK_FRAME) % 16;
    int x = int(spot.x);
    uint word = COOK_PIXELS[(frame * 18 + int(spot.y)) * 6 + x / 8];
    return int((word >> uint((x % 8) * 4)) & 15u);
}

// 化け物になる特別演出。time はキャラごとの時刻で、MONSTER_SLOT 秒ごとに MONSTER_CHANCE の確率で選ばれる。
// 選ばれた間隔のあいだの経過秒数を返す（化け物でなければ負）
float monsterTime(float time) {
    float slot = floor(time / MONSTER_SLOT);
    return hash1(slot * 7.31 + 3.7) < MONSTER_CHANCE ? time - slot * MONSTER_SLOT : -1.0;
}

// ---------- MOTHER2 のネス（Claude が待機中の pane で入力している間に動く。処理中に入力すると、キャラにプレゼントを渡す） ----------
const uint NESS_SPRITES[96] = uint[96](0x11110000u, 0x111u, 0x31321000u, 0x11311u, 0x23121111u, 0x122122u, 0x22144451u, 0x1221222u, 0x44444610u, 0x1221222u, 0x11171110u, 0x111771u, 0x11777111u, 0x1111777u, 0x88188171u, 0x1888818u, 0x88188871u, 0x1888818u, 0x88833710u, 0x173388u, 0x88833100u, 0x13388u, 0x11831000u, 0x1381u, 0x88710000u, 0x178u, 0x71141000u, 0x1411u, 0x44499100u, 0x19944u, 0x99944410u, 0x144499u, 0x44441851u, 0x1844444u, 0x99991881u, 0x181999u, 0x44444110u, 0x11144u, 0x14444100u, 0x16aa14u, 0x14411000u, 0x1666a1u, 0x11221000u, 0x1666a1u, 0x165100u, 0x16661u, 0x11000u, 0x1110u, 0x11110000u, 0x111u, 0x31321000u, 0x11311u, 0x23121111u, 0x122122u, 0x22144451u, 0x1221222u, 0x44444610u, 0x1221222u, 0x11171110u, 0x111771u, 0x11777111u, 0x1111777u, 0x88188171u, 0x1888818u, 0x88188871u, 0x1888818u, 0x88833710u, 0x173388u, 0x88833100u, 0x13388u, 0x11831000u, 0x1381u, 0x88710000u, 0x178u, 0x71141000u, 0x1411u, 0x44499100u, 0x19944u, 0x99944410u, 0x144499u, 0x44441851u, 0x1844444u, 0x99991881u, 0x181999u, 0x44444110u, 0x11144u, 0x141aa610u, 0x14444u, 0x11a66610u, 0x1144u, 0x11a66610u, 0x1221u, 0x1666100u, 0x15610u, 0x111000u, 0x1100u);
const uint NESS_SIDE[100] = uint[100](0x11110000u, 0x11u, 0x13311100u, 0x133u, 0x22222210u, 0x111522u, 0x22222221u, 0x1542222u, 0x22222221u, 0x144422u, 0x11111111u, 0x11181u, 0x88111111u, 0x18888u, 0x88181111u, 0x18188u, 0x88881111u, 0x188188u, 0x33811110u, 0x18833u, 0x33888100u, 0x18883u, 0x88881000u, 0x1818u, 0x88811110u, 0x188u, 0xb1199100u, 0x111u, 0x44199910u, 0x114u, 0x99419910u, 0x1111u, 0x44111910u, 0x155u, 0x99441100u, 0x1199u, 0x11bbb100u, 0x1411u, 0x44441811u, 0x1522314u, 0x11113251u, 0x1522311u, 0x1251u, 0x122800u, 0x1110u, 0x15100u, 0x1510u, 0x11100u, 0x1100u, 0x1000u, 0x11110000u, 0x11u, 0x13311100u, 0x133u, 0x22222210u, 0x111522u, 0x22222221u, 0x1542222u, 0x22222221u, 0x144422u, 0x11111111u, 0x11181u, 0x88111111u, 0x18888u, 0x88181111u, 0x18188u, 0x88881111u, 0x188188u, 0x33811110u, 0x18833u, 0x33888100u, 0x18883u, 0x88881000u, 0x1818u, 0x88811110u, 0x188u, 0xb1199100u, 0x111u, 0x44199910u, 0x114u, 0x99419910u, 0x1111u, 0x44111910u, 0x155u, 0x99441100u, 0x1199u, 0x11bbb100u, 0x1411u, 0x44441100u, 0x14u, 0x44441000u, 0x14u, 0x11110000u, 0x11u, 0x22210000u, 0x15u, 0x52210000u, 0x15u, 0x11100000u, 0x1u);
const uint NESS_QUARTER[96] = uint[96](0x11111110u, 0x11u, 0x13113111u, 0x123u, 0x32222221u, 0x1222u, 0x22222221u, 0x154442u, 0x44222221u, 0x14444u, 0x11181111u, 0x1181u, 0x11881111u, 0x11888u, 0x88188180u, 0x18818u, 0x88188880u, 0x18818u, 0x88883310u, 0x11888u, 0x88888810u, 0x1888u, 0x11888100u, 0x188u, 0x88881100u, 0x18u, 0xb1111910u, 0x11u, 0x44444191u, 0x1114u, 0x99919991u, 0x1919u, 0x44414411u, 0x18114u, 0x99991851u, 0x18119u, 0x44444110u, 0x1114u, 0x14444110u, 0x14u, 0x41441100u, 0x14u, 0x21222100u, 0x12u, 0x15555110u, 0x155u, 0x1111100u, 0x11u, 0x11111110u, 0x11u, 0x13113111u, 0x123u, 0x32222221u, 0x1222u, 0x22222221u, 0x154442u, 0x44222221u, 0x14444u, 0x11181111u, 0x1181u, 0x11881111u, 0x11888u, 0x88188180u, 0x18818u, 0x88188880u, 0x18818u, 0x88883310u, 0x11888u, 0x88888810u, 0x1888u, 0x11888100u, 0x188u, 0x88881100u, 0x18u, 0xb1111910u, 0x11u, 0x44444191u, 0x1114u, 0x99919991u, 0x1919u, 0x44414411u, 0x18114u, 0x99991851u, 0x18119u, 0x44444110u, 0x1114u, 0x14444110u, 0x144u, 0x144410u, 0x1441u, 0x12221u, 0x12210u, 0x15551u, 0x15510u, 0x1110u, 0x11100u);
const uint NESS_BACK[192] = uint[192](0x11110000u, 0x1111u, 0x32131100u, 0x11131u, 0x22212210u, 0x1522213u, 0x22222220u, 0x1422222u, 0x22221220u, 0x121222u, 0x22222110u, 0x112222u, 0x11111110u, 0x111111u, 0x11111180u, 0x1811111u, 0x11111180u, 0x1811111u, 0x11111818u, 0x181111u, 0x11118111u, 0x118111u, 0x11881810u, 0x11881u, 0x11118881u, 0x18111u, 0x99141110u, 0x11419u, 0x11148110u, 0x18411u, 0x19914410u, 0x184199u, 0x99918880u, 0x1588199u, 0x19911880u, 0x1881199u, 0x99141110u, 0x111199u, 0x44441100u, 0x1144u, 0x11441000u, 0x144u, 0x1221000u, 0x1221u, 0x1251000u, 0x1521u, 0x110000u, 0x110u, 0x11110000u, 0x1111u, 0x32131100u, 0x11131u, 0x22212210u, 0x1522213u, 0x22222220u, 0x1422222u, 0x22221220u, 0x121222u, 0x22222110u, 0x112222u, 0x11111110u, 0x111111u, 0x11111180u, 0x1811111u, 0x11111180u, 0x1811111u, 0x11111818u, 0x181111u, 0x11118111u, 0x118111u, 0x11881810u, 0x11881u, 0x11118881u, 0x18111u, 0x99141110u, 0x11419u, 0x11148110u, 0x18411u, 0x19914410u, 0x184199u, 0x99918880u, 0x1588199u, 0x19911880u, 0x1881199u, 0x99141110u, 0x111199u, 0x44441100u, 0x1144u, 0x11441000u, 0x144u, 0x1221000u, 0x1441u, 0x110000u, 0x1221u, 0x0u, 0x111u, 0x0u, 0x0u, 0x11110000u, 0x1111u, 0x13222111u, 0x11323u, 0x31222144u, 0x122222u, 0x22122144u, 0x1222222u, 0x22222211u, 0x1122222u, 0x22221110u, 0x111222u, 0x11111181u, 0x111111u, 0x11111881u, 0x111111u, 0x11111881u, 0x11111u, 0x11111811u, 0x11111u, 0x11118110u, 0x11111u, 0x11881110u, 0x1811u, 0x88111110u, 0x111u, 0x14449100u, 0x1999u, 0x14994411u, 0x11111u, 0x91414888u, 0x19199u, 0x91911488u, 0x19999u, 0x91444111u, 0x19199u, 0x14441000u, 0x1999u, 0x11441000u, 0x111u, 0x12221000u, 0x122u, 0x12551000u, 0x155u, 0x11111000u, 0x11u, 0x0u, 0x0u, 0x11110000u, 0x1111u, 0x13222111u, 0x11323u, 0x31222144u, 0x122222u, 0x22122144u, 0x1222222u, 0x22222211u, 0x1122222u, 0x22221110u, 0x111222u, 0x11111181u, 0x111111u, 0x11111881u, 0x111111u, 0x11111881u, 0x11111u, 0x11111811u, 0x11111u, 0x11118110u, 0x11111u, 0x11881110u, 0x1811u, 0x88111110u, 0x111u, 0x14449100u, 0x1999u, 0x14994411u, 0x11111u, 0x91414888u, 0x19199u, 0x91911488u, 0x19999u, 0x91444111u, 0x19199u, 0x14441000u, 0x1999u, 0x1441000u, 0x141u, 0x1221000u, 0x1221u, 0x1551000u, 0x1510u, 0x110000u, 0x110u);

// ネスの絵 frame の、ドット spot の色の番号（NESS_COLORS の並び。0 は何もない）。flip で左向きにする
int nessPixel(int frame, vec2 spot, bool flip) {
    if (spot.x < 0.0 || spot.x >= 16.0 || spot.y < 0.0 || spot.y >= 24.0) {
        return 0;
    }
    int x = flip ? 15 - int(spot.x) : int(spot.x);
    uint word = NESS_SPRITES[(frame * 24 + int(spot.y)) * 2 + x / 8];
    return int((word >> uint((x % 8) * 4)) & 15u);
}

// 横向きのネスの絵 frame の、ドット spot の色の番号。元の絵は右向きで、flip で左向きにする
int nessSidePixel(int frame, vec2 spot, bool flip) {
    if (spot.x < 0.0 || spot.x >= 16.0 || spot.y < 0.0 || spot.y >= 25.0) {
        return 0;
    }
    int x = flip ? 15 - int(spot.x) : int(spot.x);
    uint word = NESS_SIDE[(frame * 25 + int(spot.y)) * 2 + x / 8];
    return int((word >> uint((x % 8) * 4)) & 15u);
}

// 斜め向きのネスの絵 frame の、ドット spot の色の番号。元の絵は右斜め前を向いていて、flip で左斜め前にする
int nessQuarterPixel(int frame, vec2 spot, bool flip) {
    if (spot.x < 0.0 || spot.x >= 13.0 || spot.y < 0.0 || spot.y >= 24.0) {
        return 0;
    }
    int x = flip ? 12 - int(spot.x) : int(spot.x);
    uint word = NESS_QUARTER[(frame * 24 + int(spot.y)) * 2 + x / 8];
    return int((word >> uint((x % 8) * 4)) & 15u);
}

// 後ろ向きのネスの絵の、ドット spot の色の番号。frame は 0〜1 が真後ろ、2〜3 が左斜め後ろ（flip で右斜め後ろ）
int nessBackPixel(int frame, vec2 spot, bool flip) {
    if (spot.x < 0.0 || spot.x >= 15.0 || spot.y < 0.0 || spot.y >= 24.0) {
        return 0;
    }
    int x = flip ? 14 - int(spot.x) : int(spot.x);
    uint word = NESS_BACK[(frame * 24 + int(spot.y)) * 2 + x / 8];
    return int((word >> uint((x % 8) * 4)) & 15u);
}

// 8 方向の向きで立つネス。dir は 0: 正面 / 1: 右斜め前 / 2: 右 / 3: 右斜め後ろ / 4: 後ろ / 5: 左斜め後ろ / 6: 左 / 7: 左斜め前
int nessFacing(int dir, vec2 spot) {
    if (dir == 0) {
        return nessPixel(0, spot, false);
    } else if (dir == 1 || dir == 7) {
        return nessQuarterPixel(0, spot, dir == 7);
    } else if (dir == 2 || dir == 6) {
        return nessSidePixel(0, spot + vec2(0.0, 1.0), dir == 6);
    } else if (dir == 4) {
        return nessBackPixel(0, spot, false);
    }
    return nessBackPixel(2, spot, dir == 3);
}

vec4 nessColor(int c) {
    return c > 0 ? vec4(NESS_COLORS[c], 1.0) : vec4(0.0);
}

float nessSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

// 4 本のとげの星（バットが当たったときの光）。center から半径 r
float nessStar(vec2 p, vec2 center, float r) {
    vec2 d = abs(p - center);
    return step(d.x * d.y * 6.0 + max(d.x, d.y) * 0.35, r * 0.35) * step(max(d.x, d.y), r);
}

// ハンバーガー（7 × 5 ドット。パン・レタス・肉・パン）。width は食べて残った割合
vec4 hamburgerAt(vec2 p, vec2 center, float width) {
    vec2 q = (p - center) / NESS_PIXEL;
    if (abs(q.y) >= 2.5 || q.x < -3.5 || q.x >= -3.5 + 7.0 * width) {
        return vec4(0.0);
    }
    int y = int(floor(q.y + 2.5));
    bool corner = abs(q.x) >= 2.5 && (y == 0 || y == 4);
    if (corner) {
        return vec4(0.0);
    }
    vec3 c = y == 0 ? vec3(0.87, 0.60, 0.30) : y == 1 ? vec3(0.45, 0.78, 0.35) : y == 2 ? vec3(0.45, 0.26, 0.15) : vec3(0.87, 0.60, 0.30);
    return vec4(c, 1.0);
}

// 小さなハート（7 × 6 ドット）
bool heartAt(vec2 p, vec2 center) {
    vec2 q = floor((p - center) / 3.0 + vec2(3.5, 3.0));
    if (q.x < 0.0 || q.x >= 7.0 || q.y < 0.0 || q.y >= 6.0) {
        return false;
    }
    const uint HEART[6] = uint[6](0x36u, 0x7fu, 0x7fu, 0x3eu, 0x1cu, 0x08u);
    return (HEART[int(q.y)] >> uint(q.x) & 1u) != 0u;
}

// Claude が待機中の pane で入力している間のネス。NESS_ACTION 秒ごとに、走る・バット・PK キアイ・ヨーヨー・ハンバーガー・
// 斜め向きで歩く・見回す・くるっと回るから選ぶ。
// origin はネスの左上。描く色（a が 0 なら何もない）を返す
vec4 nessTypingAt(vec2 p, vec2 origin, float time) {
    float segment = floor(time / NESS_ACTION);
    int action = int(hash1(segment * 3.1 + 0.7) * 8.0);
    float t = time - segment * NESS_ACTION;
    int foot = int(mod(floor(time / NESS_STEP), 2.0));

    if (action == 0) {
        // 横向きで、右へ走って戻ってくる。走るときは 1 ドット跳ねる
        float phase = t / NESS_ACTION;
        float x = NESS_RUN * (0.5 - 0.5 * cos(6.2831853 * phase));
        float bob = foot == 0 ? 0.0 : -NESS_PIXEL.y;
        vec2 spot = floor((p - origin - vec2(x, bob - NESS_PIXEL.y)) / NESS_PIXEL);
        return nessColor(nessSidePixel(foot, spot, phase >= 0.5));
    }
    if (action == 5) {
        // 斜め向きで、のんびり右へ歩いて戻ってくる
        float phase = t / NESS_ACTION;
        float x = NESS_RUN * 0.6 * (0.5 - 0.5 * cos(6.2831853 * phase));
        int slow = int(mod(floor(time / (NESS_STEP * 2.5)), 2.0));
        return nessColor(nessQuarterPixel(slow, floor((p - origin - vec2(x, 0.0)) / NESS_PIXEL), phase >= 0.5));
    }
    if (action == 6) {
        // 見回す: 右斜め → 正面 → 左斜め → 後ろ
        const int LOOK[4] = int[4](1, 0, 7, 4);
        return nessColor(nessFacing(LOOK[int(mod(t, 2.4) / 0.6)], floor((p - origin) / NESS_PIXEL)));
    }
    if (action == 7) {
        // くるっと回る: 8 方向を 0.1 秒ずつ回り、正面で少し止まる
        float s = mod(t, 1.5);
        int dir = s < 0.8 ? int(s / 0.1) : 0;
        return nessColor(nessFacing(dir, floor((p - origin) / NESS_PIXEL)));
    }

    vec2 center = origin + vec2(7.5, 12.0) * NESS_PIXEL;
    vec2 rightHand = origin + vec2(13.5, 16.5) * NESS_PIXEL;
    vec4 front = nessColor(nessPixel(action == 1 ? 0 : foot, floor((p - origin) / NESS_PIXEL), false));
    vec4 behind = vec4(0.0);
    vec4 over = vec4(0.0);

    if (action == 1) {
        // バットを振る: 肩にかついだ構えから、1 秒ごとに振り下ろす。当たった瞬間に星が光る
        float s = mod(t, 1.0);
        float swing = s < 0.12 ? s / 0.12 : (s < 0.45 ? 1.0 : 1.0 - (s - 0.45) / 0.55);
        float angle = mix(1.9, -0.5, swing);
        vec2 tip = rightHand + vec2(cos(angle), -sin(angle)) * 34.0;
        float d = nessSegment(p, rightHand, tip);
        float thick = mix(1.5, 3.0, clamp(dot(p - rightHand, tip - rightHand) / (34.0 * 34.0), 0.0, 1.0));
        if (d < thick) {
            over = vec4(0.62, 0.43, 0.24, 1.0);
        }
        if (s >= 0.1 && s < 0.35 && nessStar(p, tip + vec2(8.0, 0.0), 10.0 * (1.0 - (s - 0.1) / 0.35)) > 0.0) {
            over = vec4(0.98, 0.92, 0.45, 1.0);
        }
    } else if (action == 2) {
        // PK キアイ: 体の中心から、虹色の輪が 1.2 秒ごとに広がる
        for (int k = 0; k < 2; k++) {
            float r = fract(t / 1.2 + float(k) * 0.5);
            float radius = 10.0 + 70.0 * r;
            float d = abs(length(p - center) - radius);
            if (d < 2.5) {
                float hue = atan(p.y - center.y, p.x - center.x) / 6.2831853 + time * 0.5;
                vec3 rainbow = 0.55 + 0.45 * cos(6.2831853 * (hue + vec3(0.0, 0.33, 0.67)));
                behind = vec4(rainbow, 1.0 - r);
            }
        }
    } else if (action == 3) {
        // ヨーヨー: 右手から下へ、上下させる
        float drop = 6.0 + 34.0 * (0.5 - 0.5 * cos(6.2831853 * t / 0.8));
        vec2 yoyo = rightHand + vec2(2.0, drop);
        if (length(p - yoyo) < 4.5) {
            over = vec4(0.88, 0.25, 0.25, 1.0);
        } else if (abs(p.x - yoyo.x) < 0.75 && p.y > rightHand.y && p.y < yoyo.y) {
            over = vec4(0.9, 0.9, 0.9, 1.0);
        }
    } else {
        // ハンバーガー: 手から口へ運んで、3 口で食べる。食べ終わるとハートが出る
        float s = mod(t, 2.5);
        vec2 mouth = origin + vec2(7.5, 12.5) * NESS_PIXEL;
        if (s < 0.5) {
            over = hamburgerAt(p, mix(rightHand, mouth, s / 0.5), 1.0);
        } else if (s < 1.8) {
            float bites = floor((s - 0.5) / 0.43) + 1.0;
            over = hamburgerAt(p, mouth + vec2(0.0, mod(s, 0.43) < 0.12 ? 1.5 : 0.0), 1.0 - bites / 3.0 + 0.001);
        } else if (heartAt(p, origin + vec2(7.5 * NESS_PIXEL.x, -8.0 - 24.0 * (s - 1.8)))) {
            over = vec4(0.95, 0.45, 0.6, 1.0);
        }
    }
    return over.a > 0.0 ? over : (front.a > 0.0 ? front : behind);
}

// プレゼントの箱（5 × 6 ドット。赤い箱に黄色いリボン）。p にあれば色の番号を返す
int presentAt(vec2 p, vec2 center) {
    vec2 spot = floor((p - center) / 4.0 + vec2(2.5, 3.0));
    if (spot.x < 0.0 || spot.x >= 5.0 || spot.y < 0.0 || spot.y >= 6.0) {
        return 0;
    }
    if (spot.y == 0.0) {
        return spot.x == 1.0 || spot.x == 3.0 ? 9 : 0;
    }
    return spot.x == 2.0 || spot.y == 3.0 ? 9 : 2;
}

// 処理中に入力したときの、ネスがキャラにプレゼントを投げ渡す場面。origin はキャラの左上。
// 色の番号（0 は何もない）を返し、キャラが受け取ってバンザイしているかを catching に入れる
int nessTossAt(vec2 p, vec2 origin, float time, out bool catching) {
    float t = mod(time, NESS_TOSS);
    catching = t >= 0.55 && t < 0.8;
    // ネスはキャラの右で足踏みしながら、左手で投げる
    vec2 nessOrigin = origin + vec2(18.0 * MASCOT_PIXEL.x + NESS_GAP, 0.0);
    int frame = int(mod(floor(time / NESS_STEP), 2.0));
    int color = nessPixel(frame, floor((p - nessOrigin) / NESS_PIXEL), false);
    if (color > 0) {
        return color;
    }
    // ネスの手からキャラの頭へ、山なりに飛ぶ
    if (t >= 0.1 && t < 0.55) {
        float k = (t - 0.1) / 0.45;
        vec2 from = nessOrigin + vec2(1.5, 16.5) * NESS_PIXEL;
        vec2 to = origin + vec2(9.0 * MASCOT_PIXEL.x, 0.5 * MASCOT_PIXEL.y);
        vec2 at = mix(from, to, k) - vec2(0.0, 60.0 * 4.0 * k * (1.0 - k));
        return presentAt(p, at);
    }
    return 0;
}

// なめらかに変わる乱れ（0〜1）
float valueNoise(vec2 q) {
    vec2 i = floor(q);
    vec2 f = fract(q);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(i.x + i.y * 57.0);
    float b = hash1(i.x + 1.0 + i.y * 57.0);
    float c = hash1(i.x + (i.y + 1.0) * 57.0);
    float d = hash1(i.x + 1.0 + (i.y + 1.0) * 57.0);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 化け物の胴（腕と体。目の穴と足はない）の、ドット q での有無
float monsterBodyAt(vec2 q) {
    if (q.x < 0.0 || q.x >= 18.0 || q.y < 0.0 || q.y >= 4.0) {
        return 0.0;
    }
    int y = int(q.y);
    uint row = CLAWD_ARMS[y] | (y < 2 ? CLAWD_EYES[6] : 0u);
    return float((row >> uint(q.x)) & 1u);
}

// 点 p から線分 a-b までの距離（化け物の足に使う）
float legDistance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - a - ab * h);
}

// 化け物を color に描く。p は画面の位置、origin はキャラの左上、t は化け物になってからの秒数、time はキャラの時刻。
//   0〜1.2 秒: 震えながら少し大きくなる / 0.5〜1.8 秒: 体の下から足がたくさん生え、体を持ち上げて歩く
//   1〜2.6 秒: ドット絵から、陰影と肌の質感のある描写に変わっていく / 1.8〜3 秒: 目が赤く光る縦長の瞳になる
//   7.5〜9 秒: 足を引っ込めて、元のキャラに戻る
void applyMonster(inout vec3 color, vec2 p, vec2 origin, float t, float time) {
    float back = 1.0 - smoothstep(7.5, 8.8, t);
    float grow = smoothstep(0.0, 1.2, t) * back;
    float legs = smoothstep(0.5, 1.8, t) * (1.0 - smoothstep(7.4, 8.4, t));
    float real = smoothstep(1.0, 2.6, t) * back;
    float eyes = smoothstep(1.8, 3.0, t) * back;

    // 足の付け根（胴の下の真ん中）を中心に大きくする。化け物になるときと戻るときは小刻みに震える
    float shake = (smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.8, 1.3, t)) + smoothstep(7.4, 7.8, t) * back) * 2.5;
    vec2 jitter = shake * vec2(hash1(floor(time * 30.0)) - 0.5, hash1(floor(time * 30.0) + 9.1) - 0.5);
    vec2 anchor = origin + vec2(9.0, 4.0) * MASCOT_PIXEL + jitter;
    float scale = 1.0 + 0.6 * grow;
    vec2 unit = MASCOT_PIXEL * scale;
    vec2 q = (p - anchor) / unit + vec2(9.0, 4.0);
    // 体と足から遠いところは何もしない
    if (q.x < -14.0 || q.x > 32.0 || q.y < -8.0 || q.y > 14.0) {
        return;
    }
    float aa = 1.2 / unit.x;   // 輪郭のぼかし（1 px ほど）

    // まわりを暗く沈める（化け物の気配）
    float aura = exp(-length((q - vec2(9.0, 3.0)) * vec2(1.0, 1.4)) / 9.0);
    color = mix(color, SHADE, 0.55 * real * aura);

    // 足が伸びるにつれて、体が少し持ち上がる
    float raise = 0.5 * legs;
    vec2 qb = q + vec2(0.0, raise);

    // 足。左右に 8 本ずつ、クモのように膝を外側へ持ち上げて地面を踏み、付け根から順に波打って歩く。
    // 外側の足ほど大きく広がる。ドット絵のうちは足もドットにする
    vec2 lq = mix(floor(q) + 0.5, q, real);
    float groundY = 6.8;
    float legHit = 0.0;
    float legShade = 0.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float dir = i < 8 ? -1.0 : 1.0;
        float spread = (mod(fi, 8.0) + 0.5) / 8.0;   // 0（内側）〜 1（外側）
        vec2 root = vec2(9.0 + dir * (1.5 + 4.5 * spread), 2.8 - raise);
        float phase = time * 9.0 - fi * 0.8;
        float lift = max(0.0, sin(phase));
        vec2 knee = root + legs * vec2(dir * (1.0 + 3.0 * spread) + 0.4 * cos(phase), -1.4 - 1.0 * spread - 0.5 * lift);
        vec2 foot = vec2(knee.x + legs * (dir * (0.5 + 1.0 * spread) - 0.3 * cos(phase)),
                         mix(root.y, groundY - 0.9 * lift, legs));
        float thick = mix(0.5, 0.32, real);
        float d1 = legDistance(lq, root, knee) - thick * legs;
        float d2 = legDistance(lq, knee, foot) - thick * 0.6 * legs;
        float d = min(d1, d2);
        float hit = legs > 0.01 ? 1.0 - smoothstep(-aa, aa, d) : 0.0;
        if (hit > legHit) {
            legHit = hit;
            // 付け根ほど明るく、先ほど暗い。関節は少し明るい
            legShade = mix(1.0, 0.4, clamp(length(lq - root) / 5.0, 0.0, 1.0))
                + 0.3 * exp(-length(lq - knee) * 3.0);
        }
    }
    vec3 legColor = mix(MASCOT_COLOR * 0.8, vec3(0.62, 0.24, 0.18), real) * legShade;
    color = mix(color, legColor, legHit);

    // 胴。ドット絵のうちはドットのまま、リアルになるにつれて輪郭が丸くなる（まわりの有無を平均してなめらかにする）
    float pixelBody = monsterBodyAt(qb);
    float coverage = 0.0;
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            coverage += monsterBodyAt(qb + vec2(float(dx), float(dy)) * 0.3);
        }
    }
    coverage /= 25.0;
    float smoothBody = smoothstep(0.3, 0.5, coverage);
    float body = mix(pixelBody, smoothBody, real);
    if (body > 0.0) {
        // 体を楕円体に見立てた陰影（左上から光が当たる）と、ぬめりのあるハイライト
        vec2 n2 = (qb - vec2(9.0, 2.0)) / vec2(8.0, 2.8);
        float z = sqrt(max(0.0, 1.0 - dot(n2, n2)));
        vec3 normal = normalize(vec3(n2 * 0.9, z + 0.15));
        vec3 light = normalize(vec3(-0.5, -0.8, 0.7));
        float diffuse = clamp(dot(normal, light), 0.0, 1.0);
        float specular = pow(max(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0), 18.0);
        // 肌のでこぼこと、浮き出た血管
        float bumps = valueNoise(qb * 3.0 + 4.0);
        float veins = 1.0 - smoothstep(0.0, 0.06, abs(valueNoise(qb * 1.6 + 11.0) - 0.5));
        vec3 flesh = mix(vec3(0.42, 0.13, 0.10), MASCOT_COLOR * 1.1, 0.35 + 0.5 * diffuse);
        flesh *= 0.75 + 0.35 * bumps;
        flesh = mix(flesh, vec3(0.30, 0.04, 0.06), 0.55 * veins);
        flesh *= mix(0.55, 1.0, smoothstep(0.3, 0.8, coverage));   // 輪郭の近くは暗く
        flesh += vec3(1.0, 0.85, 0.75) * specular * 0.45;
        color = mix(color, mix(MASCOT_COLOR, flesh, real), body);
    }

    // 目。ドット絵のうちは元の穴、怖くなると赤く光る縦長の瞳になって大きくなる。あとから小さな目が 2 つ増える
    vec3 eyeCenters[4] = vec3[4](vec3(5.5, 1.5, 1.0), vec3(13.5, 1.5, 1.0), vec3(8.0, 0.8, 0.5), vec3(10.6, 2.6, 0.45));
    float pulse = 0.8 + 0.2 * sin(time * 7.0);
    for (int i = 0; i < 4; i++) {
        float size = eyeCenters[i].z * (i < 2 ? 1.0 : smoothstep(0.6, 1.0, eyes));
        if (size <= 0.0) {
            continue;
        }
        vec2 e = (qb - eyeCenters[i].xy) / size;
        if (i < 2) {
            // 元の穴（1 ドット）。目が怖くなるまでは、背景の色で抜く
            float hole = (abs(e.x) < 0.5 && abs(e.y) < 0.5) ? 1.0 : 0.0;
            color = mix(color, vec3(0.08, 0.06, 0.07), hole * (1.0 - eyes) * body);
        }
        // 瞳が獲物を探すように、ときどき左右へ動く
        vec2 look = vec2(0.25 * sin(time * 1.3 + float(i)), 0.0);
        float r = length(e * vec2(1.0, 1.25)) / mix(0.5, 0.95, eyes);
        float iris = 1.0 - smoothstep(0.9, 1.0, r);
        vec3 eyeColor = mix(vec3(1.0, 0.85, 0.3), vec3(0.75, 0.02, 0.02), smoothstep(0.0, 0.9, r)) * pulse;
        // 縦長の瞳孔
        vec2 pupil = e - look;
        float slit = 1.0 - smoothstep(0.08, 0.14, abs(pupil.x) / max(0.2, 1.0 - pupil.y * pupil.y));
        eyeColor = mix(eyeColor, vec3(0.02), slit * step(abs(pupil.y), 0.8));
        color = mix(color, eyeColor, iris * eyes);
        // 赤い光のにじみ
        color += vec3(0.9, 0.08, 0.05) * eyes * pulse * 0.6 * exp(-max(0.0, r - 0.8) * 2.2) * (1.0 - iris);
    }
}

// 紙吹雪のパステル5色
vec3 confettiColor(float h) {
    int i = int(h * 5.0);
    return i == 0 ? vec3(0.96, 0.76, 0.91) : (i == 1 ? vec3(0.98, 0.89, 0.69) : (i == 2 ? vec3(0.54, 0.86, 0.92)
        : (i == 3 ? vec3(0.65, 0.89, 0.63) : vec3(0.80, 0.65, 0.97))));
}

// 紙吹雪。region の範囲を、列ごとに数枚ずつ揺れながら落ちる。当たった色と濃さ（0〜1）を返す
vec4 confetti(vec2 p, vec2 regionMin, vec2 regionMax) {
    if (!insideRect(p, regionMin, regionMax)) {
        return vec4(0.0);
    }
    float columnWidth = CONFETTI_SIZE * 4.0;
    float column = floor(p.x / columnWidth);
    float height = regionMax.y - regionMin.y;
    for (int k = 0; k < 3; k++) {
        float h = hash1(column * 3.0 + float(k));
        float y = regionMin.y + mod(h * height + iTime * (120.0 + 80.0 * h), height);
        float x = (column + 0.5) * columnWidth + sin(iTime * 3.0 + h * 6.2831853) * CONFETTI_SIZE;
        if (abs(p.x - x) < CONFETTI_SIZE * 0.5 && abs(p.y - y) < CONFETTI_SIZE * 0.35) {
            // 落ちる範囲の下のほうでは薄くする
            float fade = 1.0 - smoothstep(0.6, 1.0, (y - regionMin.y) / height);
            return vec4(confettiColor(hash1(column * 7.0 + float(k) * 13.0)), fade);
        }
    }
    return vec4(0.0);
}

// 点 p から線分 a-b までの距離
float segmentDistance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
    return length(p - a - ab * t);
}

// 花火。area の下からロケットが上がり、上のほうで弾ける。時間をずらして5つ上がる。足す光を返す
vec3 fireworks(vec2 p, vec2 areaMin, vec2 areaMax) {
    vec3 light = vec3(0.0);
    for (int b = 0; b < 5; b++) {
        float offset = float(b) * FIREWORK_PERIOD / 5.0;
        float burst = floor((iTime + offset) / FIREWORK_PERIOD);
        float t = fract((iTime + offset) / FIREWORK_PERIOD);
        float seed = burst * 5.0 + float(b);
        vec2 center = mix(areaMin, areaMax, vec2(0.1 + 0.8 * hash1(seed), 0.15 + 0.35 * hash1(seed + 0.5)));
        vec3 color = confettiColor(hash1(seed + 0.25));
        vec3 color2 = confettiColor(hash1(seed + 0.75));

        if (t < FIREWORK_RISE) {
            // ロケット: 下から弾ける位置まで、減速しながら上がる。光の尾を引く
            vec2 start = vec2(center.x + (hash1(seed + 0.1) - 0.5) * 80.0, areaMax.y);
            float rise = t / FIREWORK_RISE;
            vec2 head = mix(start, center, 1.0 - (1.0 - rise) * (1.0 - rise));
            vec2 tail = mix(start, center, 1.0 - (1.0 - max(rise - 0.15, 0.0)) * (1.0 - max(rise - 0.15, 0.0)));
            float d = segmentDistance(p, tail, head);
            light += vec3(1.0, 0.9, 0.75) * (exp(-d * d / 6.0) * 0.8 + exp(-length(p - head) / 10.0) * 0.6);
            continue;
        }

        float bt = (t - FIREWORK_RISE) / (1.0 - FIREWORK_RISE);
        if (length(p - center) > FIREWORK_RADIUS * 1.2 + 120.0) {
            continue;
        }
        // 弾けた瞬間に、周りをぱっと明るくする
        light += mix(color, vec3(1.0), 0.5) * 0.25 * exp(-length(p - center) / 140.0) * max(0.0, 1.0 - bt / 0.12);

        float spread = 1.0 - (1.0 - bt) * (1.0 - bt);  // 速く広がって、だんだん止まる
        float fade = pow(1.0 - bt, 1.5);
        for (int k = 0; k < 40; k++) {
            float h = hash1(seed * 1.7 + float(k));
            float angle = 6.2831853 * (float(k) + h) / 40.0;
            float speed = 0.55 + 0.45 * hash1(seed + float(k) * 3.1);
            vec2 dir = vec2(cos(angle), sin(angle)) * FIREWORK_RADIUS * speed;
            vec2 head = center + dir * spread + vec2(0.0, 90.0 * bt * bt);  // 少しずつ落ちる
            float tailSpread = 1.0 - (1.0 - max(bt - 0.08, 0.0)) * (1.0 - max(bt - 0.08, 0.0));
            vec2 tail = center + dir * tailSpread + vec2(0.0, 90.0 * max(bt - 0.08, 0.0) * max(bt - 0.08, 0.0));
            float d = segmentDistance(p, tail, head);
            // 消えぎわは瞬かせる
            float twinkle = bt > 0.6 ? 0.5 + 0.5 * sin(iTime * 40.0 + float(k) * 2.3) : 1.0;
            vec3 sparkColor = mod(float(k), 2.0) < 1.0 ? color : color2;
            light += sparkColor * FIREWORK_BRIGHT * fade * twinkle * (exp(-d * d / 5.0) + 0.15 * exp(-d / 8.0));
        }
    }
    return light;
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
    // 13マス目は git push
    bool pushed = mod(floor(readValue(vec2(rightEdge - 12.5 * cw, 0.5)) / 16.0), 2.0) >= 1.0;
    float sinceCursor = iTime - iTimeCursorChange;

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

    // Claude が処理中・入力待ち・終わった直後の pane では、その pane の左上でキャラが動く（非アクティブな pane でも明るいまま）。
    // 14〜21マス目に、pane ごとに「左」と「上 + 状態 * 512」が入っている。pane ごとに時刻をずらして動きをばらばらにする
    // 状態は 1: 処理中 / 2: 入力待ち / 3: 終わった直後 / 4: 処理が長引いている（鍋をかき混ぜる） / 5: アクティブな pane で待機中
    for (int i = 0; i < 4; i++) {
        float paneLeft = readValue(vec2(rightEdge - (13.5 + 2.0 * float(i)) * cw, 0.5));
        float topState = readValue(vec2(rightEdge - (14.5 + 2.0 * float(i)) * cw, 0.5));
        float state = floor(topState / 512.0);
        if (state < 1.0) {
            continue;
        }
        float paneTop = mod(topState, 512.0);
        bool waiting = state == 2.0;
        bool celebrating = state == 3.0;
        // キー入力などでカーソルが動いている間は、アクティブな pane のキャラだけ走る
        bool running = sinceCursor < MASCOT_RUN_AFTER && paneLeft == left && paneTop == top;
        bool typing = sinceCursor < NESS_AFTER && paneLeft == left && paneTop == top;
        // pane の左上から、上と左に同じだけあけて置く（跳ねると、上の間が一時的に縮む）
        vec2 origin = gridMin + vec2(paneLeft, paneTop) * cellSize + vec2(MASCOT_MARGIN);
        float time = iTime + float(i) * 1.7;
        // Claude が待機中の pane で入力している間は、キャラの代わりにネスが動く
        if (state == 5.0) {
            vec4 ness = typing ? nessTypingAt(px, origin, time) : vec4(0.0);
            fragColor.rgb = mix(fragColor.rgb, ness.rgb, ness.a);
            continue;
        }
        // 処理中に入力している間は、ネスがキャラにプレゼントを投げ渡す（料理のシーンや化け物は出さない）
        bool catching = false;
        if ((state == 1.0 || state == 4.0) && typing) {
            int color = nessTossAt(px, origin, time, catching);
            if (color > 0) {
                fragColor.rgb = NESS_COLORS[color];
            }
            state = 1.0;
        }
        if (state == 4.0) {
            // 鍋をかき混ぜるシーンは、キャラの体がいつもの位置に来るように置く（上は湯気の分だけ pane の上端に寄せる）
            int color = cookingAt(px, origin - vec2(COOK_PIXEL.x, MASCOT_MARGIN - COOK_PIXEL.y), time);
            if (color > 0) {
                fragColor.rgb = COOK_COLORS[color];
            }
            continue;
        }
        // 処理中にまれに、足がたくさん生えた化け物になる（キー入力中は出さない）
        float monsterT = state == 1.0 && !typing ? monsterTime(time) : -1.0;
        if (monsterT >= 0.0) {
            applyMonster(fragColor.rgb, px, origin, monsterT, time);
            continue;
        }
        int hit = mascotAt(px, origin, time, waiting, celebrating, running, catching);
        if (hit == 1) {
            fragColor.rgb = MASCOT_COLOR;
        } else if (hit == 2) {
            fragColor.rgb = MASCOT_ALERT;
        } else if (hit == 3) {
            fragColor.rgb = MASCOT_DUST;
        } else if (hit == 4) {
            fragColor.rgb = MASCOT_SHADOW;
        }

        // 終わった直後は、キャラの周りに紙吹雪を舞わせる（バンザイ中は歩かないので、体の中心から左右に同じ幅）
        if (celebrating) {
            float center = origin.x + 9.0 * MASCOT_PIXEL.x;
            float confettiLeft = center - CONFETTI_WIDTH * 0.5;
            float confettiRight = center + CONFETTI_WIDTH * 0.5;
            float headerTop = gridMin.y + (paneTop - 1.0) * ch;
            vec4 paper = confetti(px, vec2(confettiLeft, headerTop), vec2(confettiRight, headerTop + CONFETTI_HEIGHT));
            fragColor.rgb = mix(fragColor.rgb, paper.rgb, paper.a);
        }
    }

    // git push が成功した直後は、画面の上のほうに花火を上げる
    if (pushed) {
        fragColor.rgb += fireworks(px, vec2(gridMin.x, gridMin.y + ch), vec2(gridMax.x, gridMin.y + (gridMax.y - gridMin.y) * 0.6));
    }

    // prefix を押している間は、画面の外周を光らせる
    if (prefix) {
        vec2 fromEdge = min(px, iResolution.xy - px);
        fragColor.rgb += glowColor * PREFIX_GLOW * exp(-min(fromEdge.x, fromEdge.y) / PREFIX_WIDTH);
    }
}
