"""Author substrate replacement upstream of optical highlights and display gain.

Explicit body colors remain separate from reflection/scattering. For RGB-only
LUTs, min(R,G,B) approximates the neutral carrier; the chromatic residual stays
untinted. A saturation-gated floor supplies a substrate in black regions. This
is an appearance approximation, not an inversion of the original spectrum.

All edits are declarative and idempotent, including the older hand-authored
graphs. Generated nodes use the reserved Substrate prefix. No extra LUT fetches.
"""
from dataclasses import dataclass
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MATERIALS = ROOT / 'Packages/OpticsContent/Sources/OpticsContent/Materials'
BLOCK = re.compile(r'        def Shader "([^"]+)"[^{}]*\{[^{}]*\}', re.S)


@dataclass(frozen=True)
class Ref:
    name: str
    typ: str = 'color3f'
    port: str = 'out'


class Author:
    def __init__(self, path):
        self.path, self.name = path, path.stem
        self.text = BLOCK.sub(lambda m: '' if m[1].startswith('Substrate') or m[1] == 'BaseColorBlend' else m[0], path.read_text())
        self.blocks = []

    def line(self, name, value, typ=None):
        if isinstance(value, Ref):
            source = (f'/Root/{self.name}.inputs:{value.name[1:]}' if value.name.startswith('@')
                      else f'/Root/{self.name}/{value.name}.outputs:{value.port}')
            return f'            {value.typ} inputs:{name}.connect = <{source}>'
        typ = typ or ('color3f' if isinstance(value, tuple) else 'float')
        literal = '(' + ', '.join(map(str, value)) + ')' if isinstance(value, tuple) else str(value)
        return f'            {typ} inputs:{name} = {literal}'

    def node(self, name, kind, typ='color3f', **args):
        name = 'Substrate' + name
        lines = [f'        def Shader "{name}"', '        {', f'            uniform token info:id = "ND_{kind}"']
        lines += [self.line(key, value, typ if isinstance(value, tuple) else None) for key, value in args.items()]
        if typ == 'separate':
            lines += [f'            float outputs:out{c}' for c in 'rgb']
        else:
            lines.append(f'            {typ} outputs:out')
        lines.append('        }')
        self.blocks.append('\n'.join(lines))
        return Ref(name, typ)

    def op(self, name, op, a, b, typ='color3f'):
        suffix = {'color3f': 'color3', 'float': 'float'}[typ]
        if op in ['multiply', 'divide'] and typ == 'color3f' and (isinstance(b, (float, int)) or isinstance(b, Ref) and b.typ == 'float'):
            suffix += 'FA'
        return self.node(name, op + '_' + suffix, typ, in1=a, in2=b)

    def mix(self, name, a, b, amount=None):
        return self.node(name, 'mix_color3', bg=a, fg=b, mix=amount or Ref('@BaseAmount', 'float'))

    def hook(self, node, port, value):
        found = False
        def patch(m):
            nonlocal found
            if m[1] != node:
                return m[0]
            found = True
            body, count = re.subn(r'^[ \t]+\w+ inputs:' + re.escape(port) + r'(?:\.connect)? = [^\n]+', self.line(port, value), m[0], flags=re.M)
            assert count == 1, (self.name, node, port, count)
            return body
        self.text = BLOCK.sub(patch, self.text)
        assert found, (self.name, node)

    def channels(self, name, color):
        sep = self.node(name, 'separate3_color3', 'separate', **{'in': color})
        return [Ref(sep.name, 'float', 'out' + c) for c in 'rgb']

    def bounds(self, name, color):
        r, g, b = self.channels(name + 'Channels', color)
        low = self.op(name + 'Min', 'min', self.op(name + 'MinRG', 'min', r, g, 'float'), b, 'float')
        high = self.op(name + 'Max', 'max', self.op(name + 'MaxRG', 'max', r, g, 'float'), b, 'float')
        return low, high

    def body(self, node, port, original, level=1.):
        target = Ref('@BaseColor') if level == 1 else self.op('BodyLevel', 'multiply', Ref('@BaseColor'), level)
        self.hook(node, port, self.mix('BodyColor', original, target))

    def neutral(self, node, port, original, protect_highlights=False):
        # Work before Gain and before veins, skin shading, diffraction highlights,
        # pearl luster, etc. Colored low-energy fringes must not become white.
        positive = self.op('Positive', 'max', original, (0., 0., 0.))
        low, high = self.bounds('Neutral', positive)
        chroma = self.op('Chroma', 'subtract', high, low, 'float')
        saturation = self.op('Saturation', 'divide', chroma, self.op('SafeMax', 'max', high, .0001, 'float'), 'float')
        colored = self.node('ColoredMask', 'smoothstep_float', 'float', **{'in': saturation, 'low': .04, 'high': .4})
        mask = self.op('NeutralMask', 'subtract', 1., colored, 'float')
        floor = self.op('DarkBody', 'multiply', mask, .35, 'float')
        # Preserve the original neutral shading above the dark floor. Subtract
        # only achromatic energy; no hue rotation or multiplication of fringes.
        body = self.op('BodyLevel', 'max', low, floor, 'float')
        tinted = self.op('TintedBody', 'multiply', Ref('@BaseColor'), body)
        neutral = self.node('NeutralRGB', 'convert_float_color3', **{'in': low})
        delta = self.op('BodyDelta', 'subtract', tinted, neutral)
        amount = Ref('@BaseAmount', 'float')
        if protect_highlights:
            highlight = self.node('HighlightMask', 'smoothstep_float', 'float', **{'in': high, 'low': .4, 'high': 1.4})
            keep = self.op('BodyMask', 'subtract', 1., highlight, 'float')
            amount = self.op('Amount', 'multiply', amount, keep, 'float')
        adjusted = self.op('Replaced', 'add', original, self.op('WeightedDelta', 'multiply', delta, amount))
        self.hook(node, port, adjusted)

    def absorption(self):
        # BaseAbsorption = -log(max(BaseColor, 0.002)), evaluated on the CPU only
        # when the swatch changes. Retain relative spectral absorption and path.
        low, _ = self.bounds('Absorption', Ref('AbsorptionCoefficients'))
        neutral = self.node('AbsorptionNeutral', 'convert_float_color3', **{'in': low})
        chromatic = self.op('ChromaticAbsorption', 'subtract', Ref('AbsorptionCoefficients'), neutral)
        chosen = self.op('ChosenAbsorption', 'add', chromatic, Ref('@BaseAbsorption'))
        self.hook('NegativeOpticalDepth', 'in1', self.mix('Absorption', Ref('AbsorptionCoefficients'), chosen))
        if 'inputs:BaseAbsorption' not in self.text:
            self.text = self.text.replace('        color3f inputs:BaseColor', '        color3f inputs:BaseAbsorption = (0., 0., 0.)\n        color3f inputs:BaseColor', 1)
        # bounds() also authors max nodes; only the minimum is needed here.
        self.blocks = [b for b in self.blocks if not re.search(r'def Shader "SubstrateAbsorptionMax(?:RG)?"', b)]

    def write(self):
        # Intensity remains an independent effect control. A zero replacement
        # amount must restore the original output even with a swatch selected.
        terminal = {'DragonflyMaterial': 'WingColor', 'BirefringenceMaterial': 'ExtMul', 'HologramMaterial': 'LitColor'}.get(self.name, 'GainMul')
        self.hook('IntensityBlend', 'fg', Ref(terminal))
        self.hook('IntensityBlend', 'bg', self.mix('IntensityBase', (.2140411405,) * 3, Ref('@BaseColor')))
        self.text = re.sub(r'\n(?:[ \t]*\n){2,}', '\n\n', self.text)
        end = self.text.rfind('    }')
        self.text = self.text[:end].rstrip() + '\n\n' + '\n\n'.join(self.blocks) + '\n' + self.text[end:]
        self.path.write_text(self.text)


