/**
 * @vitejs/plugin-rsc 0.5.26 collects client dependencies before Vite 8 removes
 * CSS-only JS chunks. Run that same collector after CSS extraction so preloads
 * reference emitted files and retain the CSS transferred to their importers.
 * Remove this compatibility hook once the pinned upstream plugin does this.
 */
export function rscCssManifestOrder(){
 return {
  name:'confluence:rsc-css-manifest-order',apply:'build',enforce:'post',
  configResolved(config){
   const manifest=config.plugins.find(plugin=>plugin.name==='rsc:virtual:vite-rsc/assets-manifest');
   // Vinext also runs child builds that do not have the RSC asset manifest.
   // The ordering hook only applies to the RSC client build; still fail when
   // that manifest exists but the pinned Vite CSS extraction hook has drifted.
   if(!manifest)return;
   if(!manifest.generateBundle||!config.plugins.some(plugin=>plugin.name==='vite:css-post'))throw new Error('RSC CSS compatibility hook could not find its build plugins. Review the pinned Vite/RSC versions.');
   const hook=manifest.generateBundle;
   if(typeof hook==='function')manifest.generateBundle={order:'post',handler:hook};
   else if(typeof hook.handler==='function')manifest.generateBundle={...hook,order:'post'};
   else throw new Error('RSC asset manifest hook changed. Review its ordering after CSS extraction.');
  },
 };
}
