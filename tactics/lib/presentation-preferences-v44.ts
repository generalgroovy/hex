import type {AudioMix} from './game-audio-v16.ts';
export const PRESENTATION_KEY='hex-presentation-v44';
export type PresentationPreferences={sound:boolean;instant:boolean|null;mix:AudioMix};
export const DEFAULT_PRESENTATION:PresentationPreferences={sound:false,instant:null,mix:{ui:.8,combat:.8,reducedIntensity:false}};
/** Stored preferences are user-controlled input; malformed saves keep safe defaults. */
export function presentationPreferences(raw:string|null):PresentationPreferences{
 let saved:Partial<PresentationPreferences>={};
 try{const parsed=raw?JSON.parse(raw):null;if(parsed&&typeof parsed==='object')saved=parsed}catch{}
 const volume=(value:unknown)=>typeof value==='number'&&Number.isFinite(value)?Math.max(0,Math.min(1,value)):.8;
 return {sound:saved.sound===true,instant:typeof saved.instant==='boolean'?saved.instant:null,mix:{ui:volume(saved.mix?.ui),combat:volume(saved.mix?.combat),reducedIntensity:saved.mix?.reducedIntensity===true}};
}
