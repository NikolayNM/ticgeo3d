-- Debug:
local D_INVULN=false
local D_NOENTS=false

-- Tile size in world coords
local TSIZE=50

-- Player's collision rect size
local PLR_CS=20

local FLOOR_Y=S3.FLOOR_Y
local CEIL_Y=S3.CEIL_Y

-- Original palette (saved at boot time).
local ORIG_PAL={}

-- Buttons
local BTN={
 FWD=0, BACK=1, LEFT=2, RIGHT=3,
 FIRE=4, LOB=5,
 STRAFE=6, OPEN=7,
}

-- Player attack sequence
local PLR_ATK={
 -- Draw phase
 {tid=TID.CBOW_D,t=0.2,fire=false},
 {tid=TID.CBOW_E,t=0.8,fire=true}
}

local MODE={
 -- Game modes.
 TITLE=0,   -- title screen.
 INSTRUX=1, -- instructions screen.
 PLAY=2,    -- playing level.
 DEAD=3,    -- player is dead.
}

-- Permanent game state (doesn't reset on every
-- level).
local A={  -- A for "App"
 mode=MODE.TITLE,
 mclk=0,   -- time elapsed in current mode
           -- (resets on mode switch).
 lftime=-1,  -- last frame time, -1 if none.
}

-- Transient game state. Resets every time we start
-- a new level.
local G=nil  -- deep copied from G_INIT
local G_INIT={
 -- eye position and yaw
 ex=350, ey=25, ez=350, yaw=30,
 lftime=-1,  -- last frame time
 clk=0, -- game clock, seconds

 -- All the doors in the level. This is a dict indexed
 -- by r*240+c where c,r are the col/row on the map.
 -- The value is a reference to the wall that
 -- represents the (closed) door.
 doors={},

 -- If set, a door open animation is in progress
 -- Fields:
 --   w: the wall being animated.
 --   irx,irz: initial pos of door's right side
 --   phi: how much door has rotated so far
 --     (this increases until it's PI/2,
 --     then the animation ends).
 doorAnim=nil,

 -- Player speed (linear and angular)
 PSPD=120,PASPD=2.0,
 
 -- Entities. Each has:
 --   etype: entity type (E.* constants)
 --   bill: the billboard that represents it
 --   ctime: time when entity was created.
 --   anim: active animation (optional)
 --   x,y,z: position
 --   w,h: width,height
 --   tid: texture id
 --
 --   attp: current attack phase, nil if not attacking.
 --   atte: time elapsed in current attack phase.
 --
 --  Behavior-related fields:
 --
 --   pursues: (bool) does it pursue the player?
 --   speed: speed of motion, if it moves
 --
 --   attacks: (bool) does it attack the player?
 --   dmgMin: min damage caused per attack
 --   dmgMax: max damage caused per attack
 --   attseq: attack sequence, array of phases, each:
 --     t: time in seconds,
 --     tid: texture ID for entity during this phase
 --     dmg: if true, damage is caused in this phase
 --
 --   vuln: (bool) does this entity take damage?
 --   hp: hit points
 --   hurtT: time when enemy was last hurt
 --     (for animation)
 --
 --   vx,vz: if set, this is the velocity.
 --
 --   shoots: if true, shoots player.
 --   shot: EID of projectile.
 --   shotInt: interval between successive shots (sec)
 --   shotSpd: speed of the shot (units/sec)
 --
 --   hurtsPlr: if true, hurts player on contact.
 --   dmgMin,dmgMax: min/max damage caused.
 --   collRF: collision radius factor (1 = use width
 --    2 = 2*width, etc)
 --
 --   falls: if true, ent falls toward ground with
 --    gravity.
 --   fallVy0: initial y speed
 --   fallAcc: fall acceleration
 ents={},

 -- Player's hitpoints (floating point, 0-100)
 hp=50,
 -- Ammo.
 ammo=20,
 grens=5,

 -- time, as per G.clk when plr last threw grenade
 lastGrenT=-999,

 -- If not nil, player recently took damage.
 --  Contains:
 --   hp: damage taken (hp)
 --   cd: countdown to end justHurt state.
 justHurt=nil,

 -- overlay representing player's weapon
 weapOver=nil,

 -- if >0, we're currently attacking and this indicates
 -- the current attack phase.
 atk=0,
 -- If attacking, this is how long we have been in
 -- the current attack phase.
 atke=0,
 -- Message to display, nil if none.
 msg="",
 -- Count down to stop displaying message.
 msgCd=0,

 -- Do we have the key? (That opens locked doors).
 hasKey=false,

 -- Current flash fx, if any
 flash=nil,
}

