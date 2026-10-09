/*
 * sparkle.glsl - カーソル移動で小さな星がきらめくシェーダー
 *
 * 機能:
 *   - カーソル移動時に、カーソルの周りで小さな4本光の星が数個だけ瞬いて消える
 *   - 星はそれぞれ少しずつ遅れて現れ、膨らんでから縮んで消える
 *   - 星の色は1つごとにランダムなパステルカラー
 */

// ========== 設定 ==========
const int STAR_COUNT = 3;
const float DURATION = 0.5;          // 演出の長さ（秒）
const float STAGGER = 0.15;          // 星ごとの出現の遅れ（最大, 秒）
const float SPREAD = 1.2;            // 星が出る範囲（カーソルの高さに対する比）
const float STAR_SIZE = 0.45;       // 光の長さ（カーソルの高さに対する比）
const float SATURATION = 0.45;       // 彩度（低いほど淡いパステル）
const float BRIGHTNESS = 1.6;        // 明るさ
// ==========================

// 疑似乱数
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

vec3 hsv2rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// 4本光の星の明るさ（縦横に細長いひし形を重ね、中心に小さな光をのせる）
float starShape(vec2 p, float len) {
    float width = len * 0.12;
    vec2 a = abs(p);
    float vertical = 1.0 - smoothstep(0.0, 1.0, a.x / width + a.y / len);
    float horizontal = 1.0 - smoothstep(0.0, 1.0, a.y / width + a.x / len);
    float core = exp(-dot(p, p) / (width * width * 4.0));
    return max(max(vertical, horizontal), core);
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

    for (int i = 0; i < STAR_COUNT; i++) {
        float seed = float(i) * 73.156 + timeSeed;

        // 星ごとに少し遅れて現れる
        float delay = hash(seed * 1.234) * STAGGER;
        float life = (t - delay) / (DURATION - STAGGER);
        if (life <= 0.0 || life >= 1.0) {
            continue;
        }

        // カーソルの周りのランダムな位置
        float angle = hash(seed * 2.345) * 6.28318;
        float dist = (0.4 + 0.6 * hash(seed * 3.456)) * SPREAD * iCurrentCursor.w;
        vec2 pos = cursorCenter + vec2(cos(angle), sin(angle)) * dist;

        // 膨らんでから縮む、少し回転させる
        float pulse = sin(life * 3.14159);
        float len = STAR_SIZE * iCurrentCursor.w * (0.7 + 0.6 * hash(seed * 4.567)) * pulse;
        float rot = (hash(seed * 5.678) - 0.5) * 0.6 + life * 0.8;
        vec2 d = fragCoord - pos;
        float c = cos(rot);
        float s = sin(rot);
        d = vec2(c * d.x + s * d.y, -s * d.x + c * d.y);

        float glow = starShape(d, max(len, 0.001));
        vec3 color = hsv2rgb(vec3(hash(seed * 6.789), SATURATION, 1.0));

        // 光っているように足し合わせる
        fragColor.rgb += color * glow * pulse * BRIGHTNESS;
    }
}
