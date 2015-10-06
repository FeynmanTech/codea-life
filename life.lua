
--# Main
-- LifeShader

-- Use this function to perform your initial setup
function setup()
    
    displayMode(OVERLAY)
    noSmooth()
    
    local p = readProjectData("p") or 1
    
    ims = {}
    -- Read patterns
    local i, rule = readRLE(patterns[p])
    table.insert(ims, i)
    
    im = ims[1]
    
    life = {}

    life.s = vec2(im.width+200,im.height+200)
    
    life.m = mesh()
    
    fragment = fragment:gsub("// @RULE", rule)
    
    life.m.shader = shader(vertex, fragment)
    life.m.shader.size = life.s
    life.m.shader.scale = 2
    life.source = image(life.s.x, life.s.y)
    life.target = image(life.s.x, life.s.y)
    
    life.m:addRect(life.s.x / 2, life.s.y / 2, life.s.x, life.s.y)
    
    spriteMode(CENTER)
    setContext(life.target)
    background(0)
    setContext()
    
    setContext(life.source)
    background(0)
    sprite(im, math.floor(life.s.x / 2), math.floor(life.s.y / 2), im.width/2, im.height/2)
    setContext()
        
    life.m:setColors(color(255))
    life.m.texture = life.source
    
    parameter.integer("SPEED", 1, 10, 1)
    parameter.integer("SC", 1, 4, 1)
    
    parameter.integer("pattern", 1, #patterns, p)
    parameter.action("Load pattern", function() saveProjectData("p", pattern) restart() end)
end

-- This function gets called once every frame
function draw()
    -- This sets a dark background color 
    background(0, 0, 0, 255)

    noSmooth()
    
    spriteMode(CORNER)
    for n = 1, SPEED do
    setContext(life.target)
    life.m.texture = life.source
    life.m:draw()
    setContext()
    life.source, life.target = life.target, life.source
    end
    spriteMode(CENTER)
    sprite(life.source, WIDTH/2,HEIGHT/2, life.source.width*SC, life.source.height*SC)
end

function touched(t)
    setContext(life.source)
    stroke(255)
    strokeWidth(1)
    line(t.prevX, t.prevY, t.x, t.y)
    setContext()
end

--# Shader
vertex = [[
//
// A basic vertex shader
//

//This is the current model * view * projection matrix
// Codea sets it automatically
uniform mat4 modelViewProjection;

//This is the current mesh vertex position, color and tex coord
// Set automatically
attribute highp vec4 position;
attribute highp vec4 color;
attribute highp vec2 texCoord;

//This is an output variable that will be passed to the fragment shader
varying highp vec4 vColor;
varying highp vec2 vTexCoord;

void main()
{
    //Pass the mesh color to the fragment shader
    vColor = color;
    vTexCoord = texCoord;
    
    //Multiply the vertex position by our combined transform
    gl_Position = modelViewProjection * position;
}
]]
fragment = [[
//
// A basic fragment shader
//

//Default precision qualifier
precision highp float;

//This represents the current texture on the mesh
uniform sampler2D texture;

uniform vec2 size;

uniform float scale;

//The interpolated vertex color for this fragment
varying vec4 vColor;

//The interpolated texture coordinate for this fragment
varying vec2 vTexCoord;

float w = 1. / size.x / scale;
float h = 1. / size.y / scale;

float r = 0.1;

uniform highp vec2 points[5];

void main()
{
    //Sample the texture at the interpolated coordinate
    vec4 col = texture2D( texture, vTexCoord );
    
    int neighbors = 0;
    
    neighbors += int(texture2D(texture, vTexCoord - vec2(w, h)).r+r);
    neighbors += int(texture2D(texture, vTexCoord - vec2(0., h)).r+r);
    neighbors += int(texture2D(texture, vTexCoord - vec2(-w, h)).r+r);
    
    neighbors += int(texture2D(texture, vTexCoord - vec2(w, 0.)).r+r);
    neighbors += int(texture2D(texture, vTexCoord + vec2(w, 0.)).r+r);
    
    neighbors += int(texture2D(texture, vTexCoord + vec2(-w, h)).r+r);
    neighbors += int(texture2D(texture, vTexCoord + vec2(0., h)).r+r);
    neighbors += int(texture2D(texture, vTexCoord + vec2(w, h)).r+r);
    
    // @RULE

    //Set the output color to the texture color
    gl_FragColor = col;
}
]]
--# LoadRLE
-- Parses an RLE file containing a pattern
function readRLE(t)
    -- Remove comments
    t = t:gsub("#.-\n", "")
    
    -- Rule code init
    local rule = ""
    
    -- Get pattern dimensions
    local w, h
    for a, b, r in t:gmatch("x = (%d+), y = (%d+), rule = (.-)\n") do
        w, h = tonumber(a)+1, tonumber(b)+1
        for b, s in r:gmatch("B(%d+)/S(%d+)") do
            rule = rule .. "if (col.r==0. && (neighbors==" .. b:sub(1,1)
            for n = 2, #b do
                rule = rule .. "||neighbors=="..b:sub(n,n)
            end
            rule = rule .. ")) col=vec4(1.,1.,1.,1.); else if (col.r==1.&&(neighbors!=" .. s:sub(1,1)
            for n = 2, #s do
                rule = rule .. "&&neighbors!=" .. s:sub(n,n)
            end
            rule = rule .. ")) col = vec4(0.,0.,0.,1.);"
        end
    end
    t = t:gsub("x = %d+, y = %d+.-\n", "")
    --t = t:gsub("%s", "")
    
    -- Create pattern image
    local i = image(w, h)
    setContext(i)
    background(0)
    fill(255)
    noStroke()
    
    -- Read pattern data
    local x, y = 1,h-1
    
    function step(c)
        if c == "b" then
            x = x + 1
            if x > w then
                x = 1
                y = y - 1
            end
        elseif c == "o" then
            rect(x, y, 1, 1)
            x = x + 1
            if x > w then
                x = 1
                y = y - 1
            end
        elseif c == "$" then
            x = 1
            y = y - 1
        end
    end
    local p = 1 -- position in string
    local c = "" -- current char
    local l = 1 -- repetition
    while c ~= "!" do
        c = t:sub(p,p)
        if c:match("%d") then
            local start = t:find("%D", p)
            l = tonumber(t:sub(p, start-1))
            for n = 1, l do
                step(t:sub(start, start))
            end
            p = start+1
        else
            step(t:sub(p,p))
            p = p + 1
        end
    end
    setContext()
    return i, rule
end

--# Lineship
patterns = {}
patterns[1] = [[#C  Optimized version of Jason Summers' p96 c/12 diagonal lineship.
#C A p768 version was also constructed.  David Bell, 24 June 2005
x = 675, y = 653, rule = B3/S23
617bo$618boboobobo$612b3o3b4o3bo$618bobbooboo$617bo$615b3o$615b3o17boo
$635boo7$643boo$643boo$631b4o$635bo$617bobooboo7bo4bo$616b5obboo7boobo
$616bobb3obo10bo$622bo3$606bo3boobboobo$606bo3boo4boboo$606bo3boobboob
oo$610boo$608bobbo$608bobo$609bo9$612booboo$613bobo$600bo12boo$599b3o
10boobo$598booboo12boo4bo$599b3o10booboo4bo$600bo$600bobo20boo$600b4o
19boo$603bo$$599booboo$598bo5bo$599bo3bo$592b3o5bo$591bo3bo$590bo4bo
29boo$589bo3bo30bobbo$589bobbob3o27bobbo$589bo7bo26bobbo$591bo3bobo27b
oo$570bo20bo3boboo$569b3o21b3oboo31bo$568booboo58bo$567boobobo58bo$
566b3obb3o$567bo6bo41bo$568b5obo40bo$569b4oboo39b3o$574bo$573bo12boo$
586boo3$571bo$569boobo15booboboo$587boobo3bo$572bo15bobobobo$569bobbo
16bo$570bo$$575boo$568b3o5boo$575boo$575bo11b4o$586boboo$586bobo$$581b
o$579bobboo$574boo3bobb4o$574boo3boboobo$582boobo$582bo$580bo4bo$580b
3o$580boob3o$528bo54b3o$527boboo51bobo15bo$531bo50boo15bo$525bo3bobbo
66b3o$441bo81bo9bo11b3o$441bo7bo73bo4boobboo$441bo5b3o82boo46bo$440boo
3bobo77bo5bo31b3o8bo5bo$446bobbo76bo4b3o28bo3bo6bo7bo$445bobboo77bo4b
oo12b3o5boo7boo9b4obboo$460boo67b4o12booboo4boo9booboo9b3o$460boo82bob
oboo17boo11bobo$544bo3bo32bo$545bobbo32bo$518bo26b3o$518bo$518bo8bo14b
o$525bobo13bobo18boo12bo$468boo49b3obbo3bo12bobbo17boo12boo$468boo50bo
b5o15boo31bobo$449boo3boo70bo$443bo3b4o3bobo64boo15boo$443boboobbobbo
3bo81boo$443boboo4bo3boo$447bo3bo$452bo78bo$501b3o26bobo$522b3o5bobo$
433b3o6bo62boo15b3o6bo$434boo3boobo64bo12bo4boo$414bo18boo5bobo58b4obo
13bobo3bo$412booboo21b3obo58b5o13boo3b3o$412booboo24boo76boo3bo$412boo
108bo21bo39bo$414boobo68bo14bobo14bo3bo21boo37bo$415bobbo63boobobo7bo
5bobo14bobo22bobo37b3o$415bobbo63bobbooboobbooboo5bo$416boo64bo5bobo5b
o4bobo$483boobbo8bo5boo$487bobb3obbo6bo$487b3o$414bo45bobo109bo$413bob
o44bobobo7bo97boo$413bobo43bobboobo4b3o98boo$414bo45boo3boboboobo44bo$
460boo3boob5o10b3o29booboo$464boboo3boo10bobo29b3oboo$463bobo16booboo
15boo12b5o$482boo18boo13b3o$422bo21bobo71bo$421bobo21boo$421bobo21bo
39bo$399booboo18bo62bo$399boo30bo$399boobobo28bo45b3o$402bobo25bo3bo
43bo3bo27boo$403boo27b4o41bo4bo27boo$433bo33boobo5bo3boo3bo$391bobo36b
oboo29bo3b6o11bo$377bobo7bobbobbo36boboo28bo5bo4bobboo6b3o$376booboo5b
oboboobo36bobo29bo11bo$377boboo6bo42boo31bo9bo$381bo11b3o72bo$380bo13b
oo72bobbo$380bo12boo75bo$568bo$567bo$470boo95b3o$470boo3$401b3o$399boo
bbo$398bo3bo153bo$393bo5bobbo151boo$392bobo4bobo153boo$382boo17bo$382b
oo18bo$402bobo$402boo$$476bobo$477boo$477bo$390boo$390boo12$552bo$551b
o$551b3o6$540bo$538boo$489boo48boo$479bo3boo4b3o$479boboobbo6bo$479bo
bb5obb4o$483b3o3b3o$482b3o$482boo17boo5bobo$482bo18boo6boo$509bo6$509b
oo$359b5o7bo137boo$357boo5boo4bobo115bo8boobbo$357bo7bo4bo116bobbo5b3o
bboo$357boo7bo3bobbo107b3obbo3bo6boobb3o$359boo6bo3b3o107b3obbo4bo5boo
bboo$362bo122bo3boo$362bo4bo13boo106boo$363boobo14boo103boo48bo$482bob
o50bo$473bob3o4bobo50b3o$471boobo4bo5bo$473boo4bobbobbo$479bobbobbo$
478bo4bo$378bo3bo6boo67bo15bobbo$376bobbob3o5boo66bobo15boo47bo$379bob
obo72booboo61boo$367bobo7bo79bobbo62boo$361boo4b3obobooboo81b3o$361boo
6bobboo3bobo3bo75bobo$377bobo80boo$365boo93boo60bo$353b3o8b4o136b3o14b
o$351b7o5boobbo138bo14b3o$350b9o3bob3o69bo68bo$349bo7b3o3boobo68boo20b
3o$298bo51b3o6bo74b5o18boo$351boo80bo24bobbo$302bo51bo77boo5bo12boo5bo
bo$355bo75b3oboo8bobo3b3o$294b3obo57bo75boboboobboo3bob6oboo$294b3obo
134bobbobboo5bobo4bobbo$295bo8boo106b3o20boo11bobbobo$296bo3b3oboo105b
o25boobo8b3obo$297bo6bo105bo4boo23bo13bobobbo3bo$298bobobobo104bo3bo
15b3o27bobbo$299bo15boo92bobbo4bo4boo36bo$315boo92bo3bo3bo4b3obo$361b
oo47boobob3o54b3o$346bo14boo50bo60bo45bo$346bo67b4o40boo13bo45bo$345bo
bo68boo11boboo25boo59b3o$346boobbo78bobbo35boo$345bo5bo77b3o36bob3o$
323boo20bo5bo116boobbo$323boo20bo4bo118b3o$305b3o41bo19boo99bo$303bo3b
oo37b3o20boo137bo$297b3o3bobobboo156boo38boo$302bo5bo157boo39boo$303bo
bboo36booboo$303bo45bo$288bo55boo72boo$287bobo56b3o69boo86bo$505bo$
287bobbo3bob3o206b3o$289bo4bo41bo$290boboobobo38bo7bo$268b3o20boo3bo
39bo5b3o$269bo22bo42boo3bobo$269bobbo68bobbo81boo$269bobbo67bobboo81b
oo$270bobo39bo$312bo$314bo5bo$313bo6bobo$312bo3bobbo$269bo43bobboboboo
$268bobo47boboo37bo$269bo62boo25bobo$269bo62boo25boo$504bo$342bo160bo$
299bo32bo10bo88b3o68b3o$300bo29bobo3boo4bo89bobo$277bo20b3o28bo5b3o94b
obo14boo$276bobo51bob3o3bo93bo4boo9bobbo$276bobo52bo5bo93b3o3boo10b3o
16bo$255boo7boo11bo55boobbo99bo12boo15b3o$255b3o6b3obboo50boo3bo8bo97b
4o13bo15booboo21bo$255boobobo26bo31b3o4boo106boo12boboo15b3o20boo$258b
oo26boo26b3obo8boo105bo13b4o16bo15boo5boo$237bo48bobo29bobobb5o9bo110b
obobo15bobo13b3o$286boo31bo3b3o10boo97bo13booboo3boo9b4o12b3o$233bo7bo
44boo145bobo12bo3bo4boo12bo12bo$233bo8bobb3o85bobbo95b4o13b3o33bo4bo$
232bo4boo3bobb3o37bo47bobbo95b3o15bo16booboo17bo$233bobo6bobboobbo34b
3o46b3o98bo31bo5bo16b3o$233boboo10bobo33boboo180bo3bo$247b3o70boo100bo
26boo17bo15bo$238bo44boo35boo8boo86boobobo7bo13bobo36bobo52bo$329b3o
86bobbooboobbooboo12bobo17boo17boo52b3o$329b3o86bo5bobo5bo32boo70boobb
o$330bobo86boobbo8bo11b4o88boobboo$330bobo71b3o16bobb3obbo13bo91boo$
330b3o70bobbo16b3o15boo95b5o$253b3o146bo4bo33boo99boo$252boobboo144bo
bb3o132bobbo$252boobboo144bo5bo132boo12boo$253boboo146b7o24bo120boo$
253boo88bo65bo23bobo$245boo6boo88bobo63bo23bobo$237boo8b3o8bobo82boo
62boo25bo17b3o$237boo5b3oboo8boo194bo33bo50b3o$259bo193bo33bo51bobo$
331bo50boo21bo81b3o49bo$332bo49b3o19b3o132bobbo20boo$330b3o49boobo17bo
3boo131bobo20boo$386bo17booboo132b3o$378bo3boo3bo16booboo134boo$245boo
141bo5bo6boo134b3o4boo$245boo138bobo5bo4b3o75bo66boo$359bo25bo6b3o3boo
bboo70boo148bo$308bo49boboo18bo4bobo5boo3boboboo71boo54b3o89b3o$308bo
53bo31boobbo131bobbo88bobobo$308bo47bo3bobbo20b4o7booboo129bo4bo86b3ob
3o12bo$311boo41bo9bo11b3o5boo10b3o130bobb3o104bobo$311boo12boo27bo4boo
bboo109bo54bo5bo87bob3o13boo$306bo3b3o11boo37boo55b3o50bo56b7o86b5o9bo
3bo$307b3o15bo30bo5bo59bo50b3o60bo86boobboo11bobboo$308bo15b3o30bo4b3o
56bo114bo36bo51boboo14bo$307boo15b3o31bo4boo12b3o25boo9bo51bo65boo36bo
bo52boo9bobboo$307b3o16bo33b4o12booboo24boo8bobbo49bobo100bo3bo13b3o
31bobobbo11bo7boo$309bo14bobbo47boboboo33bo4bo48boo101bo3bo8bo37bobobb
o20boo$307bo16b3o48bo3bo34bo5bo150bobob3o4boob3o35bo$309bo15bo50bobbo
33booboo93bo60boobobbo5boboo$307b3o66b3o37boobo90boo64bobo8bo$342bo72b
oobbo89b5o62boo11bobbo5boo$340bobo72b4o89bo80b3o6boo38boo$341boo70b3ob
o89boo5bo6boo$413boo91b3oboo8bobbo114boo$507boboboobboo4boo133bo$322bo
bo183bobbobboo83bo39bobo9bo3bobo$322bobbo39boo143boo86boo40bo10b5oboo$
322bobbo39boo145boobo82boboboo24boo10booboo7bo4bo$322bo3bo145bo42bo83b
3obooboo8b3o9b3oboo8boo9boobo$323bobo145bo126bo3boobboo23bobbo8boo10bo
$324bo38bo107b3o55boo67bo3bo11bo5bo11b3ob5obobo3bo$364bo163bobbo66bobb
o12b7o13bo3bobb3o4bo$309b3o6bo43b3o164boo47boo13boo4bo16bo17bobboobbo
bbo$308bo4bo3bobo258boo13boo21bo3bo14boo3b3obo$308bo4boo3bo11bo42boo
208boo30bo18boo6b3o$308bo6bo13boboo40boo207boboo30bo16boo$309b3obobbob
o14bo126bo105bo15bo8b3o23bo4bo10boobo$313b5o9bo3bobbo123boo78bo26b3o
15bobbo5boo23bo4bo12bo$318bo6bo9bo11b3o109boo79bo23booboo17bo29boobobo
$287bo7bo29bo4boobboo201bo25boo3bo15boo29bobo$286b3o5bobo37boo228bobob
obo12bo32bo$285boob4obbobbo29bo5bo173b3o28bo26boobobbo$286b3obbo36bo4b
3o122bo47bo3bo28boo27boobo$287bobboobbo34bo4boo12b3o5boo99bo48bo3bo32b
o25boo$291boobobo34b4o12booboo4boo99b3o46bo3bo31bobo$295bo10boo38bobob
oo189bo3bo13b3o48bo$306boo38bo3bo101bo54booboo29bo3bo8bo54bobo5bo$347b
obbo9boo90bobo53bobbo29bobob3o4boob3o57booboo8boo$347b3o10boo90boo31bo
23bobo30boobobbo5boboo51b3obbo3boo8boo$307b3o45boo3bo123b3o23boo34bobo
8bo57booboo$307b3o44b4oboo122booboo19bo3bo34boo11bobbo52b4o$313b3o39bo
bobbo123b3o14bo4bobobobo46b3o$311bo3bo58bo110bo14b3o4bo$309booboboo43b
oboo9bobo110bobo11bo3bo$166bobo122bo17bo32bo18bo11boo110b4o9boobb3o$
152bobo7bobbobbo121b4o6boo8boo24boo3b3o144bo10bo3bo25bobo104boo$151boo
boo5boboboobo120bo4bo4b3oboo31boo3bobbo4b3o147bobbo27boo104boo$152bob
oo6bo125boo10boob3o4bo12boo16b3obobbooboo131booboo11bobo27bo$156bo11b
3o118boboboo4b3oboo3b4o11b3o15boobbobboobbo130bo5bo$155bo13boo119b3o6b
oo7boobbo10boobo15boo6boo132bo3bo$155bo12boo7boo112bo15bo4bo14bo12bo3b
o111bo28bo$177boo127booboboo6bo3boo3bo126bo166b3o$305b4o20bo11bo53bo
59b3o42boboo44boo70b4oboo$305b4o17bobo11bobbo52bo102b5o44boo59bo5bobo
4boobbo$308boo16bo13b4o50b3o102b4o94bo11boo4boo7b3o$294boo13boo10bo4bo
bo12bo254bobo9boobo7bobo$178boo114boo12bo191b3o92bo3bo10b3o$177bobbo
144b4o171b3o92bo3bo10boo$177bobbo4boo117b3o18boo117bo56bo93bobob3o5b4o
$175bob4o4boo255boo45boo105boobobbo5boo$174bobbo124bo4bo135boo44boo65b
oo42bobo5bo$174bobo125bo17b3o233boo42boo$157boo9bo3boo132boo11bobbo
250b3o$157boo8bo135booboo10bo4bo249b3o14boo$169boobbo131bo12bobb3o118b
o129bo3bo7bobo4boo$162bo6b4o145bo5bo11boo103bo131boob3o5bobbobb3o$160b
3o156b7o10boo103b3o129boo4bo4bobob6o$159bo3bo161bo171boo77bobbo9bobboo
$144booboo10bobbo162bo110bo60boo78boo11b3o$144boo13bobbo160boo111bobo
152bo$144boobobo10boo274boo107bobbo$134bo12bobo394bo$132booboo11boo
394bo3bo$132booboo185bo21boo198b4o$132boo187bobo20boo60bo192bobo$134b
oobo182boobo80bobo211bo$135bobbo181boo83boo163bo28bobo15bo$135bobbo
182b3o245boo46b3o$136boo111b3o70bo182bobbo60bobo$248bo74bobbo177bo51bo
bo$247bo4boo73bo176bo3bo38bob3o4bobo20boo$143boo101bo3bo15b3o58bo176b
4o37boobo4bo5bo19boo$142bobbo100bobbo4bo4boo58bo5b3o112bo106boo4bobbo
bbo$134b3o6boo101bo3bo3bo4b3obo47bo6bobo118bo113bobbobbo39boo$247boobo
b3o52boobobo4bo109bo11b3o110bo4bo$134bobo113bo56bobbooboo113bo119bobbo
16boo$135bo115b4o20boo30bo5bobo4bo105b3o36bobbo80boo17boo$136bo116boo
11boboo5boo31boobbo8bo142bo$136boo128bobbo42bobb3obbo143bo3bo118boo$
133boboobo12boo113b3o43b3o149b4o119boo$133b4oboo10bobbo121bo152bo$134b
5o12boo122bo4bo145boo$136boo136bobobbobo138b3o4boo157bo$274bobobo3bo
32boo105bo153boo7boo$273bo4b3obboo29bobbo103bo9boo142bobbo6bobo$278bob
o3bo8b3o19boo114bo144boo$126b3o6bo141boo14bobo136bo128b3o4b3o$127boo3b
oobo139bo4boobo9bobo121boo14bo133bobbo$126boo5bobo119boo13bo22bo4boo
111bo4bobo15bo132bo3bo$131b3obo119boo3b3o6bo22b3o3boo111boo5bo16bo124b
o3boboobobo$134boo107bo16bobo5bobbo26bo30bo80bobo23bo129booboo$242boo
16bobbo4bobbo22b4o12boo17bobo105bo123bobo3b3o14boo$104bo136b5o14b3o6b
oo24boo13boo17boo107bo123bo20bobbo$104bo7bo127bo21bo32bo143bo144boo$
104bo5b3o126boo5bo14bo44boo132bo107b3o$103boo3bobo127b3oboo16bobo33bo
8bobbo132bo$109bobbo126boboboobboo11boo32bobo9bobo133bo109bo39bo$108bo
bboo127bobbobboo13bo31b4o10bo135bo104bo3boo37bobo8bo$123boo117boo49b3o
92b3o36b3o14bo105bobo38bobo7bo$123boo119boobo47bo94bo35bobbo15bo101b3o
42bo8b3o$247bo141bo39bo16bo102bo46b3o$403boo24bo17bo76bo62boo7b4o$122b
o10boo267bobo21bobo19bo75bo23boo36bobbo5b3obbo$122bo3bobo256boo17bo44b
o74bob3o20boo36boo7bobbo$120booboboobbo249bo4bobo63bo75b3o20bo46boo$
121b6obbo110bo138boo5bo64bo75bo13b3o5boo41bo4bobo$122bo5boo109bobo136b
obo71bo74boo19boo40b5o3bo$125bobo110booboo55boo153bo74bo61b3oboobboo$
112boo3boo6bo113bobbo12boo41boo154bo55bo6boo9boo13bo46boo4boo$106bo3b
4o3bobo121b3o11boo198bo53bobo3bo3bo22boo47bobobobo$106boboobbobbo3bo
121bobo212bo51bo3bobo3boo5booboo11b3o48bo$106boboo4bo3boo7boo113boo
213bo51bobobboboboo6b3o12bo22boo$110bo3bo12boo113boo214bo51bo3bobboo7b
o12bo23bobo$115bo11boo330bo54bo4bo19bo3boo20bo$138bobo21bo193b3o101bo
54bobbo24boo$123boobbo10bobobo7bo12boo141boo50bo102bo32bo22bo22bo$124b
3o10bobboobo4b3o11boo76bo22boo41boo49bo104bo23b3o3b4o45bobbo$125bo12b
oo3boboboobo90bo21boo106boo90bo22bobo3booboo44b3o$111boo25boo3boob5o
90boo127bobo91bo21b3obbo$111boo7bobo19boboo3boo89b3o110boo17bo92bo25b
oo3bo$123bo17bobo16boo185bo4bobo111bo25b4o$123bo36boo135bo49boo5bo112b
o25b3o10boo18boo$123bo117b3o52b3o14bo32bobo119bo37boo18boo$120booboo
114bo4bo50booboo13bobo153bo$121bobo115boo3bo51b3o14boo155bo$122bo118b
4o52bo173bo36boobo$237bobo57bobo172bo35bo4bo$228bob3o4bobo57b4o172bo
34bo5bo$168boo56boobo4bo5bo59bo173bo36bobbo$158bobbo6boo58boo4bobbobbo
234bo34bobboo19boo$145boobo6boobobboo71bobbobbo55booboo23b3o149bo24bo
7bobbo21boo$141bo3b6o4boobo4bo69bo4bo56bo5bo24bo150bo12boo9b3o6bobo$
140bo5bo4bo3boo72bobbo63bo3bo24bo152bo10bobobo7b3o$140bo11bo4bo4boo50b
oo14boo65bo41boo138bo9bo3boo5bo3bo$141bo9bo5booboo42bo3boo4b3o121bobo
139bo9boo8b4o6boo$146bo57boboobbo6bo103boo17bo140bo8b3o7boboo4boobbo$
143bobbobbo54bobb5obb4o97bo4bobo159bo26boboo$134bo8boo3bo59b3o3b3o98b
oo5bo160bo22booboo$130boobobo5boobo62b3o18bo85bobo58bo43b3o49bo12bo21b
3o$130bobbooboobbo66boo18bobo144b3o41bobbo41b3o3b4o12bo20bo$130bo5bobo
4bo63bo18booboo142booboo43bo41bobo3booboo12bo19boobbo$131boobbo8bo84bo
144b3o14bo29bo41b3obbo18bo6boo11b3o$135bobb3obbo84boo19bo125bo14b3o25b
obo47boo3bo14bo5boo11boo$135b3o90boo19bobo123bobo11bo3bo75b4o16bo$249b
oo124b4o9boobb3o75b3o10boo5bo14bo$226bo3bo147bo10bo3bo89boo6bo11b3o$
194bo32bo3bo157bobbo99bo9bobbo$195boo31bo145booboo11bobo6boo92bo9bobbo
$194boo27b3o5bo141bo5bo19boo93bo9bobo$213bo8bobbo3bo77boo65bo3bo116bo
8b3o$212bobbo5bo7b3o74bobo66bo120bo$206b3obbo3bo5bobbo64boo17bo188bo$
140boo64b3obbo4bo4bobo59bo4bobo99boboo97boo5bo$140bobo67bo3boo67boo5bo
98b5o84bo12boo6bo$124b3o87boo66bobo104b4o74boo9b3o19bo$140bobo68boo12b
ob3o174boo60bobobo7b3o20bo$128boo10bo85b4o160b3o14bo58bo3boo5bo3bo20bo
$130bo96boo161b3o9bo4bo59boo8b4o22bo$124b4obo261bo4boo4bo5bo58b3o7bob
oo23bo$124b5o85boo163boo14b3o4bo3boo97bo$148boo64boo163boobboo9b4o6bob
oo98bo$148boo217b3o13boo7boobb3obo56bo6boo41bo$124bobo239bo3bo12boobb
oo3boobobboo56bobo3bo3bo41bo$124bobo239bo3bo16boboboo6bo55bo3bobo3boo
42bo$125bo240bo3bo15bobbobbobbo60bobobboboboo43bo$124bobo99bo48boo67bo
42bo5b3o61bo3bobboo45bo$125boo99bo47bobo66boo22booboo13bo75bo4bo45bo$
125bo131boo17bo65b5o21bobbo13bobo74bobbo47bo$251bo4bobo82bo19bo7bobo
13b3o76bo49bo$114bo110boo24boo5bo81boo5bo13bo8boo143bo$114bo33bo4bo96b
obo86b3oboo8bobo5bo5bo3bo144bo$114bo8bo23bo6bo69b3o113boboboobboo3bobo
10bobobobo144bo$121bobo24bo4bo187bobbobboo5bo12bo150bo$115b3obbo3bo
218boo174bo$116bob5o110bo111boobo171bo$122bo110bobo112bo12b3o157bo$
117boo114boo124boobbo97bo60bo$360b3o96bobbo60bo$226bo112b3o11bo7bo49b
3o48boo60bo$227boo109bobbo10bobo55bobbo32bo13boboobbo58bo$118boo106boo
109bo4bo9bobo58bo32bo14b3o3bo58bo$119boo19bo102boo92bobb3o10bo59bo32bo
b3o11bobobbo59bo$138boo102bobo92bo5bo66bobo35b3o11bobboo61bo83bo$96bo
42boo103bo93b7o104bo9booboobo63bo82bo5b3o$95boboo120bo124bo104boo7b4o
9boo57bo80bobo3boobbo$99bo27bo91boo96bo26bo105bo7bobo10boo58bo80bo3bo
5bo$93bo3bobbo9boo14bobbo88bobo95b3o23boo17bo88boo80bo79bo3bo$91bo9bo
6b3o14bo3bo185boobbo40bobo170bo83bobboo$91bo4boobboo4b5o3boo10boo3bo
182boobboo40bobo84booboo82bo83boo11boo$100boo4boo6boo13bobo183boo44bo
86b3o84bo95boo$93bo5bo7bo18boo3bo184b5o127bo87bo$94bo4b3o23bo3bo190boo
215bo$95bo4boo7b3o14bobbo188bobbo216bo$97b4o10bo15bo191boo12boo138boo
64bo$111bo10boo209boo138boo65bo$118bo3boo349bobo65bo$118b3o351boob3o
64bo96boo$117boboo90boo123boo138boo65bo81bo13boo$120boo88bobo104b3o15b
o139bobbo65bo70boo9boo$121boo89bo104bobo15b3ob3o25bo29bo78bobo66bo68bo
b3o8boo$121b3o63bo129bo17b3obbo25bobo29boo25bobo48boo68bo67bo3bo10bo$
117boobb3o63boo128bobbo18bo25bo3bo13b3o11boo17bob3o4bobo13b3o22bo80bo
67boobo5b5o$117b3ob3o62bobo129bobo44bo3bo8bo35boobo4bo5bo36bo82bo67bo
10bo$118booboo196b3o43bobob3o4boob3o34boo4bobbobbo16bo19b3o81bo$102boo
14b5o198boo43boobobbo5boboo40bobbobbo12bo3boo103bo$102boo16bo194b3o4b
oo46bobo8bo39bo4bo16bobo105bo60bo$321boo14boo31boo11bobbo5boo23bobbo
19b3o109bo51b3o3b4o$336bo46b3o6boo24boo22bo110bo50bobo3booboo$333boobb
oo215bo49b3obbo$333boo106boo112bo53boo3bo$442boo112bo53b4o$393bo48bo
114bo53b3o$110boo219bo60boo48boo114bo23bo$110boo12bo54boo140boo3b7o59b
oboboo43boo116bo22bo5b3o49bo$122boo54bobo140boo3bo4boo60b3obooboo158bo
20bobo3boobbo47boo$70bo52boo55bo146boboo61bo3boobboo3boo154bo20bo3bo5b
o45b5o$69b3o83bo175bo60bo3bo7boo26bobobboo123bo19bo3bo50bo19bo$68boob
oo82boo171bobbo60bobbo10bo11bo4bobo6bobboobbo123bo23bobboo44boo5bo13bo
$67boobobo81bobo171bobbo40boo13boo4bo23bobobboobboo7boobbo124bo23boo
11boo32b3oboo8bobo5bo$66b3obb3o254b3o41boo13boo28bob4obbobo5boobbobo
125bo35boo33boboboobboo3bobo$67bo6bo254boo46boo39bo6bobo138bo70bobbobb
oo5bo$68b5obo254boo45boboo42bob3o140bo71boo$69b4oboo23b3o227boo29bo15b
o8b3o180bo35bo36boobo20boo$74bo23bo3bo256b3o15bobbo5boo181bo33b5o36bo
12b3o5boo$73bo12boo11boo257booboo17bo189bo32bobb3o46boobbo$86boo13boob
oo251boo3bo15boo46bo144bo26boo8boo46b3o$103boo253bobobobo12bo47bobo
144bo32bobbo48bo$359boobobbo59bobo126bo18bo21bo9b3o56b3o3bo$71bo290boo
bo60bo126bobo18bo10boo9boo7boo57boboob3o$69boobo74boo188bo25boo210bo8b
ob3o8boo64boo3bobb3o$146bobo187bobo214bobbo3bob3o11bo7bo3bo10bo68boboo
boo$72bo75bo186bo3bo13b3o38b3o24boo132bo4bo16bo7boobo5b5o6boo63bobboo$
69bobbo21boo27bo211bo3bo8bo45b3o14boo7boo134boboobobo14bo7bo10bo6bobbo
59booboo$70bo23boo27boo210bobob3o4boob3o41bo3bo7bobo4boo8bo11bo15bo
106boo3bo16bo23booboo$122bobo211boobobbo5boboo42boob3o5bobbobb3o19bobo
13bo108bo15boo4bo21bobo40boo4bo$75boo263bobo8bo42boo4bo4bobob6o18bobo
13b3o122boo5bo19boo42boo3bobo6boo$68b3o5boo262boo11bobbo40bobbo9bobboo
19bo147bo18bo3bo26boo15booboo4b3o$75boo276b3o42boo11b3o6boo161bo18bobb
o25bo17boobbo4bobbo$62b3o10bo336bo7boo162bo4boo11b3o26bobbo15boboo5boo
$61bo3bo519bo3boo38boob4o14bobo$60bo4bo520bo14bo26bo22boo$59bo3bo378bo
144bo13bo26bo3b3obbo12bobo$59bobbob3o355bo18bobo138boo4bo9boo28bobbobb
ob3o11bobo$59bo7bo352boobbo16bobo121bo16boo5bo8boo10bo19boo4b3o11boo$
61bo3bobo352bo4bo16bo9bo112b3o22bo7bobbo7boo21boobobo$61bo3boboo46boo
304boobbobboo21bobo103bo6bo3bo22bo7b3o6b5o20boobo$63b3oboo45bobo305bob
oobboo21bobo103bo3b3o4bo23bo7bo6bo19bo8bo$116bo303b4o13boo13bo104bo3b
3oboboo24bobo10boo5bo13bo$342boo76b3o13boo123boo3bo27boo9b3oboo8bobo5b
o$342boo56boo13boo21bo8boo157boboboobboo3bobo$400boo13boo29bobbo97bo
59bobbobboo5bo$405bo41boo98bo61boo$404boboo4bo134bo8bo54boobo$43bo20bo
bo321bo15bobbo4bobbo138bobo57bo12b3o$42b3o22bo319bobo15boboo5boo132b3o
bbo3bo67boobbo$41booboo17bobbo319bo3bo15boo141bob5o70b3o$42b3o17bobo
285boo34bo3bo13bobo148bo71bo$43bo17bobbo285boo34bobob3o12bo144boo$43bo
bo16boo323boobobbo$43b4o344bobo$46bo12boo330boo$24bo3boobboobo23boo22b
oo289bo$24bo3boo4boboo4booboo35bobo288bobo5bo148b3o$24bo3boobbooboo4bo
5bo36bo294booboo44boo121b3o$28boo12bo3bo326b3obbo3boo43bobo104boo15b3o
61boo$26bobbo13bo335booboo45bo106bo12bo4boo59boo$26bobo350b4o147b4obo
13bobo3bo$5bo21bo30boboo468b5o13boo3b3o$6boboobobo43b5o486boo3bo$3o3b
4o3bo43b4o294b3o193bo21bo$6bobbooboo501bo14bobo14bo3bo21boo$5bo52b3o
292bo5bo151boobobo7bo5bobo14bobo22bobo$3b3o52b3o292b7o151bobbooboobboo
boo5bo91boo$3b3o37boo14bo295bo155bo5bobo5bo4bobo90boo$24b3o16boo310bo
3bo17boo133boobbo8bo5boo$23bobbo327bo21bo139bobb3obbo6bo$23bo309bo21bo
14bo3bo141b3o$23bobbo305b3o21bo4bo8bob3obbo111bobo$23bobbo304bobobo20b
o4bo8boobo115bobobo7bo$25b3o302b3ob3o12bo5boobobo11bo4bo18boo90bobboob
o4b3o$24bobo321bobo3bobo15bo4bo17bobo91boo3boboboobo44bo$24bo26boo279b
ob3o13boo3bo16bo24bo91boo3boob5o10b3o29booboo$26bo24boo279b5o9bo3bo21b
o3bo116boboo3boo10bobo29b3oboo$20b3o4boo303boobboo11bobboo19b3o116bobo
16booboo15boo12b5o$19boboo6bo304boboo14bo158boo18boo13b3o$5bobooboo7bo
boo5boo306boo9bobboo195bo$4b5obboo7b3obo3bo303bobobbo11bo27boo$4bobb3o
bo8boo5bo303bobobbo40boo8bobo124bo$10bo12bobboo304bo56bo124bo$23boobo
3boo354boboo$25bo361bo5boo113b3o$392b3o112bo3bo27boo$347boo43b3o111bo
4bo27boo$11boo377boboo102boobo5bo3boo3bo$11boo334boo41bobo99bo3b6o11bo
$391bo99bo5bo4bobboo6b3o$22bo325bobo140bo11bo$22bo326bo142bo9bo$23bo
313boo10bo147bo$337boo158bobbo$22boo475bo$20bobbobo$20bo4bo$20bo478boo
$21b3o475boo$$345boo$345boo!
CB 1,1,1,1
]]
--# GollyTicker
patterns[2] = [[#CXRLE Pos=-5784,-1286
x = 864, y = 747, rule = B3/S23
225b4o7b2o$224bo3bo6bo2bo12b2o$224bo10bo2b2o11b2o$225bob2obo4bo2bo$
228b3o6bo2$228b3o6bo$227b2obo4bo2bo$226bo8bo2b2o$227b2o6bo2bo$228bo7b
2o3$261b2o$261b2o4$340b4o7b2o$255bo5bo77bo3bo6bo2bo12b2o$254b3o3b3o76b
o10bo2b2o11b2o$253bo2b2ob2o2bo76bob2obo4bo2bo$253bo3bobo3bo79b3o6bo$
255bobobobo$343b3o6bo$252b2ob2o3b2ob2o77b2obo4bo2bo$254bo7bo78bo8bo2b
2o$342b2o6bo2bo$343bo7b2o3$261bo114b2o$260b3o113b2o$259bo3bo$258bo5bo$
258bo5bo$259bo3bo191b4o7b2o$370bo5bo77bo3bo6bo2bo12b2o$259bo3bo105b3o
3b3o76bo10bo2b2o11b2o$258bo5bo103bo2b2ob2o2bo76bob2obo4bo2bo$254b2o2bo
5bo103bo3bobo3bo79b3o6bo$254b2o3bo3bo106bobobobo$260b3o195b3o6bo$261bo
105b2ob2o3b2ob2o77b2obo4bo2bo$369bo7bo78bo8bo2b2o$457b2o6bo2bo$458bo7b
2o3$376bo114b2o$375b3o113b2o$374bo3bo$373bo5bo89bo$373bo5bo76bo11b2o$
374bo3bo76bo12bobo99b4o7b2o$455b3o27bo5bo77bo3bo6bo2bo12b2o$374bo3bo
105b3o3b3o76bo10bo2b2o11b2o$373bo5bo103bo2b2ob2o2bo76bob2obo4bo2bo$
318bo50b2o2bo5bo103bo3bobo3bo79b3o6bo$317bo51b2o3bo3bo106bobobobo$317b
3o55b3o195b3o6bo$376bo105b2ob2o3b2ob2o77b2obo4bo2bo$484bo7bo78bo8bo2b
2o$572b2o6bo2bo$480b2o91bo7b2o$444bo34b2o$444bobo34bo$444b2o45bo114b2o
$490b3o113b2o$345bo143bo3bo$306bo38b2o141bo5bo$306bobo35bobo141bo5bo$
306b2o181bo3bo191b4o7b2o$600bo5bo77bo3bo6bo2bo12b2o$489bo3bo105b3o3b3o
76bo10bo2b2o11b2o$488bo5bo103bo2b2ob2o2bo76bob2obo4bo2bo$433bo37b2o11b
2o2bo5bo103bo3bobo3bo79b3o6bo$432bo39b2o10b2o3bo3bo106bobobobo$432b3o
36bo18b3o195b3o6bo$491bo105b2ob2o3b2ob2o77b2obo4bo2bo$599bo7bo78bo8bo
2b2o$333b2o352b2o6bo2bo$334b2o352bo7b2o$333bo225bo$559bobo$559b2o45bo
114b2o$605b3o113b2o$460bo143bo3bo$460b2o141bo5bo$459bobo141bo5bo$604bo
3bo191b4o7b2o$715bo5bo77bo3bo6bo2bo12b2o$322bo281bo3bo105b3o3b3o76bo
10bo2b2o11b2o$322b2o279bo5bo103bo2b2ob2o2bo76bob2obo4bo2bo$321bobo224b
o50b2o2bo5bo103bo3bobo3bo79b3o6bo$547bo51b2o3bo3bo106bobobobo$547b3o
55b3o195b3o6bo$606bo105b2ob2o3b2ob2o77b2obo4bo2bo$714bo7bo78bo8bo2b2o$
802b2o6bo2bo$803bo7b2o3$721bo114b2o$272bo37b2o408b3o113b2o$271bo39b2o
406bo3bo$271b3o36bo407bo5bo89bo$718bo5bo88b2o$719bo3bo89bobo$830bo5bo$
719bo3bo105b3o3b3o$718bo5bo103bo2b2ob2o2bo$663bo37b2o11b2o2bo5bo103bo
3bobo3bo$662bo39b2o10b2o3bo3bo106bobobobo$662b3o36bo18b3o$299bo421bo
105b2ob2o3b2ob2o$260bo38b2o528bo7bo$260bobo35bobo262b2o$260b2o302b2o$
563bo2$836bo$425b2o408b3o$426b2o406bo3bo$425bo225bo181bo5bo$651bobo
179bo5bo$651b2o181bo3bo2$552bo281bo3bo$552b2o279bo5bo$551bobo224bo37b
2o11b2o2bo5bo$777bo39b2o10b2o3bo3bo$777b3o36bo18b3o$836bo$375bo$375bob
o$375b2o4$502bo$501bo303bo$501b3o301b2o$804bobo2$364bo$363bo303bo$363b
3o301b2o$666bobo4$490bo$490bobo$490b2o7$253bo$214bo38b2o$214bobo35bobo
$214b2o5$644bo$644b2o$643bobo2$203bo$202bo$202b3o$732bo$731bo$731b3o$
368bo$329bo38b2o$329bobo35bobo262b2o$329b2o302b2o$632bo3$494b2o$495b2o
$494bo3$318bo$317bo$317b3o6$747b2o$748b2o$747bo3$7b2o$7b2o4$433bo37b2o
$432bo39b2o262bo$432b3o36bo225bo38b2o$69bo627bobo35bobo$69b2o626b2o$
68bobo2$559bo$559bobo$3o3b3o550b2o$o2bobo2bo186b2o$2obobob2o187b2o262b
o$2o5b2o186bo225bo38b2o$122b2o297bobo35bobo$122b2o297b2o$57b2o$58b2o
262bo$2b2ob2o50bo264b2o$o2bobo2bo312bobo224bo$obo3bo3bo3b3o530bo$3o3bo
3bo3bobo530b3o$8bo2bobo2bo$10b2ob2o130bo$145bobo$145b2o$674bo$46bo627b
obo$8b2o5b2o29b2o67b3o3b3o550b2o$8b2obobob2o28bobo67bo2bobo2bo148bo$8b
o2bobo2bo98b2obobob2o147bo303bo$8b3o3b3o98b2o5b2o147b3o301b2o$237b2o
335bobo$237b2o$134bo37b2o$133bo39b2o$117b2ob2o11b3o36bo$115bo2bobo2bo
539bo$115bobo3bo3bo3b3o530bo$34b2o79b3o3bo3bo3bobo530b3o$35b2o86bo2bob
o2bo167bo$27b2o5bo90b2ob2o130bo38b2o$27b2o231bobo35bobo262b2o$260b2o
302b2o$15b2o546bo$15b2o144bo$123b2o5b2o29b2o67b3o3b3o$123b2obobob2o28b
obo67bo2bobo2bo148bo$123bo2bobo2bo98b2obobob2o147bo$123b3o3b3o98b2o5b
2o147b3o262bo$352b2o297bobo$352b2o297b2o$287b2o$86b2o200b2o$86b2o144b
2ob2o50bo$230bo2bobo2bo$230bobo3bo3bo3b3o$27bo7bo44bo5bo143b3o3bo3bo3b
obo$26b4o3b4o42b3o3b3o61bo88bo2bobo2bo$26bo3bobo3bo42bob2ob2obo54b2o4b
3o89b2ob2o130bo$27bo2bobo2bo42b2o7b2o53b2o3bo3bo223bobo262bo37b2o$27b
3o3b3o42b2o7b2o58b2ob2o223b2o262bo39b2o$78b3o5b3o41b2o15b2ob2o487b3o
36bo$80b3ob3o43b2o$82bobo62b2ob2o86b2o5b2o98b3o3b3o$79bo2bobo2bo59b2ob
2o86b2obobob2o98bo2bobo2bo$78bo2bo3bo2bo58bo3bo86bo2bobo2bo98b2obobob
2o$79b2o5b2o60b3o14b2o71b3o3b3o98b2o5b2o$34b2o113bo14bo2bo299b2o$34b2o
128bobo300b2o$165bo236b2o$201b2o200b2o262bo$170b2o29b2o144b2ob2o50bo
264b2o$169bo2bo172bo2bobo2bo312bobo$169bobo173bobo3bo3bo3b3o$142bo7bo
19bo24bo5bo143b3o3bo3bo3bobo$141b4o3b4o42b3o3b3o61bo88bo2bobo2bo$141bo
3bobo3bo23b2o17bob2ob2obo54b2o4b3o89b2ob2o130bo$142bo2bobo2bo23bo2bo
15b2o7b2o53b2o3bo3bo223bobo$142b3o3b3o23bobo16b2o7b2o58b2ob2o223b2o$
86b2o87bo17b3o5b3o41b2o15b2ob2o$86b2o107b3ob3o43b2o144bo$180b2o15bobo
62b2ob2o86b2o5b2o29b2o67b3o3b3o$179bo2bo11bo2bobo2bo59b2ob2o86b2obobob
2o28bobo67bo2bobo2bo148bo37b2o$179bobo11bo2bo3bo2bo58bo3bo86bo2bobo2bo
98b2obobob2o147bo39b2o$180bo13b2o5b2o60b3o14b2o71b3o3b3o98b2o5b2o147b
3o36bo$149b2o113bo14bo2bo299b2o$149b2o128bobo300b2o$280bo198bo37b2o$
316b2o160bo39b2o$285b2o29b2o144b2ob2o11b3o36bo$284bo2bo172bo2bobo2bo$
284bobo173bobo3bo3bo3b3o$257bo7bo19bo24bo5bo143b3o3bo3bo3bobo$256b4o3b
4o42b3o3b3o61bo88bo2bobo2bo167bo$256bo3bobo3bo23b2o17bob2ob2obo54b2o4b
3o89b2ob2o130bo38b2o$257bo2bobo2bo23bo2bo15b2o7b2o53b2o3bo3bo223bobo
35bobo$257b3o3b3o23bobo16b2o7b2o58b2ob2o223b2o$201b2o87bo17b3o5b3o41b
2o15b2ob2o$201b2o107b3ob3o43b2o144bo$312bobo62b2ob2o86b2o5b2o29b2o67b
3o3b3o$309bo2bobo2bo59b2ob2o86b2obobob2o28bobo67bo2bobo2bo$308bo2bo3bo
2bo58bo3bo86bo2bobo2bo98b2obobob2o$309b2o5b2o60b3o14b2o71b3o3b3o98b2o
5b2o$264b2o113bo14bo2bo$264b2o128bobo$395bo$431b2o$400b2o29b2o144b2ob
2o$399bo2bo172bo2bobo2bo$399bobo173bobo3bo3bo3b3o$372bo7bo19bo24bo5bo
143b3o3bo3bo3bobo$371b4o3b4o42b3o3b3o61bo88bo2bobo2bo$371bo3bobo3bo42b
ob2ob2obo54b2o4b3o89b2ob2o$372bo2bobo2bo42b2o7b2o53b2o3bo3bo$372b3o3b
3o42b2o7b2o58b2ob2o$316b2o105b3o5b3o41b2o15b2ob2o$316b2o107b3ob3o43b2o
$427bobo62b2ob2o86b2o5b2o$424bo2bobo2bo59b2ob2o86b2obobob2o$423bo2bo3b
o2bo58bo3bo86bo2bobo2bo$424b2o5b2o60b3o14b2o71b3o3b3o$379b2o113bo14bo
2bo$379b2o128bobo$510bo$546b2o$546b2o3$487bo7bo44bo5bo$486b4o3b4o42b3o
3b3o61bo$486bo3bobo3bo42bob2ob2obo54b2o4b3o$487bo2bobo2bo42b2o7b2o53b
2o3bo3bo$487b3o3b3o42b2o7b2o58b2ob2o$431b2o105b3o5b3o41b2o15b2ob2o$
431b2o107b3ob3o43b2o$542bobo62b2ob2o$539bo2bobo2bo59b2ob2o$538bo2bo3bo
2bo58bo3bo$539b2o5b2o60b3o$494b2o113bo$494b2o2$661b2o$661b2o3$602bo7bo
44bo5bo$601b4o3b4o42b3o3b3o$601bo3bobo3bo42bob2ob2obo$602bo2bobo2bo42b
2o7b2o$602b3o3b3o42b2o7b2o$546b2o105b3o5b3o$546b2o107b3ob3o$657bobo$
654bo2bobo2bo$653bo2bo3bo2bo$654b2o5b2o$609b2o$609b2o11$661b2o$661b2o
6$685b2o$685b2o11$633b2o$633b2o$678b2o5b2o$678bob2ob2obo$679bobobobo$
679bobobobo$546b2o130bo7bo$546b2o78b3o3b3o$625bo2bo3bo2bo$625bo3bobo3b
o$624b2obobobobob2o43b2ob2o$624b2ob2o3b2ob2o41bo2bobo2bo$625b3o5b3o42b
3o3b3o$679bo5bo2$685b2o$685b2o2$494b2o137bo$494b2o136bobo$539b2o5b2o
83bo3bo$538bo2bo3bo2bo82b5o$539bo2bobo2bo82bobobobo$542bobo86bo3bo$
431b2o107b3ob3o67b2o$431b2o105b3o5b3o65b2o15bo3bo$487b3o3b3o42b2o7b2o
81bobobobo$487bo2bobo2bo42b2o7b2o77b2o3b5o$486bo3bobo3bo42bob2ob2obo
78b2o3bo3bo$486b4o3b4o42b3o3b3o84bobo$487bo7bo44bo5bo86bo3$546b2o$546b
2o$510bo$379b2o128bobo$379b2o128bo2bo94b3o3b3o$424b2o5b2o77b2o95b3o3b
3o$423bo2bo3bo2bo172bob2o3b2obo$424bo2bobo2bo173bob2o3b2obo$427bobo
177b2o5b2o$316b2o107b3ob3o43b2o131bo5bo$316b2o105b3o5b3o41b2o$372b3o3b
3o42b2o7b2o$372bo2bobo2bo42b2o7b2o53b2o11bo$371bo3bobo3bo42bob2ob2obo
54b2o5bo5b2o107b2ob2o$371b4o3b4o42b3o3b3o62b2o2bobo98bo6b2o5bo$372bo7b
o44bo5bo62b2o102b2ob2o3bobobob2ob2o$598b2ob2obobobo3b2ob2o$600bo5b2o6b
o2b2o$431b2o168b2ob2o11bobo$431b2o184bo$395bo$264b2o128bobo87b2o$264b
2o128bo2bo85bobo114bo5bo$309b2o5b2o77b2o71b3o3b3o8bo113b2o5b2o$308bo2b
o3bo2bo149bo2bobo2bo11b2o108bob2o3b2obo$309bo2bobo2bo73b2o75b2obobob2o
12b2o107bob2o3b2obo$312bobo76b2o75b2o5b2o11bo110b3o3b3o$201b2o107b3ob
3o43b2o237b3o3b3o$201b2o87bo17b3o5b3o41b2o$257b3o3b3o23bobo16b2o7b2o
309b3o$257bo2bobo2bo23bo2bo15b2o7b2o53b2o254bo$256bo3bobo3bo23b2o17bob
2ob2obo54b2o5bo90b2ob2o154bo$256b4o3b4o42b3o3b3o62b2o86bo2bobo2bo$257b
o7bo19bo24bo5bo62b2o79b3o3bo3bo3bobo$284bobo173bobo3bo3bo3b3o$284bo2bo
172bo2bobo2bo$285b2o29b2o144b2ob2o$316b2o$280bo$149b2o128bobo87b2o235b
2o$149b2o128bo2bo85bobo235b2o$194b2o5b2o77b2o71b3o3b3o8bo89b2o5b2o$
193bo2bo3bo2bo149bo2bobo2bo98b2obobob2o210bobo$194bo2bobo2bo73b2o75b2o
bobob2o28bobo67bo2bobo2bo211b2o$197bobo76b2o75b2o5b2o29b2o67b3o3b3o
211bo$195b3ob3o43b2o144bo$193b3o5b3o41b2o$142b3o3b3o42b2o7b2o$142bo2bo
bo2bo42b2o7b2o53b2o$141bo3bobo3bo42bob2ob2obo54b2o5bo90b2ob2o$141b4o3b
4o42b3o3b3o62b2o86bo2bobo2bo$142bo7bo44bo5bo62b2o79b3o3bo3bo3bobo$345b
obo3bo3bo3b3o289b3o$345bo2bobo2bo297bo39bo$201b2o144b2ob2o11b3o36bo
249bo39b2o$201b2o160bo39b2o286b2o$364bo37b2o$254b2o211b2o$149bo103bobo
211b2o$148b3o87b3o3b3o8bo89b2o5b2o$147bo3bo86bo2bobo2bo98b2obobob2o$
147b2ob2o86b2obobob2o28bobo67bo2bobo2bo$147b2ob2o86b2o5b2o29b2o67b3o3b
3o$130b2o144bo386b2o$130b2o15b2ob2o511bobo$147b2ob2o511bo38bobo$142b2o
3bo3bo551b2o$142b2o4b3o89b2ob2o458bo$149bo88bo2bobo2bo$230b3o3bo3bo3bo
bo$230bobo3bo3bo3b3o$230bo2bobo2bo$232b2ob2o50bo$288b2o$287b2o$352b2o
320b3o$352b2o320bo39bo$123b3o3b3o98b2o5b2o186bo249bo39b2o$123bo2bobo2b
o98b2obobob2o187b2o286b2o$123b2obobob2o98bo2bobo2bo186b2o$123b2o5b2o
98b3o3b3o3$260b2o$260bobo35bobo$125b2ob2o130bo38b2o$123bo2bobo2bo167bo
386b2o$115b3o3bo3bo3bobo554bobo$115bobo3bo3bo3b3o266b2o286bo$115bo2bob
o2bo274bobo35bobo$117b2ob2o50bo225bo38b2o$173b2o262bo$172b2o$237b2o$
237b2o$115b2o5b2o147b3o$115b2obobob2o147bo$115bo2bobo2bo148bo$115b3o3b
3o2$409b3o36bo$409bo39b2o$183bobo224bo37b2o$184b2o$184bo$547b3o$283b2o
262bo$283bobo262bo$283bo$709b2o$709bobo$122b2o585bo$122b2o335bobo$195b
o264b2o$196b2o262bo$195b2o$559b2o$559bobo$294b3o36bo225bo$294bo39b2o$
295bo37b2o3$471bo$472b2o$206bobo262b2o$207b2o$207bo2$306b2o$306bobo$
306bo3$771bobo$772b2o$772bo8$743b3o$743bo39bo$744bo39b2o$783b2o11$505b
obo$506b2o$506bo2$605b2o$605bobo$340b3o262bo$340bo$341bo8$616b3o$352b
2o262bo$352bobo35bobo224bo$352bo38b2o$391bo2$490b2o$490bobo$490bo10$
501b3o$501bo$502bo3$639b3o$639bo$413bobo224bo$414b2o444bo$414bo386b2o
56bobo$801bobo$513b2o286bo38bobo10b2o2bo5bo$513bobo325b2o10b2o5bo$513b
o327bo15b2o3b2o4$857b2o3b2o$425bo434bo$426b2o429bo5bo$425b2o$812b3o44b
obo$812bo47bo$524b3o36bo249bo34bobo$524bo39b2o282b2o$525bo37b2o284bo3b
o7bo$852bobo5bobo$721bo133bo3bo$720b3o129bo2bo3bo2bo$714b2o3bo3bo129bo
bo3bobo$714b2o2bo5bo130b2ob2o$718bo5bo127b2ob2ob2ob2o$719bo3bo128b2o2b
obo2b2o$853b3o3b3o$536b2o181bo3bo130bo5bo$536bobo179bo5bo$536bo181bo5b
o$719bo3bo$720b3o137b2o$721bo138b2o$711bo$709b2o$710b2o114b2o7b3o$825b
o2bo4bo4bo$714bo7bo102bo2bo4bo5bo$606bo105b2ob2o3b2ob2o100bo3bo8bo$
547b3o55b3o218b2o8b2o$547bo51b2o3bo3bo106bobobobo$548bo50b2o2bo5bo103b
o3bobo3bo102b2o8b2o$603bo5bo103bo2b2ob2o2bo105bo8bo$604bo3bo105b3o3b3o
100b2o8bo5bo10b2o$715bo5bo101bo9bo4bo11b2o$604bo3bo89bobo126bo7b3o$
603bo5bo88b2o124bo2bo$603bo5bo89bo$604bo3bo$605b3o113b2o$559b2o45bo
114b2o$559bobo$559bo$688bo7b2o$687b2o6bo2bo$599bo7bo78bo8bo2b2o$491bo
105b2ob2o3b2ob2o77b2obo4bo2bo$471bo18b3o195b3o6bo$472b2o10b2o3bo3bo
106bobobobo$471b2o11b2o2bo5bo103bo3bobo3bo79b3o6bo$488bo5bo103bo2b2ob
2o2bo76bob2obo4bo2bo$489bo3bo105b3o3b3o76bo10bo2b2o11b2o$600bo5bo77bo
3bo6bo2bo12b2o$489bo3bo89bobo99b4o7b2o$488bo5bo88b2o$488bo5bo89bo$489b
o3bo$490b3o113b2o$444b2o45bo114b2o$444bobo34bo$444bo34b2o$480b2o91bo7b
2o$572b2o6bo2bo$484bo7bo78bo8bo2b2o$376bo105b2ob2o3b2ob2o77b2obo4bo2bo
$375b3o195b3o6bo$369b2o3bo3bo106bobobobo$369b2o2bo5bo103bo3bobo3bo79b
3o6bo$373bo5bo103bo2b2ob2o2bo76bob2obo4bo2bo$374bo3bo105b3o3b3o76bo10b
o2b2o11b2o$455b3o27bo5bo77bo3bo6bo2bo12b2o$374bo3bo76bo12bobo99b4o7b2o
$373bo5bo76bo11b2o$373bo5bo89bo$374bo3bo$375b3o113b2o$376bo114b2o3$
458bo7b2o$457b2o6bo2bo$369bo7bo78bo8bo2b2o$367b2ob2o3b2ob2o77b2obo4bo
2bo$458b3o6bo$370bobobobo$368bo3bobo3bo79b3o6bo$368bo2b2ob2o2bo76bob2o
bo4bo2bo$369b3o3b3o76bo10bo2b2o11b2o$370bo5bo77bo3bo6bo2bo12b2o$455b4o
7b2o4$376b2o$376b2o3$343bo7b2o$342b2o6bo2bo$341bo8bo2b2o$342b2obo4bo2b
o$343b3o6bo2$343b3o6bo$340bob2obo4bo2bo$339bo10bo2b2o11b2o$339bo3bo6bo
2bo12b2o$340b4o7b2o!
]]
--# CordershipGun
patterns[3] = [[#C p784 six-engine Cordership gun: Dave Greene, 2 May 2003
#C Herschel-based insertion of 37 gliders into three salvos
x = 1285, y = 1065, rule = B3/S23
906bo6boo$906b3o4bobbobo$909bo5boob3o$908boo11bo$915boob3o$915boobo3$
904boo3boo$904boo3boo4$900bo$899bobo$900bo7$917boo$917boo5$939boo$929b
oo6boboo$929boo5bo$907boo30bo$908bo26boobo$905b3o27boo$905bo$932bo$
931bobo$931boo$935boo16bo$935bobo14b3o$914boo14boo5bo6boo5bob3o$915bo
14boo5boo4bobo4bo3bo$864bo6boo39b3o26b3o5bo3bo$864b3o4bobbobo23bo11bo
27bo3bo3b3obo$867bo5boob3o20boo39bobboo4b3o$866boo11bo18boboo36boo10bo
$873boob3o18b3obbo35bo7bo$873boobo22bobobo32bobo6bobo$900bobobo31boo3b
oobboo$901bobb3o34boo$862boo3boo33boobo$862boo3boo34boo$903bo3bo$906bo
bo40bo$907boo41bo$858bo44boo43b3o$857bobo42bobo$858bo43bo5boo$901boo5b
oo$935boo$935boobboo$939bobo$940bo$943b3o$875boo60boo3bo$875boo61bo3bo
3bo$935b3o4bobbobo$935bo8bobobbo$945bo3bo$949bo$897boo47b3o31bo$887boo
6boboo79b3o$887boo5bo82bo$865boo30bo53bo25boo$866bo26boobo53bobo9boo$
863b3o27boo54bo3bo9bo$863bo84bo3bo10bobo$890bo56bo3bo12boo10bo$889bobo
32bo21bo3bo24bobo$889boo56bobo25bobo$893boo16bo10bob3o21bo27bo4boo$
893bobo14b3o11boobo16bo19boo15bobo$872boo14boo5bo6boo5bob3o10boboo15bo
bo17bobo17bo8b3o$822bo6boo42bo14boo5boo4bobo4bo3bo12b3obo13boo18bo19b
oo10bo$822b3o4bobbobo35b3o26b3o5bo3bo35boo13boo27bo3bo$825bo5boob3o21b
o11bo27bo3bo3b3obo16bo19bobo40bobobbo$824boo11bo19boo39bobboo4b3o21bo
10boo5bo38bobbobo$831boob3o19boboo36boo10bo21bobo9boo5boo37bo3bo$831b
oobo20b3obbo35bo7bo26boo55bo$857bobobo12b3o17bobo6bobo21boo60b3o$858bo
bobo13bo17boo3boobboo21bobo44boo11bo$820boo3boo32bobb3o10bo23boo25bo5b
oo39boo10bobo$820boo3boo33boobo61boo5boo51boo$861boo97boo27boo$861bo3b
o92boboo27bobo$864bobo90bo26boo5bo$816bo48boo93bo23boo5boo$815bobo43b
oo70b3o20boobo$395boo6bo412bo43bobo70b3o20boo$391bobobbo4b3o456bo5boo
65b3o25bo$389b3oboo5bo458boo5boo68b3o14bo7b3o$388bo11boo491boo41b3o13b
obo9bo$389b3oboo498boobboo37b3o13boo9boo$391boboo502bobo56boo$898bo42b
o14bobo$833boo66b3o36bobo8boo5bo$399boo3boo427boo60boo3bo40boo8boo5boo
$399boo3boo490bo3bo3bo32boo$893b3o4bobbobo30bobo45boo$893bo8bobobbo28b
o5boo40bo$903bo3bo27boo5boo38bobo$409bo444b3o50bo74boo$408bobo434boo7b
3o47b3o31bo$409bo435boo7b3o79b3o$823boo26b3o81bo$824bo26b3o55bo25boo$
821b3o27b3o54bobo9boo74bo$774bo6boo38bo85bo3bo9bo72b3o$774b3o4bobbobo
61bo57bo3bo10bobo69bo$777bo5boob3o58bobo55bo3bo12boo10bo58boo$391boo
383boo11bo57boo33bo21bo3bo24bobo42boo$391boo390boob3o62boo15b3o34bobo
25bobo43bo$783boobo64bobo17bo8bob3o21bo27bo4boo27boo9bobo$830boo14boo
5bo6boo5bo3bo10boobo16bo19boo15bobo26boo10boo10bo$831bo14boo5boo4bobo
4bobobbo10boboo15bobo17bobo17bo8b3o31boo5bobo$772boo3boo49b3o26b3o4bo
bbobo13b3obo13boo18bo19boo10bo29bobbo4bobo$369b3o400boo3boo36boo11bo
27bo3bo3bo3bo36boo13boo27bo3bo30boo6bo4boo$369b3o7boo475bobboo3bo20bo
19bobo40bobobbo26boo15bobo$369b3o7boo432bo3bo36boo9b3o21bo10boo5bo38bo
bbobo27bobo17bo$372b3o26boo410bo4bo35bo7bo25bobo9boo5boo37bo3bo28bo19b
oo$372b3o26bo366bo46bobobo32bobo6bobo25boo55bo31boo$372b3o27b3o362bobo
46bobobo31boo3boobboo22boo60b3o$404bo363bo48bo4bo34boo25bobo44boo11bo$
377bo440bo3bo61bo5boo39boo10bobo$376bobo504boo5boo51boo$377boo440boobb
o94boo27boo$355b3o15boo447bobo91boboo27bobo39boo6boo$354bo17bobo448boo
90bo26boo5bo39boo5boo$354bo3bo5boo6bo5boo14boo423boo97bo23boo5boo47bo$
354bobbobo4bobo4boo5boo14bo390boo31bobo70b3o20boobo$356bobobbo4b3o26b
3o38boo6bo340boo31bo5boo65b3o20boo$357bo3bo3bo3bo27bo11boo21bobobbo4b
3o372boo5boo65b3o25bo$361bo3boobbo60b3oboo5bo409boo41b3o14bo7b3o$358b
3o9boo36bo3bo16bo11boo364bo43boobboo37b3o13bobo9bo$363bo7bo35bo4bo17b
3oboo371boo46bobo36b3o13boo9boo72booboo$362bobo6bobo32bobobo21boboo
370boobo46bo3bo53boo78bobobobo$363boobboo3boo31bobobo387boo6bobb3o48b
oo38bo14bobo60boo16bobbobo$367boo34bo4bo388boo5bobobo44boo3boboo36bobo
8boo5bo61bo19boboo$403bo3bo32boo3boo328boo26bobobo46bobb3obbo36boo8boo
5boo60bobo16boo3bo$440boo3boo329bo24b3obbo44b3o5bobobo31boo82boo13bobo
bbobo$402bobboo366b3o26boboo45bo8bobobo23boboobbobo45boo50boobbooboo$
401bobo369bo29boo56bobb3o21boobobbo5boo40bo$401boo397bo3bo57boobo26b3o
5boo38bobo$405boo43bo348bobo61boo75boo160boo$405bobo41bobo347boo62bo
30b3o205boo$400boo5bo42bo352boo88bo3boboo$400boo5boo394bobo15boo44bo
26bobboobo$373boo407boo14boo5bo6boo5boboo43b3o9boo10bo3bo$369boobboo
408bo14boo5boo4bobo4bo46bob3o9bo10bo63bo$368bobo361bo6boo39b3o26b3o9bo
42bo3bo10bobo9bo60b3o$365bo3bo362b3o4bobbobo35bo27bo3bo4boobo42bo3bo
12boo3boo64bo$365boo368bo5boob3o21bo39bobboo4boo43b3obo17bobo64boo27b
oo15boo$364boobo3boo59boo300boo11bo19bobo36boo31boo22b3o18bo51boo42boo
15bobo$363bobb3obbo60boo307boob3o19bo3bo35bo7bo24boobo21bo19b3o3bo6boo
38bo34boo25bo117boo$362bobobo5b3o366boobo22bo3bo32bobo6bobo27bo16bo19b
oo5boobbo5bobo9bo16boo9bobo33bo25boo116boo$361bobobo8bo393bo3bo31boo3b
oobboo25bo18bobo17bobo5boobo8bo9boo15boo10boo10bo22bobo$359b3obbo45boo
357bo3bo35boo30boboo14boo18bo9bo9boo7boobo30boo5bobo22boo73boo$360bob
oo366boo3boo33bobo70boo18boo13boo27bobb3o28bobbo4bobo97boo$329bo31boo
45bo3bo317boo3boo34bo91bobo40bobobo31boo6bo4boo$329b3o30bo45bo4bo6boo
353bo71bo10boo5bo39bobobo28boo15bobo$332bo77bobobo5boo314bo37bobo69bob
o9boo5boo36b3obbo28bobo17bo35bo$331boo25bo52bobobo26boo291b4o36boo70b
oo55boboo29bo19boo32b3o$346boo9b3o52bo4bo24bo283bo6boo3bo32boo70boo60b
oo29boo52bo$346bo9b3obo52bo3bo25b3o279bobo4bobo4bo30bobo69bobo44boo11b
o3bo83boo20bo$344bobo10bo3bo83bo280bo4bobbo35bo5boo64bo5boo39boo10bobo
90boo16b3o82boo$333bo10boo12bo3bo51boobbo311bo8bo29boo5boo63boo5boo51b
oo92bo19bo82bo$332bobo24bob3o53bobo311bobo69boo70b3o27boo86bo20boo11b
oo66b3o$332bobo25b3o22boo31boo313bo69boobboo66b3o27bobo85boo32boo66bo$
327boo4bo27bo21boboo27boo317boo72bobo65b3o22boo5bo39boo$316bo9bobo15b
oo19bo16bo13b3o14bobo318bo73bo41bo21b3o25boo5boo38boo$315boo9bo17bobo
17bobobboo14bo10b3o6boo6bo5boo14boo412bobo20b3o$314boboo7boo19bo18boob
oo11boobo11b3o6bobo4boo5boo14bo307boo60boo4b3o34bo3bo19b3o184boo$313b
3obbo27boo13boo7bo10boo16b3o5b3o26b3o39boo6bo256boo61bo4b3o35bo3bo23bo
181boo$315bobobo40bobo36b3o4bo3bo27bo35bobobbo4b3o316b3o5b3o36bo3bo14b
o7b3o116boo90boo$316bobobo39bo5boo10bo20b3o4boobbo39bo21b3oboo5bo319bo
10b3o34bo3bo12bobo9bo91boo3boo17boo91bo$317bobb3o36boo5boo9bobo31boo
36b3o19bo11boo329b3o35bobo13boo9boo92bo3boo110bobo15boo$318boobo55boo
25bo7bo35bob3o19b3oboo287bo48b3o36bo18boo79booboo13bo66boo50boo15boo$
319boo60boo20bobo6bobo32bo3bo22boboo268bo17b3o81bo8bo14bobo77bobobobo
12boo64bobo$319bo3bo11boo44bobo20boobboo3boo31bo3bo294bobo7boo6bob3o
78b3o7bobo8boo5bo60boo16bobbobo14bobboo59bo$322bobo10boo39boo5bo24boo
35b3obo295bobo7boo5bo3bo78bo11boo8boo5boo60bo19boboo13bo3bo58boo$323b
oo51boo5boo61b3o33boo3boo244boo11bo14bo3bo53bo25boo6boo81bobo16boo3bo
13b3o12boo$319boo27b3o96bo34boo3boo245bo25b3obo65boo20bobo45boo35boo
13bobobbobo16bobo10bo16bo$318bobo27b3o92bo287b3o27b3o53b3obo9bo20bo5b
oo40bo51boobbooboo16boo11b3o7boobobobo$318bo5boo22b3o91bobo286bo30bo
53boboo11bobo17boo5boo38bobo91bo7bobooboo20boo$317boo5boo25b3o21bo66b
oo314bo57boobo12boo10bo53boo127bo$351b3o20bobo69boo44bo264bobo31b3o20b
ob3o17bo6bobo182b3o$351b3o19bo3bo68bobo42bobo263boo20boo9bo45bo6bobo
184bo$348bo23bo3bo64boo5bo43bo268boo27bo3bo21bo27bo4boo209boo$346b3o7b
o14bo3bo65boo5boo311bobo14bo3bo7bobbobo16bo19boo15bobo208boo46boo$345b
o9bobo12bo3bo39boo324boo14boo5bo6boo5bo4bo9bobobbo13bobo17bobo17bo60bo
195bobo$345boo9boo13bobo36boobboo274bo6boo42bo14boo5boo4bobo4bobobo12b
o3bo13boo18bo19boo7b3o47b3o197bo$352boo18bo36bobo278b3o4bobbobo35b3o
26b3o5bobobo17bo17boo13boo28b3o46bo200boo$351bobo14bo41bo282bo5boob3o
33bo27bo3bobbo4bo15b3o18bobo42b3o46boo$351bo5boo8bobo36bo285boo11bo60b
obboobbo3bo21bo10boo5bo39b3o34boo42boo15boo$350boo5boo8boo36bobo4boo
60boo223boob3o20boo26bobo8boo32bobo9boo5boo38b3o35bo42boo15bobo$371boo
31bo3bo3bo61boo223boobo22boobo25boo8bo7bobboo22boo56b3o24boo9bobo32boo
25bo$324boo45bobo29bo3bo5b3o313bo24bo7bobo6bobo21boo87boo10boo10bo22bo
25boo$325bo40boo5bo28bo3bo8bo310bo35boo3boobboo21bobo44boo11bo52bobo
21bobo141boo$325bobo38boo5boo26bo3bo47bo234boo3boo32boboo36boo25bo5boo
26bo12boo10bobo51bobo22boo73boo66boo$326boo74bobo47boo234boo3boo34boo
62boo5boo26boo23boo53bo4boo92boo$370bo32bo47boboo372boobo26boo37boo15b
obo175boo$370b3o77b3obbo6boo269bo92bobb3o25bobo35bobo17bo175bo42bobo$
373bo78bobobo5boo268bobo66boo22bobobo22boo5bo35bo19boo34bo140bo41boobo
$372boo79bobobo26boo198bo48boo89bobobo23boo5boo33boo53b3o139boo27bo16b
3o15bo$313bo73boo9boo54bobb3o24bo198bobo43boo68bo3bo18b3obbo120bo171b
3o11boo4bo14b3o$313b3o71bo10boobo53boobo26b3o196bo43bobo68bo4bo18boboo
121boo20bo152bo10bob5o17bo$316bo68bobo14bo53boo29bo240bo5boo65bobobo
18boo3bo122boo16b3o127boo20boo12bo20boo$315boo57bo10boo12bo26bo29bo3bo
266boo5boo66bobobo14bo3bo3b3o121bo19bo126boo33bo3boo26boo$330boo41bobo
5boo17boboo22boo31bobo299boo40bo4bo11bobo9bo118bo20boo11boo68boo52boo
23bo3bobo26bo$330bo42bobo4bobbo18boo21boobo31boo299boobboo37bo3bo11boo
9boo72boo44boo32boo69bo50bobbo23boo3bo25bobo31b3o$328bobo9boo26boo4bo
6boo41bobb3o26boo307bobo42b3o11boo79boo146b3o51boo4boo44boo4boo32b3o$
317bo10boo10boo25bobo15boo19bo16bobobo10boo15bobo308bo38boobb5o10bobo
226bo37boo20bo44bobbo26bo10b3o$316bobo5boo31bo9bo17bobo17bobo14bobobo
11boobo5boo6bo5boo14boo222boo67bo37bobboboo4boo5bo265bo18bobo45boo27b
3o5b3o$316bobo4bobbo29bobo7boo19bo18boo12b3obbo16bo4bobo4boo5boo14bo
223boo60boo44b5o5boo5boo189boo73bobo16boo34boo42bo4b3o$311boo4bo6boo
29bo3bo27boo13boo17boboo14bo9b3o26b3o283bo3bob3o32boo3boo142booboo58b
oo3bo70boo52boo41boo4b3o$310bobo15boo26bo3bo40bobo18boo16boboo4bo3bo
27bo280b3o6boobo30bobo5bo39boo100booboo5boo55bo$310bo17bobo26bo3bo16bo
22bo5boo10bo3bo18boo4boobbo39bo24boo6bo197boo36bo8boboo30bo5boo40bo77b
oo3boo17boo7bobboo53b3o169bo$309boo19bo27bo3bo13bo23boo5boo9bobo32boo
36bobo19bobobbo4b3o245b3obo27boo5boo38bobo58booboo15bo3boo19b3o3b3obbo
78boo111bo32bobo$330boo27bobo56boo26bo7bo35bo3bo16b3oboo5bo199bo3bo
123boo58bobobobo12bo22bo3bo5bo4bo28boo49bo59b3o48bobo15bo11boobboo$
360bo14boo3bo41boo21bobo6bobo32bo3bo16bo11boo189boo6bo4bo46bo32bo86boo
16bobbobo12boo21bo3b3o3b5o28bobo49bobo15boo40boboboo45bobo13b3o11boo
11bo$364bo10bo3bo42bobo21boobboo3boo31bo3bo18b3oboo196boo5bobobo79b3o
87bo19boboo13bobboo16bo10boo30bo52boo15boo40bobobbo46bo13bo27b3o$363bo
bo10b3o10boo26boo5bo25boo35bo3bo21boboo174boo26bobobo53bo25bo90bobo16b
oo3bo12bo3bo58boo116b3o58boo29bo$364boo51boo5boo62bobo201bo24bo4bo54b
oo24boo90boo13bobobbobo14b3o12boo164boo7boo32boo3boo40boo$156boo202boo
25bo3bo88bo8bo199b3o25bo3bo54boobo8boo74bo45boobbooboo15bobo10bo165bo
8boo11boo20bo3bo51boo$157bo161boo38bobo25bo4bo86boo4boo34boo3boo161bo
85bobb3o8bo72b3o70boo11b3o7boobo173bo18b3o5b3o48bo$157bobo159boo38bo5b
oo22bobobo85bobobbobbo33boo3boo188bobboo53bobobo10bobo69bo88bo7boboo
23boo105boo5boo35b3o15bo9bo46bobo$158boo198boo5boo23bobobo21bo67boo
229bobo55bobobo12boo10bo58boo122bo106bobboobboo37bo66boo4boo$391bo4bo
92bo225boo33bo20b3obbo24bobo42boo138b3o104boobo107bobbo$392bo3bo17b3ob
o68boobo228boo28bobo20boboo25bobo43bo140bo105bo23boo85boo$389bo23boboo
66boo5bo40bo187bobo14b3o9bo3bo20boo27bo4boo27boo9bobo168boo74bo23bo74b
oo$387b3o3boobbo15boobo66boo5boo38bobo165boo14boo5bo6boo6b3o10bo3bo16b
o3bo15boo15bobo26boo10boo5bobo3boo155boo75boobboo18b3o71boo$386bo9bobo
12bob3o40boo73bo167bo14boo5boo4bobo6b3o11bo3bo14bobo17bobo17bo9bo36boo
5bo146bo86bobbo20bo$157boo151booboo71boo9boo53boobboo192bo6boo37b3o26b
3o5b3o15bo3bo13boo18bo19boo45b3ob3o145boo56boo29boo$157boo4boo144bobob
obobb3o72boo18bo37bobo196b3o4bobbobo33bo27bo3bo4b3o16bobo18boo13boo27b
3obo38boo3boo142boo55bobo$163boo144bobobbo3bo12boo59bobo14bo42bo200bo
5boob3o19bo39bobboo4b3o17bo19bobo40boboo28boo15bobo28boo15boo153bo92b
oo$308boobo7bo11bo60bo5boo8bobo241boo11bo17b3o36boo33bo10boo5bo40boobo
27bobo17bo28boo15bobo152boo91boo$307bo3boo15boobo59boo5boo8boo37b3o4b
oo203boob3o17b3obo35bo7bo25bobo9boo5boo37bob3o28bo19boo19boo25bo$308bo
bobbobo14bo81boo33b3o4bo204boobo20bo3bo32bobo6bobo25boo87boo41bo25boo$
162boo143booboobboo10bo38boo45bobo32b3o5b3o55boo169bo3bo31boo3boobboo
22boo61bo72bobo310boo3boo$158boobboo159boo41bo40boo5bo29b3o10bo55boo
170bob3o35boo25bobo44boo11bo77boo73boo66boo147boo19bo3bo$157bobo163b4o
bo37bobo38boo5boo28b3o201boo3boo31b3o63bo5boo39boo10bobo151boo66boo15b
o131bobo5bo9b3o5b3o$157bo12boo154b3o38boo75b3o201boo3boo32bo63boo5boo
26bo24boo236bobo132bo5boo8bo9bo$156boo11bobo151boobboo83bo278bo93b3o
27boo232boo133boo3boobo$169bo18bo133bobb3o84b3o77bo197bobo91bob3o26bob
o39boo50bo278bobb3o$168boo18b3o60bo18bo50b3obboo87bo275boo90bo3bo22boo
5bo39boo48b3o139boo127bo8bobobo$191bo59b3o6boo6b3o51bobbo88boo25bo48bo
b3o6boo141bo42boo70b3o20bo3bo23boo5boo87bo142bo42bobo83b3o5bobobo$190b
oo62bo5boo5bo55b3o28bo74boo61boobo5boo140bobo40bobo69bo22b3obo120boo
20bo121bo41boobo85bobb3obbo$187boo64boo12boo55bo29b3o72bo9bob3o48boboo
27boo54boo6bo56bo41bo5boo64bo3bo19b3o125boo16b3o118boo27bo16b3o15bo66b
oo3boboo$187bob5o163bo69bobo11boobo48b3obo25bo51bobobbo4b3o97boo5boo
64bobbobo19bo3bo123bo19bo146b3o11boo4bo14b3o70boo$193bo117boo15boo26b
oo58bo10boo12boboo79b3o46b3oboo5bo134boo39bobobbo13bo7b3o119bo20boo11b
oo136bo10bob5o17bo66bo3bo56boo$188boobo74boo42bobo15boo41boo42bobo24b
3obo20b3o25bo30bo45bo11boo133boobboo36bo3bo12bobo9bo118boo32boo68boo
43boo20boo12bo20boo65bobo24bo32boboo$188booboo68boo3boo42bo25boo33bo
43bobo52bo28bo73b3oboo144bobo39bo12boo9boo72booboo146bo43boo33bo3boo
26boo51boobboo57bo$261boo46boo25bo32bobo9boo27boo4bo27bo21bo3bo27bobo
74boboo145bo37b3o17boo78bobobobo142b3o53boo23bo3bobo26bo52boo27b3obo
32bo$176boo156bobo21bo10boo10boo26bobo15boo19bo16bobobbo28boo227bo38bo
14bobo60boo16bobbobo142bo53bobbo23boo3bo25bobo31b3o37bo8boboo30boobo$
176boo156boo21bobo49bo17bobo17bobo13bobbobo9bo16boo164boo58boo4bobo36b
obo8boo5bo61bo19boboo105boo88boo4boo44boo4boo32b3o37b3o6boobo30boo$
357bobo38b3o7boo19bo18boo13bo3bo9bobo14bobo86boo3boo71boo59bo3bo3bo36b
oo8boo5boo60bobo16boo3bo104boo72boo20bo44bobbo26bo10b3o40bo3bob3o6b3o$
192boo78bo79boo4bo39b3o28boo13boo17bo12bo3bo5boo6bo5boo14boo65boo3boo
129b3o5bo3bo31boo82boo13bobobbobo42boo136bo18bobo41bo3boo27b3o5b3o42b
oo14b3o19bo$192boo76b3o78bobo15boo27b3o42bobo18b3o10bo3bo4bobo4boo5boo
14bo202bo8bo3bo23boboobbobo45boo50boobbooboo17boo3boo17boo136bobo16boo
34boo4bobo35bo4b3o49bo8b3o18bobo$269bo46bo34bo17bobo29b3o39bo5boo10bo
16bo3bo5b3o26b3o209bo3bo22boobobbo5boo40bo78bo3boo156boo52boo5boo34boo
4b3o45bo15b3o15boo5boo$269boo45b3o31boo19bo29b3o38boo5boo9bobo16bo3bo
3bo3bo27bo163bo46bobo27b3o5boo38bobo76bo66boo48boo195bobo14b3o19boobbo
$319bo51boo28b3o56boo18bobo4boobbo38b3o60bo88b3o46bo76boo77boo64bobo
49bo145bo22boo21boobboo15b3o19boboo$297bo20boo144boo15bo10boo39bo58bob
o78boo6bob3o76b3o124bobboo59bo51bobo15boo92bo32bobo21boobboo17boo36boo
5bo12bo$295b3o16boo90bo11boo44bobo18bo7bo35bo3bo59bo79boo5bo3bo76bo3bo
boo120bo3bo58boo52boo15boo91bobo15bo11boobboo26bobo42bo11boo5bo12boo$
294bo19bo90bobo10boo12bo26boo5bo17bobo6bobo32bobobbo117boo26bo3bo77boo
bboobo121b3o12boo209bobo13b3o11boo11bo19bobboo38bobo15boo12boobo$198b
oo81boo11boo20bo89boo23boo26boo5boo17boobboo3boo30bobbobo120bo25b3obo
52boo9boo144bobo10bo211bo13bo27b3o8boobo49boo14bo13bobb3o$199bo81boo
32boo85boo26boboo55boo35bo3bo118b3o27b3o51boboo10bo74bo70boo11b3o7boob
o211boo29bo7boboobboobbo3bo34boo16b3o3bo8bobobo$175boo22bobo158boo39bo
bo25b3obbo91bo122bo30bo51bo14bobo70b3o85bo7boboo23boo135boo32boo3boo
40boo14bobbo4bo32bobo15bo6b3o5bobobo$174bobo23boo158boo39bo5boo22bobob
o22boo67b3o146bo31bo10boo14bo12boo10bo58bo123bo136boo11boo20bo3bo51b6o
5bobobo31bo5boo10boo8bobb3obbo$174bo225boo5boo23bobobo87bo150bobo29boo
9boo11boobo24bobo57boo27boo15boo77b3o146bo18b3o5b3o48bo11bobobo29boo5b
oo19boo3boboo$173boo258bobb3o18bo3bo61bobo49boo98boo20boo7boboo10bo10b
oo26bobo42boo42boo15bobo78bo103boo5boo35b3o15bo9bo46bobobboobo6bo4bo
61boo$434boobo18bo4bo61boo50boo102boo24b3obbo49bo4boo38bo34boo25bo182b
obboobboo37bo66boo4boo3boboo7bo3bobboo54bo3bo$312boo117bo3boo18bobobo
67boo150bobo14bo3bo6bobobo16bo19boo15bobo26boo9bobo33bo25boo182boobo
107bobbo26boobboo49bobo$312boo17boo3boo91b3o3bo3bo14bobobo68bobo128boo
14boo5bo6boo5bo4bo7bobobo14bobo17bobo17bo9bo16boo10boo10bo22bobo208bo
23boo85boo21boo8bobo44boobboo$199boo130boo3bo91bo9bobo11bo4bo64boo5bo
129bo14boo5boo4bobo4bobobo10bobb3o12boo18bo19boo7bobo31boo5bobo22boo
73boo133bo23bo74boo44bo45boo9boo$199boo4boo131bo12booboo72boo9boo11bo
3bo65boo5boo22b3o100b3o26b3o5bobobo12boobo17boo13boo27bo3bo29bobbo4bob
o97boo105boo27boobboo18b3o71boo47b3o51boo$205boo68boo60boo11bobobobo
78boo58boo55bo103bo27bo3bobbo4bo14boo18bobo40bo3bo31boo6bo4boo199bobo
28bobbo20bo114boo3bo$271boobbobboo52boobbo13bobobbo16boo60bobo14bobboo
35boobboo55bo3bo6boo119bobboobbo3bo15bo3bo10boo5bo39bo3bo28boo15bobo
156boo42bo28boo138bo3bo3bo12bo$272bo3boboo52bo3bo12boobo19bo61bo5boo8b
obo37bobo59bobbobo5boo78boo37boo30bobo9boo5boo37bo3bo28bobo17bo35bo
120boo42boo164b3o4bobbobo12bo$192boo78bobobo42boo12b3o12bo3boo16bobo
60boo5boo8boo39bo62bobobbo25boo56boobo35bo7bobboo20boo56bobo29bo19boo
32b3o257boo71bo8bobobbo8b3o$148bobo42bo10boo67booboboo40bo10bobo15bobo
bbobo13boo82boo31bo67bo3bo25bo61bo32bobo6bobo19boo61bo29boo52bo260boo
81bo3bo$147boboo41bo7boobboo70bobbo4boo20boboo7b3o11boo15booboobboo50b
oo45bobo29b3o4boo64bo26b3o55bo35boo3boobboo19bobo44boo11bo87boo20bo
325bo$129bo15b3o16bo27boo5bobo74boo6boo20boobo7bo90bo40boo5bo28bob3o3b
o62b3o29bo56boboo36boo23bo5boo26boo11boo10bobo90boo16b3o320b3o$127b3o
14bo4boo11b3o34bo12boo194bobo38boo5boo26bo3bo5b3o64bo85boo60boo5boo51b
oo92bo19bo276boo3boo114bo$126bo17b5obo10bo36boo11bobo195boo72bo3bo8bo
63bobo180bo3bo25boo86bo20boo11boo243boo19bo3bo114bobo$126boo20bo12boo
20boo26bo18bo251b3obo74boo88bo90bo4bo25bobo85boo32boo243bobo5bo9b3o5b
3o111bobo$116boo26boo3bo33boo25boo18b3o250b3o54bo16boo91bobo88bobobo
22boo5bo39boo137bo187bo5boo8bo9bo92boo16booboo$83b3o31bo26bobo3bo23boo
57bo58bo18bo139bo32bo71bobo92boo65bo21bobobo23boo5boo38boo135boo43boo
8boo133boo3boobo110boo$82bo34bobo25bo3boo23bobbo54boo58b3o6boo6b3o139b
3o84bob3o5boo6bo5boo14boo67boo89bo4bo209boo42boo8bo42bobo93bobb3o127b
ooboo$82bo3bo31boo4boo44boo4boo51boo64bo5boo5bo87bo57bo85boobo4bobo4b
oo5boo14bo67bobo67bob3o17bo3bo184boo79bo41boobo82bo8bobobo93boo34boobo
$82bobbobo8bo26bobbo44bo20boo35bob5o58boo12boo86b3o54boo85boboo6b3o26b
3o38boo6bo17bo5boo64boobo23bo181boo78boo27bo16b3o15bo64b3o5bobobo93bob
o39bo$84bobobbo4b3o27boo20bo24bobo18bo42bo163bo68boo9b3o59b3obo3bo3bo
27bo34bobobbo4b3o16boo5boo64boboo15bobboo3b3o116boo170b3o11boo4bo14b3o
65bobb3obbo32boo60bo40boo$85bo3bo3bo42boo7boo25boo16bobo37boobo118boo
15boo27boo68bo10b3o67boobbo60b3oboo5bo53boo38b3obo12bobo9bo91boo3boo
17boo173bo10bob5o17bo63boo3boboo32boo60boo$89bo3boo41boo7bobo42boo38b
ooboo72boo42bobo15boo42boo51bobo10b3o61bo10boo36b3o18bo11boo52boobboo
51boo9boo92bo3boo169boo20boo12bo20boo69boo35bo$86b3o213boo3boo42bo25b
oo34bo41bo10boo14b3o22boo38bo7bo36b3o19b3oboo63bobo35bo18boo79booboo
13bo66boo108boo33bo3boo26boo56bo3bo56boo71boo$91bo63b3o60boo82boo46boo
25bo33bobo9boo29bobo25b3o61bobo6bobo34b3o21boboo64bo40bo14bobo77bobobo
bo12boo64bobo117boo23bo3bobo26bo32bo23bobo24bo32boboo22boo47boo4boo$
90bobo32bo26bobobobo59boo155bobo22bo10boo10boo29bobo25b3o21bo3bo36boo
bboo3boo31b3o96bo35bobo8boo5bo60boo16bobbobo14bobboo59bo117bobbo23boo
3bo25bobo52boobboo57bo26boobboo20boo27bobo$91boobboo11bo15bobo24boobo
3bo216boo22bobo5boo40boo4bo49bo4bo40boo36b3o89boo42boo8boo5boo60bo19bo
boo13bo3bo58boo117boo4boo44boo4boo31b3obo17boo27b3obo32bo27bobo18bobo
29bo$83bo11boo11b3o13bobo25bobobboo75boo163bobo4bobbo38bobo15boo19bo
16bobobo80b3o32boo3boo51bo3bob3o30boo81bobo16boo3bo13b3o12boo118boo28b
oo20bo34boo8bobbo26bo8boboo38bo8boboo30boobo29bo19bo31boo$81b3o27bo13b
o24bo5bo77boo77bo80boo4bo6boo29bo9bo17bobo17bobo14bobobo116boo3boo48b
3o6boobo28bobo45boo35boo13bobobbobo16bobo10bo120bo29bo18bobo32bo3bo8b
oo27b3o6boobo38b3o6boobo30boo35bo14boo23boo$80bo29boo38boobobbo154b3o
79bobo15boo24b3o7boo19bo18boo12bo4bo79bo92bo8boboo28bo5boo40bo51boobb
ooboo16boo11b3o7boobo103b3o30bobo16boo32bo4bo40bo3bob3o42bo3bob3o6b3o
52boo4bobo38boo$80boo40boo3boo20booboobo5boo147bo46bo35bo17bobo22b3obo
27boo13boo16bo3bo79bobo101b3obo25boo5boo38bobo91bo7boboo23boo78bo33boo
50bo4bo39boo49boo14b3o19bo33bo3bo3bo$70boo51bo3bo20boo11boo147boo45b3o
32boo19bo23bo3bo40bobo100boo179boo127bo165boo50bo50bo8b3o18bobo29b3o5b
o3bo$71bo48b3o5b3o18bo210bo52boo23bo3bo39bo5boo10bobboo84boo43bo56bo
32bo171b3o164b3o43bo50bo15b3o15boo5boo23bo8bo3bo30bo$71bobo46bo9bo15b
3o35boo5boo145bo20boo78bob3o37boo5boo9bobo87bobo41bobo86b3o173bo176bo
32bobo48bobo14b3o19boobbo33bo3bo28bobo$72boo4boo66bo37boobboobbo143b3o
16boo83b3o56boo83boo5bo42bo60bo25bo352bobo15bo11boobboo22boo21boobboo
15b3o19boboo35bobo30bo$77bobbo107boboo143bo19bo85bo61boo79boo5boo102b
oo24boo351bobo13b3o11boo11bo14boobboo17boo36boo5bo12bo24bo$78boo85boo
23bo131boo11boo20bo87bo11boo44bobo51boo135boobo8boo72bo63boo122boo105b
o13bo27b3o16bobo42bo11boo5bo12boo$90boo74bo23bo26boo103boo32boo86bobo
10boo39boo5bo47boobboo134bobb3o8bo70b3o63bobo122bo119boo29bo16bobboo
38bobo15boo12boobo$90boo71b3o18boobboo26bobo183boo41boo24bo26boo5boo
45bobo18bo118bobobo10bobo67bo66bo124bobo15boo49boo32boo3boo40boo60boo
14bo13bobb3o$163bo20bobbo28bo185boo37boo110bo19boo116bobobo12boo10bo
56boo191boo15boo49boo11boo20bo3bo51boo3boobbo3bo34boo16b3o3bo8bobobo$
186boo27boo223bobo26bob3o98bobo93bo20b3obbo17boo5bobo40boo42boo15boo
226bo18b3o5b3o48bo5bobbo4bo32bobo15bo6b3o5bobobo$440bo5boo23boobo74boo
4boo59boo49bobo20boboo17bobbo4bobo41bo42boo15bobo182boo5boo35b3o15bo9b
o46bobobb3o5bobobo31bo5boo10boo8bobb3obbo$122boo315boo5boo23boboo72bob
oo4bo60boo48bo3bo20boo19boo6bo4boo25boo9bobo32boo25bo182bobboobboo37bo
66boo4boo3bo8bobobo29boo5boo19boo3boboo$122boo229boo117b3obo20boo47bo
9b3o108bo3bo16bo3bo15boo15bobo24boo10boo10bo22bo25boo182boobo107bobbo
18bo4bo61boo$353boo17boo3boo99bobo14boboo50bo8bo109bo3bo14bobo17bobo
17bo9bo30boo5bobo21bobo208bo23boo85boo20bo3bobboo54bo3bo$372boo3bo92bo
3bo7bo11bo50boobo120bo3bo13boo18bo19boo38bobbo4bobo22boo73boo133bo23bo
74boo39boobboo49bobo$76boo3boo296bo13booboo70b3o7bo4bo13bo47boo123bobo
18boo13boo27b3obo28boo6bo4boo92boo134boobboo18b3o71boo33boo8bobo44boo
bboo$77bo3bo19boo213boo60boo12bobobobo68bo9bo5bo9boobo16bo80b3o74bo19b
obo40boboo26boo15bobo229bobbo20bo117bo45boo9boo$74b3o5b3o15bobo209boo
bbobboo52boobbo14bobobbo16boo51boo9bo3boo9boo18b3o78b3o7boo69bo10boo5b
o40boobo25bobo17bo229boo143b3o51boo$74bo9bo15bo133boo77bo3boboo52bo3bo
13boobo19bo59boobbo3bo33bo24boo51b3o7boo68bobo9boo5boo37bob3o26bo19boo
34bo332boo3bo$93boo4boo89bobo42bo19boo56bobobo42boo12b3o13bo3boo16bobo
58bobo5bo8bo24boo80b3o26boo47boo85boo53b3o121boo134boo74bo3bo3bo$93boo
bo92boboo41bo20boo57booboboo40bo10bobo16bobobbobo13boo59bo5bobo7bobo
38boo7bo3bo53b3o26bo44boo61bo81bo124boo45boo87boo71b3o4bobbobo$97bo8bo
64bo15b3o16bo27boo81bobbo4boo20boboo7b3o11boo16booboobboo73boo5boo8boo
39bo8bo4bo52b3o27b3o40bobo44boo11bo85boo20bo149bobo159bo8bobobbo$94bo
9b3o62b3o14bo4boo11b3o110boo6boo20boobo7bo134boo33bobo10bobobo83bo40bo
5boo39boo10bobo88boo16b3o149bo169bo3bo$95boboo4bo64bo17b5obo10bo242boo
45bobo21bo10boo12bobobo55bo66boo5boo26bo24boo90bo19bo148boo126boo3boo
39bo$97boo4boo63boo20bo12boo20boo220bo40boo5bo20bobo24bo4bo20bo31bobo
99b3o27boo84bo20boo11boo243boo19bo3bo37b3o$40bo117boo26boo3bo33boo220b
obo38boo5boo19bobo25bo3bo19b3o31boo98bob3o26bobo37boo44boo32boo54bobo
186bobo15b3o5b3o112bo$39b3o59bo57bo26bobo3bo23boo230boo61boo4bo49bob3o
8b3o15boo101bo3bo22boo5bo37boo134boo189bo5bo9bo9bo111bobo$38b3obo32bo
24bobo22b3o31bobo25bo3boo23bobbo114bo18bo156bobo15boo15boobbo16bo3bo8b
o17bobo77b3o20bo3bo23boo5boo173bo189boo3b3o130bobo$39bo3bo30bobo24boo
bboo18b3o32boo4boo44boo4boo114b3o6boo6b3o156bo17bobo17bobo14bo3bo9bo3b
o5boo6bo5boo14boo55bo22b3obo400bob3o110boo16booboo$40bo3bo28bo3bo27boo
18b3o10bo26bobbo44bo20boo4boo95bo5boo5bo148boo8boo19bo18boo13b3obo10bo
bbobo4bobo4boo5boo14bo42boo6bo5bo3bo19b3o182boo69boo136bo8bo3bo111boo$
41bob3o28bo3bo8bo40b3o5b3o27boo45bobo18bo5boo94boo12boo147boobo27boo
13boo18b3o13bobobbo4b3o26b3o35bobobbo4b3o5bobbobo19bo3bo179boo69boo
136b3o5bo3bo130booboo$42b3o22b3o5bo3bo5b3o40b3o4bo42boo34boo16bobo65bo
134bo67bo40bobo19bo15bo3bo3bo3bo27bo11boo20b3oboo5bo10bobobbo13bo7b3o
8boo104boo273bo3b3obo95boo34boobo$43bo26bo5bo3bo3bo43b3o4boo41boo52boo
67boo91boo15boo22b3o62bo43bo5boo10bo23bo3boobbo60bo11boo10bo3bo12bobo
9bo6b3o80boo3boo17boo147boo123boo4b3o55boo38bobo39bo$47bo18bo3bo6bobo
4boo214boo47boo42bobo15boo25bo62boboo38boo5boo9bobo19b3o9boo36bo3bo18b
3oboo21bo12boo9boo6bobbo60booboo15bo3boo166bo42bobo86bo96bo40boo$46bob
o16bobobbo7bo54bo210boo3boo42bo25boo16boo64boo56boo25bo7bo35bo4bo20bob
oo18b3o17boo14b3o59bobobobo12bo66boo106bo41boobo81bo25bo33bo3bo35boo$
40boo5boo14bobbobo13bo49bobo209boo46boo25bo32boo111boo20bobo6bobo32bob
obo49bo14bobo13b3o42boo16bobbobo12boo64bobo105boo27bo16b3o15bo62bobo
24boo31bo4bo$40bobboo18bo3bo13bobo49boobboo11bo266bobo32bo54bo11boo44b
obo20boobboo3boo31bobobo49bobo8boo5bo59bo19boboo13bobboo59bo136b3o11b
oo4bo14b3o56boobboo24boobo29bobobo71boo$41boobo18bo18boobboo21boo14bo
11boo11b3o264boo26boo3bobo9boo42bobo10boo39boo5bo24boo34bo4bo32boo3boo
12boo8boo5boo58bobo16boo3bo12bo3bo58boo139bo10bob5o17bo55boo27bobb3o
27bobobo23boo47boo4boo$42bo5boo14b3o19boo17boobboo12b3o27bo290b3o3boo
10boo43boo23b3o25boo5boo59bo3bo33boo3boo8boo80boo13bobobbobo14b3o12boo
163boo20boo12bo20boo74bo8bobobo27bo4bo24boobboo20boo27bobo$42bo5boo11b
o42bobo15bo29boo201bo87b4o56boo26bo148bobo45boo48boobbooboo15bobo10bo
164boo33bo3boo26boo64b3o5bobobo6bo21bo3bo29bobo18bobo29bo$28boo13boo
15bobo19b3o20bo16boo40boo3boo32boo55boo91b3o86bobb3o54bobo26bo3bo91bo
bboo48bo5boo40bo74boo11b3o7boobo106boo51boo23bo3bobo26bo68bobb3obbo64b
o19bo31boo$28boobo13bo14boo20bo29boo51bo3bo20boo11boo55bo91bo46bo33boo
6bo5bo54bo5boo21bobbobo22bo66bobo50boo5boo38bobo89bo7boboo23boo82bo49b
obbo23boo3bo25bobo31b3o33boo3boboo6bob3o18bobboo35bo14boo23boo$32bo8bo
3b3o16boo17bo16b3o4boo4bo48b3o5b3o18bo69b3o88boo45b3o30bobo5boo3bo4boo
49boo5boo23bobobbo20boo65boo48bo49boo125bo43bobo34b3o50boo4boo44boo4b
oo32b3o39boo9boobo16bobo31boo4bobo38boo$29bo9b3o6bo15bobo33b3o4bo5bobo
46bo9bo15b3o35boo5boo28bo138bo29bo7bobobo5bobo81bo3bo19boobo68boo43bob
o176b3o40boo35bo36boo20bo44bobbo26bo10b3o22bo13bo3bo9boboo16boo5boo26b
o3bo3bo$30boboo4bo8boo10boo5bo33b3o5b3o3boo4boo66bo37boobboobbo145bo
20boo28boo8b3o8bo85bo18bobb3o67bobo43bo96boo81bo41bo73bo18bobo23boobo
18boo27b3o5b3o26bo11bobo13b3obo18boobbo23b3o5bo3bo$32boo4boo19boo5boo
29b3o10bo8bobbo107boboo144b3o16boo42b3o8boo78bobb3o18bobobo64boo5bo
139boo198bobo16boo24b4o6boo42bo4b3o11boo11b3o7boobboo37boboo24bo8bo3bo
30bo$97b3o20boo9boo74boo23bo144bo19bo132b3o7bo14bobobo65boo5boo137bo4b
oo195boo41bo3bo6boo41boo4b3o11boobboo17boo20bo15boo5bo35bo3bo28bobo$
36bo54boo4b3o29b3obo74bo23bo83bo47boo11boo20bo129bo9bobo11b3obbo39boo
140bo29boo6bo238b3o74bobo42bo11boo5bo12bo23bobo30bo$35bobo49boobboo36b
o3bo71b3o18boobboo82bobo47boo32boo129boo9boo12boboo36boobboo138b3o23bo
bo4boboob3o238b3o53bo21bo42bobo15boo12b3o23bo$36boobboo44bobo39b5o72bo
20bobbo39boo44boo219boo17boo36bobo141bo26bobbo9bo149boo90bo19bo32bobo
23b3o38boo14bo13bob3o$29boo9boo45bo42b3o95boo39bo265bobo14bo3bo33bo3bo
142boo24bo3bo7bo5boo145bo109bobo15bo11boobboo18boo3bo37boo16b3o3bo8bo
3bo$29boo52bo166boo15bobo171boo92bo5boo8bobo36boo130boo40bobbo6boo5bob
o86bo57bobo15boo90bobo13b3o11boo11bo11bo3bo3bo32bobo15bo6b3o5bo3bo$89b
oo29b3o41boo84boo15boo128boo42boo91boo5boo8boo36boobo3boo58bo5bo60bo
32boo6b3o16bo84boo59boo15boo91bo13bo27b3o6b3o4bobbobo31bo5boo10boo8bo
3b3obo$81b3obo3bo30b3o41boo230bobbo155boo31bobb3obbo58boo5boo48boo9bob
o31bo25boo84boo29bobo150boo29bo5bo8bobobbo28boo5boo19boo4b3o$80boboo6b
3o301bo4bo108boo45bobo29bobobo5b3o54boo8bo47boo10boo10bo20bobo140boo
100boo32boo3boo40boo15bo3bo63bo$80boobo8bo300b6o15boo3boo88bo40boo5bo
28bobobo8bo36boo25boo70bobo20boo73boo66bo100boo11boo20bo3bo51boo9bo3b
oo54bo$78bob3o35boo3boo267boobo18boo3bo89bobo38boo5boo25b3obbo63booboo
4bo72bobo95boo180bo18b3o5b3o48bo7b3o4boobboo49bobo$119bo3bo19boo248bob
o25bo88boo73boboo45bo3bo16b4o3bo73bo4boo229boo5boo35b3o15bo9bo46bobo
18bobo44boobboo$80bo35b3o5b3o9bo5bobo213boo34boo24boo132bo31boo46bo4bo
6boobb3obboboobbo3bo58boo15bobo228bobboobboo37bo66boo4boo20bo45boo9boo
$3bo112bo9bo8boo5bo211boobbobboo52boobbo12booboo117b3o30bo48bobobo5boo
bbo7b4o3bo57bobo17bo33bo195boobo107bobbo29bo52boo$bbobo129boboo3boo
212bo3boboo52bo3bo11bobobobo119bo79bobobo8b3o6b5o4boo53bo19boo30b3o
196bo23boo85boo23boo4bobo$bbobo128b3obbo216bobobo42boo12b3o12bobobbo
16boo101boo25bo54bo4bo10b3o11bo53boo50bo124boo73bo23bo74boo36bo3bo3bo$
booboo16boo111bobobo8bo123boo82booboboo23bo16bo10bobo13boobo19bo43bo
73boo9b3o54bo3bo12bo12b3o102boo20bo102boo74boobboo18b3o71boo33b3o5bo3b
o$22boo112bobobo5b3o124bo85bobbo4boo16boboboboo7b3o11boo13bo3boo16bobo
43b3o71bo9b3obo72boobo9bo106boo16b3o178bobbo20bo106bo8bo3bo$booboo131b
obb3obbo103boo22bobo83boo6boo17booboobo7bo29bobobbobo13boo47bo68bobo
10bo3bo53boobbo13b3o118bo19bo147boo28boo139bo3bo$bboboo34boo96boobo3b
oo101bobo23boo153booboobboo61boo57bo10boo12bo3bo55bobo12b3o116bo20boo
11boo134bobo169bobo$o39bobo96boo107bo265boo41bobo5boo17bob3o55boo131b
oo32boo136bo91boo77bo$oo40bo38boo56bo3bo103boo265bo42bobo4bobbo17b3o
22boo28boo91boo214boo90boo154bo$42boo37boobo32bo24bobo367bobo9boo26boo
4bo6boo19bo21boboo10b3o14bobo91boo461bobo$85bo57boobboo352bo10boo10boo
15bo9bobo15boo19bo16bo14b3o6boo6bo5boo14boo533bobo$8boo72bo32bob3o27b
oo351bobo5boo30boo9bo17bobo17bobo18bo11b3o6bobo4boo5boo14bo181boo237b
oo3boo88boo16booboo$bboo4boo47boo24boboo30boobo8bo143boo98bo18bo107bob
o4bobbo28boboo7boo19bo18boo14boobo15b3o5b3o26b3o178boo69boo146boo19bo
3bo89boo$bobo27boo20boobboo26boo30boboo6b3o143boo4boo92b3o6boo6b3o102b
oo4bo6boo28b3obbo27boo13boo18boo17b3o4bo3bo27bo115boo132boo146bobo5bo
9b3o5b3o104booboo$bo29bobo18bobo54b3o6b3obo3bo152boo95bo5boo5bo104bobo
15boo26bobobo40bobo37b3o4boobbo39bo79boo3boo17boo282bo5boo8bo9bo68boo
34boobo$oo31bo15bo3bo35bo19b3o14boo247boo12boo103bo17bobo26bobobo39bo
5boo10bo33boo36b3o79bo3boo301boo3boobo85bobo39bo$8boo23boo14boo37bobo
18b3o8bo372boo19bo27bobb3o36boo5boo9bobo25bo7bo35bob3o60booboo11bo66b
oo244bobb3o84bo40boo$8boo38boobo3boo25boo5boo15b3o15bo141boo165boo15b
oo62boo27boobo55boo25bobo6bobo32bo3bo60bobobobo10boo64bobo106boo126bo
8bobobo85boo$47bobb3obbo26bobboo19b3o14bobo96bobo42bo10boo108boo42bobo
15boo92boo60boo22boobboo3boo31bo3bo44boo16bobbobo12bobboo59bo108bo42bo
bo7bo74b3o5bobobo$46bobobo5b3o24boobo19b3o15boobboo21boo68boboo41bo7b
oobboo103boo3boo42bo25boo84bo3bo11boo44bobo25boo35b3obo46bo19boboo11bo
3bo58boo109bo41boobo7bo76bobb3obbo121boo$14bo30bobobo8bo12bo12bo5boo
36boo17boobboo50bo15b3o16bo27boo5bobo107boo46boo25bo88bobo10boo39boo5b
o63b3o47bobo16boo3bo11b3o12boo155boo27bo16b3o3b3o9bo65boo3boboo73boo
47boo4boo$13bobo27b3obbo21boo12bo5boo11bo42bobo52b3o14bo4boo11b3o34bo
12boo168bobo89boo4bo46boo5boo63bo49boo13bobobbobo14bobo10bo16bo168b3o
11boo4bo14b3o69boo74boobboo20boo27bobo$14bo29boboo21boboo12boo15bobo
38boobbo52bo17b5obo10bo36boo11bobo168boo86boo7boo18b3o93bo68boobbooboo
14boo11b3o7boobobobo62bo107bo10bob5o17bo65bo3bo56boo20bobo18bobo29bo$
45boo21b3obbo13bo14boo96boo20bo12boo20boo26bo18bo198boo38bobo7bobo17b
3o92bobo105bo7bobooboo20boo40bo40boo43boo20boo12bo20boo64bobo24bo32bob
oo21bo19bo31boo$46bo23bobobo8bo3b3o16boo34bo3bobboo39boo26boo3bo33boo
25boo18b3o87bo108boo38bo5boo22b3o92boo141bo41b3o39bo43boo33bo3boo26boo
50boobboo57bo44boo23boo$71bobobo5b3o6bo15bobo32bo4bobbo7b3o31bo26bobo
3bo23boo57bo84b3o147boo5boo25b3o21bo71boo138b3o77b3o53boo23bo3bobo26bo
32bo18boo27b3obo32bo19boo4boo39boo$72bobb3obbo8boo10boo5bo31bobobo5b3o
3bo34bobo25bo3boo23bobbo54boo83bo46bo137b3o20bobo70bobo139bo77bo53bobb
o23boo3bo25bobo70bo8boboo30boobo21bo4boobo$73boobo3boo19boo5boo29bobob
o8bo3bo3bo31boo4boo44boo4boo51boo86boo45b3o135b3o19bo3bo64boo5bo271boo
4boo44boo4boo31b3obo35b3o6boobo30boo20b3o9bo$74boo61bo4bo13bobbobo8bo
26bobbo44bo20boo35bob5o52bo78bo131bo23bo3bo65boo5boo107bo18bo127boo20b
o44bobbo26bo8boboo40bo3bob3o6b3o44bo8bo34bo$74bo3bo54boobbo3bo16bobobb
o4b3o25boobo45bobo18bo42bo50bobo56bo20boo129b3o7bo14bo3bo39boo141b3o6b
oo6b3o128bo18bobo45boo27b3o6boobo39boo14b3o19bo34boboo29bobo$77bobo49b
oobboo24bo3bo3bo29bo12boo34boo16bobo37boobo53boo54b3o16boo132bo9bobo
12bo3bo36boobboo144bo5boo5bo131bobo16boo34boo42bo3bob3o47bo8b3o18bobo
35boo30bo$78boobboo44bobo8boo22bo3boo28bobo10boo52boo38booboo107bo19bo
57booboo71boo9boo13bobo36bobo147boo12boo131boo52boo41boo51bo15b3o15boo
5boo$71boo9boo45bo30b3o34bobo203boo11boo20bo54bobobobo77boo18bo38bo
248boo149bo44bobo14b3o19boobbo$71boo51b3o38bo32bo93boo109boo32boo54bob
obbo16boo59bobo14bo38bo91boo15boo143bo145bo21boo21boobboo15b3o19boboo$
127bo3boo31bobo125boo198boobo19bo60bo5boo8bobo36bobo4boo84boo15bobo42b
oo70bo27bobo15boo92bo32bobo20boobboo17boo36boo5bo12bo$123bo3bo3bo33boo
bboo11bo308bo3boo16bobo59boo5boo8boo36bo3bo3bo77boo25bo42boo3boo63boo
29boo15boo91bobo15bo11boobboo25bobo42bo11boo5bo12boo$122bobobbo4b3o22b
o11boo11b3o123boo182bobobbobo13boo81boo31bo3bo5b3o75bo25boo46boo64boo
138bobo13b3o11boo11bo18bobboo9bo28bobo15boo12boobo$120bobbobo8bo20b3o
27bo122boo181booboobboo49boo45bobobboobo23bo3bo8bo75bobo278bo13bo27b3o
9boo17bobo29boo14bo13bobb3o$120bo3bo29bo29boo364bo40boo5bobboboo22bo3b
o86boo292boo29bo8boobboobbo3bo7boo25boo16b3o3bo8bobobo$120bo33boo40boo
3boo32boo197boo114bobo38boo5b3o27bobo191bobo136boo32boo3boo40boo13bobb
o4bo32bobo15bo6b3o5bobobo$121b3o20boo51bo3bo20boo11boo197boo17boo3boo
91b3o5boobboo64bo151bo40boo137boo11boo20bo3bo51b5o5bobobo31bo5boo10boo
8bobb3obbo$45bo99bo48b3o5b3o18bo229boo3bo94b3o3b3o10boo22b3o182b3o39bo
150bo18b3o5b3o48bo10bobobo29boo5boo19boo3boboo$44bobo98bobo46bo9bo15b
3o35boo5boo193bo92boo4bo5boboo3boboo16boobo3bo137bo46bo146boo5boo35b3o
15bo9bo46bobobboo7bo4bo61boo$44bobo99boo4boo66bo37boobboobbo109bobo18b
oo60boo93boboobb3obobobbobo3bo16boboobboo135b3o45boo146bobboobboo37bo
66boo4boo3boo8bo3bobboo54bo3bo$43booboo16boo85bobbo107boboo111boo14boo
bbobboo52boobbo96boo3b3o8b5o37boo9boo108bo197boobo107bobbo25boobboo49b
obo$64boo86boo85boo23bo112bo16bo3boboo52bo3bo79bo74bo10boobo106boo20bo
176bo23boo85boo20boo8bobo44boobboo$43booboo116boo74bo23bo26boo101bobob
o42boo12b3o80b3o26bobboo39bobo14bo109boo16b3o174bo23bo74boo43bo45boo9b
oo$44boboo34boo71bobo6boo71b3o18boobboo26bobo19boo36bo44booboboo23bo
16bo10bobo85bo25b3o30bo10boo12bo26bo86bo19bo145boo27boobboo18b3o71boo
46b3o51boo$42bo39bobo70boo80bo20bobbo28bo22bo37boo45bobbo4boo16bobobob
oo7b3o11boo40boo15boo26boo27bo29bobo24boboo22boo83bo20boo11boo132bobo
28bobbo20bo113boo3bo$42boo40bo71bo103boo27boo22bobo34boo46boo6boo17boo
boobo7bo54bobo15boo41boo42bobo26boo21boobo82boo32boo134bo28boo137bo3bo
3bo$84boo67bo160boo178bo25boo33bo38boo4bo49bobb3o170bo80boo163b3o4bobb
obo$152bobo41boo295boo25bo32bobo9boo26bobo15boo19bo16bobobo171bo174boo
70bo8bobobbo$50boo100bobo41boo320bobo21bo10boo10boo16bo9bo17bobo17bobo
14bobobo172b3o172boo80bo3bo$44boo4boo47boo52bo289boo73boo21bobo38bobo
7boo19bo18boo12b3obbo434bo$43bobo27boo20boobboo342boo96bobo37bo3bo27b
oo13boo17boboo432b3o$43bo29bobo18bobo53boo3boo357boo20boo4bo39bo3bo40b
obo18boo90boo147bo151boo3boo113bo$42boo31bo19bo55bo3bo19boo136boo198bo
bo19bobo15boo28bo3bo39bo5boo10bo3bo66boo3boo17boo146bobo130boo19bo3bo
113bobo$50boo23boo14bo56b3o5b3o15bobo136boo4boo179bo14bo19bo17bobo28bo
3bo37boo5boo9bobo70bo3boo165boo131bobo15b3o5b3o110bobo$50boo38bobo4boo
49bo9bo15bo133boo9boo179b3o31boo19bo29bobo56boo69bo307bo5bo9bo9bo91boo
16booboo$89bo3bo3bo69boo4boo89bobo42bo193bo51boo29bo61boo65boo60boo
109boo133boo3b3o110boo$88bo3bo5b3o66boobo92boboo41bo172bo20boo86bo11b
oo44bobo66bobboo52boobbobboo105bo42bobo93bob3o127booboo$56bo30bo3bo8bo
70bo8bo64bo15b3o16bo27boo169b3o16boo89bobo10boo11boo26boo5bo66bo3bo52b
oobo3bo107bo41boobo82bo8bo3bo92boo34boobo$55bobo28bo3bo77bo9b3o62b3o
14bo4boo11b3o37boo158bo19bo91boo51boo5boo66b3o12boo42bobobo106boo27bo
16b3o15bo64b3o5bo3bo92bobo39bo$56bo30bobo79boboo4bo64bo17b5obo10bo36b
oobboo46bo98boo11boo20bo85boo25bo3bo102bobo10bo16bo23booboboo136b3o11b
oo4bo14b3o65bo3b3obo93bo40boo$88bo82boo4boo63boo20bo12boo20boo12bobo
48bobo98boo32boo84bobo25bo4bo102boo11b3o7boobobobo16boo4bobbo142bo10bo
b5o17bo63boo4b3o55boo36boo$114bo117boo26boo3bo33boo12bo12boo5bo31boo
177boo39bo5boo22bobobo116bo7bobooboo17boo6boo119boo20boo12bo20boo70bo$
113b3o59bo57bo26bobo3bo23boo20boo11bobo4b3o171boo36boo38boo5boo23bobob
o21bo254boo33bo3boo26boo31bo24bo25bo33bo3bo68boo$112b3obo32bo24bobo22b
3o31bobo25bo3boo23bobbo31bo6b3o9bo161bobbo107bo4bo191bo91boo23bo3bobo
26bo32boo22bobo24boo31bo4bo19boo47boo4boo$113bo3bo30bobo24boobboo18b3o
32boo4boo44boo4boo30boo18b3o86boo72boo109bo3bo17b3obo167boo90bobbo23b
oo3bo25bobo31boobo17boobboo24boobo29bobobo21boobboo20boo27bobo$114bo3b
o28bo3bo27boo18b3o10bo26bobbo44bo20boo22b4o11bo85boo180bo23boboo170boo
89boo4boo44boo4boo31bobb3o16boo27bobb3o27bobobo26bobo18bobo29bo$115bob
3o28bo3bo8bo40b3o5b3o27boo45bobo18bo22b5o10boo148boo11boo102b3o3boobbo
15boobo245boo20bo44bobboo25bo8bobobo37bo8bobobo27bo4bo28bo19bo31boo$
116b3o22b3o5bo3bo5b3o40b3o4bo42boo34boo16bobo22boobo8boo151boo8boobbo
4boo3boo90bo9bobo12bob3o247bo18bobo47boo25b3o5bobobo38b3o5bobobo6bo21b
o3bo33bo14boo23boo$117bo26bo5bo3bo3bo43b3o4boo32bo8boo52boo35bob5o156b
o3bo4boo3bo91boo9boo264bobo16boo34boo12bo29bobb3obbo42bobb3obbo25b3o
32boo4bobo38boo$121bo18bo3bo6bobo4boo21bo61bobo103bo104boo51b3o12bo12b
ooboo79boo18bo250boo52boo12boo27boo3boboo42boo3boboo6bob3o14b5obboo28b
o3bo3bo$120bobo16bobobbo7bo26boo26bo35boo99boobo106bobo64boo11bobobobo
77bobo14bo320bobo34boo49boo9boobo12boobobbo28b3o5bo3bo$114boo5boo14bo
bbobo13bo23boo24bobo32bo102booboo107bo59boobbo13bobobbo16boo60bo5boo8b
obo320bo32bo3bo46bo3bo9boboo13b5o5boo22bo8bo3bo30bo$114bobboo18bo3bo
13bobo49boobboo11bo15bobo213boo58bo3bo12boobo19bo60boo5boo8boo353bobo
48bobo13b3obo13boo3boobbo32bo3bo28bobo$115boobo18bo18boobboo21boo14bo
11boo11b3o13bobo89boo3bo165boo12b3o12bo3boo16bobo81boo333bo11boobboo
22boo21boobboo31bo5boboo34bobo30bo$116bo5boo14b3o19boo17boobboo12b3o
27bo13bo90boo4bo148bo16bo10bobo15bobobbobo13boo35boo45bobo330b3o11boo
11bo14boobboo17boo20bo15boo5bo36bo$116bo5boo11bo42bobo15bo29boo109bo
148boboboboo7b3o11boo15booboobboo51bo40boo5bo329bo27b3o16bobo42bo11boo
5bo12bo$102boo13boo15bobo42bo16boo40boo3boo32boo61boo6boo115boo20boob
oobo7bo90bobo38boo5boo328boo29bo16bo42bobo15boo12b3o$102boobo13bo14boo
50boo51bo3bo20boo11boo69boo116bo126boo324boo32boo3boo40boo19b3o38boo
14bo13bob3o$106bo8bo3b3o16boo34b3o4boo4bo48b3o5b3o18bo197b3o453boo11b
oo20bo3bo51boo3boo3bo37boo16b3o3bo8bo3bo$103bo9b3o6bo15bobo33b3o4bo5bo
bo46bo9bo15b3o35boo5boo154bo468bo18b3o5b3o48bo5bo3bo3bo32bobo15bo6b3o
5bo3bo$104boboo4bo8boo10boo5bo33b3o5b3o3boo4boo66bo37boobboobbo580boo
5boo35b3o15bo9bo46bobobb3o4bobbobo31bo5boo10boo8bo3b3obo$106boo4boo19b
oo5boo29b3o10bo8bobbo107boboo168bo18bo393bobboobboo37bo66boo4boo3bo8bo
bobbo28boo5boo19boo4b3o$171b3o20boo85boo23bo169b3o6boo6b3o84bo309boobo
107bobbo18bo3bo63bo$110bo54boo4b3o32boo74bo23bo48boo122bo5boo5bo87b3o
308bo23boo85boo23bo3boo54bo$109bobo49boobboo39boo71b3o18boobboo50bo
121boo12boo89bo307bo23bo74boo32b3o4boobboo49bobo$110boobboo44bobo116bo
20bobbo52bobo223boo308boobboo18b3o71boo8bo34bobo44boobboo$103boo9boo
45bo140boo27boo24boo177boo15boo42boo295bobbo20bo79bobo35bo45boo9boo$
103boo52bo172bobo158boo42bobo15boo42bo296boo103boo39bo52boo$163boo73b
oo90bo155boo3boo42bo25boo32bobo9boo393bo30boo4bobo$155b3obo3bo74boo89b
oo155boo46boo25bo22bo10boo10boo349boo41bobo30bo3bo3bo$154boboo6b3o392b
obo21bobo5boo365boo41bobo27b3o5bo3bo$154boobo8bo392boo22bobo4bobbo408b
o28bo8bo3bo$152bob3o35boo3boo157boo220boo4bo6boo448bo3bo$193bo3bo19boo
137boo4boo133bo79bobo15boo402boo3boo36bobo$154bo35b3o5b3o9bo5bobo129bo
13boo131b3o79bo17bobo381boo19bo3bo38bo$77bo112bo9bo8boo5bo130bobo144bo
46bo34boo19bo381bobo15b3o5b3o112bo$76bobo129boboo3boo131boo144boo45b3o
53boo382bo15bo9bo111bobo$76bobo128b3obbo331bo436boo3b3o130bobo$75boob
oo16boo81boo28bobobo8bo125boo11boo159bo20boo441b3o111boo16booboo$96boo
82boo28bobobo5b3o81bobo42bo7boobboo157b3o16boo434bo10b3o111boo$75boob
oo99bo31bobb3obbo83boboo41bo7bobo160bo19bo435b3o5b3o132booboo$76boboo
34boo96boobo3boo64bo15b3o16bo27boo6bo12boo135boo11boo20bo248bo187bo4b
3o96boo34boobo$74bo39bobo96boo68b3o14bo4boo11b3o34boo11bobo135boo32boo
44boo200boo187boo4b3o95bobo39bo$74boo40bo38boo56bo3bo64bo17b5obo10bo
50bo18bo198boo201boo249b3o38bo40boo$116boo37boobo32bo24bobo63boo20bo
12boo20boo26boo18b3o590bo62bo36boo$159bo57boobboo17bo31boo26boo3bo33b
oo49bo588bobo24bo32bo3bo$82boo72bo32bob3o27boo16boo32bo26bobo3bo23boo
57boo584boobboo24b3o30bobobbo70boo$76boo4boo47boo24boboo30boobo8bo34bo
boo31bobo25bo3boo23bobbo52boo587boo27bob3o27bobbobo23boo47boo4boo$75bo
bo27boo20boobboo26boo30boboo6b3o33b3obbo31boo4boo44boo4boo52bob5o144b
oo455bo8bo3bo5bo22bo3bo24boobboo20boo27bobo$75bo29bobo18bobo54b3o6b3ob
o3bo38bobobo8bo26bobbo44bo20boo42bo144boo17boo3boo431b3o5bo3bo5boo22bo
32bobo18bobo29bo$74boo31bo15bo3bo35bo19b3o14boo38bobobo5b3o27boo45bobo
18bo38boobo165boo3bo15booboo415bo3b3obo5boboo22b3o30bo19bo31boo$82boo
23boo14boo37bobo18b3o8bo46bobb3obbo42boo34boo16bobo38booboo171bo12bobo
bobo392bo20boo4b3o5b3obbo18bo54boo23boo$82boo38boobo3boo25boo5boo15b3o
15bo43boobo3boo41boo52boo152boo60boo12bobobbo16boo376bo26bo8bobobo16bo
bo31boo4boo39boo$121bobb3obbo26bobboo19b3o14bobo43boo130boo119boobbobb
oo52boobbo13boobo19bo375b3o22bo13bobobo15boo5boo26bo4boobo$120bobobo5b
3o24boobo19b3o15boobboo21boo16bo3bo127boo120bo3boboo52bo3bo12bo3boo16b
obo399bobo13bobb3o17boobbo23b3o9bo$88bo30bobobo8bo12bo12bo5boo36boo17b
oobboo19bobo32bo215bobobo42boo12b3o14bobobbobo13boo373boo21boobboo15b
oobo18boboo24bo8bo34bo$87bobo27b3obbo21boo12bo5boo11bo42bobo24boobboo
11bo15bobo108boo105booboboo23bo16bo10bobo15booboobboo388boobboo17boo
20boo14boo5bo35boboo29bobo$88bo29boboo21boboo12boo15bobo38boobbo7boo8b
o11boo11b3o13bobo108boo108bobbo4boo16boboboboo7b3o11boo200bo216bobo38b
o3bo11boo5bo37boo30bo$119boo21b3obbo13bo14boo49bobbo6b3o27bo13bo219boo
6boo17booboobo7bo213boo218bo42bobo15boo12b3o$120bo23bobobo8bo3b3o16boo
34bo3bobboobb3o6bo29boo489boo221bo39boo14bo14b3o$145bobobo5b3o6bo15bob
o32bo4bobbo12boo40boo3boo32boo654boo4bobo34boo16b3o3bo10b3o$146bobb3o
bbo8boo10boo5bo31bobobo5b4o51bo3bo20boo11boo655bo3bo3bo32bobo15bo6b3o
5b3o$147boobo3boo19boo5boo29bobobo9bo48b3o5b3o18bo665b3o5bo3bo31bo5boo
10boo8bo4b3o$148boo61bo4bo5b3obbobo46bo9bo15b3o35boo5boo622bo8bo3bo29b
oo5boo19boo4b3o$148bo3bo54boobbo3bo5bobbo3boo4boo66bo37boobboobbo632bo
3bo$151bobo49boobboo12boo10bobbo107boboo634bobo4boo54bo$152boobboo44bo
bo8boo19boo85boo23bo27boo607bo5boobboo49bobo$145boo9boo45bo42boo74bo
23bo26bobo202boo15boo396bobo44boobboo$145boo51b3o45boo71b3o18boobboo
27bo203bobo15boo397bo45boo9boo$201bo3boo112bo20bobbo28boo203bo25boo
446boo$197bo3bo3bo136boo232boo25bo387boo4boo$196bobobbo4b3o392bobo388b
o4boobo$194bobbobo8bo69boo246boo73boo386b3o9bo$194bo3bo79boo246boo198b
o262bo8bo$194bo529boo273boboo$195b3o527boo274boo$119bo112boo3boo344bo$
118bobo112bo3bo19boo324b3o492bo$118bobo109b3o5b3o15bobo132boo193bo490b
obo$117booboo16boo90bo9bo15bo90bobo42bo171bo20boo490bobo$138boo109b3o
3boo89boboo41bo170b3o16boo475boo16booboo$117booboo127b3o76bo15b3o16bo
27boo168bo19bo476boo$118boboo34boo91b3o10bo63b3o14bo4boo11b3o174bo9boo
11boo20bo492booboo$116bo39bobo93b3o5b3o62bo17b5obo10bo177boo8boo32boo
456boo34boobo$116boo40bo93b3o4bo65boo20bo12boo20boo148boo3bobo499bobo
39bo$158boo92b3o4boo21boo31boo26boo3bo33boo146b4o505bo40boo$195b3o118b
o26bobo3bo23boo154bo4bo175bo327boo$124boo68bo62bo22bo3bo31bobo25bo3boo
23bobbo139boo11bobb4o174bobo$118boo4boo47boo19bo3bo32bo24bobo21bo4bo
31boo4boo44boo4boo103bo35boo11booboboo174boo360boo$117bobo27boo20boobb
oo19bobbobo30b3o24boobboo19bobobo8bo26bobbo44bo20boo88boo51boo43boo
442boo47boo4boo$117bo29bobo18bobo25bobobbo27b3obo27boo20bobobo5b3o27b
oo45bobo18bo88boo49b3o45boo17boo3boo418boobboo20boo27bobo$116boo31bo
19bo27bo3bo22bo5bo3bo8bo40bo4bobbo42boo34boo16bobo206boo3bo423bobo18bo
bo29bo$124boo23boo14bo35bo22boo5bo3bo5b3o41bo3bobboo41boo52boo146boo
66bo422bobboo15bo31boo$124boo38bobo4boo25b3o22boobo5bob3o3bo296bobo64b
oo441boo23boo$163bo3bo3bo31bo18bobb3o5b3o4boo44boobbo199bobo46bo59boo
bbo421boobbo3bo38boo$162bo3bo5b3o27bobo16bobobo8bo54bobo199boo46boo58b
o3bo422bobbo4bo$130bo30bo3bo8bo21boo5boo15bobobo13bo51boobboo11bo183bo
94boo12b3o420b3o5bobobo$129bobo28bo3bo31bobboo17b3obbo13bobo42bo11boo
11b3o260bo16bo10bobo422bo8bobobo30bo$130bo30bobo33boobo18boboo15boobb
oo21boo13b3o27bo258boboboboo7b3o11boo113bobo317bo4bo27bobo$162bo35bo5b
oo14boo20boo17boobboo12bo29boo237boo20booboobo7bo128boo319bo3bo28bo$
198bo5boo11bo3bo38bobo16boo40boo3boo32boo187bo164bo$184b3o12boo15bobo
42bo7boo51bo3bo20boo11boo184b3o486boo$184b3o14bo14boo39bo12bo22b3o23b
3o5b3o18bo197bo$184b3o10bo3b3o16boo34bobo4boo5bobo20bo25bo9bo15b3o35b
oo5boo$187b3o5b3o6bo15bobo32bo3bo3bo7boo4boo15bo16b3o31bo37boobboobbo
104bo$187b3o4bo8boo10boo5bo31bo3bo5b3o9bobbo30bobbo73boboo106boo$187b
3o4boo19boo5boo29bo3bo8bo10boo31bo3bo49boo23bo106boo$252bo3bo32boo18b
oobobo50bo23bo$192bo54boo4bobo33boo18booboo48b3o18boobboo$191bobo49boo
bboo5bo55b3o49bo20bobbo$192boobboo44bobo140boo90bo$185boo9boo45bo34bo
35bo163bo$185boo90bobo32b5o4boo153b3o$239boo4boo30bobo33bobbo4boo$237b
oboo4bo32bo32b3obboo$236bo9b3o62boobb3o383bobo$239bo8bo26boo3boo29bo
389boo$235boobo37bo3bo19boo9boobo387bo$235boo36b3o5b3o15bobo10b3o$273b
o9bo9bo5bo13bo$159bo132bobo3boo212bo$158bobo19bo110bo3bo214bobo$158bob
o18boo111bo3bo8bo205boo$157booboo16bob3o110bo3bo5b3o$178boboboo110bo3b
o3bo371bo$157booboo17b4o56bo55bobo4boo368boo$158boboo18boo14boo40boo
56bo376boo29bobo$156bo39bobo38boboo59bo403boo$156boo40bo37b3obbo31b3o
23bobo403bo$198boo38bobobo29bo27boobboo$239bobobo28bo3bo27boo$164boo
74bobb3o21boo3bobbobo8bo$158boo4boo47boo26boobo29bobobbo4b3o$157bobo
27boo20boobboo27boo22bo3bo4bo3bo3bo$157bo29bobo18bobo31bo3bo18bo4bo8bo
3boo$156boo31bo15boobbo35bobo16bobobo7b3o$164boo23boo48boo5boo15bobobo
13bo$164boo38bo3bobboo26bobboo17bo4bo13bobo$203bo4bobbo28boobo17bo3bo
15boobboo21boo$202bobobo5b3o26bo5boo36boo17boobboo$170bo30bobobo8bo13b
o12bo5boo11bobboo38bobo$169bobo27bo4bo22bobo12boo15bobo42bo$170bo28bo
3bo22bo3bo13bo14boo39bo$227bo3bo8bo3b3o16boo34b3o4boo$201boo25bo3bo5b
3o6bo15bobo32bob3o3bo258bobo$229bo3bo3bo8boo10boo5bo31bo3bo5b3o256boo$
230bobo4boo19boo5boo29bo3bo8bo256bo$231bo63b3obo$235bo54boo4b3o$234bob
o49boobboo5bo$235boobboo44bobo44bo$228boo9boo45bo44boo$228boo70bo29bob
oo$281b3o4boo9bobo27b3obbo$281b3o4bo11bo30bobobo8bo313bo$281b3o5b3o40b
obobo5b3o312bo$278b3o10bo41bobb3obbo315b3o$278b3o13boo38boobo3boo$278b
3o13boo23boo14boo245bo$286boo31bo15bo3bo243bo$202bo84bo29bobo18bobo
217bo22b3o$201bobo83bobo27boo20boobboo211bobo$201bobo84boo4boo47boo
212boo$200booboo16boo71boo$221boo$200booboo123boo$201boboo34boo45boo
40bo200bo132bo$199bo39bobo44bo39bobo201boo128boo$199boo40bo46boboo34b
oo201boo130boo$241boo44booboo$308boo7bo$207boo78booboo16boo7bo308bobo$
201boo4boo47boo30bobo24bobo308boo$200bobo27boo20boobboo30bobo24bo311bo
$200bo29bobo18bobo35bo26bo$199boo31bo19bo113bo205bobo$207boo23boo14bo
324boo$207boo45boo108bob3o204bo$246b3obo3bo111boobo8bo$245boboo6b3o
108boboo6b3o167bo$213bo31boobo8bo109b3obo3bo171boo$212bobo28bob3o127b
oo169boo$213bo101boo52bo260bo$245bo69boo9boo45bo255bo$322boobboo44bobo
254b3o$321bobo49boobboo$322bo54boo4b3o$383b3o$318boo4boo19boo5boo29b3o
10bo$316boboo4bo8boo10boo5bo33b3o5b3o$315bo9b3o6bo15bobo33b3o4bo$318bo
8bo3b3o16boo34b3o4boo$314boobo13bo14boo$314boo13boo15bobo42bo$328bo5b
oo11bo42bobo$328bo5boo14b3o19boo17boobboo165bo$327boobo18bo18boobboo
21boo163bobo$326bobboo7bo10bo3bo13bobo191boo$326boo5booboo11bobbobo13b
o$332bobobboo12bobobbo7bo253bo$297b3o33bo18bo3bo6bobo4boo244boo$266bo
29bo32bo26bo5bo3bo3bo246boo$265bobo28bo3bo27b3o22b3o5bo3bo5b3o$266bo
29bobbobo8bo16bob3o28bo3bo8bo$298bobobbo4b3o15bo3bo28bo3bo27boo$299bo
3bo3bo17bo3bo30bobo24boobboo$260boo41bo3boo15b3obo32bo24bobo$260boo23b
oo13b3o22b3o59bo$252boo31bo19bo20bo$253bo29bobo18bobo76boo4boo$253bobo
27boo20boobboo70boboo4bo$254boo4boo47boo69bo9b3o$260boo121bo8bo$379boo
bo$294boo83boo4boo$252boo40bo65bo9bo15bo$252bo39bobo65b3o5b3o15bobo$
254boboo34boo69bo3bo19boo$253booboo104boo3boo$274boo$253booboo16boo$
254bobo151boo$254bobo151boo$255bo75boo$472boo$329bo3bo115bo20bobbo$
329bo4bo41boo71b3o18boobboo$331bobobo8bo31boo74bo23bo$332bobobo5b3o19b
oo85boo23bo$333bo4bobbo21bobbo107boboo$334bo3bobboo15boo4boo66bo37boo
bboobbo$281boo74bobo46bo9bo15b3o35boo5boo$281boo9boo41boobbo17bo48b3o
5b3o18bo141boo$288boobboo44bobo15boo51bo3bo20boo11boo127bobo$287bobo
49boobboo21boo40boo3boo32boo129bo$288bo54boo4boo15bo29boo$284bo64boobo
14b3o27bo13bo$290boo19boo5boo33bo8bo6bo11boo11b3o13bobo$282b3obo3bo8b
oo10boo5bo31bo9b3o14boobboo11bo15bobo173bo$281boboo6b3o6bo15bobo32bob
oo4bo16bobo32bo174boo$281boobo8bo3b3o16boo35boo4boo16bo207bobo$279bob
3o13bo14boo58b3o$295boo15bobo42bo17bo3boo41boo52boo$281bo12bo5boo11bo
42bobo12bo3bo3bo42boo34boo16bobo$294bo5boo15bo20boo17boobboo7bobobbo4b
3o27boo45bobo18bo$259boo32boobo19b3o15boobboo21boo5bobbobo8bo26bobbo
44bo20boo$292bobboo18b3obo13bobo32bo3bo31boo4boo44boo4boo$228bo28bo3bo
30boo5boo15bo3bo13bo33bo34bobo25bo3boo23bobbo93boo$227bobo27bo4bo35bob
o16bo3bo47b3o31bo26bobo3bo23boo94bobo$228bo30bobobo8bo26bo18bob3o6b3o
4boo64boo26boo3bo33boo87bo$260bobobo5b3o22bo23b3o7b3o4bo75boo20bo12boo
20boo98bo$261bo4bobbo24bobo23bo8b3o5b3o72bo17b5obo10bo121boo$222boo38b
o3bobboo22bo3bo28b3o10bo73b3o14bo4boo11b3o117bobo$222boo23boo43bo3bo
29b3o28boo56bo11bo3b3o16bo27boo$214boo31bo15boobbo23bo3bo30b3o24boobb
oo67boo5boboo41bo$215bo29bobo18bobo21bo3bo57bobo71bobo5bobo42bo$215bob
o27boo20boobboo18bobo59bo124boo$216boo4boo47boo19bo56bo$222boo131boo$
347b3obo3bo$256boo88boboo6b3o$214boo40bo89boobo8bo$214bo39bobo87bob3o$
216boboo34boo95boo$215booboo106bo9bo9bo5bo$236boo88b3o5b3o15bobo104boo
$215booboo16boo91bo3bo19boo105bo$216bobo109boo3boo125bobo$216bobo242b
oo$217bo113bo$330bobo41boo$293boo35bobo41boo$293boobo34bo$297bo8bo45b
oobbo81boo$294bo9b3o44b3obboo57bo20bobbo$295boboo4bo38boo8boobb3o56b3o
18boobboo$297boo4boo37boo8boobboo60bo23bo126boo6boo17booboobo7bo$243b
oo85boo85boo23bo126bobbo4boo16boboboboo7b3o11boo$243boo9boo45bo27bobbo
107boboo63boo57booboboo23bo16bo10bobo$250boobboo44bobo21boo4boo66bo37b
oobboobbo61bobo56bobobo42boo12b3o$249bobo49boobboo5bo10bobo46bo9bo15b
3o35boo5boo17boo15boo27bo56bo3boboo52bo3bo$250bo54boo4bobo9bo48b3o5b3o
18bo60boo15bobo37bo44boobbobboo52boobbo$310bo3bo7boo51bo3bo20boo11boo
66bo37boo47boo60boo$245b3o4boo19boo5boo29bo3bo16boo40boo3boo32boo66boo
35bobo110bo$245b3o4bo8boo10boo5bo31bo3bo5b4o6bo29boo260boo3bo$245b3o5b
3o6bo15bobo32bo3bo3bo3bo7b3o27bo241boo17boo3boo$185bo30b3o23b3o10bo3b
3o16boo34bobo4boo12bo11boo11b3o242boo$184bobo29b3o23b3o14bo14boo39bo
27boobboo11bo$185bo30b3o10bo12b3o12boo15bobo42bo22bobo$219b3o5b3o26bo
5boo11bo3bo28boo8bobo22bo131bo$219b3o4bo29bo5boo14boo20boo6bobo8boobb
oo14bo133b3o$179boo38b3o4boo27boobo18boboo15boobboo6bo14boo13b3o4boo
41boo52boo28bo44boo$179boo23boo48bobboo17b3obbo13bobo39bob3o3bo42boo
34boo16bobo27boo44boo54boo32boo$171boo31bo19bo29boo5boo15bobobo13bo39b
o3bo5b3o27boo45bobo18bo72bo56boo11boo20bo$172bo29bobo18bobo34bobo16bob
obo8bo42bo3bo8bo26bobbo44bo20boo141bo19bo$172bobo27boo20boobboo31bo18b
obb3o5b3o4boo34b3obo31boo4boo44boo4boo158b3o16boo$173boo4boo47boo26b3o
22boobo5bob3o3bo36b3o31bobo25bo3boo23bobbo160bo20boo$179boo78bo22boo5b
o3bo5b3o34bo32bo26bobo3bo23boo184bo$192b3o60bo3bo22bo5bo3bo8bo66boo26b
oo3bo33boo125boo45b3o$193bo19boo39bobobbo27b3obo27boo57boo20bo12boo20b
oo125bo46bo$171boo20bobbo5boo9bo38bobbobo30b3o24boobboo57bo17b5obo10bo
149b3o$171bo16b3obb4o8bo5bobo38bo3bo32bo24bobo62b3o14bo4boo11b3o148bo$
173boboo12boobb3o6bobo6boo39bo62bo65bo15b3o16bo27boo6boo$172booboo13b
3o10bo49b3o143boboo41bo7boo173boo$191bo118b3o4boo81bobo42bo181bobo$
172booboo133b3o4bo126boo108boo46boo25bo$173bobo24boo108b3o5b3o233boo3b
oo42bo25boo$173bobo23bobbo104b3o10bo238boo42bobo15boo$174bo25boo105b3o
294boo15boo$193b3o55bo55b3o3boo$250b3o35bo9bo15bo231boo12boo$249b3obo
34b3o5b3o15bobo230bo5boo5bo$250bo3bo8bo27bo3bo19boo150boo75b3o6boo6b3o
$251bo3bo5b3o26boo3boo170boo75bo18bo$252bob3o3bo164boo$253b3o4boo164bo
$200boo52bo81boo88bobo$200boo9boo45bo77boo89boo96boo6boo20boobo7bo$
207boobboo44bobo9bo255bobbo4boo20boboo7b3o11boo$206bobo49boobboo4boo
130boo120booboboo40bo10bobo17booboobboo$207bo54boo3boboo106bo20bobbo
119bobobo42boo12b3o16bobobbobo13boo$202b3o61b3obbo32boo71b3o18boobboo
117bo3boboo52bo3bo14bo3boo16bobo$205bo3boo19boo5boo29bobobo8bo22boo74b
o23bo115boobbobboo52boobbo15boobo19bo$201bo3bo3bo8boo10boo5bo31bobobo
5b3o10boo85boo23bo119boo9b3o48boo14bobobbo16boo$200bobobbo4b3o6bo15bob
o32bobb3obbo12bobbo107boboo181bo14bobobobo$198bobbobo8bo3b3o16boo34boo
bo3boo6boo4boo66bo37boobboobbo128bobbo41boo3bo17booboo$198bo3bo13bo14b
oo39boo11bobo46bo9bo15b3o35boo5boo129boo23boo17boo3boo$198bo15boo15bob
o38bo3bo8bo48b3o5b3o18bo172bo24boo$199b3o11bo5boo11bo42bobo6boo51bo3bo
20boo11boo155b3o$174b3o36bo5boo36boo17boobboo12boo40boo3boo32boo51boo
15boo86b3o$143bo29bo38boobo19boo16boobboo21boo12bo29boo102boo15bobo85b
oo$142bobo28bo3bo33bobboo19boobo13bobo40b3o27bo13bo107bo78boo$143bo29b
obbobo8bo23boo5boo19bo9boobbo43bo11boo11b3o13bobo106boo23b3o50bobbo83b
oo$175bobobbo4b3o29bobo16bo68boobboo11bo15bobo133bo50bobbo35boo46boo$
176bo3bo3bo33bo18boboo7bo3bobboo47bobo32bo133bo51booboo13boo20bo$137b
oo41bo3boo28bo24boo6bo4bobbo45bo3bo48boo171boo14bo19bo$137boo23boo13b
3o66bobobo5b3o42boo50bobbo187b3o16boo$129boo31bo19bo29b3obo28bobobo8bo
41boobo3boo39bo4bobbo47boo140bo20boo$130bo29bobo18bobo27boboo28bo4bo
27boo21bobb3obbo41bobbooboo29boo16bobo34bo126bo$130bobo27boo20boobboo
23boobo28bo3bo24boobboo20bobobo5b3o27boo8bo4boo30bobo18bo32b3o76boo45b
3o55boo$131boo4boo47boo21bob3o57bobo23bobobo8bo26bobbo44bo20boo30bo79b
o46bo36boo19bo$137boo106boo25bo22b3obbo31boo4boo44boo4boo46boo79b3o81b
o17bobo$211bo55b3o26boboo31bobo25bo3boo23bobbo129bo81bobo15boo$171boo
97bo3boo21boo32bo26bobo3bo23boo214boo4bo$129boo40bo94bo3bo3bo23bo31boo
26boo3bo33boo184boo24bobo$129bo39bobo93bobobbo4b3o62boo20bo12boo20boo
184bobo23bobo$131boboo34boo92bobbobo8bo62bo17b5obo10bo84bo49boo46boo
25bo24bo10boo10boo$130booboo128bo3bo73b3o14bo4boo11b3o81boo48boo3boo
42bo25boo34bobo8bobbo$151boo110bo6boo71bo15b3o16bo27boo51bobo53boo42bo
bo15boo44bo$130booboo16boo92bo9bo8b3o4bo89boboo41bo153boo15boo44boo$
131bobo111b3o5b3o15bobo88bobo42bo200boo8b3o12bo$131bobo114bo3bo19boo
132boo10boo82boo12boo91bo8bo14bobb3o4bobo$132bo75boo37boo3boo164boo83b
o5boo5bo89b3o10bo18bo4bobo$500b3o6boo6b3o86bo27b4o4bobbo$206bo3bo289bo
18bo113bobo6b3o$196boo8bo4bo81boo337b3o9bo$196bobo9bobobo8bo71boo338b
3o6b3o6bo$196bo12bobobo5b3o413bo13bobo$210bo4bobbo138boo260boo29boo$
211bo3bobboo114bo20bobbo124boo6boo20boobo7bo93bobo38boo5boo$158boo101b
oo71b3o18boobboo26boo94bobbo4boo20boboo7b3o11boo16booboobboo53bo40boo
5bo$158boo9boo41boobbo44boo74bo23bo26bo44boo45booboboo40bo10bobo16bobo
bbobo13boo37boo45bobo$165boobboo44bobo18boo11boo85boo23bo26bobo42boo
44bobobo42boo12b3o13bo3boo16bobo83boo$164bobo49boobboo14bo11bobbo107bo
boo26boo88bo3boboo52bo3bo13boobo19bo62boo5boo8boo$165bo54boo4boo9b3o3b
oo4boo66bo37boobboobbo114boobbobboo52boobbo14bobobbo16boo62bo5boo8bobo
$161bo64boobo9bobbobo46bo9bo15b3o35boo5boo118boo60boo12bobobobo79bobo
14bo$167boo19boo5boo33bo11bo48b3o5b3o18bo224bo13booboo81boo18bo$159b3o
bo3bo8boo10boo5bo31bo9b6o51bo3bo20boo11boo204boo3bo94boo9boo13bobo$
158boboo6b3o6bo15bobo32boboo4bo14boo40boo3boo32boo185boo17boo3boo93bo
9bobo12bo3bo$133bo24boobo8bo3b3o16boo35boo4boobbo10bo29boo236boo118b3o
7bo14bo3bo$101bo54bob3o13bo14boo49b3o9b3o27bo13bo344bo23bo3bo$100bobo
28bob3o36boo15bobo42bo8bo10bo11boo11b3o13bobo346b3o19bo3bo$101bo31boob
o8bo12bo12bo5boo11bo42bobo6boo18boobboo11bo15bobo108boo236b3o20bobo$
133boboo6b3o25bo5boo15bo20boo17boobboo21bobo32bo109boo160boo40boo5boo
25b3o21bo$134b3obo3bo27boobo19b3o15boobboo21boo22bo305boo41bo5boo22b3o
$95boo45boo25bobboo18b3obo13bobo177boo96boo32boo87bobo27b3o$95boo23boo
14bo32boo5boo15bo3bo13bo46boo4boo41boo52boo27boo96boo11boo20bo88boo27b
3o$87boo31bo19bo34bobo16bo3bo57boboo4bo42boo34boo16bobo137bo19bo94boo
51boo5boo$88bo29bobo18bobo34bo18bob3o6b3o4boo40bo9b3o27boo45bobo18bo
38booboo95b3o16boo92bobo10boo39boo5bo$88bobo27boo20boobboo26bo23b3o7b
3o4bo44bo8bo26bobbo44bo20boo37boobo98bo20boo85bo3bo11boo44bobo$89boo4b
oo47boo25bobo23bo8b3o5b3o37boobo31boo4boo44boo4boo58bo118bo52boo31boo
10bo49boo$95boo73bo3bo28b3o10bo37boo32bobo25bo3boo23bobbo52bob5o68boo
45b3o32boo19bo31boobo10bo44boo$107boo8bo51bo3bo29b3o28boo52bo26bobo3bo
23boo54boo73bo46bo35bo17bobo30bobb3o7b3o26boo5boo9bobo$106b3obo5bo12b
oo37bo3bo30b3o24boobboo51boo26boo3bo33boo48boo71b3o79bobo15boo30bobobo
39bo5boo10bo$87boo16bobo3boo7boo7bo37bo3bo57bobo65boo20bo12boo20boo49b
o73bo80boo4bo6boo33bobobo40bobo$87bo17bobobboo5bob3o5bobo38bobo59bo66b
o17b5obo10bo49boo18b3o160bobo4bobbo30b3obbo27boo13boo18boo$89boboo13b
3o9bo8boo40bo56bo71b3o14bo4boo11b3o47bo18bo138boo22bobo5boo32boboo7boo
19bo18boo14boobo$88booboo13b3o14bo108boo66bo15b3o16bo27boo5boo11bobo
155bobo22bo10boo10boo17boo9bo17bobo17bobo18bo$119bo4bo99b3obo3bo85bob
oo41bo7bo12boo82boo46boo25bo33bobo9boo18bo9bobo15boo19bo16bo$88booboo
27bobo100boboo6b3o83bobo42bo6bobo94boo3boo42bo25boo34bo40boo4bo6boo19b
o21boboo$89bobo24boo105boobo8bo127boo7boobboo95boo42bobo15boo42boo44bo
bo4bobbo17b3o22boo$89bobo23bobbo102bob3o150boo140boo15boo27boo59bobo5b
oo17bob3o$90bo25boo110boo133boo200bo60bo10boo12bo3bo$109b3o91bo9bo9bo
5bo132bobo95boo12boo86b3o72bobo10bo3bo$166b3o34b3o5b3o15bobo131bo97bo
5boo5bo87bo76bo9b3obo$166b3o37bo3bo19boo145boo79b3o6boo6b3o161boo9b3o$
166b3o10bo25boo3boo159boo4boo79bo18bo146boo25bo$169b3o5b3o191boo252bo$
169b3o4bo442boob3o30bo$169b3o4boo73boo91boo229boo42boobo31boo$116boo
133boo92bo101bo126bobo38boo5bo30boboo$116boo9boo45bo170bobo99b3o124bo
40boo5boboo26b3obbo$123boobboo44bobo139boo29boo102bo63booboobboo50boo
45boboboo28bobobo8bo$122bobo49boobboo5bo106bo20bobbo55boo75boo23boobo
7bo29bobobbobo13boo82boo33bobobo5b3o$123bo54boo4b3o32boo71b3o18boobboo
52bobo100boboo7b3o11boo13bo3boo16bobo60boo5boo8boo38bobb3obbo$119bo63b
3obo31boo74bo23bo51bo116bo10bobo13boobo19bo61bo5boo8bobo38boobo3boo$
118bobo4boo19boo5boo29bo3bo8bo9boo85boo23bo50boo115boo12b3o12bobobbo
16boo60bobo14bo40boo$117bo3bo3bo8boo10boo5bo31bo3bo5b3o8bobbo107boboo
119boo58bo3bo11bobobobo78boo17b3o35bo3bo$116bo3bo5b3o6bo15bobo32bob3o
3bo6boo4boo66bo37boobboobbo118bo59boobbo12booboo72boo9boo12bo41bobo$
115bo3bo8bo3b3o16boo34b3o4boo4bobo46bo9bo15b3o35boo5boo116bobo64boo87b
o9bobo12bo3bo38boobboo$114bo3bo13bo14boo39bo11bo48b3o5b3o18bo159boo20b
oobboo40bo88b3o7bo13bobbobo41boo$115bobo12boo15bobo42bo6boo51bo3bo20b
oo11boo71boo94b3obboo33boo3bo92bo3bo19bobobbo66boo5boo$116bo12bo5boo
11bobboo38bobo15boo40boo3boo32boo7bo63boo95boobb3o13boo17boo3boo94b3o
19bo3bo66boo5bo$129bo5boo36boo17boobboo11bo29boo220bobboo14boo117bob3o
22bo71bobo$128boobo17bo3bo15boobboo21boo12b3o27bo13bo45boobo43boo68boo
147boo5boo23bo3bo20b3o72boo$127bobboo17bo4bo13bobo41bo11boo11b3o13bobo
46boboboo39boo68boo107boo39bo5boo22bo3bo92boo$127boo5boo15bobobo13bo
50boobboo11bo15bobo46b3oboo217bobbo38bobo26b3obo93bobo$133bobo16bobobo
7b3o52bobo32bo49boo53booboo161booboo38boo27b3o95bobboo$130bo3bo18bo4bo
8bo3boo47bo122bo15boobo163bo45boo24bo26boo5boo$130boo22bo3bo4bo3bo3bo
44bo125boo20bo84boo32boo41bobbo41bobo10boo39boo5bo63bo3bo$129boobo29bo
bobbo4b3o40b3o4boo41boo52boo21bobo13bob5o84boo11boo20bo42bobo42bo11boo
44bobo27boo34bo4bo$128bobb3o21boo3bobbobo8bo39bob3o3bo42boo34boo16bobo
36boo102bo19bo85bo61boo24boobboo3boo31bobobo$127bobobo28bo3bo27boo19bo
3bo5b3o27boo45bobo18bo39boo100b3o16boo53boo87boo27bobo6bobo32bobobo$
126bobobo29bo27boobboo18bo3bo8bo26bobbo44bo20boo39bo102bo20boo28boo19b
o28b3obo37boo5boo9bobo27bo7bo35bo4bo$124b3obbo31b3o23bobo21b3obo31boo
4boo44boo4boo32boo18b3o125bo29bo17bobo27boboo40bo5boo10bo23b3o9boo36bo
3bo$125boboo59bo23b3o31bobo25bo3boo23bobbo33bo18bo124b3o30bobo15boo28b
oobo40bobo19bo22bo3boobbo$126boo56bo28bo32bo26bobo3bo23boo22boo11bobo
141bo33boo11bo31bob3o27boo13boo18bobo17bo3bo3bo3bo27bo11boo$127bo55bob
o4boo53boo26boo3bo33boo14bo12boo12boo166b3o5boo41boo19bo18boo13bo3bo
15bobobbo4b3o26b3o$182bo3bo3bo64boo20bo12boo20boo14bobo24boo24boo140b
3o6bo32bo9bo17bobo17bobo14bo3bo12bobbobo4bobo4boo5boo14bo$181bo3bo5b3o
61bo17b5obo10bo38boobboo45bobo44boo106boo10boo26bobo15boo15bo3bo16bo3b
o11bo3bo5boo6bo5boo14boo$180bo3bo8bo62b3o14bo4boo11b3o39boo47bo44boo
73boo31bobo9boo27boo4bo27boo20bo3bo10bo17bobo$179bo3bo74bo15b3o16bo27b
oo179bobo32bo43bobo25boobo20bobo12b3o15boo$180bobo3boo88boboo41bo155b
oo25bo32boo42bobo24bobb3o20bo35boo$161bo9bo9bo5bo89bobo42bo155bo25boo
16boo58bo10boo12bobobo57bobo$161b3o5b3o15bobo131boo11boo142bobo15boo
25bo69bobo10bobobo59bo$164bo3bo19boo138boo4boo10b4o129boo15boo22b3o72b
o8b3obbo87bo$163boo3boo158boo15boobbo5boo15boo4bo141bo74boo8boboo56b3o
27b3o$344boobbo4boboboo16booboo15boo6boo17booboobo7bo143boo24boo57b3o
26bo$345bobbobboo5bo17bobbo15bobbo4boo16boboboboo7b3o11boo129bo25bo57b
3o26boo$209boo135boo6bo3bo13boo6boo10booboboo23bo16bo10bobo125b3o81b3o
7boo$209boo140bo5bo14bo8bo9bobobo42boo12b3o123bo32bo50b3o7boo$352b4o
17bo6bo10bo3boboo52bo3bo77boo127b3o$273boo54boo23bo18b3o14boobbobboo
52boobbo76bobo38boo5boo27bob3o$250bo20bobbo27boo24bobo40b3o20boo60boo
74bo40boo5bo30boobo8bo$177boo71b3o18boobboo26bo24bo42bobo83bo73boo45bo
bo30boboo6b3o$177boo74bo23bo25bobo21boo42bo15boo61boo3bo122boo32b3obo
3bo$165boo85boo23bo26boo66bo14boo42boo17boo3boo18booboobboo73boo5boo8b
oo44boo62boo$164bobbo107boboo152boo43bobobbobo13boo59bo5boo8bobo37bo
69boo$159boo4boo66bo37boobboobbo195bo3boo16bobo58bobo14bobboo38bo$158b
obo46bo9bo15b3o35boo5boo95b3o98boobo19bo59boo56bobo$158bo48b3o5b3o18bo
240bobobbo16boo51boo9boo11bo3bo37boobboo$157boo51bo3bo20boo11boo127boo
98bobobobo68bo9bobo11bo4bo40boo$167boo40boo3boo32boo127bobo98booboo70b
3o3bo3bo14bobobo66boo5boo$167bo29boo178bobbo19boo32boo119bo3boo10bo7bo
bobo65boo5bo$168b3o27bo13bo165boboo18boo11boo20bo122boobo10bo7bo4bo68b
obo45bo$170bo11boo11b3o13bobo107boo57bo32bo19bo123bobb3o7b3o8bo3bo68b
oo45bobo$178boobboo11bo15bobo107boo91b3o16boo89boo5boo23bobobo89boo50b
o$177bobo32bo166bo36bo20boo86bo5boo22bobobo22boo66bobo$174boobbo126boo
71bo59bo86bobo25b3obbo92bo$305boo81boo45b3o49boo37boo26boboo$173bo3bo
bboo41boo52boo109bo46bo51boo41boo23boo26boo5boo62boo36boo3boo$172bo4bo
bbo42boo34boo16bobo37booboo67b3o137bobo10boo12bo26boo5bo25boo36boobo
34boo3boo$171bobobo5b3o27boo45bobo18bo37boobo70bo138bo11boo44bobo21boo
bboo3boo35bo$170bobobo8bo26bobbo44bo20boo41bo265boo21bobo6bobo32bo$
168bo4bo31boo4boo44boo4boo51bob5o130boo70b3o56boo22boobbo7bo35boboo24b
oboo$168bo3bo31bobo25bo3boo23bobbo51boo61bobo71bobo69b3o38boo5boo9bobo
32boo37boo22b3oboo$204bo26bobo3bo23boo56boo58bobo46boo25bo42boo25b3o
39bo5boo10bo21bo3bobboobbo62bo11boo$170boo31boo26boo3bo33boo48bo58b3o
3boo42bo25boo20boo19bo23b3o42bobo18b3o15bo4bobbo3bo27bo35b3oboo5bo$
213boo20bo12boo20boo25boo18b3o65boo18bobo21bobo15boo29bo17bobo23b3o28b
oo13boo17bo17bobobo5b3o26b3o37bobobbo4b3o$213bo17b5obo10bo49bo18bo88b
oo22boo15boo29bobo15boo24b3o7boo19bo18boo13bo3bo12bobobo4bobo4boo5boo
14bo44boo6bo$214b3o14bo4boo11b3o33boo11bobo105bo72boo4bo6boo39bo17bobo
17bobo13bobbobo9bo4bo5boo6bo5boo14boo$216bo15b3o16bo27boo5bo12boo71boo
12boo96bobo4bobbo38bobo15boo19bo16bobobbo7bo3bo14bobo$234boboo41bo6bob
o84bo5boo5bo97bobo5boo40boo4bo27bo21bo3bo27boo$235bobo42bo6boobboo77b
3o6boo6b3o95bo10boo10boo29bobo52bo9boo20boo$279boo10boo77bo18bo106bobo
9boo29bobo24b3obo20b3o31bobo$498bo41bo10boo12boboo57bo$279boo217boo51b
obo11boobo53bo30bo$278bobo202boo68bo9bob3o53b3o27b3o$279bo12boo190bo
68boo65bob3o25bo$286boo4boo187b3o54boo25bo53bo3bo26boo$286boo138booboo
bboo46bo57bo78bo3bo5boo8bo$427bobobbobo13boo86b3o78b3obo6boo6bobo$426b
o3boo16bobo85bo81b3o16boo$260boo165boobo19bo117b3o48bo$261bo166bobobbo
16boo116b3o$261bobo164bobobobo59boo72b3o10bo$262boo23boo140booboo59bob
o38boo5boo28b3o5b3o$286bobo204bo40boo5bo29b3o4bo61boo$286bo205boo45bob
o29b3o4boo60boo$285boo252boo$518boo5boo8boo39bo$519bo5boo8bobo37bobo$
519bobo14bobboo35boobboo$438boo80boo58boo$438boo73boo9boo11bo3bo65boo
5boo$279boo232bo9bobo11bo4bo64boo5bo43bo$279boo233b3o3bo3bo14bobobo68b
obo42bobo$516bo3boo18bobobo67boo44bo$263boo254boobo18bo4bo61boo$263boo
253bobb3o18bo3bo61bobo$449boo34boo5boo23bobobo87bo$275booboo148boo19bo
36bo5boo22bobobo22boo68bo34boo3boo$275boobo150bo17bobo36bobo25b3obbo
92bobo33boo3boo$259boo19bo148bobo15boo38boo26boboo55boo35bo3bo$258boo
14bob5o149boo4bo6boo46boo23boo26boo5boo17boobboo3boo31bo3bo$260bo13boo
159bobo4bobbo44bobo10boo12bo26boo5bo17bobo6bobo32bo3bo22boboo$277boo
156bobo5boo46bo11boo44bobo18bo7bo35bo3bo19b3oboo$278bo157bo10boo10boo
88boo26boo36bobo19bo11boo$255boo18b3o169bobo9boo25b3o56boo19boo4boobbo
39bo21b3oboo5bo$256bo18bo173bo36b3o38boo5boo9bobo16boboo4bo3bo27bo35bo
bobbo4b3o$243boo11bobo190boo35b3o39bo5boo10bo16bo9b3o26b3o39boo6bo$
244bo12boo12boo161boo47b3o42bobo18b3o14bo4bobo4boo5boo14bo$244bobo24b
oo162bo47b3o28boo13boo17bo13boobo5boo6bo5boo14boo$245boobboo181b3o48b
3o7boo19bo18boo13bo3bo9boo15bobo$249boo181bo61bo17bobo17bobo13bobbobo
26boo$494bobo15boo19bo16bobobbo28boo$270boo223boo4bo27bo21bo3bo27bobo$
500bobo52bo24bo3bo$250boo248bobo24b3obo20b3o25boo29bo$244boo4boo11boo
180boo54bo10boo12boboo49boobo26b3o$244boo16bobo6boo171bobo38boo5boo18b
obo11boobo48bobb3o24bo$261boobo6bobo170bo40boo5bo21bo9bob3o48bobobo26b
oo$262boo9bo169boo45bobo21boo60bobobo5boo$263bo3b4obbo216boo7boo25bo
47b3obbo6boo$268bobobo196boo5boo8boo12bo74boboo$270boo198bo5boo8bobo8b
3o76boo$245boo223bobo14bo9bo79bo$244bobo224boo18bo37b3o$244bo219boo9b
oo52b3o$243boo219bo9bobo12bob3o35b3o10bo55boo$465b3o3boobbo15boobo37b
3o5b3o55boo$467bo23boboo37b3o4bo$470bo3bo17b3obo35b3o4boo$469bo4bo$
436boo5boo23bobobo21bo42bo$437bo5boo22bobobo64bobo$437bobo25bo4bo66boo
bboo$438boo25bo3bo71boo73bo$442boo51boo5boo64boo5boo38bobo$441bobo10b
oo11boo26boo5bo65boo5bo40bo$442bo11boo44bobo70bobo$438bo61boo71boo$
437bobo56boo71boo$436bo3bo37boo5boo9bobo70bobo34boo3boo$435bo3bo39bo5b
oo10bo3bo68bo35boo3boo$434bo3bo40bobo18boo72bo$433bo3bo27boo13boo17bob
oo70bobo$434bobo7boo19bo18boo12b3obbo31boo35bo3bo21boboo$435bo9bo17bob
o17bobo14bobobo26boobboo3boo31bo3bo18b3oboo$445bobo15boo19bo16bobobo
24bobo6bobo32bo3bo16bo11boo$446boo4bo49bobb3o23bo7bo35bo3bo16b3oboo5bo
$451bobo26boo21boobo31boo36bobo19bobobbo4b3o$451bobo24boboo22boo21boo
4boobbo39bo24boo6bo$452bo10boo12bo26bo20boboo4bo3bo16bobo8bo$463bobo
14bo43bo9b3o17boo7b3o$465bo10boobo47bo4bobo4boo5boo7bo6bo$465boo9boo
45boobo5boo6bo5boo14boo$450boo71boo15bobo$451bo89boo$448b3o94boo$448bo
32bo62bobo$480bobo58bo3bo$479bo3bo57boo29bo$480bo3bo8bo46boobo26b3o$
481bo3bo5b3o45bobb3o24bo$482bo3bo3bo47bobobo26boo$483bobo4boo45bobobo
5boo$484bo50b3obbo6boo$488bo47boboo$487bobo47boo$488boobboo44bo$492boo
$519boo5boo$519boo5bo32boo$524bobo32boo$524boo$520boo$520bobo$521bo$
525bo$524b3o$486boo35b3obo49bo$482boobboo3boo31bo3bo47bobo$481bobo6bob
o32bo3bo47bo$482bo7bo35bob3o$489boo36b3o$477b3o4boobbo39bo$477b3o4bo3b
o13b3o11bo50boo3boo$477b3o5b3o14bo11b3o50boo3boo$474b3o6bobo4boo5boo4b
o9bo$474b3o6boo6bo5boo14boo$474b3o14bobo65boboo$492boo63b3oboo$496boo
58bo11boo$495bobo59b3oboo5bo$492boobbo62bobobbo4b3o$523bo39boo6bo$491b
o3bo25b3o$490bo4bo24bo$489bobobo14bo11boo$488bobobo5boo7bobo$486bo4bo
6boo7bobo$486bo3bo17bo$$488boo$511booboo$511booboo$511booboo$517bobo$
514boo$515bo3bo$515bo$518boo$519bo$514bo4bo$514bo3bo9bo$516boo9bobo$
528bo4$518boo3boo$518boo3boo3$510boboo$508b3oboo$507bo11boo$508b3oboo
5bo$510bobobbo4b3o$514boo6bo!
]]
--# Pseudogun
patterns[4] = [[#C Pseudo p34 gun based on two p102 Herschel factories.
#C Karel Suhajda, 18 Apr 2003 -- from Jason Summers' "guns1j"
#C  collection, which now contains the smallest known glider gun of
#C  every period between 14 and 999.  A separate "guns2j" collection
#C  contains a selection of small higher-period guns.
#C Construction methods are known for glider guns of all periods above
#C  the minimum of 14, and also for true period guns above p61
#C  -- the period of 'true' guns matches the period of the output,
#C  unlike pseudo-period guns such as this example.  As of this
#C  writing [September 2006] true guns are unknown for 36 periods.
#C It is quite possible that true guns exist for all these periods,
#C  but current search programs are unable to perform exhaustive
#C  searches for oscillators at anywhere near the periods neede to
#C  make direct glider generation possible.
#C In general, prime period guns need more space than composite
#C  numbers, especially multiples of large powers of two or three;
#C  in the latter case, various doubling and counting mechanisms
#C  can be used.  See p97307852711.rle in the Oscillators folder,
#C  which is trivial to convert to a prime-period gun.
#C P34 traffic-light eater from Jason Summers' "jslife" collection.
x = 243, y = 157, rule = B3/S23
185boboo$183b3obobbo9bo$182bo4boboo7b3o$178boobbooboobo8bo24bo$177bob
3o3bobbo8boo22bobo$155boo7bo12bo4boobboboo18bo12bob3o$154bobo7b3o9boob
oobobobo4bo3bo12b3o9boo4bo$154bo12bo7bobbobobobbobboobobbobo14bo7bobb
5o$152boob4o7boo8bobo3boobobo3bobbobboboo9boo8bobbo3boo$151bobo4bo16b
oobobo3boboboo4bobboboo18boobob3obbo$151boboboobboo8bo4bobboboboobobob
o5bobbo15bo8boboboboo$150boobo3boobbo6bobobb3o3bobbobobobo5boo16bobob
oobboobobbo$149bo3boboobbooboboobboo4bobbobobboboboo8bo11boobboo7bobob
oo$150b3o4bo4boboo9boo4boobbo22boo9boobobo$152boboobob3o14bobo4bobo34b
obobo$153bobooboo15bobbobobobboo33bobbo$176boo4bobo36boo$178b4obbo$
115bo62bobbobo$101boo10b3o66bo40boo5boo$100bobbo8bo45bo63bobo5bo$99bob
obo8boo43bobo62bo5bobo$99boboboo53boo61bo3bobboo$97boobobo3bo3bo43boo
64boo3bo$97bobbobboobobbobo41bobo22bo41bo5bo$94boobobobo4bobbobboboo
37bo5boo18boo39bo4bo$94bobboobboboo4bobboboo36boo5boo17boo41bo$95boo3b
obbo5bobbo110bobo$97booboobbo4boo$97bo4boo7bo48boo8boo59boo$98b3obo57b
o8boo25boo7boo17booboobbo$100bobo59bo8bo23bobo6bobbo14b3obob3obbo$101b
o59b4o32bo5bobobo10boobo4bo4b3o$74bo85bo4bo37boboboo5boobbooboboobboob
o$12bo47boo10b3o60boo23b5obo34boobobobbo3bobo6bobboo3boboo$11bobo45bo
bbo8bo62bobo21boo3bobbo10boo22bobbo3b3o3bo8boobboobobo$9b3obo44bobobo
8boo15boo5boo37bo22bobb3oboboo5boobboo19boobobbobobbo15bo4bobo$8bo4boo
11bo31boboboo25bo5boo35boob4o18boobobobo7bobo23bobboo4boo7boo7b4oboo$
8b5obbo8b3o29boobo4bo4bo19bobo39bobobobbo21bobboboobboobbo25boo4bobo8b
o12bo$6boo6bo8bo32bobboboboo3bobo19boo39boboboobboo19boobobo35bobobobb
o8b3o7bobo$5bobboboboboo7boo28boobobboo3bo4boobboo19boo34booboobboobbo
20boboboo7boo24bo4boo11bo7boo$5boobobobobbo37bobboobobboo9boo18bobo33b
o3boboobboobo19bobobo8bo26b3obo$8bobboboo6bo14boo16boobbobobo31bo35b3o
4boo3bo20bobbo9b3o25bobo$8boobo3bo4bobo12bobo18b5obbo68boboobob3o22boo
12bo26bo$10boboboo5boobboo8bo20bo4boo4bo65bobo3bo$10bobobo10boobboobb
oob4o17b3obo4bo$11bobbo14bobbobobobbo19bobo4b3o68bo$12boo17booboboobb
oo18bo31b5obo38bo54boo$32boboobboobbo47b3oboboobo85boo5boo$5boo5boo18b
oboboobboobo45bo4bo4b3o35bo47boo$6bo5boo19bo4boo3bo45boboobboboo3bo33b
obo64bobo15boo$6bobo25b3obob3o47bobboo3boboo34boo66boo15bo$7boo6bo20bo
3bo50boobbobbobo9bo19boo8boo45boo15bo17bo$11b4o78bo4bobo10boo16bobo8bo
bo12boo30boo32boo$10bob5o21bo54b4oboo10boo19bo3boo5bo12bobo23boo$11bo
26bo58bo37boo5boo13bo23boo$95bobo55b4oboo10b3o61boo$37bo57boo56bobbobo
bo11bo61bobo$11bo24bobo112boo4boobo10bo25boo3bo33bo$10b3o23boo112bobb
4oboboo35boobooboo13boo12b4oboo$7bobobobobo24boo107boboobboboo3bo34bo
7bo12boo12bobbobobo$6boboo3boobo23bobo106bo4bo4b3o34boo6bo25boo4boobo$
4b3o3bobo3bo18boo5bo107b3o3boobo37boobboo26bobb4oboboo$3bo3b3o4booboo
16boo5boo24bo42bo40bobobobo38boobboo25boboobboboo$3boobo3b3o4bo50b3o
38b3o41b3o72bo4bo4b3o$4boboobo5bobo7b3o43bo20boo14bo120b3o3b3obbo$4bo
5bobbo3boo8bo26boo14boo11boo6boo15boo86booboo30bobobobbo$bboob4ob4oboo
bbo6bo27boo27boo8bo101bobobobo30b3o3boo$bobobobbo5bo3bo83b3o49bo23boo
16bobbobo$bo4bobb4o3boo109bo25bobo23bo19boboo$ooboobboo4b3o25bo6boo48b
ooboboboo21boo24boo23bobo16boo3bo$3boboobb4obbo25bobo4boo51bobobbo20b
oo21boo28boo13bobobbobo24b3o3bo$3o5bo3bo28boo9boo48bob3o42bobo43boobb
ooboo23bo5boo$obb3obob3o40boo13bobobboo24boo20boo27bo5boo73bobb3o$bbo
bbobobo57bobboobbo23bo4bo15bobbo25boo5boo74bo3b3o$boo67boobbo24bo20boo
82booboo19bo7bobo$6b3o59boobbobo20boo3bo102bobboobo19bobbo5bo$47boo47b
o105bobo4bo21boo5boo$39bobo5boo44b3o6boboo17boo10bobo51boo12bob4oboo$
7bo32boo51bo6b3oboo17bo12boo51boboo12bo4boboboo$6bobo31bo26bo3boo26bo
24b3o9bo51booboboo9bobbobboboboo$7boo57bobo3bo27b3oboo20bo43boo18boob
oo6boobboo3bobo11bo$3boo61boo3bo30bobo64boo10b3o5boobboo6boboobboboobo
12bo$bbobo31boo32bo12boobboo13bobo4boo60bo12bo5bobo5boobo4bo4bo11b3o$
bbo5boo26bobo27b5obo10bo4bo14bo6bo70bobbo5b3o5bobob3obob3o$boo5boo28bo
27bo4boo11b4o8bo10b3o72boo16bo3b5o$34b4oboo26b3o11b3o3bobo4b3o10bo92bo
33boo5boo$34bobbo3bo27boboo4bo3bobbo3boo3bo104boboo32boo5bo$32boo5bobo
28bobo3bobo3bobo8boo103boobbo36bobo$31bobb3o4boo32bobobboboboo19boo94b
oo36boo$21boo7boboo4boo3bo31bobboobo3bo5bo12bobo99bo28boo$20boo8bo3bob
o3b3o33bobobbob3o4bobo11bo100bobo27bobo$22bo8b3o3boobo34boobobobobbo5b
oobbooboobboob4o97boo28bo$5boo5boo19bobobobo35bobbo5boo9boobobbobobobb
o84boo7boo$6bo5boo20b3o39boo4bobo15booboo4boo82bo7bobo$6bobo7bo18bo42b
5obo16bobob4obbo40bobo36bobo7bo5boo$7boo6bo62bo4bo17boboobobboobo40boo
36boo7boo5boo5b3o$11boobb3o54bo6b4o19bo4bo4bo40bo60bo20b5o$10bobo21bo
38bo29b3o3b3o95boo6bo17b3obob3o$11bo21bobo24b3o8b3o5boo24bobobo85bo11b
o24bo4bo4bo$33boo25bobbo15boo25b3o85bobo12bo21boboobobboobo$11bo25boo
21bobbo130bobo11b4o19bobo3boobbo$11bo25bobo21bobbo128boob3o8bo4bo17boo
bobbobboo$32boo5bo20boobbo96bo37bo7b5obo14bobbobo4bo$7bobo3bo18boo5boo
17b3obbo17bobo22bo55boo29boob3o6boobbobobo10boobboobboob4o$6boboobob3o
41boo3bo18boo22bobo53boo30boobo7bobboobobboo5boobboo8bo$4b3o4boo3bo15b
oo16boobo3bobboo20bo22boo97boobobboo3bo3bobo12bobo$3bo3boboobboobo14bo
bbo15boboo4b3o48boo89boo5bobboboboo4bo14boo$4booboobboobbo3boo10bobobo
73bobo68boo18bo6boobo4bo$5boboboobboo4boobboo5boobobo61bo6boo5bo67bobo
16bobo8boboboo7boo$5bobobobbo10bobo4bo3boboo59boo5boo5boo66bo18boo9bob
obo8bo$6boob4o11bo6boobobbo58bobo79boo10bo19bobbo9b3o$8bo21bobbobobob
oo147booboo18boo12bo$8bobo10boo7boobobobobbo22boo38boo84bobbo$9boo11bo
8bo6boo22bobbo38bo78bo6boo$19b3o9bob5o23bobobo36bo79bo$19bo9boobo4bo
23boboboo9boo22b4o78b3o$29bobbob3o22boobo4bo4boobboo21bo4bo$31boobo24b
obboboboo3bobo24bob5o$56boobobboo3bo4bo13boo10bobo4boo82bo$56bobboobo
bboo19boobboo5boo5bobbo70bo9bobo$57boobbobobo8boo14bobo4bobboboboboo
71boo7bobo$59b5obo8bo16bo5b3obobbo73boo9bo$59bo4boboo7b3o19bo3boboo69b
oo17boo$60b3obobbo9bo10boo7boobobo70bobo17bobo$62boboo23bo8bobobo70bo
21bo$86b3o9bobbo70boo21boo$86bo12boo$$186bobo$187boo$187bo6$195bo$196b
oo$195boo7$203bobo$204boo$204bo$$214b3o$$212bo5bo$212bo5bo$212bo5bo$$
214b3o!]]
--# ChannelBreeder
patterns[5] = [[#C p100 c/2 Herschel channel breeder: David Bell, 19 December 1996
#C [See also p100-H-track-puffer.rle in the Puffers folder, which
#C could easily be made into a breeder by adding a Herschel factory
#C of any desired period to the stationary end of the Herschel track.]
x = 647, y = 262, rule = B3/S23
183b6o4b4o$182bo5bo3b6o$188bo3b4oboo$182bo4bo8boo$169b5o10boo$157bo10b
o4bo$155bo3bo13bo33boo$160bo7bo3bo30b4oboo6boo$133b5o17bo4bo9bo32b6o5b
ooboo$132bo4bo18b5o43b4o6b4o$137bo47boo16bo11boo$132bo3bo48boo9bo6bo$
134bo61bo$167bo7b4o17bo6boo7b3o$145boo21bo6b5o20booboo5bo3boo$133boo5b
oo3boo20bo10bobo9boo9bob5obbobobboo$133boo5boo31boo4boo9boo10bobb3obo
5bo$172bobboo29bo3bobboo$130boo40boobobbo31bo$128bo4bo34boo4boobbo33bo
$117b3o14bo32b3o6b3o3bobo$116b5o7bo5bo34bo6boo4boo32boo$116b3oboo7b6o
48bo14boo14booboo$119boo36bobo4bo5boo24bo4bo12b4o$158bo4boo4boo31bo12b
oo$163b3obbo27bo5bo$167boo28b6o$122bobo42bo295boo$121bo4bo334bo4bo29b
oo$121bo4bo340bo26bo4bo$121boo338bo5bo32bo$462b6o26bo5bo$121boobboo24b
oo342b6o$121boobboo20b4oboo$121b3obo21b6o303boo$122bo25b4o300b4oboo17b
o54b4o$123bo328b6o17bobo52b6o6boo$453b4o18bobbo51b4oboo4b4o$476boo10b
4o28b3o11boo5booboo$170bo321bo30boo18boo$168bo3bo282boo28bo6bo12boo10b
o5b3o$173bo281boo8b3o14bob3o4bo13boo9boobo6bo$168bo4bo309boobo3bo35boo
$169b5o309b4o30bobo4bobo6boo$486boo28bo7bobo6bo7boo$510boo5bo4boobo7bo
bbo5boo$510boo6b4oboobo7b3o4boo$209b6o309bobo9boo3bo$128bo47boo30bo5bo
5b4o301bo$112boo12boobo45bobbo35bo4bo3bo$111b3o12bobboo32b3o3boo5boo
30bo4bo9bo263b5o50boo$111boobo14bo16boo9bo4bo3bobboo25boo12boo7bobbo
263bo4bo49b4o$112b3o31boo9bo4bo4bo20bo7boo293bo49booboo$113bo12b3o28bo
3bo5bo6bo11b3o17b3o8boo267bo3bo52boo$161boob4o6boo9b3obo14bo4bo6b5o
267bo$127bo33bo3boo6bobo8bo16bo5boo7bo4bo$151boo9bobbo17bobbo5b3o6bo3b
o10b3obbo$124b3o24boo9b4o11boo5bobo7boboo4bobbobo9bobboo298boo$125bobb
o5b3o40boo6boobo5boboo3bo4bobo9boo284boo12bo4bo$125bo10bo39bo11boo4boo
305b3oboo17bo$123boobo7bobo39bobo8boo11bo251bo48b5o12bo5bo$122boob3obb
o3boo38bo3bo274boo47b3o14b6o$124bo4bo68bo21b4o228boo$174bobo20bo21bo3b
o265boo$175bo21bo25bo261b4oboo3b6o$219bobbo262b6o3bo5bo$486b4o10bo$
474boo18bo4bo7boo$471b3oboo19boo7bo4bo$177b3o20b4o255b3o9b5o35bo4bobbo
$176b5o18bo3bo254b5o9b3o30bo5bo8bo$176b3oboo21bo230boo22b3oboo42b6o4bo
3bo$179boo18bobbo223boo3b3oboo24boo54b4o$422b4oboobb5o52boo$422b6o4b3o
53boo15b3o$423b4o71b3o$469boo7boo24boboo7boo$448boo21bo5bobb3o21bobo7b
obboo$436boo5boo3boo16bobboo12bo9boo9boo3bo3b3obbo$436boo5boo22bo9bo5b
o9boo11bob3obbo4bo$475boobo3bo30b5o$99bo375boobobo33boo$100boo360bo8b
oo5bobbo4bo$99boo362bo7boo6boo4bo30bobbo$469bo10bo4b3o32bo$427bo32bobo
5bo4bo42bo3bo$428boo30bobo10bo26b4o13b4o$427boo32bo4boo4boo25b6o$466b
oo3bo27b4oboo$469b3o31boo$108b3o448b5o$107b5o446bo4bo13b3o$107b3oboo
197b3o250bo13bobbo45b6o$95boo13boo106b5o86b5o137boo98b5obbo3bo14boobbo
28bo14bo5bo5b4o$93bo4bo118bo4bo86b3oboo134bo4bo95bo4bo4bo17bobbo26bo4b
o17bo4bo3bo$99bo122bo74boo13boo141bo99bo23bobo32bo15bo9bo$93bo5bo105b
4o8bo3bo73bo4bo148bo5bo94bo3bo42boo8bo5bo11boboo7bobbo$94b6o48b6o50b6o
9bo81bo148b6o96bo44boo9boo$123boo22bo5bo5b4o41b4oboo84bo5bo285bo37boo
8bo$62boo62boo25bo4bo3bo45boo52boo32b6o48b6o231bo21bobbobobb3o4b3o8b3o
$61b3o56boo5bo19bo4bo9bo95b4oboo6boo76bo5bo5b4o223bo18bo3bobbobb3obboo
4bo5bo3bo$61boobo32boo9bo10boo6bo21boo7bobbo96b6o5booboo81bo4bo3bo224b
3o10boo3bo9bobboboo5b5o4bo$62b3o32boo9bo7bo9bo17bo114b4o6b4o76bo4bo9bo
227bo9boo4bo10boo3boo4b4oboboo$63bo44bo12bo4bo16b3oboo79boo40boo45boo
9bo22boo7bobbo218boo33bobo7b3oboo3bo$115bo4bo4bo16boobbobo9boo68boo8b
3o14boo60boo9bo232bo18bo4bo4bobo25boo13bobo$115bob3o4bo16boobboobo4boo
3bobo87booboo5bo3bo65bo18b3o8boo199bo3bo19bo6boboo$74bo41booboobboo17b
o4bo12bo86bo9b3o5bo3bo65b3o7bo4bo6b5o202bo16boobbobo5boo$75boo43bo4bo
17bo14b3o86bo5bo3bobo4bo4boo64b3o6bo3boo7bo4bo196bo4bo16b3ob5oboboo42b
4o$74boo45b5o22boo83boo3boo8bo6bobbo5bo5boo50boo16bo4boo10b3obbo197b5o
18boo4bobo44bo3bo$125boboo19boo83boo15b5o14boo51boo15bobo3boobo9bobboo
220b3obbooboo47bo$128boo120b4o4bobbo77bobo5bobo9boo41bo233bobbo$107boo
15b5o87bo42boo142boo11bobo$104b3oboo16boo31b4o51bo3bo183boo11bo$104b5o
49bo3bo56bo89boo104bo$105b3o54bo51bo4bo51boo33b3oboo49b4o50bobbo159b6o
33b4o$158bobbo53b5o49booboo32b5o49bo3bo50b3o86bo72bo5bo32bo3bo$269b4o
34b3o54bo139bobo76bo36bo$270boo88bobbo140boo71bo4bo33bobbo$579boo$137b
4o78bobo$136b6o77boo86bo$136b4oboo77bo86bobo29b4o$140boo105b6o54boo29b
6o223boo$246bo5bo85b4oboo219b3oboo$252bo89boo220b5o66boo$246bo4bo307b
oo4b3o17bo11boo32b4oboo6boo$248boo306b3oboo23boo9bobbo31b6o5booboo$78b
o477b5o22b4o3bo6boo33b4o6b4o$78bobo476b3o7boo13boo6bo26boo24boo$38bo
39boo8bo49bo49bo49bo49bo49bo49bo49bo128boo8b3obboboo31boo8bobo$38b3o
47b3o47b3o47b3o47b3o47b3o47b3o47b3o47b3o116bo26b3o8b3o8bo20bobbo6bo$
41bo7bo41bo49bo49bo49bo49bo49bo49bo49bo114bo29bo10bo6bobbo22bo5bo3b3o$
40boo8boo38boo48boo48boo48boo48boo48boo48boo48boo115bo38bo10bo7bo14bo
4bo3bob3o$49boo521boo9bo19bo3bo7b4o3boo4b3o5bo6boo$572boo8boo14b3o3boo
b3o5boobo3boo5bo7b5obo$377bo218booboo4bo3boo3bo3bo20b4o$31bo49bo49bo
49bo49bo49bo49bo46boo216bobbo6boo3bobboboo22bo$29b3o47b3o47b3o47b3o47b
3o47b3o47b3o45boo187b3o29bo8b4o5boo$28bo49bo49bo49bo49bo49bo49bo236b5o
26boo10b3o$3bo11boo11boo48boo48boo48boo48boo48boo48boo235b3oboo26boo
45boo$3b3o9boo358boo154bobo34boo26boo44booboo$3bobo368bobo154boo63bo
45b4o$5bo370bo155bo110boo$$144bobo$bo142boo$obo142bo105bo255bo79boo35b
oo$bo247bobo254boo75b4oboo32booboo$40boo48boo158boo254bobo74b6o33b4o$
40boo11boo35boo11boo48boo48boo379b4o35boo$53bo49bo49bo49bo$54b3o47b3o
29bo17b3o47b3o45boo341boo$56bo49bo29boo18bo49bo46boo329boo7bo4bo$135bo
bo114bo329bo4bo11bo$588bo4bo5bo$545boboobo22b6o3bo5bo5b6o$15boo48boo
48boo48boo48boo48boo48boo48boo48boo48boo77bo4boboo19bo5bo4b6o$16bo49bo
49bo49bo49bo49bo49bo49bo49bo49bo77bo4boobbo24bo$13b3o47b3o47b3o47b3o
47b3o47b3o47b3o47b3o47b3o47b3o78bo3b3o3bo17bo4bo39b6o$13bo49bo49bo49bo
49bo49bo49bo49bo49bo49bo81b4obbobo20boo25bo14bo5bo5b4o$552bo46bo4bo17b
o4bo3bo$542bo62bo15bo9bo$215boo324bobbo43boo8bo5bo11boboo7bobbo$213bo
4bo321b3o45boo9boo$219bo247boo72boo73boo8bo$199boo12bo5bo243b4oboo71b
4o35bo19bobbobobb3o4b3o8b3o$196b3oboo12b6o212boo29b6o73b3o34bobo16bo3b
obbobb3obboo4bo5bo3bo$196b5o231bobo29b4o111bobbo10boo3bo9bobboboo5b5o
4bo$197b3o232bo147boo11boo4bo10boo3boo4b4oboboo$608bobo7b3oboo3bo$577b
3o29boo13bobo$200b3o34boo246bobbo40boo45bo3bo$236b4o192b3o54bo39bobo
44bo3bo$182b5o13bo35booboo49b3o138b5o49bo3bo39bo46bo3bo47b4o$181bo4bo
14boobboo31boo50bobbo137b3oboo49b4o87b3o47bo3bo$186bo16bobo84bo143boo
195bo$161bo19bo3bo19boboo25bo42boo11bo336bobbo$161boo19bo23boo8bo15bo
45boo11bobo273b6o22b5o$160bobo53bo11bo3bobboo40bo186bobo5bobo9boo80bo
5bo4b4o13bo4bo8b4o$181boo20bo20bobb3obo5bo209boo15bobo3boobo9bobboo84b
o3b6o17bo7b6o$196bo5b3o9bo8bob5obbobobboo208boo16bo4boo10b3obbo78bo4bo
4b4oboo11bo3bo8b4oboo$195bobo3b4o8bo8booboo5bo3boo222b3o6bo3boo7bo4bo
80boo10boo14bo14boo$195bobobboobb3o7bo10boo7b3o223b3o7bo4bo6b5o$196bo
bb3o3boo246bo18b3o8boo$177boo8b3o10b4o3bo17bo216boo9bo$177boo22b3o3bo
17bo11boo203boo9bo22boo7bobbo$202b3obbo18b4o6b4o234bo4bo9bo$205bo19b6o
5booboo239bo4bo3bo128boo$225b4oboo6boo234bo5bo5b4o124b4oboo$151boo76b
oo190b6o48b6o133b6o$147b4oboo266bo5bo188b4o$147b6o38boo132b6o95bo$148b
4o6boo29bo4bo129bo5bo89bo4bo$156bo4bo33bo134bo91boo13boo$162bo26bo5bo
128bo4bo104b3oboo196bobbo$156bo5bo27b6o130boo106b5o144b3o54bo$157b6o
272b3o144b5o17boo30bo3bo$582b3oboo16bobo30b4o$585boo17bo$344b3o31boo$
341boo3bo27b4oboo252bobo$302boo32bo4boo4boo25b6o247b3oboo3bo$303boo30b
obo10bo26b4o13b4o216boo10boo4b4oboboo$302bo32bobo5bo4bo42bo3bo216boo8b
oo5b5o4bo$344bo10bo4b3o32bo226boo4bo5bo3bo$338bo7boo6boo4bo30bobbo229b
3o8b3o$337bo8boo5bobbo4bo227bo27b3o5boo8bo$350boobobo33boo198boo16boo$
350boobo3bo30b5o196b3o15boo16boboo7bobbo$311boo5boo22bo9bo5bo9boo11bob
3obbo4bo193b4o39bo9bo$311boo5boo3boo16bobboo12bo9boo9boo3bo3b3obbo192b
oobo41bo4bo3bo$323boo21bo5bobb3o21bobo7bobboo231bo5bo5b4o$344boo7boo
24boboo7boo180b6o48b6o$298b4o71b3o195bo5bo$297b6o4b3o53boo15b3o194bo$
297b4oboobb5o52boo206bo4bo$301boo3b3oboo24boo54b4o177boo13boo$309boo
22b3oboo42b6o4bo3bo189b3oboo$333b5o9b3o30bo5bo8bo189b5o$334b3o9b5o35bo
4bobbo191b3o$346b3oboo19boo7bo4bo$349boo18bo4bo7boo$361b4o10bo$360b6o
3bo5bo$360b4oboo3b6o$364boo$327boo$328boo47b3o14b6o$327bo48b5o12bo5bo$
376b3oboo17bo$379boo12bo4bo$395boo3$363bo$361bo3bo52boo$366bo49booboo$
361bo4bo49b4o$362b5o50boo$$400bo$399bobo9boo3bo$385boo6b4oboobo7b3o4b
oo$385boo5bo4boobo7bobbo5boo$361boo28bo7bobo6bo7boo$358b4o30bobo4bobo
6boo$358boobo3bo35boo$330boo8b3o14bob3o4bo13boo9boobo6bo$330boo28bo6bo
12boo10bo5b3o$367bo30boo18boo$351boo10b4o28b3o11boo5booboo$328b4o18bo
bbo51b4oboo4b4o$327b6o17bobo52b6o6boo$327b4oboo17bo54b4o$331boo$$370b
6o$337b6o26bo5bo$336bo5bo32bo$342bo26bo4bo$336bo4bo29boo$338boo!]]
--# Day_Night
patterns[6] = [[
#C This is a period 256 rocket gun which demonstrates the symmetry of
#C the Day/Night rules, and how a signal can be sent across the border
#C between day and night regions.  Here a period 256 anti-gun destroys
#C every other rocket from a normal period 128 rocket gun.  Based on a
#C reaction by Dean Hickerson.  David I. Bell, May 1997
x = 240, y = 224, rule = B3678/S34678
7boo25boo$7boo25boo$6b4o23b4o$6b3obo21bob3o$5b4obo21bob4o$5b5o23b5o$4b
6o23b6o$4b5obo21bob5o$3b6obo21bob6o$3b7o23b7o$bb8o23b8o$bb7obo21bob7o$
b9o23b9o$b9o23b9o$bb8o23b8o$bb8o23b8o$3b7o23b7o$3b7o23b7o$b8obo21bob8o
$b8obo21bob8o$10o23b10o$b3obobobobobobo11bobobobobobob4o$b3obobobobobo
bo11bobobobobobob3o28bobbo$bb8o23b9o26b8o$bb7obo21bob10o24b8o$4b5obo
21bob12o20b12o$4b5obo21bob12o20b12o$6b3obo21bob14o16b5o6b5o$6b4o23b15o
16b16o$7boo25b16o16b3o6b3o$7boo12bo11b17o19b6o$20b3o10boobbo4bo4bo$19b
5o14b4ob4o22b6o$18bob3obo$20b3o$18b7o$20b3o32bobo$21bo119booboo$13bobo
4b3o4bobo31b3ob3o54bo11bo6b6o$12bobbo3b5o3bobbo29boob4o54boboboo5b5o3b
ob4obo$11b6ob7ob6o28bob7obo50b8o3b7obb8o$10b23o25boob9o52b28o$11b6ob7o
b6o26boboob5o53b8o3b7obb8o$12bobbo3b5o3bobbo28bob7o53boboboo5b5o3bob4o
bo$13bobo4b3o4bobo28b3ob5o55bo11bo6b6o$21bo36boob5obo73booboo$20b3o36b
oobboobobo$18b7o37b3o$20b3o$18bob3obo$19b5o14b4ob4o137bobbobbobboo$20b
3o10boobbo4bo4bo134b15o$7boo12bo11b17o132b17o$7boo25b16o131b20o$6b4o
23b15o134b21o9boo$6b3obo21bob14o134b23o7boo$4b5obo21bob12o135b26o4b4o$
4b5obo21bob12o136b27obboboo$bb7obo21bob10o138b29o$bb8o23b9o139b22obb6o
b5o$b3obobobobobobo11bobobobobobob3o140b21o4boobobooboo$b3obobobobobob
o11bobobobobobob4o139b22o7bo$10o23b10o138b23o3booboo$b8obo21bob8o140b
23obboobo$b8obo21bob8o140b22o6boo$3b7o23b7o141b23o6boo$3b7o23b7o142b
24o$bb8o23b8o141b26o$bb8o23b8o140b29o$b9o23b9o140b30o$b9o23b9o140b32o$
bb7obo21bob7o140b35o$bb8o23b8o141b36o$3b7o23b7o142b36o$3b6obo21bob6o
141b38o$4b5obo21bob5o143b36o$4b6o23b6o143b36o$5b5o23b5o143b27obb9o$5b
4obo21bob4o144b26obb8o$6b3obo21bob3o145b25o4b7o$6b4o23b4o144b25obo3b8o
$7boo25boo146b24obo5b5o$7boo25boo146b24obo7b3o$181b25obo7b4o$182b24obo
6b4o$182b24obo6b4o$181b25obo5b6o$182b24obo5b5o$182b24obo3b7o$181b26o4b
8o$182b26obb8o$182b26obb8o$181b38o$182b36o$182b36o$181b38o$182b36o$
182b36o$181b38o$182b36o$182b36o$181b38o$182b36o$182b36o$181b38o$182b
36o$182b36o$181b38o$182b36o$182b36o$181b38o$182b36o$182b36o$181b38o$
182b36o$182b36o$181b38o$182b36o$182b36o$181b38o$182b36o$182b36o$181b
38o$182b36o$182b36o$181b38o$182b36o$182b36o$181b38o$182b36o$182b36o$
181b38o$182b36o$182b36o$181b38o$182b36o$182b36o$181b38o$182b36o$182b
36o$181b38o$182b10obbobb21o$182b9obo3bob20o$181b11o5b22o$182b9o7b20o$
182b8obo5bob19o$181b10o7b21o$182b8o9b19o$182b8o9b19o$181b11ob3ob22o$
182b36o$182b36o$181b38o$182b36o$152bobbobbobbobbobbobbobbobbobbobb36o
bbobbobbobbobbobboo$150b89o$150b89o$149b91o$150b44ob44o$150b43o3b43o$
149b33obb8o5b8obb33o$150b32obb7o7b7obb32o$150b30o5b5o9b5o5b30o$149b31o
4bob6o5b6obo4b31o$150b28o6bob4obo5bob4obo6b28o$150b28o7b5obo5bob5o7b
28o$149b28o4bobobob3o9b3obobobo4b28o$150b23obboo4bobobob4o7b4obobobo4b
oobb23o$150b15obb4o10boboboboobo7boboobobobo10b4obb15o$149b14o6boo14b
8obob8o14boo6b14o$150b11o23bob4obbooboobb4obo23b11o$150b9o25bob17obo
25b9o$149b8o28b6o7b6o28b8o$150b5o29b9o3b9o29b5o$150b3o31b6obo5bob6o31b
3o$149b4o32b8o3b8o32b4o$150b5ob6ob4obb10o3bobb5obbo3bobb5obbo3b10obb4o
b6ob5o$150b6o6bo4boo10b12o7b12o10boo4bo6b6o$149b42o7b42o$150b89o$150b
43obob43o$149b31ob27ob31o$150b28obbob25obobb28o$150b27obbobb25obbobb
27o$149b22ob9ob25ob9ob22o$150b18obb11obb11ob11obb11obb18o$150b18obobbo
b9obb7o5b7obb9obobbob18o$149b19o5b7o5bob5o5b5obo5b7o5b19o$150b20ob10o
3bob5o7b5obo3b10ob20o$150b18o5b7o5bob5o5b5obo5b7o5b18o$149b19obobbob9o
bb7o5b7obb9obobbob19o$150b18obb11obb11ob11obb11obb18o$150b21ob9ob25ob
9ob21o$149b28obbobb25obbobb28o$150b28obbob25obobb28o$150b30ob27ob30o$
149b44obob44o$150b89o$150b41o7b41o$149b7o6bo4boo10b12o7b12o10boo4bo6b
7o$150b5ob6ob4obb10o3b8obbo3bobb8o3b10obb4ob6ob5o$150b3o31b9o3b9o31b3o
$149b4o31b6obo5bob6o31b4o$150b5o27b11o3b11o27b5o$150b7o23b11obbobobb
11o23b7o$149b10o21b14ob14o21b10o$150b11o17b15o3b15o17b11o$150b13o6boo
7b33o7boo6b13o$149b16obb4o5b37o5b4obb16o$150b23ob41ob23o$150b43o3b43o$
149b91o$150b41o7b41o$150b41o7b41o$149b45ob45o$150b42o5b42o$150b44ob44o
$149b44o3b44o$150b44ob44o$150b89o$149b91o$150b89o$150b89o$152bobbobbo
bbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbobbo
bbobbobbo!

]]
--# Knightship
patterns[7]=[[
#C p168 knightship found by David Eppstein
x = 7, y = 4, rule = B13568/S01
bo4bo$b2ob3o$2o3bo$2bobo!
]]