-- sprite numbers
local S={
 FLAG=240,
 META_0=241,
 HUD_KEY=230,
}

-- entity types. Use the same sprite ID that
-- represents the entity on the map, to allow
-- that entity type to be created on map load.
-- Use values >512 for entities that can't be
-- on map.
local E={
 ZOMB=32,
 POTION=48,
 AMMO=64,
 DEMON=49,
 KEY=65,
 SPITTER=50,
 -- Dynamic ents that don't appear on map:
 ARROW=1000,
 FIREBALL=1001,
 GREN=1002,
}

-- animations
local ANIM={
 ZOMBW={inter=0.2,tids={TID.CYC_W1,TID.CYC_W2}},
 POTION={inter=0.2,tids={TID.POTION_1,TID.POTION_2}},
 AMMO={inter=0.2,tids={TID.AMMO_1,TID.AMMO_2}},
 DEMON={inter=0.2,tids={TID.DEMON_1,TID.DEMON_2}},
 KEY={inter=0.2,tids={TID.KEY_1,TID.KEY_2}},
 SPITTER={inter=0.2,tids={TID.SPITTER_1,
  TID.SPITTER_2}},
 FIREBALL={inter=0.2,tids={TID.FIREBALL_1,
  TID.FIREBALL_2}},
}

-- possible Y anchors for entities
local YANCH={
 FLOOR=0,   -- entity anchors to the floor
 CENTER=1,  -- entity is centered vertically
 CEIL=2,    -- entity anchors to the ceiling
}

-- default entity params
--  w,h: entity size in world space
--  yanch: Y anchor (one of the YANCH.* consts)
--  tid: texture ID
--  data: fields to shallow-copy to entity as-is
local ECFG_DFLT={
 yanch=YANCH.FLOOR,
}
-- Entity params overrides (non-default) by type:
local ECFG={
 [E.ZOMB]={
  w=50,h=50,
  anim=ANIM.ZOMBW,
  pursues=true,
  speed=20,
  attacks=true,
  dmgMin=5,dmgMax=15,
  hp=2,
  vuln=true,
  attseq={
   {t=0.3,tid=TID.CYC_PRE},
   {t=0.5,tid=TID.CYC_ATK,dmg=true},
   {t=0.8,tid=TID.CYC_W1},
  },
 },
 [E.DEMON]={
  w=20,h=20,
  yanch=YANCH.CENTER,
  anim=ANIM.DEMON,
  pursues=true,
  speed=40,
  attacks=true,
  dmgMin=5,dmgMax=15,
  hp=2,
  vuln=true,
  attseq={
   {t=0.3,tid=TID.DEMON_PRE},
   {t=0.5,tid=TID.DEMON_ATK,dmg=true},
   {t=0.8,tid=TID.DEMON_2},
  },
 },
 [E.SPITTER]={
  w=20,h=20,
  yanch=YANCH.CENTER,
  anim=ANIM.SPITTER,
  pursues=true,
  speed=40,
  attacks=false,
  shoots=true,
  shot=E.FIREBALL,
  shotInt=1.5,
  shotSpd=250,
  hp=2,
  vuln=true,
  attseq={
   {t=0.3,tid=TID.SPITTER_PRE},
   {t=0.5,tid=TID.SPITTER_ATK,dmg=true},
   {t=0.8,tid=TID.SPITTER_2},
  },
 },
 [E.ARROW]={
  w=8,h=8,
  ttl=2,
  tid=TID.ARROW,
  yanch=YANCH.CENTER,
 },
 [E.POTION]={
  w=16,h=16,
  anim=ANIM.POTION,
 },
 [E.AMMO]={
  w=16,h=16,
  anim=ANIM.AMMO,
 },
 [E.KEY]={
  w=16,h=8,
  anim=ANIM.KEY,
 },
 [E.FIREBALL]={
  w=8,h=8,
  anim=ANIM.FIREBALL,
  ttl=2,
  yanch=YANCH.CENTER,
  hurtsPlr=true, dmgMin=5, dmgMax=15,collRF=3,
 },
 [E.GREN]={
  w=8,h=8,
  tid=TID.GREN,
  yanch=YANCH.CENTER,
  falls=true,
  fallVy0=40,
 }
}

