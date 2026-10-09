/*
 * focus-glow.glsl - ウィンドウが非アクティブのとき画面の縁にパステルのにじみを出すシェーダー
 *
 * 機能:
 *   - フォーカスが外れると、画面の縁がパステルでにじむ
 *   - 色は左上のピンクから右下の水色へ変わる
 *   - フォーカスが戻ると、にじみはすっと消える
 *
 * 非アクティブの間は描き直されないことがあるため、にじみはフェードインせず
 * フォーカスが外れた時点で出す。消えるときだけフェードさせる
 */

// ========== 設定 ==========
const float WIDTH = 0.08;            // にじみの幅（画面の短辺に対する比）
const float INTENSITY = 0.35;        // にじみの強さ
const float FADE_OUT = 0.4;          // フォーカスが戻ってから消えるまで（秒）
const vec3 TOP_LEFT = vec3(0.96, 0.76, 0.91);     // Pink #f5c2e7
const vec3 MIDDLE = vec3(0.71, 0.75, 1.0);        // Lavender #b4befe
const vec3 BOTTOM_RIGHT = vec3(0.54, 0.86, 0.92); // Sky #89dceb
// ==========================

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = texture(iChannel0, uv);

    float strength = 1.0;
    if (iFocus == 1) {
        strength = 1.0 - smoothstep(0.0, FADE_OUT, iTime - iTimeFocus);
        if (strength <= 0.0) {
            return;
        }
    }

    // 一番近い縁までの距離
    vec2 fromEdge = min(fragCoord, iResolution.xy - fragCoord);
    float edgeDist = min(fromEdge.x, fromEdge.y);
    float width = WIDTH * min(iResolution.x, iResolution.y);
    float glow = exp(-edgeDist / width);

    // 左上（uv は下が 0 なので y を反転）から右下へのグラデーション
    float diagonal = (uv.x + (1.0 - uv.y)) * 0.5;
    vec3 color = diagonal < 0.5
        ? mix(TOP_LEFT, MIDDLE, diagonal * 2.0)
        : mix(MIDDLE, BOTTOM_RIGHT, diagonal * 2.0 - 1.0);

    fragColor.rgb += color * glow * INTENSITY * strength;
}