NEUTRAL_HOOKS = {
    'IridescentFilm': ('GainMul', 'FilmImage'), 'Morpho': ('GainMul', 'FilmImage'),
    'Nacre': ('GainMul', 'NacreImage'), 'Newton': ('GainMul', 'NewtonImage'),
    'Opal': ('GainMul', 'OpalImage'), 'Beetle': ('GainMul', 'RainbowMixNode'),
    'Birefringence': ('GainMul', 'PhaseImage'), 'Hologram': ('GainMul', 'HoloImage'),
    'Scarab': ('GainMul', 'PolMix'), 'LayeredFilm': ('GainMul', 'DisplayChannel'),
    'Feather': ('Base', 'FilmImage'), 'Chameleon': ('SkinMul', 'ChromaImage'),
    'Pearl': ('PlusTint', 'PearlImage'), 'Dragonfly': ('GainMul', 'WingImage'),
    'DiffractionGrating': ('Weighted', 'GratingImage'),
    'GemFire': ('GainMul', 'Fire'), 'Lenticular': ('GainMul', 'SelectedView'),
    'Moire': ('GainMul', 'BeatColor'),
    'Alexandrite': ('Absorption', 'IlluminantColor'),
    'Pleochroism': ('Final', 'Transmission'),
}
BODY_COLORS = {
    'Chatoyancy': Ref('@BodyTint'), 'Moonstone': (.24, .27, .33),
    'Labradorite': (.016, .025, .026), 'Sunstone': (.24, .055, .012),
    'Retroreflective': (.04, .045, .05),
}


def apply_all():
    for path in sorted(MATERIALS.glob('*.usda')):
        g = Author(path)
        name = path.stem.removesuffix('Material')
        if name in BODY_COLORS:
            g.body('Body', 'in1', BODY_COLORS[name])
        elif name in NEUTRAL_HOOKS:
            node, source = NEUTRAL_HOOKS[name]
            g.neutral(node, 'in1', Ref(source), protect_highlights=name == 'GemFire')
        elif name == 'AbsorbingGlass':
            g.absorption()
        elif name == 'Atmosphere':
            g.body('PlanetSurface', 'in1', (.012, .032, .065), .3)
        elif name == 'Rainbow':
            g.body('SkyAndRainbow', 'in2', (.009, .016, .028), .22)
        elif name == 'ParallaxNebula':
            g.body('Layer3Behind', 'in1', (.002, .004, .018), .2)
        elif name == 'LCD':
            # Replace the LCD backing. Dark segments and off-axis leakage remain.
            g.body('BaseMix', 'bg', Ref('OffColor'), .65)
        elif name == 'Speckle':
            # Sparkle is an explicit coverage mask; keep the original laser color.
            background = g.op('Backdrop', 'multiply', Ref('@BaseColor'), .35)
            covered = g.node('Coverage', 'clamp_float', 'float', **{'in': Ref('Sparkle', 'float'), 'low': 0., 'high': 1.})
            behind = g.op('Behind', 'subtract', 1., covered, 'float')
            weight = g.op('Amount', 'multiply', Ref('@BaseAmount', 'float'), behind, 'float')
            g.hook('GainMul', 'in1', g.op('Replaced', 'add', Ref('Beam'), g.op('Body', 'multiply', background, weight)))
        else:
            raise AssertionError('Missing base color policy: ' + name)
        g.write()
    print('Authored substrate replacement for 31 material graphs (no extra texture samples)')


if __name__ == '__main__':
    apply_all()
