#include <metal_stdlib>
using namespace metal;

struct OpticsParameters {
    uint kind; // 0 film, 1 nacre, 2 grating, 3 crossed-polarizer phase, 4 Newton
    float ior;
    float sigma;
    float thicknessMax;
};

constant float hermiteX[5] = {-2.856970f, -1.355626f, 0, 1.355626f, 2.856970f};
constant float hermiteW[5] = {0.011257411f, 0.222075922f, 0.533333333f, 0.222075922f, 0.011257411f};

// All GPU film families have identical exterior/substrate media. This exact
// symmetric-slab form saves general complex Fresnel work on the common path.
// Phase, Fresnel denominators and 81-sample sums deliberately remain float.
inline float slab(float d, float lambda, float opticalCos, float2 rSquared) {
    if (d <= 0) return 0;
    float s = sin(2.0f * M_PI_F * d * opticalCos / lambda);
    float2 interference = 4.0f * rSquared * (s * s);
    float2 oneMinusR = 1.0f - rSquared;
    float2 reflected = interference / max(oneMinusR * oneMinusR + interference, 1e-20f);
    return 0.5f * (reflected.x + reflected.y);
}

inline float averagedSlab(float d, float lambda, float opticalCos, float2 rSquared, float sigma) {
    if (sigma == 0) return slab(d, lambda, opticalCos, rSquared);
    float reflected = 0;
    for (uint k = 0; k < 5; ++k)
        reflected += hermiteW[k] * slab(max(d + hermiteX[k] * sigma, 0.0f), lambda, opticalCos, rSquared);
    return reflected;
}

// Complex amplitudes for asymmetric / absorbing substrates and coherent stacks.
inline float2 cmul(float2 a, float2 b) { return float2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x); }
inline float2 cdiv(float2 a, float2 b) { return float2(dot(a,b),a.y*b.x-a.x*b.y)/max(dot(b,b),1e-20f); }
inline float2 csqrt(float2 a) {
    // A real dielectric must have exactly zero absorption. Fast length/sqrt
    // rounding can otherwise invent a tiny imaginary part in sqrt(n²-sin²θ).
    if (a.y == 0) return a.x >= 0 ? float2(sqrt(a.x),0) : float2(0,sqrt(-a.x));
    float l = length(a);
    return float2(sqrt(max(0.0f,(l+a.x)*0.5f)), (a.y<0?-1.0f:1.0f)*sqrt(max(0.0f,(l-a.x)*0.5f)));
}
struct PreparedStack {
    uint layers;
    float2 rs[7], rp[7], phase[6];
};
// Indices, refracted cosines and interface amplitudes do not depend on wavelength
// in these nondispersive models. Calculate them once per texel, outside the sum.
inline PreparedStack prepareStack(uint kind, float u, float design) {
    PreparedStack stack;
    stack.layers = kind >= 8 ? 6 : 1;
    float2 indices[8], q[8], admP[8];
    indices[0] = float2(1,0);
    if (kind >= 8) {
        for (uint i=1;i<=6;++i) indices[i]=float2(i%2==1?2.1f:1.45f,0);
        indices[7]=float2(1.52f,0);
    } else {
        indices[1]=float2(kind==5?1.47f:(kind==6?2.4f:1.38f),0);
        indices[2]=kind==6?float2(2.7f,3.3f):float2(kind==5?1.333f:1.52f,0);
    }
    for (uint i=0;i<=stack.layers+1;++i) {
        q[i]=i==0?float2(u,0):csqrt(cmul(indices[i],indices[i])-float2(1-u*u,0));
        admP[i]=cdiv(cmul(indices[i],indices[i]),q[i]);
    }
    for (uint i=0;i<=stack.layers;++i) {
        stack.rs[i]=cdiv(q[i]-q[i+1],q[i]+q[i+1]);
        stack.rp[i]=cdiv(admP[i]-admP[i+1],admP[i]+admP[i+1]);
        if (i<stack.layers) {
            float thickness=kind>=8?design/(4*indices[i+1].x):design;
            stack.phase[i]=q[i+1]*(4*M_PI_F*thickness);
        }
    }
    return stack;
}
inline float stackReflectance(thread const PreparedStack &stack, float lambda) {
    float2 rs=stack.rs[stack.layers], rp=stack.rp[stack.layers];
    for (int i=int(stack.layers)-1;i>=0;--i) {
        float2 phase=stack.phase[i]/lambda;
        float2 propagation=exp(-phase.y)*float2(cos(phase.x),sin(phase.x));
        float2 bs=cmul(rs,propagation), bp=cmul(rp,propagation);
        rs=cdiv(stack.rs[i]+bs,float2(1,0)+cmul(stack.rs[i],bs));
        rp=cdiv(stack.rp[i]+bp,float2(1,0)+cmul(stack.rp[i],bp));
    }
    return clamp((dot(rs,rs)+dot(rp,rp))*0.5f,0.0f,1.0f);
}

