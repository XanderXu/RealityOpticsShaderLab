#!/usr/bin/env python3
"""Author the additional MaterialX graphs and their matching Swift controls.
Run after changing a graph/control; generated USDA remains directly inspectable.
All colors are linear. Geometric lobes are deliberate appearance approximations.
"""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'Packages/OpticsContent/Sources/OpticsContent/Materials'
# name, Chinese label, minimum, maximum, default. Units are shown in the UI.
LIGHT = [('LightAngle','光源方位（°）',-90,90,18)]
GAIN = [('Gain','亮度',0.2,3,1)]
CONTROLS = {
 'catEye': [('Sharpness','亮带锐度',12,180,70),('AxisAngle','纤维方向（°）',0,180,0)]+LIGHT+GAIN,
 'starGem': [('Sharpness','星芒锐度',12,180,90),('AxisAngle','星芒方向（°）',0,180,0)]+LIGHT+GAIN,
 'moonstone': [('Softness','柔光集中度',1,12,3),('Depth','内部层次',0,1,0.55)]+LIGHT+GAIN,
 'labradorite': [('Spacing','等效层厚（nm）',100,550,190),('DomainScale','晶域尺度',2,18,6),('Sharpness','闪光集中度',2,50,12)]+LIGHT+GAIN,
 'sunstone': [('GrainScale','包裹体密度',20,120,55),('Threshold','闪点稀疏度',0.5,0.95,0.83),('Sharpness','闪点锐度',8,100,35)]+LIGHT+GAIN,
 'alexandrite': [('Illuminant','参考照明：日光 → 暖光',0,1,0),('PathLength','吸收光程',0.3,3,1)]+GAIN,
 'pleochroism': [('PathLength','吸收光程',0.3,3,1),('AxisAngle','晶轴方向（°）',0,180,0),('AxisTilt','晶轴倾角（°）',0,90,0)]+GAIN,
 'retroreflective': [('LightAngle','光源偏离视线基准（°）',-60,60,0),('Sharpness','回归光束集中度',20,500,160)]+GAIN,
 'oilFilm': [('Thickness','平均膜厚（nm）',0,1000,380),('Variation','膜厚变化（nm）',0,400,180)]+GAIN,
 'titanium': [('Thickness','氧化层厚度（nm）',0,300,75),('Variation','厚度变化（nm）',0,100,12)]+GAIN,
 'lensCoating': [('Thickness','MgF₂ 厚度（nm）',0,300,100),('Variation','厚度变化（nm）',0,100,0),('Gain','反射显示增益',1,15,6)],
 'dichroic': [('Thickness','设计中心波长（nm）',400,700,540),('Variation','中心波长变化（nm）',0,100,0),('Transmission','显示通道：反射 → 透射',0,1,0)]+GAIN,
}
from spatial_effects import CONTROLS as SPATIAL_CONTROLS, build as build_spatial
CONTROLS.update(SPATIAL_CONTROLS)

class Ref:
 def __init__(self,n,typ='float',port='out'): self.n,self.typ,self.port=n,typ,port
