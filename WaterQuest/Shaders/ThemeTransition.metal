#include <metal_stdlib>
using namespace metal;

// Ripple distortion shader for theme switching.
// Applied as a SwiftUI layerEffect – displaces pixels near the expanding
// circle edge to create a shockwave / lens-warp look.
//
// Arguments:
//   position  – pixel coordinate (supplied by SwiftUI)
//   center    – origin of the ripple in view coordinates
//   time      – normalised progress 0→1
//   size      – view size (width, height)

[[ stitchable ]]
half4 themeRipple(float2 position,
                  SwiftUI::Layer layer,
                  float2 center,
                  float time,
                  float2 size) {
    float maxRadius = length(size);         // full diagonal
    float radius    = time * maxRadius;     // current wave front

    float dist = length(position - center);
    float diff = dist - radius;

    // Band around the wavefront where distortion is visible
    float waveWidth = 80.0;

    float2 displaced = position;

    if (abs(diff) < waveWidth) {
        // Normalised position within the wave band [-1, 1]
        float waveFactor = diff / waveWidth;

        // Sine-based displacement (smooth shockwave profile)
        float strength = 18.0 * (1.0 - abs(waveFactor));
        float wave = sin(waveFactor * M_PI_F * 2.5) * strength;

        // Displace radially
        float2 dir = normalize(position - center);
        displaced += dir * wave;
    }

    return layer.sample(displaced);
}
