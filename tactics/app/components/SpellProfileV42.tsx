import type {Spell} from '../../lib/spells-v20';
import {spellProfileBands,spellProfileSummary,hasCentreBonus} from '../../lib/spell-profile-v42';
import {profileBandValue} from '../../lib/spell-profile-label-v42';
import './spell-profile-v42.css';

export default function SpellProfileV42({spell}:{spell:Spell}){
 const bands=spellProfileBands(spell);if(!bands)return null;
 return <div className="sp42-bands" aria-label="Centre, inner ring and rim effects" title={spellProfileSummary(spell)}>
  <span data-band="centre"><strong>{hasCentreBonus(spell)?'Centre crit':'Centre'}</strong><small>{profileBandValue(bands.centre)}</small></span>
  <span data-band="inner"><strong>Inner ring</strong><small>{profileBandValue(bands.inner)}</small></span>
  <span data-band="rim"><strong>Rim</strong><small>{profileBandValue(bands.rim)}</small></span>
 </div>;
}