class Graph:
 def __init__(self,name,params): self.name,self.params,self.nodes=name,dict(params),{}
 def p(self,name): return Ref('@'+name,self.params[name][0])
 def node(self,name,kind,typ='float',**args):
  self.nodes[name]=(kind,typ,args);return Ref(name,typ)
 def unary(self,name,op,a,typ='float'): return self.node(name,'ND_'+op+'_'+{'float3':'vector3','color3f':'color3'}.get(typ,typ),typ,**{'in':a})
 def op(self,name,op,a,b,typ='float'):
  suffix={'float3':'vector3','color3f':'color3'}.get(typ,typ)
  if op in ['multiply','divide'] and typ!='float' and (isinstance(b,(float,int)) or isinstance(b,Ref) and b.typ=='float'):suffix+='FA'
  return self.node(name,'ND_'+op+'_'+suffix,typ,in1=a,in2=b)
 def mix(self,name,a,b,t):return self.node(name,'ND_mix_color3','color3f',bg=a,fg=b,mix=t)
 def dot(self,name,a,b):return self.node(name,'ND_dotproduct_vector3',in1=a,in2=b)
 def clamp(self,name,a,low=0,high=1):return self.node(name,'ND_clamp_float',**{'in':a,'low':low,'high':high})
 def smooth(self,name,a,lo,hi):return self.node(name,'ND_smoothstep_float',**{'in':a,'low':lo,'high':hi})
 def norm(self,name,a):
  length=self.unary(name+'Length','sqrt',self.op(name+'Safe','max',self.dot(name+'Sq',a,a),0.000001))
  return self.op(name,'divide',a,length,'float3')
 def vec(self,name,x,y,z):return self.node(name,'ND_combine3_vector3','float3',in1=x,in2=y,in3=z)
 def noise(self,name,pos):return self.node(name,'ND_cellnoise3d_float',position=pos)
 def image(self,name,key,u,v):
  uv=self.node(name+'UV','ND_combine2_vector2','float2',in1=u,in2=v)
  return self.node(name,'ND_image_color3','color3f',file=self.p(key),texcoord=uv,default=(0,0,0),uaddressmode='clamp',vaddressmode='clamp')
 def finish(self,color):
  gain=self.op('GainMul','multiply',color,self.p('Gain'),'color3f')
  # base_color.apply_all inserts family-specific substrate hooks before gain.
  intensity=self.mix('IntensityBlend',(.2140411405,)*3,gain,self.p('Intensity'))
  clamp=self.op('IntensityClamp','max',intensity,(0,0,0),'color3f')
  self.node('Unlit','ND_realitykit_unlit_surfaceshader','token',color=clamp,opacity=1.0,applyPostProcessToneMap=False)
  self.node('DefaultSurfaceShader','UsdPreviewSurface','token',diffuseColor=(1,1,1),roughness=0.75)
  used=set()
  def visit(n):
   if n in used:return
   used.add(n)
   for v in self.nodes[n][2].values():
    if isinstance(v,Ref) and not v.n.startswith('@'):visit(v.n)
  visit('Unlit');visit('DefaultSurfaceShader')
  def fmt(v):
   if isinstance(v,bool):return str(int(v))
   if isinstance(v,str):return json.dumps(v)
   if isinstance(v,tuple):return '('+', '.join(map(str,v))+')'
   return str(v)
  def ref(v):return f'</Root/{self.name}.inputs:{v.n[1:]}>' if v.n.startswith('@') else f'</Root/{self.name}/{v.n}.outputs:{v.port}>'
  lines=['#usda 1.0','(defaultPrim = "Root")','def Xform "Root"','{',f'    def Material "{self.name}"','    {']
  for k,(typ,val) in self.params.items():lines.append(f'        {typ} inputs:{k}'+('' if val is None else ' = '+fmt(val)))
  lines += [f'        token outputs:mtlx:surface.connect = </Root/{self.name}/Unlit.outputs:out>', '        token outputs:realitykit:vertex',f'        token outputs:surface.connect = </Root/{self.name}/DefaultSurfaceShader.outputs:surface>']
  for n,(kind,typ,args) in self.nodes.items():
   if n not in used:continue
   lines.extend(['',f'        def Shader "{n}"'+(' (active = false)' if n=='DefaultSurfaceShader' else ''),'        {',f'            uniform token info:id = "{kind}"'])
   for k,v in args.items():
    porttype=v.typ if isinstance(v,Ref) else ('bool' if isinstance(v,bool) else 'string' if isinstance(v,str) else 'float3' if isinstance(v,tuple) else 'float')
    if k in ['default','color','diffuseColor'] or isinstance(v,tuple) and typ=='color3f':porttype='color3f'
    lines.append(f'            {porttype} inputs:{k}'+('.connect = '+ref(v) if isinstance(v,Ref) else ' = '+fmt(v)))
   lines.extend([f'            {typ} outputs:'+('surface' if n=='DefaultSurfaceShader' else 'out'),'        }'])
  lines.extend(['    }','}'])
  (OUT/(self.name+'.usda')).write_text('\n'.join(lines)+'\n')

def create(effect,name,extras=None):
 params={n:('float',d) for n,l,lo,hi,d in CONTROLS[effect]}
 params.update({'Gain':('float',params.get('Gain',('float',1))[1]),'Intensity':('float',1),'BaseColor':('color3f',(.2140411405,)*3),'BaseAmount':('float',0)})
 params.update(extras or {})
 return Graph(name,params)

