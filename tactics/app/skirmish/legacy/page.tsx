import SkirmishGameV17 from '../../components/SkirmishGameV17';
import './legacy-entry.css';
export default function Page(){return <div className="skirmish-legacy-shell"><aside className="skirmish-legacy-notice" aria-label="Match rules version"><span><strong>Previous-rules match</strong><small>Existing rooms keep their original rules.</small></span><a href="/skirmish?new=1">New match →</a></aside><SkirmishGameV17/></div>}
