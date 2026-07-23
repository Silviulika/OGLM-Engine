#version 450 core

in vec2 vertex_tex_coordinates;
out vec4 frag_color;

uniform sampler2D sceneTexture;
uniform int toneMappingMode;
uniform float exposure;
uniform float outputGamma;
uniform vec2 viewportSize;

uniform int godRaysEnabled;
uniform vec2 godRayLightPosition;
uniform int godRaySamples;
uniform float godRayDensity;
uniform float godRayExposure;
uniform float godRayDecay;
uniform float godRayWeight;
uniform float godRayIntensity;

const int MAX_GOD_RAY_SAMPLES = 128;
const vec3 LuminanceWeights = vec3(0.2126, 0.7152, 0.0722);

vec3 Linear(vec3 x)
{
    return x;
}

vec3 Exponential(vec3 x)
{
    return 1.0 - exp(-x);
}

vec3 Reinhard(vec3 x)
{
    return 1.0 - 1.0 / (1.0 + x);
}

vec3 Uncharted2(vec3 x)
{
    const float A = 0.15;
    const float B = 0.50;
    const float C = 0.10;
    const float D = 0.20;
    const float E = 0.02;
    const float F = 0.30;
    const float W = 11.2;
    const float exposureBias = 2.0;
    x *= exposureBias;
    x = ((x * (A * x + C * B) + D * E) /
         (x * (A * x + B) + D * F)) - E / F;
    float white = ((W * (A * W + C * B) + D * E) /
                   (W * (A * W + B) + D * F)) - E / F;
    return x / white;
}

vec3 MGSV(vec3 x)
{
    const float A = 0.6;
    const float B = 0.45;
    vec3 t = step(vec3(A), x);
    vec3 y = min(vec3(1.0), A + B - B * B / max(x - A + B, vec3(0.0001)));
    return mix(x, y, t);
}

vec3 Uchimura(vec3 x, float P, float a, float m, float l, float c, float b)
{
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;
    vec3 w0 = 1.0 - smoothstep(0.0, m, x);
    vec3 w2 = step(m + l0, x);
    vec3 w1 = 1.0 - w0 - w2;
    vec3 T = m * pow(max(x / m, vec3(0.0)), vec3(c)) + b;
    vec3 S = P - (P - S1) * exp(CP * (x - S0));
    vec3 L = m + a * (x - m);
    return T * w0 + L * w1 + S * w2;
}

vec3 Uchimura(vec3 x)
{
    return Uchimura(x, 1.0, 1.0, 0.22, 0.4, 1.33, 0.0);
}