def geometry(g):
 n=g.norm('Normal',g.node('NormalSource','ND_normal_vector3','float3',space='object'))
 v=g.norm('View',g.node('ViewSource','ND_realitykit_viewdirection_vector3','float3',space='object'))
 p=g.node('Position','ND_position_vector3','float3',space='object')
 p=g.op('UnitPosition','divide',p,0.12,'float3')
 nv=g.clamp('NV',g.unary('AbsNV','absval',g.dot('NdotV',n,v)),.002,1)
 return n,v,p,nv

def lighting(g,n,v):
 # Face the sheet toward the observer; only light in that hemisphere reflects.
 side=g.node('FaceSign','ND_ifgreater_float',value1=Ref('NdotV'),value2=0.,in1=1.,in2=-1.)
 n=g.op('FacingNormal','multiply',n,side,'float3')
 a=g.op('LightRadians','multiply',g.p('LightAngle'),0.01745329252)
 light=g.vec('WorldLight',g.unary('LightX','sin',a),0.,g.unary('LightZ','cos',a))
 light=g.norm('Light',g.node('ObjectLight','ND_transformvector_vector3','float3',**{'in':light,'fromspace':'world','tospace':'object'}))
 h=g.norm('Half',g.op('HalfSum','add',light,v,'float3'))
 nl=g.clamp('NL',g.dot('NLRaw',n,light))
 nh=g.clamp('NH',g.dot('NHRaw',n,h))
 return light,h,nl,nh,n

def gem_base(g,nv,color):
 shade=g.op('BodyShade','add',g.op('BodyFacing','multiply',nv,.55),.25)
 return g.op('Body','multiply',color,shade,'color3f')

g=create('catEye','ChatoyancyMaterial',{'StarAmount':('float',0),'BodyTint':('color3f',(.16,.07,.018)),'ShineTint':('color3f',(1.,.83,.38))})
n,v,p,nv=geometry(g);light,h,nl,nh,n=lighting(g,n,v)
a=g.op('AxisRadians','multiply',g.p('AxisAngle'),.01745329252)
lobes=[]
delta=g.op('NormalOffset','subtract',n,h,'float3')
for i in range(3):
 angle=g.op(f'Axis{i}Angle','add',a,i*1.0471975512)
 axis=g.vec(f'Axis{i}',g.unary(f'Cos{i}','cos',angle),g.unary(f'Sin{i}','sin',angle),0.)
 # An anisotropic angular lobe around N=H, with the inclusion direction
 # fixed in the crystal. A normal-space offset gives a narrow moving band.
 dot=g.dot(f'FiberDot{i}',delta,axis)
 lobe=g.op(f'ValidBand{i}','power',g.clamp(f'BandBase{i}',g.op(f'BandInverse{i}','subtract',1.,g.op(f'BandSquare{i}','multiply',dot,dot))),g.p('Sharpness'))
 lobes.append(lobe)
star=g.op('Star','max',g.op('Cross','max',lobes[0],lobes[1]),lobes[2])
# Scalar mix uses explicit arithmetic to keep one branch at cat-eye mode.
band=g.op('Band','add',lobes[0],g.op('StarExtra','multiply',g.op('Extra','subtract',star,lobes[0]),g.p('StarAmount')))
shine=g.op('Shine','multiply',g.op('LitBand','multiply',band,nl),1.6)
color=g.op('Final','add',gem_base(g,nv,g.p('BodyTint')),g.op('BandColor','multiply',g.p('ShineTint'),shine,'color3f'),'color3f');g.finish(color)

g=create('moonstone','MoonstoneMaterial');n,v,p,nv=geometry(g);light,h,nl,nh,n=lighting(g,n,v)
shift=g.op('Parallax','add',p,g.op('DepthShift','multiply',v,g.p('Depth'),'float3'),'float3')
noise=g.node('Clouds','ND_fractal3d_color3','color3f',position=shift,amplitude=(.5,.5,.5),octaves=3)
# Correct node signature: amplitude is a vector, octaves integer.
cloud=g.mix('CloudTint',(.04,.1,.25),noise,.2)
glow=g.op('Glow','multiply',g.op('GlowLobe','power',nh,g.p('Softness')),nl)
color=g.op('Final','add',gem_base(g,nv,(.24,.27,.33)),g.op('CloudGlow','multiply',g.op('BlueCloud','add',cloud,(.08,.25,.65),'color3f'),glow,'color3f'),'color3f');g.finish(color)

