/** One pixel-edged speech tag per consequence. The parent controls when the
 * resolved fact becomes visible; this component never predicts a result. */
import './focused-area-v42.css';
export default function CombatCallout({label,tone='status',row=0,critical=false}:{label:string;tone?:'damage'|'heal'|'status';row?:number;critical?:boolean}){
 const half=Math.max(22,label.length*3.7+9);
 return <g className={`px23-callout is-${tone}${critical?' is-critical':''}`} data-combat-callout={label} data-centre-critical={critical||undefined} transform={`translate(0 ${row*29})`}>
  <g className="px23-callout-pop"><path d={`M${-half+3}-12H${half-3}v3h3V9h-3v3H6l-6 5-6-5H${-half+3}V9h-3V-9h3Z`}/><text y="4">{label}</text>{critical&&<g><title>A centre hit contributed to this exchange. The number shows the actual net health change.</title><path className="px42-crit-badge" d="M-18-25H18v12H-18Z"/><text className="px42-crit-label" y="-16">CRIT</text></g>}</g>
 </g>;
}
