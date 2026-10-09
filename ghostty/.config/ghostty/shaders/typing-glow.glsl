/*
 * typing-glow.glsl - 入力中だけカーソルの周りがほんのり光るシェーダー
 *
 * 機能:
 *   - カーソルが動いている間、カーソルの周りに柔らかい光が出る
 *   - 手を止めると、少し置いてからゆっくり消える
 *   - 光の色はパステルで、時間とともに少しずつ移り変わる
 */

// ========== 設定 ==========
const float HOLD = 0.4;              // 手を止めてから消え始めるまで（秒）
const float FADE = 0.8;              // 消えるのにかかる時間（秒）
const float RADIUS = 1.5;            // 光の広がり（カーソルの高さに対する比）
const float INTENSITY = 0.22;        // 光の強さ
const float PULSE = 0.08;            // キーを押した瞬間に足す強さ
const float HUE_SPEED = 0.05;        // 色が一周する速さ（周/秒）
const float SATURATION = 0.45;       // 彩度（低いほど淡いパステル）
// ==========================

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // カーソル変化からの経過時間
    float t = iTime - iTimeCursorChange;
    if (t >= HOLD + FADE) {
        return;
    }

    // カーソル中心
    vec2 cursorCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z * 0.5, -iCurrentCursor.w * 0.5);

    // 入力が続く間は点いたまま、止めると消える。押した瞬間だけ少し強く
    float on = 1.0 - smoothstep(HOLD, HOLD + FADE, t);
    float strength = INTENSITY * on + PULSE * exp(-t * 12.0);

    // カーソルを中心にした柔らかい光
    float radius = RADIUS * iCurrentCursor.w;
    float dist = distance(fragCoord, cursorCenter);
    float glow = exp(-(dist * dist) / (radius * radius));

    vec3 color = hsv2rgb(vec3(fract(iTime * HUE_SPEED), SATURATION, 1.0));
    fragColor.rgb += color * glow * strength;
}
