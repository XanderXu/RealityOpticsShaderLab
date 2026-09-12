"""View-dependent material families; imported by generate_extended_materials.
Fixed sample counts, padded atlas tiles, object-space parallax, no scene-color input.
"""
CONTROLS = {
 'gemFire': [('FacetScale','切面密度',3,18,8),('CutStrength','切面倾角',0,1,0.55),('Dispersion','色散强度',0,0.25,0.16),('InternalMix','内部反射',0,1,0.65),('Gain','亮度',0.2,3,1.2)],
 'absorbingGlass': [('Thickness','吸收厚度',0,3,0.85),('Tint','吸收配色：青 → 琥珀',0,1,0.25),('Refraction','折射率',1,1.8,1.5),('Gain','亮度',0.2,3,1.2)],
 'lenticular': [('ViewSpread','视角切换灵敏度',0.3,2,1),('LensPitch','柱镜条纹密度',12,90,42),('BlendWidth','视图过渡宽度',0.05,0.9,0.22),('Gain','亮度',0.2,3,1.2)],
 'moire': [('Frequency','条纹密度',6,55,24),('Mismatch','双层频率差',0.01,0.18,0.055),('LayerGap','层间视差',0,0.25,0.10),('Rotation','第二层旋角（°）',0,25,5),('Gain','亮度',0.2,3,1.2)],
 'parallaxNebula': [('Depth','内部深度',0,0.65,0.35),('Scale','云层尺度',0.4,1.4,0.85),('Density','云层遮挡',0,1,0.65),('Gain','亮度',0.2,4,1.6)],
 'rainbow': [('LightAngle','光源方位（°）',90,180,138),('Width','虹带展宽（°）',0.2,1.4,0.35),('Gain','亮度',0.2,6,3)],
 'atmosphere': [('LightAngle','太阳方位（°）',0,180,70),('Density','大气光学厚度',0.1,3,1),('Sunset','日落偏移',-0.6,0.6,0),('Gain','亮度',0.2,6,2.5)],
}

