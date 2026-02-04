/*
 * mode-glow.glsl - カーソル形状に応じてグロー色が変わるシェーダー
 *
 * Vimのモードをカーソル形状から推測:
 *   - ブロック (w/h > 0.5) → Normal → 青
 *   - 縦線 (w/h < 0.2)     → Insert → 緑
 *   - その他               → Replace/Visual → オレンジ
 *
 * Vim検出:
 *   カーソル形状が変化してから一定時間のみエフェクトを表示。
 *   通常のシェルでは形状変化が少ないため、実質Vim使用時のみ発動。
 *
 * インストール:
 *   1. ~/.config/ghostty/shaders/ にコピー
 *   2. ghostty設定に追加: custom-shader = ~/.config/ghostty/shaders/mode-glow.glsl
 */

// ========== 設定 ==========
const float GLOW_RADIUS = 80.0;      // グローの広がり（ピクセル）
const float GLOW_INTENSITY = 0.4;    // グローの強さ (0.0-1.0)
const float PULSE_SPEED = 2.0;       // 脈動速度
const float PULSE_AMOUNT = 0.15;     // 脈動の強さ

// Vim検出設定
const float ACTIVE_DURATION = 3.0;   // エフェクト持続時間（秒）- カーソル変化後この時間表示
const float FADE_DURATION = 1.0;     // フェードアウト時間（秒）

// モード別の色
const vec3 COLOR_NORMAL  = vec3(0.3, 0.5, 1.0);   // 青
const vec3 COLOR_INSERT  = vec3(0.3, 0.9, 0.4);   // 緑
const vec3 COLOR_REPLACE = vec3(1.0, 0.6, 0.2);   // オレンジ
// ==========================

vec3 getModeColor(vec4 cursor) {
    float ratio = cursor.z / cursor.w;

    if (ratio > 0.5) {
        return COLOR_NORMAL;
    } else if (ratio < 0.2) {
        return COLOR_INSERT;
    } else {
        return COLOR_REPLACE;
    }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 termColor = texture(iChannel0, uv);

    // カーソル変化からの経過時間
    float timeSinceChange = iTime - iTimeCursorChange;

    // エフェクトの可視性を計算（フェードアウト）
    float visibility = 1.0 - smoothstep(ACTIVE_DURATION, ACTIVE_DURATION + FADE_DURATION, timeSinceChange);

    // 可視性がほぼ0ならエフェクトをスキップ
    if (visibility < 0.01) {
        fragColor = termColor;
        return;
    }

    // カーソル中心を計算
    vec2 cursorCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z * 0.5, -iCurrentCursor.w * 0.5);

    // カーソルからの距離
    float dist = distance(fragCoord, cursorCenter);

    // モードに応じた色を取得
    vec3 glowColor = getModeColor(iCurrentCursor);

    // 脈動エフェクト
    float pulse = 1.0 + sin(iTime * PULSE_SPEED) * PULSE_AMOUNT;

    // グローの強さを計算（距離に応じて減衰）
    float glow = smoothstep(GLOW_RADIUS * pulse, 0.0, dist) * GLOW_INTENSITY;

    // カーソル移動直後は強く光る
    float moveFlash = exp(-timeSinceChange * 5.0) * 0.3;
    glow += moveFlash * smoothstep(GLOW_RADIUS * 2.0, 0.0, dist);

    // 可視性を適用
    glow *= visibility;

    // 合成
    vec3 finalColor = mix(termColor.rgb, glowColor, glow);

    fragColor = vec4(finalColor, termColor.a);
}
