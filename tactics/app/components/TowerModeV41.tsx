import './tower-mode-v41.css';
/** One Tower mode, with local and shared runs kept in their original stores. */
export default function TowerMode({friends=false}:{friends?:boolean}){
 return <nav className="t41-play-style" aria-label="Tower play style"><a href="/tower" aria-current={!friends?'page':undefined}>Solo</a><a href="/tower?play=friends" aria-current={friends?'page':undefined}>With friends <span>2–6</span></a></nav>;
}
