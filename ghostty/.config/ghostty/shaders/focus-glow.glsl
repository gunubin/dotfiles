/*
 * focus-glow.glsl - ウィンドウが非アクティブのとき画面を暗く沈めるシェーダー
 *
 * 機能（フォーカスが外れてしばらくすると、ゆっくり次の状態になる）:
 *   - 画面がわずかに縮んで奥へ下がる
 *   - すりガラス越しのようにぼける
 *   - 色が少し抜けて、縁ほど暗く紺色に沈む
 *   - フィルムの粒と、モニターの走査線がうっすら乗る
 *   フォーカスが戻ると、一番沈んだ状態から短時間で元に戻る
 *   （何秒外れていたかは分からないため、すぐ戻ったときも一瞬沈んだ状態から戻る）
 *
 * 各演出の強さを 0 にすると、その演出だけ止められる
 * 非アクティブの間も描き直されるよう、config で custom-shader-animation = always にしている
 */

// ========== 設定 ==========
const float DELAY = 2.0;             // フォーカスが外れてから変わり始めるまで（秒）
const float FADE_IN = 1.5;           // 変わりきるまでにかかる時間（秒）
const float FADE_OUT = 0.3;          // フォーカスが戻ってから元に戻るまで（秒）

const float RECEDE = 0.03;           // 奥に下がるときに縮む割合
const float BLUR = 3.0;              // ぼかしの半径（px）
const float DIM = 0.35;              // 画面全体を暗くする割合
const float EDGE_DIM = 0.4;          // 縁でさらに暗くする割合
const float WIDTH = 0.1;             // 縁の暗さが広がる幅（画面の短辺に対する比）
const float DESATURATE = 0.5;        // 色を抜く割合（0 でそのまま、1 で白黒）
const float GRAIN = 0.04;            // フィルムの粒の強さ
const float GRAIN_FPS = 12.0;        // 粒が動く速さ（コマ/秒）
const float SCANLINE = 0.3;          // 走査線で暗くする割合
const float SCANLINE_PITCH = 6.0;    // 走査線の間隔（px。Retina では表示上の半分になる）
const float SCANLINE_WIDTH = 2.0;    // 走査線の太さ（px）
const vec3 SHADE = vec3(0.07, 0.07, 0.11); // 沈める先の色（catppuccin Mocha の crust 付近の紺）
// ==========================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 5x5 のガウスぼかし
vec3 blurred(vec2 uv, float radius) {
    vec2 texel = radius / 2.0 / iResolution.xy;
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            float weight = exp(-float(x * x + y * y) / 4.0);
            sum += texture(iChannel0, uv + vec2(x, y) * texel).rgb * weight;
            total += weight;
        }
    }
    return sum / total;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    float sinceChange = iTime - iTimeFocus;
    float strength = iFocus == 1
        ? 1.0 - smoothstep(0.0, FADE_OUT, sinceChange)
        : smoothstep(DELAY, DELAY + FADE_IN, sinceChange);
    if (strength <= 0.0) {
        return;
    }

    // 奥に下がる: 画面の中心を基準に縮める。はみ出た外側は沈める先の色
    float scale = 1.0 - RECEDE * strength;
    vec2 sampleUv = (uv - 0.5) / scale + 0.5;
    if (any(lessThan(sampleUv, vec2(0.0))) || any(greaterThan(sampleUv, vec2(1.0)))) {
        fragColor.rgb = SHADE;
        return;
    }

    // ぼかし
    vec3 color = BLUR > 0.0 ? blurred(sampleUv, BLUR * strength) : texture(iChannel0, sampleUv).rgb;

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

    fragColor.rgb = clamp(color, 0.0, 1.0);
}
