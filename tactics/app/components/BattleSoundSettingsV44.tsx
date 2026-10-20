"use client";
import type {AudioMix} from '../../lib/game-audio-v16';
export default function BattleSoundSettingsV44({mix,onChange}:{mix:AudioMix;onChange:(value:Partial<AudioMix>)=>void}){
 return <fieldset className="battle-sound-v44"><legend>Sound levels</legend>
  <label>Combat <output>{Math.round(mix.combat*100)}%</output><input aria-label="Combat volume" type="range" min="0" max="100" step="5" value={Math.round(mix.combat*100)} onChange={event=>onChange({combat:Number(event.target.value)/100})}/></label>
  <label>Controls <output>{Math.round(mix.ui*100)}%</output><input aria-label="Interface volume" type="range" min="0" max="100" step="5" value={Math.round(mix.ui*100)} onChange={event=>onChange({ui:Number(event.target.value)/100})}/></label>
  <label><input type="checkbox" checked={mix.reducedIntensity} onChange={event=>onChange({reducedIntensity:event.target.checked})}/> Softer effects</label>
 </fieldset>;
}
