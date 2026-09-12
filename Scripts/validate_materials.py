#!/usr/bin/env python3
"""Validate this project's authored USDA graph subset, without a USD installation.

Checks connections/types/cycles, lookup sampling, explicit direction spaces, and
UI defaults. Arithmetic probes execute the authored math; texture/noise/geometric
sources are bounded fixtures, NOT a replacement for RealityKit GPU validation.
Optional --stdlib validates node ports against official MaterialX stdlib_defs.mtlx.
"""
import argparse
import ast
import math
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MATERIALS = ROOT / 'Packages/OpticsContent/Sources/OpticsContent/Materials'
ALIASES = {'float2': 'vector2', 'float3': 'vector3', 'float4': 'vector4', 'color3f': 'color3', 'color4f': 'color4', 'asset': 'filename', 'int': 'integer', 'bool': 'boolean'}
NODE = re.compile(r'def Shader "([^"]+)"[^{}]*\{([^{}]*)\}', re.S)
PORT = re.compile(r'^\s*(?:uniform )?(\w+) (inputs|outputs):(\w+)(\.connect)?(?: = ([^\n]+))?', re.M)


def literal(value):
    value = value.removesuffix(' (').strip()
    return ast.literal_eval(value)


def ports(body):
    result = {}
    for m in PORT.finditer(body):
        typ, direction, name, connection, value = m.groups()
        if value is None:
            parsed = None
        elif connection:
            parsed = value.strip('<>')
        else:
            parsed = literal(value)
            # Honor authored sRGB literals before doing linear-light arithmetic.
            if isinstance(parsed, tuple) and re.match(r'\s*colorSpace = "srgb_texture"', body[m.end():]):
                parsed = tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in parsed)
        result[direction + ':' + name] = (ALIASES.get(typ, typ), bool(connection), parsed)
    return result


