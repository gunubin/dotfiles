/*
 * focus-glow.glsl - ウィンドウが非アクティブのとき画面を暗く沈めるシェーダー
 *
 * 機能（フォーカスが外れてしばらくすると、次の状態に切り替わる）:
 *   - 画面がわずかに縮んで奥へ下がる
 *   - すりガラス越しのようにぼける
 *   - 色が少し抜けて、縁ほど暗く紺色に沈む
 *   - フィルムの粒と、モニターの走査線がうっすら乗る
 *   - ブラウン管のように、画面が丸く膨らみ、角が丸くなり、色が赤と青にずれる
 *   フォーカスが戻ると、すぐ元に戻る。切り替えのアニメーションは付けていない
 *
 * 各演出の強さを 0 にすると、その演出だけ止められる（ぼかしを止めるときは BLUR = 0.0）
 * 非アクティブの間も描き直されるよう、config で custom-shader-animation = always にしている
 */

// ========== 設定 ==========
const float DELAY = 2.0;             // フォーカスが外れてから切り替わるまで（秒）

const float RECEDE = 0.03;           // 奥に下がるときに縮む割合
const float BLUR = 3.0;              // ぼかしの半径（px）
const float DIM = 0.35;              // 画面全体を暗くする割合
const float EDGE_DIM = 0.4;          // 縁でさらに暗くする割合
const float WIDTH = 0.1;             // 縁の暗さが広がる幅（画面の短辺に対する比）
const float DESATURATE = 0.5;        // 色を抜く割合（0 でそのまま、1 で白黒）
const float GRAIN = 0.04;            // フィルムの粒の強さ
const float GRAIN_FPS = 0.0;         // 粒が動く速さ（コマ/秒）。0 で動かない模様にする
const float SCANLINE = 0.3;          // 走査線で暗くする割合
const float SCANLINE_PITCH = 6.0;    // 走査線の間隔（px。Retina では表示上の半分になる）
const float SCANLINE_WIDTH = 2.0;    // 走査線の太さ（px）
const float CURVE = 0.08;            // ブラウン管の膨らみ
const float CORNER = 0.04;           // 角の丸み（画面の短辺に対する比）
const float CHROMA = 2.0;            // 赤と青のずれ（px。画面の端ほど大きくずれる）
const float FLICKER = 0.0;           // 明るさのちらつき（目にうるさいので止めている。戻すなら 0.03 前後）
const vec3 SHADE = vec3(0.07, 0.07, 0.11); // 沈める先の色（catppuccin Mocha の crust 付近の紺）
// ==========================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 3x3 のぼかし。赤と青は shift だけずらした位置から読む（色ずれ）
// 非アクティブ中は毎フレーム描くので、読み込み回数を抑えて 3x3 にしている
vec3 blurred(vec2 uv, float radius, vec2 shift) {
    vec2 texel = radius / iResolution.xy;
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float weight = x == 0 && y == 0 ? 4.0 : (x == 0 || y == 0 ? 2.0 : 1.0);
            vec2 p = uv + vec2(x, y) * texel;
            sum += vec3(
                texture(iChannel0, p + shift).r,
                texture(iChannel0, p).g,
                texture(iChannel0, p - shift).b
            ) * weight;
            total += weight;
        }
    }
    return sum / total;
}

// 角の丸い四角の内側なら 1、外側なら 0（境目はなめらか）
float roundedMask(vec2 uv, float radius) {
    vec2 size = iResolution.xy;
    vec2 p = abs(uv * size - size * 0.5) - (size * 0.5 - radius);
    float dist = length(max(p, 0.0)) - radius;
    return 1.0 - smoothstep(-1.0, 1.0, dist);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    if (iFocus == 1 || iTime - iTimeFocus < DELAY) {
        return;
    }
    // 各演出の掛かり具合。切り替えのアニメーションをしないので常に 1
    float strength = 1.0;

    // 奥に下がる: 画面の中心を基準に縮める
    float scale = 1.0 - RECEDE * strength;
    vec2 centered = (uv - 0.5) / scale;

    // ブラウン管の膨らみ: 端ほど外側から読んで、画面が丸く膨らんで見えるようにする
    centered *= 1.0 + CURVE * strength * dot(centered, centered);
    vec2 sampleUv = centered + 0.5;

    // 縮んだり膨らんだりしてはみ出た外側と、丸めた角の外は沈める先の色
    float mask = roundedMask(sampleUv, CORNER * strength * min(iResolution.x, iResolution.y));
    if (mask <= 0.0) {
        fragColor.rgb = SHADE;
        return;
    }

    // ぼかしと色ずれ（画面の中心から離れるほど大きくずれる）
    vec2 shift = centered * 2.0 * CHROMA * strength / iResolution.xy;
    vec3 color = blurred(sampleUv, BLUR * strength, shift);

    // 色を少し抜く
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(color, vec3(gray), DESATURATE * strength);

    // 縁ほど暗く、紺色へ沈める
    vec2 fromEdge = min(fragCoord, iResolution.xy - fragCoord);
    float edgeDist = min(fromEdge.x, fromEdge.y);
    float edge = exp(-edgeDist / (WIDTH * min(iResolution.x, iResolution.y)));
    color = mix(color, SHADE, min(1.0, DIM + EDGE_DIM * edge) * strength);

    // 走査線
    float line = step(SCANLINE_PITCH - SCANLINE_WIDTH, mod(fragCoord.y, SCANLINE_PITCH));
    color *= 1.0 - SCANLINE * line * strength;

    // フィルムの粒
    float frame = floor(iTime * GRAIN_FPS);
    color += (hash(fragCoord + frame * 17.0) - 0.5) * GRAIN * strength;

    // ちらつき
    color *= 1.0 - FLICKER * strength * (0.5 + 0.5 * sin(iTime * 50.0));

    fragColor.rgb = mix(SHADE, clamp(color, 0.0, 1.0), mask);
}
