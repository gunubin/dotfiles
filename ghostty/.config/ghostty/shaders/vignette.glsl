void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 termColor = texture(iChannel0, uv);

    // カーソル位置を正規化 (0-1)
    vec2 cursorPos = iCurrentCursor.xy / iResolution.xy;

    // カーソルからの距離でフォーカス効果
    float dist = length(uv - cursorPos);
    float vignette = 1.0 - smoothstep(0.2, 0.6, dist);

    fragColor = vec4(termColor.rgb * vignette, termColor.a);
}
