# Jan Wicked — bounded source generation

Current identity: Middle Human; Ice 1 / Dark 1 / Charge 1. No elemental effects in body art.
Built-in image generation only; all four allowed calls used; no runtime promotion in this lane.

## Call 4 — explicit north contact pair

```text
Use case: identity-preserve. Exactly FOUR fullbody sprites in a TWO BY TWO correctionboard for Jan Wicked. ONLY NORTH/BACK views of the supplied character. Same exact blackspikyhair, palehands,blackcharcoal silverclasps/collar coat withplumlining, darkpants/boots. NOfacevisibleanywhere. Everyheadcentered, shoulderslevel, torso BACK camera, no quarterview. Same head/coatsize inallfour. Crispnative gamepixels on actualtransparentRGBA, nobakedchecker.
The four bodyposes are a LEFT/RIGHT ALTERNATING walking/running pair. Explicit screen-space leg swap:
TOP LEFT WALK A: bodyseenfromBACK. Screen-RIGHT hip/knee bends up with RIGHT BOOT liftedHIGH offground, visible toRIGHTsideofcoat aroundmid-calfheight. Screen-LEFT leg is STRAIGHT DOWN withLEFTbootonlylowestpoint. BOTH boots visible, largeverticalseparation. Leftarmback/rightarmforward.
TOP RIGHT WALK B: bodyseenfromBACK. EXACT OPPOSITE: screen-LEFTboot liftedHIGH, screen-RIGHTbootonlylowestplant. Rightarmback/leftarmforward.
BOTTOM LEFT SPRINT A: sameasTOPLEFT withmuchhigherrightknee/boot, longerleftlegstep. Screen-RIGHT boot unmistakablyhigherandscreen-LEFT bootLOWEST. Torsoleansawayfromcamera,noface. Coatopenswithmovementtoexposeliftedknee.
BOTTOM RIGHT SPRINT B: sameasTOPRIGHT withhighLEFTboot, RIGHTBOOTLOWEST. Armsopposite. DO NOT repeatthesamelegphasefromleftcolumn. LEFTCOLUMN lowestsolemustontheLEFT, RIGHTCOLUMN lowestsolemustontheRIGHT.
Keepbodyanatomyconstant; do notmirrorhair/costumefasteners tocheat, onlyactuallegsandarmsmove. Bothfeetneverflatatsameheight. Handsbareempty,noshadows,noeffects,weapons,textorlabels. Complete isolated sprites withgenerousgutter. Preservecharacterstyleexactly, notlargerhead/costumevariation.
```

## Call 3 — reverse-contact correction

```text
Use case: identity-preserve animation correction. Image1 Jan Wicked actionboard andImage2 currentgaitboard defineEXACTcharacteranatomy andcostume. Createexactly8columns×2rows=16fullbody sprites, just REVERSE legcontact. Row1walkB,Row2sprintB. CharacterJanWickedadultHumanMiddle, tousledblackhair,paleskin,darkeyes,black/navy silver-claspcoatwithsubtleplumlining,blackpants/boots,emptybarehands. Samebody/coat/headsizeacrossall16 andmatchingreferences. Crispnativepixels, noantialias.
ColumnsSfront,SE,Erightprofile,NErearupRight,Nback,NWrearupLeft,Wleftprofile,SW. Keepdirectionexact.
SOUTH: centeredhead/nose/coatbuttonssquaretowardcamera. ScreenLEFTknee bent HIGHtowardchestwithleftbootatotherkneeheight. ScreenRIGHTlegextended DOWN tosinglelowest plantedboot onright. Left armforward/rightarmbehind.
NORTH: centeredback, noface. ScreenRIGHTknee/bootliftedHIGH awayfromfloor, screenLEFTlegextendedDOWNtoonlylowest plantedboot. Clearly showthe liftedrightboot besideleftknee, nottwoflatboots. Coat flapopens overlegswithoutchangingcut.
EAST: near/foreground hip thigh pointsLEFT/BACK behindpelvis andnearboot isclearly LEFT ofhip, benttrailing. Farleg stepsFORWARDRIGHT withfullrightbootplantedonfloor. Largeemptytriangulargapbetweentwolegs, bothbootsvisiblebelowcoat. NearfistreachesRIGHTtowardtraveldirection. Thisistheoppositephase, NOTanearkneeupfront. WESTexactmirror:nearbootonRIGHTbehind,farbootLEFTfront. Diagonalsreflectsameoppositephase,notgenericbobbing.
Row1 moderatewalks: plantedforwardfarlegslightlybent; readableoppositefeet. Row2strongerrun: foregroundknee bendfartherBACK, farlegextendedFORWARD andlower, emptygap/bootslarger; bodylengthstable. S/Nsprintremainfront/back exactly withhighraisedtrailingknee.
Importantreversecontact-only: show the near leg trailing BACKWARDSinprofiles, not leading/kneeupforbothposes. Keepcoatemshalfopen aroundlegs butcostumeunchanged. Noeffects/weapons/staff/shadow/text/grid. TransparentRGBAbackground genuinelyempty, nofakecheckerboard. Fixedanatomicalscale, completefullsprites, amplegutter.
```

## Call 2 — gait contacts and roll (40 poses)