g=create('labradorite','LabradoriteMaterial',{'FilmLUT':('asset',None)});n,v,p,nv=geometry(g);light,h,nl,nh,n=lighting(g,n,v)
pos=g.op('DomainPosition','multiply',p,g.p('DomainScale'),'float3')
field=g.node('DomainField','ND_fractal3d_color3','color3f',position=pos,amplitude=(.5,.5,.5),octaves=2)
g.nodes['DomainSeparate']=('ND_separate3_color3','MULTI',{'in':field})
rand=g.clamp('Domain',g.op('DomainBias','add',Ref('DomainSeparate','float','outr'),.5))
thick=g.op('LayerThickness','divide',g.op('ThicknessNoise','add',g.p('Spacing'),g.op('LayerVariation','multiply',rand,45.)),1200.)
film=g.image('Film','FilmLUT',nv,thick)
flash=g.op('Flash','power',nh,g.p('Sharpness'))
flash=g.op('DomainFlash','multiply',g.op('LitFlash','multiply',flash,nl),g.smooth('DomainMask',rand,.12,.75))
color=g.op('Final','add',gem_base(g,nv,(.016,.025,.026)),g.op('FlashColor','multiply',film,g.op('FlashGain','multiply',flash,4.),'color3f'),'color3f');g.finish(color)

g=create('sunstone','SunstoneMaterial');n,v,p,nv=geometry(g);light,h,nl,nh,n=lighting(g,n,v)
pos=g.op('GrainPosition','multiply',p,g.p('GrainScale'),'float3');r=g.noise('Grain',pos)
r2=g.noise('Grain2',g.op('Offset2','add',pos,(13.,7.,19.),'float3'));r3=g.noise('Grain3',g.op('Offset3','add',pos,(31.,41.,11.),'float3'))
# Occupancy and orientation must be independent; thresholding r must not
# preferentially select flakes pointing toward +X. A fourth cheap hash suffices.
r4=g.noise('FacetXRandom',g.op('Offset4','add',pos,(17.,53.,29.),'float3'))
facet=g.norm('Facet',g.op('FacetBias','subtract',g.vec('FacetRandom',r4,r2,r3),(.5,.5,.0),'float3'))
facing=g.clamp('FacetFacing',g.unary('FacetAbs','absval',g.dot('FacetHalf',facet,h)))
flash=g.op('Flash','power',facing,g.p('Sharpness'))
mask=g.smooth('GrainMask',r,g.p('Threshold'),.995)
shine=g.op('Shine','multiply',g.op('LitSparkles','multiply',g.op('Sparkles','multiply',flash,mask),nl),8.)
color=g.op('Final','add',gem_base(g,nv,(.24,.055,.012)),g.op('SparkleColor','multiply',(1.,.49,.12),shine,'color3f'),'color3f');g.finish(color)

g=create('alexandrite','AlexandriteMaterial');n,v,p,nv=geometry(g)
trans=g.mix('IlluminantColor',(.055,.38,.16),(.46,.035,.15),g.p('Illuminant'))
# RGB Beer-Lambert: T(path)=T(1)^path; colors deliberately representative.
trans=g.op('Absorption','power',trans,g.node('PathRGB','ND_convert_float_color3','color3f',**{'in':g.p('PathLength')}),'color3f')
g.finish(g.op('Final','multiply',trans,g.op('FacingShade','add',.35,g.op('Facing','multiply',nv,.65)),'color3f'))

g=create('pleochroism','PleochroismMaterial');n,v,p,nv=geometry(g)
a=g.op('AxisRadians','multiply',g.p('AxisAngle'),.01745329252)
ca=g.unary('CosAxis','cos',a);sa=g.unary('SinAxis','sin',a)
tilt=g.op('TiltRadians','multiply',g.p('AxisTilt'),.01745329252)
ct=g.unary('CosTilt','cos',tilt);st=g.unary('SinTilt','sin',tilt)
x=g.vec('CrystalX',ca,0.,sa)
y=g.vec('CrystalY',g.op('TiltX','multiply',g.op('NegativeSin','multiply',sa,-1.),st),ct,g.op('TiltZ','multiply',ca,st))
z=g.node('CrystalZ','ND_crossproduct_vector3','float3',in1=x,in2=y)
colors=[]
for i,(axis,tint) in enumerate([(x,(2.2,.35,1.4)),(y,(.35,1.9,1.1)),(z,(1.8,1.2,.22))]):
 d=g.dot(f'AxisView{i}',axis,v);weight=g.op(f'AxisWeight{i}','multiply',d,d)
 colors.append(g.op(f'Absorb{i}','multiply',tint,weight,'color3f'))