def build(create, geometry):
 def xyz(g,name,value):
  return [g.dot(name+axis,value,basis) for axis,basis in [('X',(1.,0.,0.)),('Y',(0.,1.,0.)),('Z',(0.,0.,1.))]]
 def frac(g,name,x):return g.op(name,'subtract',x,g.unary(name+'Floor','floor',x))
 def facing(g,n):
  s=g.node('FaceSign','ND_ifgreater_float',value1=g.dot('RawNV',n,g.view),value2=0.,in1=1.,in2=-1.)
  return g.op('FacingNormal','multiply',n,s,'float3')
 def refract(g,name,n,v,eta,nv=None):
  if nv is None:nv=g.clamp(name+'NV',g.dot(name+'Dot',n,v))
  eta2=g.op(name+'Eta2','multiply',eta,eta)
  # (1-eta²)+eta²*cos² avoids cancellation when eta=1 near grazing.
  k=g.op(name+'K','add',g.op(name+'OneMinusEta2','subtract',1.,eta2),g.op(name+'CosTerm','multiply',eta2,g.op(name+'NV2','multiply',nv,nv)))
  inside=g.unary(name+'Root','sqrt',g.op(name+'Safe','max',k,0.))
  scale=g.op(name+'Scale','subtract',g.op(name+'EN','multiply',eta,nv),inside)
  ray=g.op(name,'add',g.op(name+'Incident','multiply',v,g.op(name+'NegEta','multiply',eta,-1.),'float3'),g.op(name+'Normal','multiply',n,scale,'float3'),'float3')
  return ray,nv,inside
 def environment(g,name,direction):
  w=g.norm(name+'World',g.node(name+'Transform','ND_transformvector_vector3','float3',**{'in':direction,'fromspace':'object','tospace':'world'}))
  x,y,z=xyz(g,name,w)
  angle=g.node(name+'Azimuth','ND_atan2_float',iny=z,inx=x)
  u=g.op(name+'U','add',g.op(name+'AzScale','multiply',angle,0.1591549431),.5)
  vv=g.op(name+'V','add',g.op(name+'YScale','multiply',y,.5),.5)
  return g.image(name,'Environment',u,vv)
 def uv(g,p):
  x,y,_=xyz(g,'Surface',p)
  return g.op('SurfaceU','add',g.op('UScale','multiply',x,.45),.5),g.op('SurfaceV','add',g.op('VScale','multiply',y,.45),.5)
 def parallax(g,v):
  x,y,z=xyz(g,'Observer',v)
  # Bounded grazing offset avoids division poles on edge-on and rear faces.
  denominator=g.op('ParallaxDenominator','max',g.unary('AbsViewZ','absval',z),.25)
  return g.op('SlopeX','divide',x,denominator),g.op('SlopeY','divide',y,denominator)
 def atlas_domain(g,name,u,v):
  inset=0.5/256
  edgeU=g.op(name+'EdgeU','multiply',g.smooth(name+'Left',u,0.,.05),g.smooth(name+'Right',g.op(name+'RemainingU','subtract',1.,u),0.,.05))
  edgeV=g.op(name+'EdgeV','multiply',g.smooth(name+'Bottom',v,0.,.05),g.smooth(name+'Top',g.op(name+'RemainingV','subtract',1.,v),0.,.05))
  mask=g.op(name+'EdgeMask','multiply',edgeU,edgeV)
  return (g.op(name+'UTile','multiply',g.clamp(name+'UClamp',u,inset,1-inset),.5),
          g.op(name+'VTile','multiply',g.clamp(name+'VClamp',v,inset,1-inset),.5),mask)
 def atlas(g,name,key,u,v,tile,domain=None):
  # Keep interpolation within one tile, with fading for finite depth layers.
  u,v,mask=domain if domain is not None else atlas_domain(g,name,u,v)
  if isinstance(tile,int): col,row=(tile%2)*.5,(tile//2)*.5
  else:
   rowIndex=g.unary(name+'RowIndex','floor',g.op(name+'HalfIndex','multiply',tile,.5))
   col=g.op(name+'Column','multiply',g.op(name+'ColumnIndex','subtract',tile,g.op(name+'TwiceRow','multiply',rowIndex,2.)),.5)
   row=g.op(name+'Row','multiply',rowIndex,.5)
  u=g.op(name+'UOffset','add',u,col);v=g.op(name+'VOffset','add',v,row)
  return g.op(name+'Faded','multiply',g.image(name,key,u,v),mask,'color3f')
 def light(g):
  a=g.op('LightRadians','multiply',g.p('LightAngle'),0.01745329252)
  w=g.vec('WorldLight',g.unary('LightX','sin',a),0.,g.unary('LightZ','cos',a))
  return g.norm('Light',g.node('LightTransform','ND_transformvector_vector3','float3',**{'in':w,'fromspace':'world','tospace':'object'}))

 g=create('gemFire','GemFireMaterial',{'Environment':('asset',None)})
 n,v,p,nv=geometry(g);g.view=v
 pos=g.op('FacetPosition','multiply',p,g.p('FacetScale'),'float3')
 px,py,pz=xyz(g,'CutPosition',pos)
 diagonal=g.op('Diagonal','add',frac(g,'CutX',px),frac(g,'CutY',py))
 triangle=g.node('Triangle','ND_ifgreater_float',value1=diagonal,value2=1.,in1=1.,in2=0.)
 pos=g.op('TriangleCell','add',g.unary('CutCell','floor',pos,'float3'),g.op('TriangleOffset','multiply',(17.,29.,13.),triangle,'float3'),'float3')
 rx=g.op('FacetX','subtract',g.noise('FacetNoiseX',pos),.5)
 ry=g.op('FacetY','subtract',g.noise('FacetNoiseY',g.op('NoiseOffset','add',pos,(17.,23.,5.),'float3')),.5)
 facet=g.norm('Facet',g.op('CutNormal','add',n,g.op('CutTilt','multiply',g.vec('CutVector',rx,ry,0.),g.p('CutStrength'),'float3'),'float3'))
 facet=facing(g,facet)
 opposite=g.norm('InternalFacet',g.op('InternalFacetOffset','add',facet,(.7,-.5,.25),'float3'))
 entryNV=g.clamp('EntryNV',g.dot('EntryDot',facet,v))
 colors=[]
 for i,mask in enumerate([(1.,0.,0.),(0.,1.,0.),(0.,0.,1.)]):
  name='Band'+str(i)
  index=g.op(name+'IOR','add',2.4,g.op(name+'Dispersion','multiply',g.p('Dispersion'),float(i-1)))
  ray,_,_=refract(g,name+'Entry',facet,v,g.op(name+'Eta','divide',1.,index),entryNV)
  bounce=g.op(name+'Bounce','subtract',ray,g.op(name+'BounceNormal','multiply',opposite,g.op(name+'TwiceDot','multiply',g.dot(name+'BounceDot',ray,opposite),2.),'float3'),'float3')
  sample=g.mix(name+'PathMix',environment(g,name+'Direct',ray),environment(g,name+'Internal',bounce),g.p('InternalMix'))
  colors.append(g.op(name+'Channel','multiply',sample,mask,'color3f'))
 g.finish(g.op('Fire','add',g.op('RG','add',colors[0],colors[1],'color3f'),colors[2],'color3f'))

 g=create('absorbingGlass','AbsorbingGlassMaterial',{'Environment':('asset',None)});n,v,p,nv=geometry(g);g.view=v
 n=facing(g,n);eta=g.op('Eta','divide',1.,g.p('Refraction'));ray,nv,cosInside=refract(g,'GlassRay',n,v,eta)
 # A finite slab approximation; the thickness parameter supplies geometry absent
 # from a single surface graph, without accessing the real-world background.
 path=g.op('OpticalPath','divide',g.p('Thickness'),g.op('SafeCos','max',cosInside,.05))
 sigma=g.mix('AbsorptionCoefficients',(2.8,.35,.08),(.10,.65,3.2),g.p('Tint'))
 neg=g.op('NegativeOpticalDepth','multiply',sigma,g.op('NegativePath','multiply',path,-1.),'color3f')
 trans=g.node('Transmission','ND_convert_vector3_color3','color3f',**{'in':g.unary('Transmittance','exp',g.node('DepthVector','ND_convert_color3_vector3','float3',**{'in':neg}),'float3')})
 body=g.op('ColoredTransmission','multiply',environment(g,'Background',ray),trans,'color3f')
 reflection=g.op('ReflectionVector','subtract',g.op('TwiceNormal','multiply',n,g.op('TwiceNV','multiply',nv,2.),'float3'),v,'float3')
 # Exact dielectric Fresnel reuses the transmitted cosine from refraction.
 # Schlick's approximation produces false reflection for an index-matched medium.
 nct=g.op('IndexCosInside','multiply',g.p('Refraction'),cosInside)
 nci=g.op('IndexCosIncident','multiply',g.p('Refraction'),nv)
 rs=g.op('Rs','divide',g.op('RsNumerator','subtract',nv,nct),g.op('RsDenominator','max',g.op('RsSum','add',nv,nct),.000001))
 rp=g.op('Rp','divide',g.op('RpNumerator','subtract',nci,cosInside),g.op('RpDenominator','max',g.op('RpSum','add',nci,cosInside),.000001))
 fresnel=g.op('FresnelAverage','multiply',g.op('PolarizedSum','add',g.op('Rs2','multiply',rs,rs),g.op('Rp2','multiply',rp,rp)),.5)
 fresnel=g.node('Fresnel','ND_ifgreater_float',value1=g.p('Refraction'),value2=1.,in1=fresnel,in2=0.)
 g.finish(g.mix('Glass',body,environment(g,'SurfaceReflection',reflection),fresnel))

 g=create('lenticular','LenticularMaterial',{'Views':('asset',None)});n,v,p,nv=geometry(g)
 u,w=uv(g,p);sx,sy=parallax(g,v)
 phase=frac(g,'LensPhase',g.op('LensCoordinate','multiply',u,g.p('LensPitch')))
 view=g.clamp('ViewIndex',g.op('ViewOffset','add',1.25,g.op('ViewAngle','multiply',sx,g.p('ViewSpread'))),0,3)
 view=g.clamp('LensView',g.op('LensViewOffset','add',view,g.op('LensWarp','multiply',g.op('CenteredPhase','subtract',phase,.5),.22)),0,3)
 # Transition intervals never overlap (BlendWidth < 1): exactly two
 # adjacent images reproduce the former four-sample cascade at every index.
 lower=g.clamp('LowerIndex',g.unary('IndexFloor','floor',view),0.,2.)
 upper=g.op('UpperIndex','add',lower,1.)
 center=g.op('TransitionCenter','add',lower,.5)
 half=g.op('HalfBlend','multiply',g.p('BlendWidth'),.5)
 t=g.smooth('ViewBlend',view,g.op('BlendLow','subtract',center,half),g.op('BlendHigh','add',center,half))
 domain=atlas_domain(g,'ViewDomain',u,w)
 first=atlas(g,'ViewLower','Views',u,w,lower,domain)
 second=atlas(g,'ViewUpper','Views',u,w,upper,domain)
 g.finish(g.mix('SelectedView',first,second,t))

 g=create('moire','MoireMaterial');n,v,p,nv=geometry(g);u,w=uv(g,p);sx,sy=parallax(g,v)
 a=g.op('RotationRadians','multiply',g.p('Rotation'),0.01745329252)
 centeredU=g.op('CenteredU','subtract',u,.5);centeredV=g.op('CenteredV','subtract',w,.5)
 cosine=g.unary('CosRotation','cos',a);sine=g.unary('SinRotation','sin',a)
 cu=g.op('RotatedU','add',g.op('RotatedCenteredU','subtract',g.op('CosU','multiply',centeredU,cosine),g.op('SinV','multiply',centeredV,sine)),.5)
 cw=g.op('RotatedV','add',g.op('RotatedCenteredV','add',g.op('SinU','multiply',centeredU,sine),g.op('CosV','multiply',centeredV,cosine)),.5)
 far=g.op('FarU','add',cu,g.op('LayerShift','multiply',sx,g.p('LayerGap')))
 farV=g.op('FarV','add',cw,g.op('LayerShiftV','multiply',sy,g.p('LayerGap')))
 nearWarp=g.op('NearWarp','multiply',g.unary('NearCurve','sin',g.op('NearCurvePhase','multiply',w,6.283185307)),.22)
 farWarp=g.op('FarWarp','multiply',g.unary('FarCurve','sin',g.op('FarCurvePhase','multiply',farV,6.283185307)),.22)
 near=g.op('NearCurved','add',u,nearWarp)
 far=g.op('FarCurved','add',far,farWarp)
 f=g.op('AngularFrequency','multiply',g.p('Frequency'),6.283185307)
 nearPhase=g.op('NearPhase','multiply',near,f)
 farPhase=g.op('FarPhase','multiply',far,g.op('FarFrequency','multiply',f,g.op('FrequencyRatio','add',1.,g.p('Mismatch'))))
 beat=g.op('BeatPhase','subtract',nearPhase,farPhase)
 # Analytic low-pass product of two gratings: retain the visible difference
 # frequency instead of relying on unstable subpixel raster aliasing.
 channels=[]
 for i in range(3):
  c=g.op('Color'+str(i),'add',.5,g.op('Amplitude'+str(i),'multiply',g.unary('Beat'+str(i),'cos',g.op('Phase'+str(i),'add',beat,i*2.094395102)),.5))
  channels.append(c)
 color=g.node('BeatColor','ND_convert_vector3_color3','color3f',**{'in':g.vec('RGB',*channels)})
 g.finish(color)

 g=create('parallaxNebula','ParallaxNebulaMaterial',{'Layers':('asset',None)});n,v,p,nv=geometry(g);u,w=uv(g,p);sx,sy=parallax(g,v)
 baseU=g.op('ScaledSurfaceU','add',g.op('SurfaceScaleU','multiply',g.op('CenteredSurfaceU','subtract',u,.5),g.p('Scale')),.5)
 baseV=g.op('ScaledSurfaceV','add',g.op('SurfaceScaleV','multiply',g.op('CenteredSurfaceV','subtract',w,.5),g.p('Scale')),.5)
 color=(.002,.004,.018)
 # Back-to-front fixed four-layer compositing. RGB luminance supplies opacity.
 for i in range(3,-1,-1):
  name='Layer'+str(i);depth=g.op(name+'Depth','multiply',g.p('Depth'),float(i+1)*.25)
  uu=g.op(name+'U','add',baseU,g.op(name+'UParallax','multiply',sx,depth))
  vv=g.op(name+'V','add',baseV,g.op(name+'VParallax','multiply',sy,depth))
  layer=atlas(g,name,'Layers',uu,vv,i)
  vector=g.node(name+'Vector','ND_convert_color3_vector3','float3',**{'in':layer})
  alpha=g.clamp(name+'Alpha',g.op(name+'Density','multiply',g.dot(name+'Luminance',vector,(.2126,.7152,.0722)),g.p('Density')),0,.85)
  color=g.op(name+'Composite','add',layer,g.op(name+'Behind','multiply',color,g.op(name+'Transmission','subtract',1.,alpha),'color3f'),'color3f')
 g.finish(color)

 g=create('rainbow','RainbowMaterial',{'RainbowLUT':('asset',None)});n,v,p,nv=geometry(g);l=light(g)
 dot=g.clamp('AntisolarCos',g.op('NegativeLightView','multiply',g.dot('LightView',l,v),-1.),-1,1)
 theta=g.unary('RainbowAngle','acos',dot)
 u=g.op('AngleCoordinate','divide',theta,3.141592654)
 w=g.op('WidthCoordinate','divide',g.op('WidthOffset','subtract',g.p('Width'),.2),1.2)
 bow=g.image('Rainbow','RainbowLUT',u,w)
 g.finish(g.op('SkyAndRainbow','add',bow,(.009,.016,.028),'color3f'))

 g=create('atmosphere','AtmosphereMaterial',{'AtmosphereLUT':('asset',None)});n,v,p,nv=geometry(g);l=light(g)
 mu=g.clamp('SolarCos',g.op('SolarOffset','add',g.dot('SolarNormal',n,l),g.p('Sunset')),-1,1)
 solar=g.op('SolarCoordinate','add',g.op('SolarScale','multiply',mu,.5),.5)
 # Ray length through a spherical shell at the surface: sqrt(mu_v²+2h+h²)-mu_v.
 # This remains finite at the limb, unlike a plane-parallel 1/cos approximation.
 shell=g.op('ShellPath','subtract',g.unary('ShellRoot','sqrt',g.op('ShellSquare','add',g.op('ViewCos2','multiply',nv,nv),.1025)),nv)
 depth=g.clamp('DepthCoordinate',g.op('AtmosphereDepth','multiply',shell,g.op('DensityScale','multiply',g.p('Density'),3.)))
 sky=g.image('Atmosphere','AtmosphereLUT',solar,depth)
 lv=g.dot('LightView',l,v)
 phase=g.op('RayleighPhase','multiply',g.op('PhaseBase','add',1.,g.op('PhaseSquare','multiply',lv,lv)),.75)
 glow=g.op('ScatteredLight','multiply',sky,phase,'color3f')
 surface=g.op('PlanetSurface','multiply',(.012,.032,.065),g.op('Daylight','add',.04,g.clamp('LitSurface',mu)),'color3f')
 g.finish(g.op('Planet','add',surface,glow,'color3f'))
