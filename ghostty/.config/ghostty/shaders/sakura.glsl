/*
 * sakura.glsl - カーソル移動で桜の花びらが舞い落ちるシェーダー
 *
 * 機能:
 *   - カーソル移動時に、カーソルの周りから桜の花びらがふわっと散る
 *   - 花びらは風で右へ流れ、左右に揺れながらゆっくり落ちる
 *   - 花びらは回転し、裏返るように幅が伸び縮みする
 */

// ========== 設定 ==========
const int PETAL_COUNT = 9;
const float DURATION = 1.3;          // 演出の長さ（秒）
const float SPREAD = 0.6;            // 出現位置の散らばり（カーソルの高さに対する比）
const float BURST_SPEED = 120.0;     // 最初に散る速さ（px/秒）
const float DRAG = 3.0;              // 空気抵抗（大きいほど早く止まる）
const float FALL_SPEED = 90.0;       // 落下の速さ（px/秒）
const float WIND = 45.0;             // 右へ流れる速さ（px/秒）
const float SWAY = 10.0;             // 左右の揺れ幅（px）
const vec2 PETAL_SIZE = vec2(6.0, 4.0); // 花びらの半径（長さ, 幅 px）
const float OPACITY = 0.85;          // 花びらの最大の不透明度
const vec3 PETAL_PINK = vec3(1.0, 0.72, 0.82);  // 根元の色
const vec3 PETAL_WHITE = vec3(1.0, 0.92, 0.95); // 先端の色
// ==========================

// 疑似乱数
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

// 花びらの距離関数（根元が細く先端が広い楕円で、先端に切れ込みがある）
float petalSdf(vec2 p, vec2 size) {
    float along = clamp((p.x + size.x) / (2.0 * size.x), 0.0, 1.0);
    vec2 r = vec2(size.x, size.y * mix(0.45, 1.0, along));
    float ellipse = (length(p / r) - 1.0) * min(r.x, r.y);
    float notch = length(p - vec2(size.x * 1.15, 0.0)) - size.y * 0.55;
    return max(ellipse, -notch);
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

    // iTimeCursorChange をシードに使って毎回違うパターンに
    float timeSeed = fract(iTimeCursorChange * 0.123) * 1000.0;

    // 空気抵抗で減速したときの移動量の係数
    float travel = (1.0 - exp(-DRAG * t)) / DRAG;
    float fade = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(DURATION * 0.6, DURATION, t));

    for (int i = 0; i < PETAL_COUNT; i++) {
        float seed = float(i) * 73.156 + timeSeed;

        // カーソルの周りに散らばって現れ、ふわっと外へ散る
        float angle = hash(seed * 1.234) * 6.28318;
        vec2 dir = vec2(cos(angle), sin(angle));
        vec2 pos = cursorCenter + dir * hash(seed * 2.345) * SPREAD * iCurrentCursor.w;
        pos += dir * BURST_SPEED * (0.5 + hash(seed * 3.456)) * travel;

        // 風で右へ流れながら落ちる
        pos.x += WIND * (0.6 + 0.8 * hash(seed * 4.567)) * t;
        pos.y -= FALL_SPEED * (0.7 + 0.6 * hash(seed * 5.678)) * t;

        // 左右に揺れる
        float swayPhase = hash(seed * 6.789) * 6.28318;
        pos.x += sin(t * (4.0 + hash(seed * 7.891) * 3.0) + swayPhase) * SWAY;

        // 花びらの座標系に回転させる
        float rot = hash(seed * 8.912) * 6.28318 + (hash(seed * 9.123) - 0.5) * 6.0 * t;
        vec2 d = fragCoord - pos;
        float c = cos(rot);
        float s = sin(rot);
        d = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);

        // 裏返る動き: 幅を cos で伸び縮みさせる
        float flip = cos(t * (3.0 + hash(seed * 10.234) * 4.0) + swayPhase);
        float size = 0.8 + 0.4 * hash(seed * 11.345);
        vec2 petalSize = PETAL_SIZE * size * vec2(1.0, max(abs(flip), 0.25));

        float sdf = petalSdf(d, petalSize);
        float coverage = 1.0 - smoothstep(-0.5, 0.5, sdf);
        if (coverage <= 0.0) {
            continue;
        }

        // 根元は濃いピンク、先端は白っぽく、裏返り具合で陰影をつける
        float along = clamp((d.x + petalSize.x) / (2.0 * petalSize.x), 0.0, 1.0);
        vec3 color = mix(PETAL_PINK, PETAL_WHITE, along);
        color *= 0.8 + 0.2 * abs(flip);

        fragColor.rgb = mix(fragColor.rgb, color, coverage * fade * OPACITY);
    }
}
