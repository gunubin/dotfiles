/*
 * mode-glow.glsl - カーソル移動で火花が飛び散るシェーダー
 *
 * 機能:
 *   - カーソル移動時にパステルカラーの火花が放射状に飛散
 *   - 毎回異なる方向・距離でランダムに飛ぶ
 */

// ========== 設定 ==========
const int PARTICLE_COUNT = 12;
const float EXPLOSION_DURATION = 0.8;
const float SPARK_DISTANCE = 50.0;      // 火花の飛距離（基本）
const float SPARK_DISTANCE_RAND = 150.0; // 火花の飛距離（ランダム幅）

// Cupertinoパステルカラー
const vec3 PASTEL_PINK = vec3(1.0, 0.6, 0.7);
const vec3 PASTEL_BLUE = vec3(0.6, 0.8, 1.0);
const vec3 PASTEL_GREEN = vec3(0.6, 1.0, 0.7);
const vec3 PASTEL_PURPLE = vec3(0.8, 0.6, 1.0);
const vec3 PASTEL_ORANGE = vec3(1.0, 0.75, 0.5);
const vec3 PASTEL_YELLOW = vec3(1.0, 1.0, 0.6);
// ==========================

// 疑似乱数
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 termColor = texture(iChannel0, uv);

    // カーソル変化からの経過時間
    float timeSinceChange = iTime - iTimeCursorChange;

    // カーソル中心
    vec2 cursorCenter = iCurrentCursor.xy + vec2(iCurrentCursor.z * 0.5, -iCurrentCursor.w * 0.5);

    // ========== 火花パーティクル ==========
    if (timeSinceChange < EXPLOSION_DURATION) {
        float explosionProgress = timeSinceChange / EXPLOSION_DURATION;

        // iTimeCursorChange をシードに使って毎回違うパターンに
        float timeSeed = fract(iTimeCursorChange * 0.123) * 1000.0;

        for (int i = 0; i < PARTICLE_COUNT; i++) {
            float fi = float(i);

            // 毎回変わるランダムシード
            float seed = fi * 73.156 + timeSeed;

            // ランダムな角度
            float angle = hash(seed * 1.234) * 6.28318;

            // ランダムな速度
            float speed = SPARK_DISTANCE + hash(seed * 2.345) * SPARK_DISTANCE_RAND;

            // ランダムなサイズ
            float size = 4.0 + hash(seed * 3.456) * 6.0;

            // パーティクルの位置
            vec2 particleDir = vec2(cos(angle), sin(angle));
            vec2 particlePos = cursorCenter + particleDir * speed * explosionProgress;

            // 重力効果
            float gravity = 40.0 + hash(seed * 4.567) * 80.0;
            particlePos.y -= gravity * explosionProgress * explosionProgress;

            // パーティクルとの距離
            float particleDist = distance(fragCoord, particlePos);

            // フェードアウト
            float fade = 1.0 - explosionProgress;
            fade *= fade;

            // パーティクルを描画
            if (particleDist < size * fade) {
                // パステルカラーをランダムに選択
                float colorChoice = hash(seed * 5.678);
                vec3 sparkColor;
                if (colorChoice < 0.166) {
                    sparkColor = PASTEL_PINK;
                } else if (colorChoice < 0.333) {
                    sparkColor = PASTEL_BLUE;
                } else if (colorChoice < 0.5) {
                    sparkColor = PASTEL_GREEN;
                } else if (colorChoice < 0.666) {
                    sparkColor = PASTEL_PURPLE;
                } else if (colorChoice < 0.833) {
                    sparkColor = PASTEL_ORANGE;
                } else {
                    sparkColor = PASTEL_YELLOW;
                }

                // 中心ほど明るい
                float brightness = 1.0 - (particleDist / (size * fade));
                sparkColor *= brightness * fade * 2.0;

                fragColor = vec4(termColor.rgb + sparkColor, termColor.a);
                return;
            }
        }
    }

    // 火花がない場合はそのまま
    fragColor = termColor;
}
