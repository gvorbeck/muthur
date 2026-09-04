#include <metal_stdlib>
using namespace metal;

/// The other half of D61 — the picture bulging where the deflection fault
/// (D53) is, rather than only lighting up there.
///
/// `position` is where the *output* pixel lands; a distortion shader answers
/// with where in the *input* to sample instead, so pushing that sample point
/// away from the band is what makes the band pull the glass toward itself —
/// a lens, not a shear. The push is a bump — `t · e^(−t²)` — rather than a
/// step, so it is zero at the band's own centre line, peaks a little off it in
/// each direction, and is back to nothing by `depth`: the same "soft at both
/// ends" shape `sweepDepth` draws the light in, so the two halves of the fault
/// fade out together. The horizontal term bows outward from the middle column
/// rather than sideways in one direction, so what the band drags is a bubble
/// and not a curtain.
[[ stitchable ]] float2 tubeBulge(
    float2 position, float2 size, float bandY, float depth, float amplitude
) {
    float t = (position.y - bandY) / depth;
    float bump = t * exp(-t * t);
    float midpoint = max(size.x * 0.5, 1.0);
    float centred = (position.x - midpoint) / midpoint;
    float2 push = float2(centred, 1.0) * bump * amplitude;
    return position + push;
}