kernel void buildOpticsLUT(texture2d<half, access::write> output [[texture(0)]],
                           constant half4 *colorWeights [[buffer(0)]],
                           constant OpticsParameters &p [[buffer(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    uint width = output.get_width(), height = output.get_height();
    if (gid.x >= width || gid.y >= height) return;
    float u = (float(gid.x) + 0.5f) / float(width);
    float v = (float(gid.y) + 0.5f) / float(height);
    float opticalCos = 0;
    float2 rSquared = 0;
    if (p.kind == 0 || p.kind == 1) {
        float c2 = sqrt(1.0f - (1.0f - u * u) / (p.ior * p.ior));
        float2 a = float2(u, p.ior * u), b = float2(p.ior * c2, c2);
        float2 r = (a - b) / (a + b);
        rSquared = r * r;
        opticalCos = p.ior * c2;
    } else if (p.kind == 4) {
        // Snell through glass into the air gap: the air cosine is exactly the
        // external cosine. Avoid subtractive cancellation near critical incidence.
        const float glass = 1.52f;
        float cGlass = sqrt(1.0f - (1.0f - u * u) / (glass * glass));
        float2 a = float2(glass * cGlass, cGlass), b = float2(u, glass * u);
        float2 r = (a - b) / (a + b);
        rSquared = r * r;
        opticalCos = u;
    }

    float d = v * p.thicknessMax;
    float period = 1000000.0f / (300.0f + v * 1700.0f);
    float gratingCenter = period * abs(4.0f * u - 2.0f);
    float delta = u * 40.0f * M_PI_F;
    PreparedStack stack;
    if (p.kind >= 5) stack = prepareStack(p.kind, u, d + (p.kind >= 8 ? 400.0f : 0.0f));
    float3 rgb = 0;
    for (uint i = 0; i < 81; ++i) {
        float lambda = 380.0f + float(i) * 5.0f;
        float spectrum;
        if (p.kind >= 5) {
            float r = stackReflectance(stack, lambda);
            spectrum = p.kind == 9 ? 1 - r : r;
        } else if (p.kind == 2) {
            float2 dl = float2(lambda - gratingCenter, lambda - gratingCenter * 0.5f);
            const float sigma = 24.0f * 0.4246609f;
            float2 bands = exp(-dl * dl / (2.0f * sigma * sigma));
            spectrum = dot(bands, float2(0.8f, 0.2f));
        } else if (p.kind == 3) {
            float s = sin(delta * 550.0f / (2.0f * lambda));
            spectrum = s * s;
        } else if (p.kind == 1) {
            spectrum = (averagedSlab(d, lambda, opticalCos, rSquared, p.sigma)
                      + averagedSlab(d * 1.618f + 80.0f, lambda, opticalCos, rSquared, p.sigma)
                      + averagedSlab(d * 0.618f + 160.0f, lambda, opticalCos, rSquared, p.sigma)) / 3.0f;
        } else {
            spectrum = averagedSlab(d, lambda, opticalCos, rSquared, p.sigma);
        }
        rgb += float3(colorWeights[i].xyz) * spectrum;
    }
    if (p.kind == 1) rgb = mix(rgb, float3(dot(rgb, float3(0.2126f, 0.7152f, 0.0722f))), 0.45f);
    // Dichroic retains signed, unclipped RGB for exact linear R/T complement.
    // Only final color storage is half. MaterialX's V convention is opposite
    // to MTL row order, matching the CPU fallback's flipped blit upload.
    output.write(half4(half3(p.kind == 8 ? rgb : clamp(rgb, 0.0f, 4.0f)), half(1)), uint2(gid.x, height - 1 - gid.y));
}
