Use case: stylized-concept
Create a NEW technical game character sprite sheet. Image1 shows the desired neutral mannequin costume and pixel treatment ONLY; ignore its grid and misfacing poses.
EXACT GRID: FOUR columns by TEN rows = FORTY isolated sprites. Tall portrait image with width:height2:5. Equal square cells; no header/footer/gridlines/text. Background MUST be solid flat pure magenta #FF00FF everywhere outside the sprites, no checkerboard, no texture, no shadows. This is a chroma matte for a game-engine importer.
All40 sprites show the SAME gray cloth biped template, unrelated to any race/element: smooth neutral gray blank face, two tiny dark eye ticks on front, graphite short tunic, taupe empty hands, darkslate trousers, gray ankle shoes. No hair, ears, horns, tails, wings, weapons, spells, auras, equipment, symbols or effects. Balanced compact adventurer proportions4.6heads tall; head22percent ofstandingheight, NOT giantchibihead. Same head size and limb lengths across every pose. Crisp small-pixel clusters, twelve-color neutralpalette, clean darkoutline, noantialiasblur.
Fixed55degree elevated topdown adventure camera. Direction columns must be:
COLUMN1 SOUTH front: face directlytowardcamera, symmetric shoulderships. Evenwalking/slide/cast frontviews stayfacingcamera, notleftorright.
COLUMN2 EAST: face right, trueprofile. Motion/extendedleg/palm aimedright.
COLUMN3 NORTH: backtowardcamera, truecenteredback. NOeyes, NOface. Motion/palm directedup.
COLUMN4 WEST: faceleft, trueprofile. Motion/extendedleg/palm aimedleft.
The FOURdifferentviewpoints MUSTbevisiblydistinct on EACHrow.
Row1 neutralidle standing.
Row2 airbornejump withbentknees andarmsbalancing.
Row3 emptyhandcast push towardcamera/right/away/left respectively.
Row4 recoilinghit pose,stillmatchingviewpoint.
Row5 walkingCONTACT A, anatomicalleftlegforward/oppositerightarmforward.
Row6 sprintingCONTACT A, sameleftlegforwardlongerstride.
Row7 low slide sitting/crouching withonelegextended indirectiontravel, headpointingcorrectdirection.
Row8 tuckedroll somersault alignedwithdirection, noeffects.
Row9 walkingCONTACT B, anatomicalRIGHTlegforward/oppositeLEFTarmforward. Mustnotcopyrow5.
Row10 sprintingCONTACT B, RIGHTlegforward, mustnotcopyrow6.
Rows arrangedstrictlytop-to-bottom inthatorder. Exactly4spritesonepercelloneperdirection perrow. Root centered, lowestcontacty87.5percentcell. Standingheight60percentcell. Allspritepartswellclearofcelledges. Posecannotgrownewanatomyorchangeheadsize; foldinglimbsshortenssilhouettewithoutshrinkingbody. Outputonlythemagenta40spriteatlas.