class Graph:
    def __init__(self, path):
        self.name = path.stem
        self.text = path.read_text()
        self.public = ports(self.text.split('def Shader', 1)[0])
        self.nodes = {name: (re.search(r'info:id = "([^"]+)"', body)[1], ports(body)) for name, body in NODE.findall(self.text)}
        assert len(self.nodes) == len(NODE.findall(self.text)), f'{self.name}: duplicate node names'

    def resolve(self, source):
        prim, port = source.rsplit('.', 1)
        assert prim.startswith('/Root/' + self.name), f'{self.name}: foreign connection {source}'
        name = prim.removeprefix('/Root/' + self.name).removeprefix('/')
        declared = self.nodes[name][1] if name else self.public
        assert port in declared, f'{self.name}: missing port {source}'
        return name, port, declared[port]

    def validate(self, definitions):
        visited, active = set(), set()
        def visit(name):
            assert name not in active, f'{self.name}: cycle through {name}'
            if name in visited:
                return
            active.add(name)
            kind, declared = self.nodes[name]
            for port, (typ, linked, value) in declared.items():
                if linked:
                    dependency, target, declaration = self.resolve(value)
                    assert typ == declaration[0], f'{self.name}/{name}.{port}: {typ} != {declaration[0]}'
                    if dependency:
                        visit(dependency)
                if definitions and not kind.startswith(('ND_realitykit_', 'Usd')):
                    assert kind in definitions, f'{self.name}: unknown MaterialX node {kind}'
                    expected = definitions[kind]
                    assert port in expected, f'{self.name}/{name}: unknown port {port}'
                    assert expected[port] == typ, f'{self.name}/{name}.{port}: authored {typ}, expected {expected[port]}'
            if kind == 'ND_image_color3':
                for axis in ['u', 'v']:
                    assert declared[f'inputs:{axis}addressmode'][2] == 'clamp', f'{self.name}/{name}: LUT wrapping'
            if kind in ['ND_normal_vector3', 'ND_tangent_vector3', 'ND_bitangent_vector3', 'ND_realitykit_viewdirection_vector3']:
                assert 'inputs:space' in declared, f'{self.name}/{name}: implicit coordinate space'
                expected = 'object' if self.name in ['SpeckleMaterial','ChatoyancyMaterial','MoonstoneMaterial','LabradoriteMaterial','SunstoneMaterial','AlexandriteMaterial','PleochroismMaterial','RetroreflectiveMaterial','LayeredFilmMaterial','GemFireMaterial','AbsorbingGlassMaterial','LenticularMaterial','MoireMaterial','ParallaxNebulaMaterial','RainbowMaterial','AtmosphereMaterial'] else 'world'
                assert declared['inputs:space'][2] == expected, f'{self.name}/{name}: mixed direction spaces'
            active.remove(name)
            visited.add(name)
        visit('Unlit')
        visit('DefaultSurfaceShader')
        assert visited == set(self.nodes), f'{self.name}: unused nodes {set(self.nodes) - visited}'
        return len(visited)

    def evaluate(self, target, parameters=None, fixtures=None):
        parameters, fixtures = parameters or {}, fixtures or {}
        cache = {}
        def each(fn, *values):
            count = next((len(v) for v in values if isinstance(v, tuple)), None)
            if count is None:
                return fn(*values)
            return tuple(fn(*(v[i] if isinstance(v, tuple) else v for v in values)) for i in range(count))
        def value(declaration):
            _, linked, val = declaration
            if not linked:
                return val
            name, port, declared = self.resolve(val)
            return output(name, port.split(':')[1]) if name else parameters.get(port.split(':')[1], value(declared))
        def output(name, port='out'):
            key = (name, port)
            if key in cache:
                return cache[key]
            kind, declared = self.nodes[name]
            args = {p[7:]: value(v) for p, v in declared.items() if p.startswith('inputs:')}
            op = kind.removeprefix('ND_').split('_')[0]
            if name in fixtures:
                out = fixtures[name]
            elif op == 'constant': out = args['value']
            elif op == 'texcoord': out = fixtures.get('uv', (0.3, 0.7))
            elif op == 'position': out = fixtures.get('position', (0.03, 0.07, 0.08))
            elif op in ['normal', 'tangent', 'bitangent']:
                out = {'normal': (0., 0., 1.), 'tangent': (1., 0., 0.), 'bitangent': (0., 1., 0.)}[op]
            elif kind == 'ND_realitykit_viewdirection_vector3': out = fixtures.get('view', (0.3, 0.4, 0.8660254))
            elif op == 'image':
                texture=fixtures.get('texture', (0.02, 0.25, 1.5))
                out=texture(args['texcoord']) if callable(texture) else texture
            elif op in ['cellnoise2d', 'cellnoise3d', 'worleynoise2d']: out = fixtures.get('noise', 0.5)
            elif op == 'fractal3d': out = (fixtures.get('fractal', 0.4),) * 3
            elif op == 'time': out = fixtures.get('time', 2.0)
            elif op in ['add', 'subtract', 'multiply', 'divide', 'min', 'max', 'power']:
                funcs = {'add': lambda a,b:a+b, 'subtract':lambda a,b:a-b, 'multiply':lambda a,b:a*b, 'divide':lambda a,b:a/b, 'min':min, 'max':max, 'power':pow}
                out = each(funcs[op], args['in1'], args['in2'])
            elif op in ['absval', 'sin', 'cos', 'exp', 'sqrt', 'floor', 'acos']:
                out = each({'absval':abs, 'sin':math.sin, 'cos':math.cos, 'exp':math.exp, 'sqrt':math.sqrt, 'floor':math.floor, 'acos':math.acos}[op], args['in'])
            elif op == 'atan2': out = math.atan2(args['iny'],args['inx'])
            elif op == 'clamp': out = each(lambda x,lo,hi:min(max(x,lo),hi), args['in'], args['low'], args['high'])
            elif op == 'ifgreater': out=args['in1'] if args['value1']>args['value2'] else args['in2']
            elif op == 'mix': out = each(lambda a,b,t:a*(1-t)+b*t, args['bg'], args['fg'], args['mix'])
            elif op == 'smoothstep':
                assert args['high'] > args['low'], f'{self.name}/{name}: invalid smoothstep domain'
                t = min(max((args['in'] - args['low']) / (args['high'] - args['low']), 0), 1)
                out = t*t*(3-2*t)
            elif op == 'dotproduct': out = sum(a*b for a,b in zip(args['in1'],args['in2']))
            elif op == 'crossproduct':
                a,b=args['in1'],args['in2'];out=(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
            elif op == 'normalize':
                length=math.sqrt(sum(x*x for x in args['in']));out=tuple(x/length for x in args['in'])
            elif op == 'transformvector': out=args['in'] # identity transform fixture
            elif op.startswith('combine'): out=tuple(args['in'+str(i)] for i in range(1,int(op[-1])+1))
            elif op.startswith('separate'):
                axes='rgba' if 'color' in kind else 'xyzw';out=args['in'][axes.index(port[-1])]
            elif op == 'convert':
                out=args['in']
                if kind == 'ND_convert_vector2_vector3': out=tuple(out)+(0.,)
                elif kind == 'ND_convert_float_color3': out=(out,)*3
            elif kind == 'ND_realitykit_unlit_surfaceshader': out=args['color']
            else: raise AssertionError(f'Unsupported arithmetic probe {kind}')
            assert all(math.isfinite(v) for v in (out if isinstance(out,tuple) else (out,))), f'{self.name}/{name}: nonfinite {out}'
            cache[key]=out
            return out
        return output(target)


def ui_defaults():
    source=(ROOT/'RealityOpticsShaderLab/AppModel.swift').read_text()
    defaults={name:float(number) for name,number in re.findall(r'var (\w+): Float = ([\d.]+)', source)}
    count=0
    for body in re.findall(r'SettingSpec\(id:(.*?)\}\)', source, re.S):
        bounds=re.search(r'range: ([\d.]+)\.\.\.([\d.]+)', body)
        prop=re.search(r'set:.*?self\?\.(\w+) = \$0',body,re.S)
        if not bounds or not prop: continue
        low,high=map(float,bounds.groups()); field=prop[1]
        assert low < high and low <= defaults[field] <= high, f'UI default {field}={defaults[field]} outside {low}...{high}'
        count+=1
    assert count >= 60, f'Only {count} settings parsed; check audit parser against AppModel'
    return count


def extended_controls(graphs):
    source = (ROOT/'RealityOpticsShaderLab/ExtendedEffectControls.swift').read_text()
    count = 0
    for effect, body in re.findall(r'case \.(\w+): return \[(.*?)\]', source, re.S):
        name = ('ChatoyancyMaterial' if effect in ['catEye','starGem'] else
                'LayeredFilmMaterial' if effect in ['oilFilm','titanium','lensCoating','dichroic'] else
                effect[0].upper()+effect[1:]+'Material')
        graph = graphs[name]
        controls = re.findall(r'\.init\(name: "(\w+)", label: "[^"]+", range: (-?[\d.]+)\.\.\.(-?[\d.]+), value: (-?[\d.]+)\)', body)
        assert controls, f'No controls parsed for {effect}'
        parameters = {}
        for key, low, high, default in controls:
            low,high,default = map(float,(low,high,default))
            assert low < high and low <= default <= high
            assert 'inputs:'+key in graph.public, f'{effect}: missing {key}'
            parameters[key] = default
            count += 1
        if effect == 'starGem': parameters['StarAmount']=1
        if effect in ['titanium','lensCoating','dichroic']: parameters['DomainMax']=300
        if effect == 'dichroic': parameters['DomainMin']=400
        for setting in ['default','minimum','maximum']:
            values=dict(parameters)
            if setting!='default':
                for key,low,high,_ in controls: values[key]=float(low if setting=='minimum' else high)
            for view in [(0.,0.,1.),(1.,0.,0.),(0.,0.,-1.)]:
                assert min(graph.evaluate('Unlit',values,{'view':view}))>=0
    # Phenomenon-level regressions: illumination vs direction must do different jobs.
    alex=graphs['AlexandriteMaterial']
    day=alex.evaluate('Unlit',{'Illuminant':0});warm=alex.evaluate('Unlit',{'Illuminant':1})
    assert day[1]>day[0] and warm[0]>warm[1], 'Alexandrite illumination endpoints lost'
    pleo=graphs['PleochroismMaterial']
    for vector,channel in [((1.,0.,0.),1),((0.,1.,0.),0),((0.,0.,1.),2)]:
        c=pleo.evaluate('Unlit',fixtures={'view':vector})
        assert c[channel]==max(c), 'Crystal axes lost their separate absorption spectra'
    retro=graphs['RetroreflectiveMaterial']
    assert retro.evaluate('Cone',fixtures={'Alignment':1})==1
    assert retro.evaluate('Cone',fixtures={'Alignment':0.7})<0.001
    chat=graphs['ChatoyancyMaterial']
    assert chat.evaluate('Band',{'StarAmount':0},{'ValidBand0':.1,'ValidBand1':.8,'ValidBand2':.3})==.1
    assert math.isclose(chat.evaluate('Band',{'StarAmount':1},{'ValidBand0':.1,'ValidBand1':.8,'ValidBand2':.3}),.8)
    # Opposite light/view cannot normalize a zero half-vector into NaN.
    for name in ['ChatoyancyMaterial','SunstoneMaterial','MoonstoneMaterial','LabradoriteMaterial','RetroreflectiveMaterial']:
        graphs[name].evaluate('Unlit',fixtures={'HalfSum':(0.,0.,0.)})
    # Back-lighting must leave only ambient body color, not an optical highlight.
    for name,node in [('ChatoyancyMaterial','Shine'),('SunstoneMaterial','Shine'),
                      ('MoonstoneMaterial','Glow'),('LabradoriteMaterial','DomainFlash'),
                      ('RetroreflectiveMaterial','Return')]:
        g=graphs[name]
        assert g.evaluate(node,fixtures={'NLRaw':-1})==0, f'{name}: back-light leaks into highlight'
        # View-facing orientation keeps the back of a two-sided sheet usable.
        assert g.evaluate('NL',fixtures={'view':(0.,0.,-1.),'ObjectLight':(0.,0.,-1.)})>0.99
    sunstone=graphs['SunstoneMaterial']
    assert sunstone.evaluate('Facet',fixtures={'Grain':0.1})==sunstone.evaluate('Facet',fixtures={'Grain':0.99}), 'Occupancy biases flake orientation'
    tilted=pleo.evaluate('Transmission',{'AxisTilt':90}, {'view':(0.,0.,1.)})
    assert tilted[0]==max(tilted), 'Third crystal axis cannot be reached from the controls'
    assert pleo.evaluate('FacingShade',fixtures={'NV':0.02}) < pleo.evaluate('FacingShade',fixtures={'NV':1})
    # Complement before clipping: a negative reflected RGB channel gives >white T.
    layer=graphs['LayeredFilmMaterial']
    assert len([k for k,_ in layer.nodes.values() if k=='ND_image_color3'])==1
    raw=(-0.1,0.2,1.2)
    for channel,expected in [(0,(0.,0.2,1.2)),(1,(1.1,0.8,0.))]:
        out=layer.evaluate('DisplayChannel',{'Transmission':channel},{'RawReflection':raw})
        assert all(math.isclose(a,b,abs_tol=1e-7) for a,b in zip(out,expected)), 'Complement clipped too early'
    # New angular behavior: avoid tests masked by a constant texture fixture.
    glass=graphs['AbsorbingGlassMaterial']
    assert all(math.isclose(c,1,abs_tol=1e-6) for c in glass.evaluate('Transmission',{'Thickness':0}))
    thin=glass.evaluate('Transmission',{'Thickness':0.3});thick=glass.evaluate('Transmission',{'Thickness':2})
    assert all(a>b for a,b in zip(thin,thick)), 'Absorption must increase with path length'
    moire=graphs['MoireMaterial']
    front={'view':(0.,0.,1.)};side={'view':(.6,0.,.8)}
    assert moire.evaluate('BeatColor',fixtures=front)!=moire.evaluate('BeatColor',fixtures=side)
    assert moire.evaluate('BeatColor',{'LayerGap':0},front)==moire.evaluate('BeatColor',{'LayerGap':0},side)
    lens=graphs['LenticularMaterial']
    assert lens.evaluate('ViewIndex',fixtures={'view':(-.8,0.,.6)})<lens.evaluate('ViewIndex',fixtures={'view':(.8,0.,.6)})
    # Exact Fresnel must vanish for index matching at EVERY incidence angle.
    for index in [1.,1.1,1.5,1.8]:
        for cosine in [0.,0.0001,0.01,0.2,0.7,1.]:
            sine=math.sqrt(1-cosine*cosine)
            fixture={'view':(sine,0.,cosine)}
            actual=glass.evaluate('Fresnel',{'Refraction':index},fixture)
            ct=math.sqrt(1-(sine/index)**2)
            expected=0 if index==1 else 0.5*(((cosine-index*ct)/(cosine+index*ct))**2+((index*cosine-ct)/(index*cosine+ct))**2)
            assert math.isclose(actual,expected,abs_tol=1e-8), 'Incorrect dielectric Fresnel'
            ray=glass.evaluate('GlassRay',{'Refraction':index},fixture)
            assert math.isclose(sum(c*c for c in ray),1,abs_tol=1e-8), 'Refraction lost unit length'
    # Rotation pivots at UV center even when the second layer is tilted.
    for rotation in [0,5,25]:
        params={'Rotation':rotation};fixture={'position':(0.,0.,0.)}
        assert math.isclose(moire.evaluate('RotatedU',params,fixture),.5)
        assert math.isclose(moire.evaluate('RotatedV',params,fixture),.5)
    # Compare the optimized two-fetch shader against the former four-fetch
    # cascade, especially integer indices and narrow transitions.
    palette=[(.9,.1,.2),(.1,.8,.3),(.2,.3,.9),(.8,.7,.1)]
    def atlas_color(uv): return palette[int(uv[0]*2)+2*int(uv[1]*2)]
    for width in [.05,.22,.9]:
        for step in range(301):
            view=step/100
            expected=palette[0]
            for i in range(1,4):
                t=min(1,max(0,(view-(i-.5-width*.5))/width));t=t*t*(3-2*t)
                expected=tuple(a*(1-t)+b*t for a,b in zip(expected,palette[i]))
            actual=lens.evaluate('SelectedView',{'BlendWidth':width},{'LensView':view,'texture':atlas_color})
            assert all(math.isclose(a,b,abs_tol=1e-8) for a,b in zip(actual,expected)), 'Two-fetch selection changed the view blend'
    assert sum(kind=='ND_image_color3' for kind,_ in lens.nodes.values())==2
    # Every atlas sample stays within its tile, including extreme grazing views.
    for name in ['LenticularMaterial','ParallaxNebulaMaterial']:
        graph=graphs[name]
        for view in [(0.,0.,1.),(1.,0.,0.),(0.,1.,0.),(0.,0.,-1.)]:
            for node,(kind,_) in graph.nodes.items():
                if kind=='ND_image_color3':
                    coords=graph.evaluate(node+'UV',fixtures={'view':view})
                    assert all(0<c<1 for c in coords), 'Atlas sample escaped its padded domain'
    nebula=graphs['ParallaxNebulaMaterial']
    assert nebula.evaluate('Layer3EdgeMask',fixtures={'view':(1.,0.,0.)}) == 0, 'Oblique atlas edge stretched instead of fading'
    return count


def substrate_regressions(graphs):
    """Behavioral probes: body replacement must not erase optical information."""
    colors = [(0.,)*3, (1.,)*3, (.18,)*3, (1.,0.,0.), (0.,1.,0.), (0.,0.,1.)]
    for graph in graphs.values():
        assert 'BaseColorBlend' not in graph.nodes, f'{graph.name}: final-color overlay remains'
        assert all(kind != 'ND_image_color3' for name,(kind,_) in graph.nodes.items() if name.startswith('Substrate'))
        for intensity in [0, 1, 2]:
            original = graph.evaluate('Unlit', {'Intensity':intensity})
            for base in colors:
                params = {'BaseColor':base, 'BaseAmount':0, 'Intensity':intensity}
                restored = graph.evaluate('Unlit', params)
                assert all(math.isclose(a,b,abs_tol=1e-7) for a,b in zip(original,restored)), f'{graph.name}: 0% did not restore original'
                for amount in [.35, 1]:
                    params['BaseAmount'] = amount
                    params['BaseAbsorption'] = tuple(-math.log(max(c,.002)) for c in base)
                    for view in [(0.,0.,1.),(1.,0.,0.),(0.,0.,-1.)]:
                        assert min(graph.evaluate('Unlit',params,{'view':view})) >= 0
        if 'SubstrateReplaced' in graph.nodes and 'SubstrateNeutralChannels' in graph.nodes:
            # Dim saturated fringes must survive even on the white substrate.
            source, _, _ = graph.resolve(graph.nodes['SubstratePositive'][1]['inputs:in1'][2])
            for fringe in [(0.,0.,.03),(.01,.04,.2),(.9,.2,.01)]:
                actual = graph.evaluate('SubstrateReplaced', {'BaseColor':(1.,)*3,'BaseAmount':1}, {source:fringe})
                assert all(math.isclose(a,b,abs_tol=1e-7) for a,b in zip(actual,fringe)), f'{graph.name}: white washed out a colored fringe'
            if graph.name != 'GemFireMaterial':
                red = graph.evaluate('SubstrateReplaced', {'BaseColor':(1.,0.,0.),'BaseAmount':1}, {source:(.5,)*3})
                black = graph.evaluate('SubstrateReplaced', {'BaseColor':(0.,)*3,'BaseAmount':1}, {source:(.5,)*3})
                assert red == (.5,0.,0.) and black == (0.,)*3, f'{graph.name}: white carrier not replaced'

    # Verify actual compositing, not just isolated masks: preserve the complete
    # optical contribution at 100% replacement, including white highlights.
    for name, optical, body in [('Chatoyancy','BandColor','Body'),('Moonstone','CloudGlow','Body'),
                                ('Labradorite','FlashColor','Body'),('Sunstone','SparkleColor','Body'),
                                ('Retroreflective','ReturnColor','Body'),('Atmosphere','ScatteredLight','PlanetSurface')]:
        g = graphs[name+'Material']
        for base in colors:
            params = {'BaseAmount':1,'BaseColor':base,'Gain':.5}
            off = g.evaluate('Unlit',params,{optical:(0.,)*3})
            on = g.evaluate('Unlit',params,{optical:(.2,.4,.6)})
            assert all(math.isclose(b-a,c,abs_tol=1e-7) for a,b,c in zip(off,on,(.1,.2,.3))), f'{name}: optical highlight faded with base'
    pearl=graphs['PearlMaterial']
    for base in colors:
        params={'BaseAmount':1,'BaseColor':base,'Gain':1}
        off=pearl.evaluate('Unlit',params,{'HotTerm':(0.,)*3})
        on=pearl.evaluate('Unlit',params,{'HotTerm':(.2,)*3})
        assert all(math.isclose(b-a,.2,abs_tol=1e-7) for a,b in zip(off,on)), 'Pearl highlight was recolored'
    glass=graphs['AbsorbingGlassMaterial']
    for base in colors:
        params={'BaseAmount':1,'BaseColor':base,'BaseAbsorption':tuple(-math.log(max(c,.002)) for c in base)}
        clear=glass.evaluate('Transmission',dict(params,Thickness=0))
        thin=glass.evaluate('Transmission',dict(params,Thickness=.2))
        thick=glass.evaluate('Transmission',dict(params,Thickness=2))
        assert clear==(1.,)*3 and all(a>=b for a,b in zip(thin,thick)), 'Glass base broke path-dependent absorption'
        reflection=glass.evaluate('Glass',params,{'Fresnel':1,'SurfaceReflection':(.3,.5,.7)})
        assert reflection==(.3,.5,.7), 'Glass tint affected surface reflection'
    # Changing the far backing must still pass through all cloud layers.
    nebula=graphs['ParallaxNebulaMaterial']
    params={'BaseAmount':1,'Gain':1}
    transmission=math.prod(nebula.evaluate(f'Layer{i}Transmission',params) for i in range(4))
    black=nebula.evaluate('Unlit',dict(params,BaseColor=(0.,)*3))
    white=nebula.evaluate('Unlit',dict(params,BaseColor=(1.,)*3))
    assert all(math.isclose(b-a,.2*transmission,abs_tol=1e-7) for a,b in zip(black,white)), 'Nebula backing bypassed depth occlusion'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stdlib',type=Path)
    args=parser.parse_args()
    definitions={}
    if args.stdlib:
        definitions={n.attrib['name']:{p.tag+':'+p.attrib['name']:p.attrib['type'] for p in n if p.tag in ['input','output']} for n in ET.parse(args.stdlib).getroot().findall('nodedef')}
        definitions={k:{p.replace('input:','inputs:').replace('output:','outputs:'):t for p,t in v.items()} for k,v in definitions.items()}
    graphs={p.stem:Graph(p) for p in sorted(MATERIALS.glob('*.usda'))}
    assert len(graphs)==31
    total=0
    for graph in graphs.values():
        total+=graph.validate(definitions)
        for uv in [(0.,0.),(.5,.5),(1.,1.)]:
            for view in [(0.,0.,1.),(0.,0.,-1.),(0.,1.,0.),(1.,0.,0.)]:
                for intensity in [0,1,2]:
                    color=graph.evaluate('Unlit',{'Intensity':intensity},{'uv':uv,'view':view})
                    assert min(color)>=0, f'{graph.name}: negative radiance'
        print(f'PASS {graph.name}: {len(graph.nodes)} nodes')
    substrate_regressions(graphs)
    speckle=graphs['SpeckleMaterial']
    assert all(kind != 'ND_texcoord_vector2' for kind, _ in speckle.nodes.values())
    assert speckle.nodes['Position'][1]['inputs:space'][2] == 'object'
    for threshold in [0.4, 0.95, 0.98]:
        assert speckle.evaluate('Sparkle', {'Threshold':threshold}, {'GrainRand':0.99999}) > 0.99
    lcd=graphs['LCDMaterial']
    for cell in [0,0.2,0.8,0.99999]:
        assert lcd.evaluate('SegOn',{'Voltage':0},{'CellRand':cell})==0
        assert lcd.evaluate('SegOn',{'Voltage':1},{'CellRand':cell})==1
    wing=graphs['DragonflyMaterial']
    for width in [0.03,0.09,0.2]:
        assert wing.evaluate('CrossMask',{'VeinWidth':width},{'FxTAbs':0})==1
        assert wing.evaluate('CrossMask',{'VeinWidth':width},{'FxTAbs':width})==0
    for x in [-3.2,-0.1,0,0.9,2.3]:
        out=graphs['HologramMaterial'].evaluate('URow',fixtures={'UPlusRow':x})
        assert 0<=out<1
    phase=graphs['BirefringenceMaterial']
    assert math.isclose(phase.evaluate('PhaseU',fixtures={'PhaseView':5}),0.25)
    assert phase.evaluate('Extinction',fixtures={'Sin2aSq':0})==0
    for graph in ['DiffractionGratingMaterial','OpalMaterial','BeetleMaterial']:
        assert graphs[graph].evaluate('Radial',fixtures={'GrooveAxis':(0.,0.,0.)})==(0.,0.,0.)
    assert graphs['DiffractionGratingMaterial'].evaluate('Delta',fixtures={'LoP':0.4,'VoP':-0.4})==0
    print(f'PASS {len(graphs)} material files / {total} nodes; {ui_defaults() + extended_controls(graphs)} UI defaults; direction, range, base-color and arithmetic regressions')

if __name__=='__main__':
    main()