vec3 Filmic(vec3 x)
{
    x = max(vec3(0.0), x - vec3(0.004));
    return (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
}

vec3 ACES(vec3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

vec3 PBRNeutral(vec3 color)
{
    const float startCompression = 0.8 - 0.04;
    const float desaturation = 0.15;

    float x = min(color.r, min(color.g, color.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;
    float peak = max(color.r, max(color.g, color.b));
    if (peak < startCompression)
        return color;

    float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    color *= newPeak / max(peak, 0.0001);
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(color, newPeak * vec3(1.0), g);
}

const vec3 flim_pf = vec3(1.0);
const vec3 flim_pb = vec3(1.0);
const vec3 flim_pff = vec3(1.0);
const float flim_pe = 4.3;
const float flim_ps = 0.0;
const float flim_gr = 1.05;
const float flim_gg = 1.12;
const float flim_gb = 1.045;
const float flim_rr = 0.5;
const float flim_rg = 2.0;
const float flim_br = 0.1;
const float flim_rm = 1.0;
const float flim_gm = 1.0;
const float flim_bm = 1.0;
const float flim_lm = -10.0;
const float flim_lx = 22.0;
const float flim_tx = 0.44;
const float flim_ty = 0.28;
const float flim_sx = 0.591;
const float flim_sy = 0.779;
const float flim_fe = 6.0;
const float flim_fd = 5.0;
const float flim_pfe = 6.0;
const float flim_pfd = 27.5;
const float flim_ffs = 0.0;
const float flim_ms = 1.02;

float flim_wrap(float v, float s, float e)
{
    return s + mod(v - s, e - s);
}

float flim_range(float v, float s, float e, float r, float f)
{
    return r + ((f - r) / (e - s)) * (v - s);
}

float flim_satRange(float v, float s, float e)
{
    return clamp((v - s) / (e - s), 0.0, 1.0);
}

vec3 flim_rgb2hsv(vec3 r)
{
    float a = max(r.x, max(r.y, r.z));
    float i = min(r.x, min(r.y, r.z));
    float d = a - i;
    float h = 0.0;
    float s = a != 0.0 ? d / a : 0.0;
    float v = a;
    if (s != 0.0)
    {
        vec3 c = (vec3(a) - r) / max(d, 0.0001);
        if (r.x == a)
            h = c.z - c.y;
        else if (r.y == a)
            h = 2.0 + c.x - c.z;
        else
            h = 4.0 + c.y - c.x;
        h /= 6.0;
        if (h < 0.0)
            h += 1.0;
    }
    return vec3(h, s, v);
}

vec3 flim_hsv2rgb(vec3 w)
{
    float h = w.x;
    float s = w.y;
    float v = w.z;
    if (s == 0.0)
        return vec3(v);

    if (h == 1.0)
        h = 0.0;
    h *= 6.0;
    int i = int(floor(h));
    float f = h - float(i);
    float p = v * (1.0 - s);
    float q = v * (1.0 - s * f);
    float t = v * (1.0 - s * (1.0 - f));

    if (i == 0) return vec3(v, t, p);
    if (i == 1) return vec3(q, v, p);
    if (i == 2) return vec3(p, v, t);
    if (i == 3) return vec3(p, q, v);
    if (i == 4) return vec3(t, p, v);
    return vec3(v, p, q);
}

vec3 flim_balance(vec3 c, float h, float s, float v)
{
    vec3 r = flim_rgb2hsv(c);
    r.x = fract(r.x + h + 0.5);
    r.y = clamp(r.y * s, 0.0, 1.0);
    r.z *= v;
    return flim_hsv2rgb(r);
}

float flim_average(vec3 c)
{
    return (c.x + c.y + c.z) / 3.0;
}

float flim_sum(vec3 c)
{
    return c.x + c.y + c.z;
}

float flim_max3(vec3 c)
{
    return max(max(c.x, c.y), c.z);
}

vec3 flim_unclip(vec3 c, float p, float w)
{
    float m = flim_average(c);
    if (m <= 0.0001)
        return c;
    float n = flim_satRange(m, p / 1000.0, 1.0 - (w / 1000.0));
    return c * (n / m);
}

float flim_scurve(float v, float x, float y, float sx, float sy)
{
    v = clamp(v, 0.0, 1.0);
    x = clamp(x, 0.0, 1.0);
    y = clamp(y, 0.0, 1.0);
    sx = clamp(sx, 0.0, 1.0);
    sy = clamp(sy, 0.0, 1.0);

    float slope = (sy - y) / (sx - x);
    if (v < x)
    {
        float t = slope * x / y;
        return y * pow(max(v / x, 0.0), t);
    }
    if (v < sx)
    {
        float intercept = y - (slope * x);
        return slope * v + intercept;
    }

    float sp = -slope / (((sx - 1.0) / pow(1.0 - sx, 2.0)) * (1.0 - sy));
    return (1.0 - pow(1.0 - (v - sx) / (1.0 - sx), sp)) * (1.0 - sy) + sy;
}

float flim_densityMap(float m, float d)
{
    float o = pow(2.0, flim_lm);
    float f = flim_satRange(log2(m + o), flim_lm, flim_lx);
    f = flim_scurve(f, flim_tx, flim_ty, flim_sx, flim_sy);
    f *= d;
    f = pow(2.0, -f);
    return clamp(f, 0.0, 1.0);
}

vec3 flim_rolloff(vec3 c, vec3 st, vec3 dt, float d)
{
    vec3 sn = st / max(flim_sum(st), 0.0001);
    vec3 dn = dt / max(flim_max3(dt), 0.0001);
    float m = dot(c, sn);
    float f = flim_densityMap(m, d);
    return mix(dn, vec3(1.0), f);
}

vec3 flim_renderDensity(vec3 c, float e, float d)
{
    c *= pow(2.0, e);
    vec3 r = flim_rolloff(c, vec3(0.0, 0.0, 1.0), vec3(1.0, 1.0, 0.0), d);
    r *= flim_rolloff(c, vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 1.0), d);
    r *= flim_rolloff(c, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 1.0), d);
    return r;
}

vec3 flim_gain(float p, float s, float r, float m)
{
    vec3 o = flim_hsv2rgb(vec3(flim_wrap(p + (r / 360.0), 0.0, 1.0), 1.0 / s, 1.0));
    o /= max(flim_sum(o), 0.0001);
    return o * m;
}

mat3 flim_matrix(float rs, float gs, float bs, float rr, float gr, float br, float rm, float gm, float bm)
{
    mat3 m;
    m[0] = flim_gain(0.0, rs, rr, rm);
    m[1] = flim_gain(1.0 / 3.0, gs, gr, gm);
    m[2] = flim_gain(2.0 / 3.0, bs, br, bm);
    return m;
}

vec3 flim_nodeProcess(vec3 c, vec3 b)
{
    c = flim_renderDensity(c, flim_fe, flim_fd);
    c *= b;
    c = flim_renderDensity(c, flim_pfe, flim_pfd);
    return c;
}

vec3 Flim(vec3 c)
{
    c = max(c, vec3(0.0));
    c *= pow(2.0, flim_pe);
    c = min(c, vec3(5000.0));
    mat3 x = flim_matrix(flim_gr, flim_gg, flim_gb, flim_rr, flim_rg, flim_br,
                         flim_rm, flim_gm, flim_bm);
    mat3 i = inverse(x);
    vec3 b = flim_pb * x;
    const float g = 1e7;
    vec3 w = flim_nodeProcess(vec3(g), b);
    c = mix(c, c * flim_pf, flim_ps);
    c *= x;
    c = flim_nodeProcess(c, b);
    c *= i;
    c = max(c, vec3(0.0));
    c /= max(w, vec3(0.0001));
    vec3 f = flim_nodeProcess(vec3(0.0), b);
    f /= max(w, vec3(0.0001));
    c = flim_unclip(c, flim_average(f) * 1000.0, 0.0);
    c = mix(c, c * flim_pff, flim_ffs);
    c = clamp(c, 0.0, 1.0);
    float m = flim_average(c);
    float mixFac = (m < 0.5) ? flim_satRange(m, 0.05, 0.5) : flim_satRange(m, 0.95, 0.5);
    c = mix(c, flim_balance(c, 0.5, flim_ms, 1.0), mixFac);
    return clamp(c, 0.0, 1.0);
}

vec3 agxDefaultContrastApprox(vec3 x)
{
    vec3 x2 = x * x;
    vec3 x4 = x2 * x2;
    return 15.5 * x4 * x2
         - 40.14 * x4 * x
         + 31.96 * x4
         - 6.868 * x2 * x
         + 0.4298 * x2
         + 0.1191 * x
         - 0.00232;
}

vec3 agx(vec3 val)
{
    const mat3 agx_mat = mat3(
        0.842479062253094,  0.0423282422610123, 0.0423756549057051,
        0.0784335999999992, 0.878468636469772,  0.0784336,
        0.0792237451477643, 0.0791661274605434, 0.879142973793104);
    const float min_ev = -12.47393;
    const float max_ev = 4.026069;
    val = max(agx_mat * max(val, vec3(0.000001)), vec3(0.000001));
    val = clamp(log2(val), min_ev, max_ev);
    val = (val - min_ev) / (max_ev - min_ev);
    return agxDefaultContrastApprox(val);
}

vec3 agxEotf(vec3 val)
{
    const mat3 agx_mat_inv = mat3(
         1.19687900512017,   -0.0528968517574562, -0.0529716355144438,
        -0.0980208811401368,  1.15190312990417,   -0.0980434501171241,
        -0.0990297440797205, -0.0989611768448433,  1.15107367264116);
    return agx_mat_inv * val;
}

vec3 agxLook(vec3 val)
{
    vec3 slope = vec3(1.0);
    vec3 power = vec3(1.35);
    float sat = 1.4;
    val = pow(max(val * slope, vec3(0.0)), power);
    float luma = dot(val, LuminanceWeights);
    return vec3(luma) + sat * (val - vec3(luma));
}

vec3 AGX(vec3 x)
{
    return agxEotf(agxLook(agx(x)));
}

vec3 ApplyToneMapping(vec3 color)
{
    color = max(color, vec3(0.0));
    switch (toneMappingMode)
    {
        case 0: return Linear(color);
        case 1: return Exponential(color);
        case 2: return Reinhard(color);
        case 3: return Uncharted2(color);
        case 4: return MGSV(color);
        case 5: return Uchimura(color);
        case 6: return Filmic(color);
        case 7: return ACES(color);
        case 8: return PBRNeutral(color);
        case 9: return Flim(color);
        case 10: return AGX(color);
    }
    return ACES(color);
}

vec3 ScreenSpaceGodRays()
{
    if (godRaysEnabled == 0)
        return vec3(0.0);

    int sampleCount = clamp(godRaySamples, 1, MAX_GOD_RAY_SAMPLES);
    vec2 lightVector = vertex_tex_coordinates - godRayLightPosition;
    vec2 aspect = vec2(max(viewportSize.x / max(viewportSize.y, 1.0), 0.0001), 1.0);
    float lightDistance = length(lightVector * aspect);
    float radialMask = 1.0 - smoothstep(1.05, 1.65, lightDistance);
    if (radialMask <= 0.0)
        return vec3(0.0);

    vec2 deltaTexCoord = lightVector * max(godRayDensity, 0.0) / float(sampleCount);
    vec2 texCoord = vertex_tex_coordinates;
    float illuminationDecay = 1.0;
    vec3 rays = vec3(0.0);

    for (int i = 0; i < MAX_GOD_RAY_SAMPLES; ++i)
    {
        if (i >= sampleCount)
            break;

        texCoord -= deltaTexCoord;
        if (any(lessThan(texCoord, vec2(0.0))) || any(greaterThan(texCoord, vec2(1.0))))
        {
            illuminationDecay *= godRayDecay;
            continue;
        }

        vec3 sampleColor = max(texture(sceneTexture, texCoord).rgb, vec3(0.0));
        float luminance = dot(sampleColor, LuminanceWeights);
        float sampleLightDistance = length((texCoord - godRayLightPosition) * aspect);
        float sunCore = 1.0 - smoothstep(0.0, 0.055, sampleLightDistance);
        float sunHalo = 1.0 - smoothstep(0.045, 0.46, sampleLightDistance);
        float atmosphere = 1.0 - smoothstep(0.18, 0.78, sampleLightDistance);
        float source = (sunCore * 2.4 + sunHalo * 0.95 + atmosphere * 0.22) *
            smoothstep(0.03, 0.75, luminance);
        source = min(source, 2.2);
        vec3 rayColor = mix(vec3(1.0, 0.88, 0.58), sampleColor, 0.12);
        rays += rayColor * source * illuminationDecay * max(godRayWeight, 0.0);
        illuminationDecay *= godRayDecay;
    }

    return rays * max(godRayExposure, 0.0) * max(godRayIntensity, 0.0) * radialMask * 1.35;
}

void main()
{
    vec3 hdrColor = max(texture(sceneTexture, vertex_tex_coordinates).rgb, vec3(0.0));
    hdrColor += ScreenSpaceGodRays();
    hdrColor *= max(exposure, 0.0);

    vec3 mappedColor = ApplyToneMapping(hdrColor);
    mappedColor = pow(max(mappedColor, vec3(0.0)),
        vec3(1.0 / max(outputGamma, 0.0001)));

    frag_color = vec4(clamp(mappedColor, 0.0, 1.0), 1.0);
}
