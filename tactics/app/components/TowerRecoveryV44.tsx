import './tower-experience-v44.css';

export default function TowerRecoveryV44({expiresAt,finished=false}:{expiresAt:number;finished?:boolean}){
 const date=new Date(expiresAt);
 return <details className="t44-recovery">
  <summary>Saved until <time dateTime={date.toISOString()}>{date.toLocaleString(undefined,{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}</time></summary>
  <p>{finished?'This completed climb remains available until the time above.':'A successful action renews an unfinished climb for seven days. Watching and reconnecting do not renew it.'}</p>
  <p>Closing the tab keeps your seat; friends wait for you. Return with the same browser or your exported seat key. Retiring leaves this run permanently. New players cannot join after it starts.</p>
  <a href="/saves">Back up your seat</a>
 </details>;
}
