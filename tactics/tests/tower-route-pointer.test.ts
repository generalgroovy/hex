import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import postcss from 'postcss';

const globalCss=postcss.parse(readFileSync(new URL('../app/globals.css',import.meta.url),'utf8'));
const routeCss=postcss.parse(readFileSync(new URL('../app/components/tower-route-map.css',import.meta.url),'utf8'));
function declaration(css:ReturnType<typeof postcss.parse>,selector:string,property:string){
 let value:string|undefined;css.walkRules(selector,rule=>{rule.walkDecls(property,decl=>{value=decl.value;});});return value;
}
// These selectors contain only types, classes, simple pseudo-classes and :not.
// :not contributes its argument's specificity, not a separate pseudo-class.
function specificity(selector:string){
 const flattened=selector.replace(/:not\(([^)]+)\)/g,'$1');
 return [(flattened.match(/#[\w-]+/g)??[]).length,(flattened.match(/\.[\w-]+|:[\w-]+|\[[^\]]+\]/g)??[]).length,(flattened.match(/(?:^|\s|>)([a-z][\w-]*)/g)??[]).length];
}

test('pointer press cannot let the inherited active transform move a route hex away from its hit target',()=>{
 const inherited='button:not(:disabled):active',scoped='.trm-map .trm-node:not(:disabled):active';
 const resting=declaration(routeCss,'.trm-node','transform'),pressed=declaration(routeCss,scoped,'transform'),globalPress=declaration(globalCss,inherited,'transform');
 assert.equal(resting,'translate(-50%,-50%)');assert.equal(pressed,resting,'press and release keep the identical hit rectangle');
 assert.notEqual(globalPress,resting,'fixture includes the actual inherited button displacement that caused the defect');
 const globalSpecificity=specificity(inherited),localSpecificity=specificity(scoped),firstDifference=localSpecificity.findIndex((value,index)=>value!==globalSpecificity[index]);
 assert.ok(firstDifference>=0&&localSpecificity[firstDifference]>globalSpecificity[firstDifference],'the local press rule must beat the inherited rule, regardless of stylesheet order');
 const transition=declaration(routeCss,'.trm-map .trm-node','transition');assert.ok(transition);assert.doesNotMatch(transition,/\b(transform|translate|all)\b/,'the button hit target never interpolates between positions');
});

test('the fitted map has no horizontal minimum and every small map target has a large card equivalent',()=>{
 assert.equal(declaration(routeCss,'.trm-chart','width'),'100%');
 assert.equal(declaration(routeCss,'.trm-chart','min-width'),'0');
 assert.equal(declaration(routeCss,'.trm-scroll','overflow-x'),undefined);
 const cardHeight=declaration(routeCss,'.trm-doors>button','min-height');
 assert.ok(cardHeight&&parseFloat(cardHeight)>=60);
 assert.equal(declaration(routeCss,'.trm-route','grid-template-columns'),'minmax(0,1fr)');
});
