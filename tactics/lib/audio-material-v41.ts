/** Short deterministic material layers. No ambient loop and no network samples. */
export type SoundMaterial = 'step'|'fire'|'water'|'earth'|'air'|'light'|'dark'|'steam'|'ice';
export type MaterialTexture={samples:Float32Array;rate:number;volume:number};
const cache=new Map<SoundMaterial,MaterialTexture>();
const duration:Record<SoundMaterial,number>={step:.11,fire:.26,water:.28,earth:.23,air:.34,light:.26,dark:.32,steam:.38,ice:.2};
export function materialTexture(material:SoundMaterial):MaterialTexture{
 const cached=cache.get(material);if(cached)return cached;
 const rate=22050,count=Math.round(duration[material]*rate),samples=new Float32Array(count);
 let seed=2166136261;for(const char of material){seed^=char.charCodeAt(0);seed=Math.imul(seed,16777619)>>>0}
 let low=0,slow=0,previous=0;
 for(let index=0;index<count;index++){
  seed=(Math.imul(seed,1664525)+1013904223)>>>0;
  const noise=seed/2147483648-1,t=index/rate,p=index/(count-1);
  low+=.17*(noise-low);slow+=.025*(noise-slow);
  const attack=Math.min(1,t/(material==='air'||material==='steam'?.035:.006)),tail=Math.pow(1-p,material==='earth'||material==='step'?2.8:1.4);
  let value=0;
  if(material==='step')value=(low*.85+noise*.15)*(Math.sin(p*Math.PI*3)**2*.6+.4);
  else if(material==='fire')value=(noise-low)*.32+(noise>.93?noise*.8:0)+slow*.5;
  else if(material==='water')value=low*.5+Math.sin(2*Math.PI*(440*t-370*t*t))*.27*(.6+.4*Math.sin(2*Math.PI*17*t));
  else if(material==='earth')value=slow*2.2+low*.4+Math.sin(2*Math.PI*57*t)*.18;
  else if(material==='air')value=(low-slow)*1.6;
  else if(material==='steam')value=(noise-low)*.45+low*.35;
  else if(material==='ice')value=(noise-previous)*.13+Math.sin(2*Math.PI*2200*t)*.22*Math.exp(-17*t);
  else if(material==='light')value=(Math.sin(2*Math.PI*1760*t)+Math.sin(2*Math.PI*2640*t))*.15;
  else value=slow*1.5+Math.sin(2*Math.PI*(92*t-65*t*t))*.2;
  samples[index]=Math.max(-1,Math.min(1,value*attack*tail));previous=noise;
 }
 const result={samples,rate,volume:material==='step'?.019:material==='earth'?.024:.014};cache.set(material,result);return result;
}