sigma=g.op('Sigma','add',g.op('SigmaXY','add',colors[0],colors[1],'color3f'),colors[2],'color3f')
neg=g.op('OpticalDepth','multiply',sigma,g.op('NegativePath','multiply',g.p('PathLength'),-1.),'color3f')
depth=g.node('DepthVector','ND_convert_color3_vector3','float3',**{'in':neg})
trans=g.node('Transmission','ND_convert_vector3_color3','color3f',**{'in':g.unary('Attenuation','exp',depth,'float3')})
# Display shading restores curvature cues without changing the axis spectra.
g.finish(g.op('Final','multiply',trans,g.op('FacingShade','add',.35,g.op('Facing','multiply',nv,.65)),'color3f'))

g=create('retroreflective','RetroreflectiveMaterial');n,v,p,nv=geometry(g);light,h,nl,nh,n=lighting(g,n,v)
dot=g.clamp('Alignment',g.dot('LightView',light,v))
cone=g.op('Cone','power',dot,g.p('Sharpness'))
color=g.op('Final','add',gem_base(g,nv,(.04,.045,.05)),g.op('ReturnColor','multiply',(.85,.94,1.),g.op('ReturnGain','multiply',g.op('Return','multiply',cone,nl),3.),'color3f'),'color3f');g.finish(color)

g=create('oilFilm','LayeredFilmMaterial',{'FilmLUT':('asset',None),'IlluminantWhite':('color3f',(1.,1.,1.)),'Transmission':('float',0),'DomainMax':('float',1000),'DomainMin':('float',0)})
n,v,p,nv=geometry(g)
noise=g.node('FlowNoise','ND_fractal3d_color3','color3f',position=g.op('FlowScale','multiply',p,2.5,'float3'),amplitude=(.5,.5,.5),octaves=3)
r=Ref('FlowSeparate','float','outr');g.nodes['FlowSeparate']=('ND_separate3_color3','MULTI',{'in':noise})
variation=g.op('Variation','multiply',r,g.p('Variation'))
thick=g.op('LocalThickness','add',g.p('Thickness'),variation)
u=g.clamp('ThicknessCoordinate',g.op('DomainScale','divide',g.op('DomainOffset','subtract',thick,g.p('DomainMin')),g.p('DomainMax')))
raw=g.image('RawReflection','FilmLUT',nv,u)
# Linear spectral integration: RGB(T) = RGB(white) - RGB(R). Keep signed
# out-of-gamut R in the dichroic LUT until AFTER forming this complement.
film=g.op('Reflection','max',raw,(0.,0.,0.),'color3f')
trans=g.op('TransmissionColor','max',g.op('Complement','subtract',g.p('IlluminantWhite'),raw,'color3f'),(0.,0.,0.),'color3f')
g.finish(g.mix('DisplayChannel',film,trans,g.p('Transmission')))
# Fix authored non-scalar ports for fractal / separate nodes.
for path in [OUT/'MoonstoneMaterial.usda',OUT/'LayeredFilmMaterial.usda',OUT/'LabradoriteMaterial.usda']:
 s=path.read_text().replace('float inputs:octaves','int inputs:octaves').replace('color3f inputs:amplitude','float3 inputs:amplitude')
 s=s.replace('MULTI outputs:out','float outputs:outr\n            float outputs:outg\n            float outputs:outb')
 path.write_text(s)
build_spatial(create, geometry)
# Swift controls generated from the same defaults used above.
s='''// Generated by Scripts/generate_extended_materials.py.
import Foundation

struct EffectControl {
    let name: String
    let label: String
    let range: ClosedRange<Float>
    let value: Float
}

extension OpticsEffect {
    var additionalControls: [EffectControl] {
        switch self {
'''
for e,controls in CONTROLS.items():
 s+=f'        case .{e}: return [\n'
 for n,l,lo,hi,d in controls:s+=f'            .init(name: "{n}", label: "{l}", range: {lo}...{hi}, value: {d}),\n'
 s+='        ]\n'
s+='        default: return []\n        }\n    }\n}\n'
(ROOT/'RealityOpticsShaderLab/ExtendedEffectControls.swift').write_text(s)
from base_color import apply_all as apply_base_colors
apply_base_colors()
print(f'Generated 15 graph templates and controls for {len(CONTROLS)} effects')
