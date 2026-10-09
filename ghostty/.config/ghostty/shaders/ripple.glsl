/*
 * ripple.glsl - カーソル移動で細い輪が広がるシェーダー
 *
 * 機能:
 *   - カーソル移動時に、カーソル中心から細い輪が1つ広がって消える
 *   - 輪の色はキーごとにランダムなパステルカラー
 */

// ========== 設定 ==========
const float DURATION = 0.4;          // 演出の長さ（秒）
const float START_RADIUS = 0.4;      // 輪の初期半径（カーソルの高さに対する比）
const float END_RADIUS = 1.6;        // 輪の最終半径（カーソルの高さに対する比）
const float THICKNESS = 1.5;         // 輪の太さ（px）
const float OPACITY = 0.6;           // 輪の最大の不透明度
const float SATURATION = 0.45;       // 彩度（低いほど淡いパステル）
// ==========================

// 疑似乱数
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    // カーソル変化からの経過時間
    float t = iTime - iTimeCursorChange;
    if (t >= DURATION) {
        return;
    }

    // カーソル中心
    vec2 cursorCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z * 0.5, -iCurrentCursor.w * 0.5);

    // 広がりは最初速く、だんだん遅く
    float progress = t / DURATION;
    float eased = 1.0 - pow(1.0 - progress, 3.0);
    float radius = mix(START_RADIUS, END_RADIUS, eased) * iCurrentCursor.w;

    float ringDist = abs(distance(fragCoord, cursorCenter) - radius);
    float coverage = 1.0 - smoothstep(THICKNESS * 0.5, THICKNESS * 0.5 + 1.0, ringDist);

    // iTimeCursorChange をシードに使ってキーごとに色相を変える
    float hue = hash(fract(iTimeCursorChange * 0.123) * 1000.0);
    vec3 ringColor = hsv2rgb(vec3(hue, SATURATION, 1.0));

    float fade = (1.0 - progress) * (1.0 - progress);
    fragColor.rgb = mix(fragColor.rgb, ringColor, coverage * fade * OPACITY);
}