```text
Use case: identity-preserve game sprite animation board. Reference1 is the exact Jan Wicked action sprite board. Preserve this exact adult human identity, anatomy, proportions, dark spiky hair, pale face, black/charcoal coat withsilverclasps/collar andplum lining, bareemptyhands, darkpants andboots. Do NOT redesign thecoat/collar/hair or makeheadlarger.
Create a secondboard exactly8columns ×5rows=40sprites at the SAME image scale asreference1, ideally1536×1024. Everycellcontains onefullbody withcleanmargins andfixedanatomicalsize. Eachrow 8directions S front,SE,E rightprofile,NE rearupRight,N back,NW rearupLeft,W leftprofile,SW. SOUTH centerednose/buttons,bothshoulders square; NORTH noface/backonly.
Thisboard is TRUE animation contacts. ROW1 WALK A, ROW2 WALK B, ROW3 SPRINT A, ROW4 SPRINT B, ROW5 ROLL.
WalkA SOUTH screenLEFT leg extendedforward/down tolowestboot, screenRIGHT kneeraised/boot higher. WalkB SOUTH screenRIGHT leg extendedlowest, screenLEFT knee raised highwithboot nearotherknee. WalkA NORTH screenRIGHT boot lowest,leftknee raised. WalkB NORTH screenLEFTbootlowest,rightknee raised. The pairedspritebody/headmustnotgrow/shrink.
For EAST WalkA the thick near leg leadsRIGHT infrontofhip whilethinfarfootlagsLEFT. WalkB thicknearleg bends BACK LEFT ofhip withnearknee/bootclearlyLEFT, farleg nowleadsRIGHTwithplantedfoot. ForegroundhandreachesRIGHTinB,oppositearmA. WESTmirror: AnearfootLEFTforward; BnearbootRIGHTbehindandfarfootLEFTfront. Diagonalsfaithfullyrotatetheseopposingcontacts.
SprintA sameAfootphase butstrongerstride/lean andalternatingarms. SprintB sameOPPOSITEBfootphase: bigforegroundkneeandbootbehindhipinprofiles, farlegforward, obviousgapbetweenlegs. S sprintsstraighttowardcamera withcenterednose, NEVERdiagonal. Bshouldlookliketheoppositelegisworking, NOTthesameleadinglegmovedafewpixels. Uniformhead/bodydimensions andcoatanatomy; kneestravel, notwholebodymorphing.
Roll rowcompacttuckedroll facingthe8headings; maintainbodymass, darkhair/coat/bootsrecognizable, noorb/shapeplaceholder.
Pixel hardedges andsimplifieddeliberateclusters. ActualtransparentRGBAbackground notcheckerboardpixels. No groundshadows,weapons,staffs,orbs,elementeffects,labels orgridlines. Exactly40 isolatedfullbodyposes.
```

## Call 1 — neutral/action board (40 poses)

```text
Use case: stylized-concept. Game sprite source board, exactly 8 columns ×5 rows=40 isolated full-body sprites.
Reference Image1 is the current FLUX CAST IDENTITY sheet. ONLY use JAN WICKED, row3 column5, the pale human in a black coat; do NOT copy any other character. Reference Image2 is original Oh Tipi as PIXEL RENDERING STYLE only: crisp deliberate clusters, dark outlines, restrained materials. Do not copy scales/fins, staff or spell effects.
Subject Jan Wicked, adult MIDDLE HUMAN. Pale skin, tousled short BLACK hair, dark attentive eyes, clean-shaven face; charcoal/midnight-blue practical long coat with cool silver clasps and narrow plum inner lining, dark trousers, sturdy black boots. Bare empty hands, no glowing ornaments. Confident but friendly adult, not baby/chibi. Head and torso fixed proportions throughout; head approximately one-quarter standing height, clearly articulated twolegs and feet belowcoat. Coat hems split at knees to expose bothlegs. Image source sprites about136 pixels tall per192px cell, targetruntime68px Middle; one uniform anatomy scale across all40. Fullbodyvisible includingfeet, generous clean margins.
Everyrow directions lefttoright: SOUTH perfect symmetricfront withnose/buttonscentered andshoulderssquare; SOUTH EASTdownright; EASTrightprofile; NORTH EASTupRightrear3quarter; NORTH exactcentered BACK, NOface; NORTHWESTupleftrear3quarter; WESTleftprofile; SOUTHWESTdownleft.
Rows topbottom:
1 grounded relaxed neutral pose, bothfeetfirmly planted.
2 jump, kneesbent, emptyarmsbalance, body remainsheading, no shadow orlaunchtrail.
3 cast emptyhandtowardheading. S palmsforeshortened towardviewer, nottooneside. Ncastawayfromviewer,backonly.
4 hitrecoil whilekeepingheading. Sflinchperfectfrontal,square shoulders, notdiagonal.
5 slide lowseated withtwolegsforward alongheading. SOUTH symmetricalfront withbothforeshortened boots towardviewer andsoles equallyvisible, NOT bootsaimedright. NORTH symmetricback slideaway, noface. EASTlegsright, WESTlegsleft; diagonalsalongheading.
Only character bodies. No staffs/wands/weapons/heldobjects, spells, auras, environment, floor/shadow, labels, gridlines or watermarks. Noelementcolorsbakedinto character. Genuine transparent RGBA background, NOT checkerboardpixels. Pixelhardedges/binaryalpha, noantialiasblur. Exactly40complete isolatedbodyposes, constanthead/body sizing; neverzoomindividualposes.
```