-- tile flags
local TF={
 -- walls in the tile
 N=1,E=2,S=4,W=8,
 -- tile is non-solid.
 NSLD=0x10,
 -- tile is a door
 DOOR=0x20,
 -- locked door.
 LOCKED=0x40,
}

-- tile descriptors
-- w: which walls this tile contains
local TD={
 -- Stone walls
 [1]={f=TF.S|TF.E,tid=256},
 [2]={f=TF.S,tid=256},
 [3]={f=TF.S|TF.W,tid=256},
 [17]={f=TF.E,tid=256},
 [19]={f=TF.W,tid=256},
 [33]={f=TF.N|TF.E,tid=256},
 [34]={f=TF.N,tid=256},
 [35]={f=TF.N|TF.W,tid=256},
 -- Doors
 [5]={f=TF.S|TF.DOOR,tid=260},
 [20]={f=TF.E|TF.DOOR,tid=260},
 [22]={f=TF.W|TF.DOOR,tid=260},
 [37]={f=TF.N|TF.DOOR,tid=260},
 -- Locked doors
 [8]={f=TF.S|TF.DOOR|TF.LOCKED,tid=264},
 [23]={f=TF.E|TF.DOOR|TF.LOCKED,tid=264},
 [25]={f=TF.W|TF.DOOR|TF.LOCKED,tid=264},
 [40]={f=TF.N|TF.DOOR|TF.LOCKED,tid=264},
}

local LVL={
 -- Each has:
 --   name: display name of level.
 --   pg: map page where level starts.
 --   pgw,pgh: width and height of level, in pages
 {name="Level 1",pg=0,pgw=1,pgh=1},
 {name="Level Test",pg=1,pgw=1,pgh=1},
}

DEBUGS=nil

local SND={
 ARROW={sfx=63,note="C-4",dur=6,vol=15,spd=0},
 HIT={sfx=62,note="E-3",dur=6,vol=15,spd=0},
 KILL={sfx=62,note="C-2",dur=12,vol=15,spd=-2},
 BONUS={sfx=61,note="C-4",dur=6,vol=15,spd=-2},
 HURT={sfx=60,note="C-6",dur=6,vol=15,spd=-2},
 DOOR={sfx=59,note="C-2",dur=6,vol=15,spd=-1},
 DIE={sfx=58,note="E-2",dur=30,vol=15,spd=-1},
 BOOM={sfx=57,note="G-3",dur=30,vol=15,spd=-2},
}

local PFX={
 KILL={
  count=30,minR=5,maxR=20,minSpd=40,maxSpd=100,
  fall=true,clr={4,5,6},ttl=2,size=2,
 },
 BLAST={
  count=50,minR=5,maxR=20,minSpd=150,maxSpd=200,
  fall=true,clr={14,15,11},ttl=2,size=4,
 },
}

