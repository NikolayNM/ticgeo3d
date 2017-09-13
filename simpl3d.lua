local G={
 ex=0, ey=25, ez=100, yaw=0,
}

function Boot()
 S3Init()
 S3WallAdd({lx=0,lz=0,rx=50,rz=0,tid=14})
end

function TIC()
 cls(2)
 G.ex=G.ex+(btn(2) and -1 or (btn(3) and 1 or 0))
 G.ez=G.ez+(btn(0) and -1 or (btn(1) and 1 or 0))
 S3SetCam(G.ex,G.ey,G.ez,G.yaw)

 --local p1x,p1y,p1z=S3Proj(-50,-50,50)
 --local p2x,p2y,p2z=S3Proj(-50,-50,-50)
 --local p3x,p3y,p3z=S3Proj(50,-50,-50)
 --local p4x,p4y,p4z=S3Proj(50,-50,50)

 --tri(p1x,p1y,p2x,p2y,p3x,p3y,14)
 --tri(p1x,p1y,p3x,p3y,p4x,p4y,13)
 S3Rend()
end

---------------------------------------------------

local S={
 ex=0, ey=0, ez=0, yaw=0,
 -- Precomputed from ex,ey,ez,yaw:
 cosYaw=0, sinYaw=0, termA=0, termB=0,
 -- These are hard-coded into the projection function,
 -- so if you change then, also update the math.
 NCLIP=0.1,
 FCLIP=1000,
 -- min world Y coord of all walls
 W_BOT_Y=0,
 -- max world Y coord of all walls
 W_TOP_Y=50,
 -- list of all walls, each with
 --
 --  lx,lz,rx,rz: x,z coords of left and right endpts
 --  in world coords (y coord is auto, goes from
 --  W_BOT_Y to W_TOP_Y)
 --  tid: texture ID
 --
 --  Computed at render time:
 --   slx,slz,slty,slby: screen space coords of
 --     left side of wall (x, z, top y, bottom y)
 --   srx,srz,srty,srby: screen space coords of
 --     right side of wall (x, z, top y, bottom y)
 walls={},
 -- H-Buffer, used at render time:
 hbuf={},
}

local sin,cos,PI=math.sin,math.cos,math.pi
local floor,ceil=math.floor,math.ceil
local min,max,abs,HUGE=math.min,math.max,math.abs,math.huge
local SCRW=240
local SCRH=136

function S3Init()
 S3SetCam(0,0,0,0)
end

function S3WallAdd(w)
 table.insert(S.walls,{lx=w.lx,lz=w.lz,rx=w.rx,
   rz=w.lz,tid=w.tid})
end

function S3SetCam(ex,ey,ez,yaw)
 S.ex,S.ey,S.ez,S.yaw=ex,ey,ez,yaw
 -- Precompute some factors we will need often:
 S.cosYaw,S.sinYaw=cos(yaw),sin(yaw)
 S.termA=-ex*S.cosYaw-ez*S.sinYaw
 S.termB=ex*S.sinYaw-ez*S.cosYaw
end

function S3Proj(x,y,z)
 local c,s,a,b=S.cosYaw,S.sinYaw,S.termA,S.termB
 -- Hard-coded from manual matrix calculations:
 local px=0.9815*c*x+0.9815*s*z+0.9815*a
 local py=1.7321*y-1.7321*S.ey
 local pz=s*x-z*c-b-0.2
 local pw=x*s-z*c-b
 local ndcx=px/pw
 local ndcy=py/pw
 return 120+ndcx*120,68-ndcy*68,pz
end

function S3Rend()
 -- TODO: compute potentially visible set instead.
 local pvs=S.walls
 local hbuf=S.hbuf
 _PrepHbuf(hbuf,pvs)
 _RendHbuf(hbuf)
end

function _S3ResetHbuf(hbuf)
 local scrw,scrh=SCRW,SCRH
 for x=0,scrw-1 do
  -- hbuf is 1-indexed (because Lua)
  hbuf[x+1]=hbuf[x+1] or {}
  local b=hbuf[x+1]
  b.wall=nil
  b.z=HUGE
 end
end

-- Compute screen-space coords for wall.
function _S3ProjWall(w)
 local topy=S.W_TOP_Y
 local boty=S.W_BOT_Y

 trace("wL: "..w.lx..", "..w.lz)
 trace("wR: "..w.rx..", "..w.rz)

 -- notation: lt=left top, rt=right top, etc.
 local ltx,lty,ltz=S3Proj(w.lx,topy,w.lz)
 local rtx,rty,rtz=S3Proj(w.rx,topy,w.rz)
 if rtx<=ltx then return false end  -- cull back side
 if rtx<0 or ltx>=SCRW then return false end
 local lbx,lby,lbz=S3Proj(w.lx,boty,w.lz)
 local rbx,rby,rbz=S3Proj(w.rx,boty,w.rz)

 w.slx,w.slz,w.slty,w.slby=ltx,ltz,lty,lby
 w.srx,w.srz,w.srty,w.srby=rtx,rtz,rty,rby

 trace("L: "..w.slx..", "..w.slz..", "..w.slty..", "..w.slby)
 trace("R: "..w.srx..", "..w.srz..", "..w.srty..", "..w.srby)

 if w.slz<S.NCLIP and w.srz<S.NCLIP
   then return false end
 if w.slz>S.FCLIP and w.srz>S.FCLIP
   then return false end
 return true
end

function _PrepHbuf(hbuf,walls)
 _S3ResetHbuf(hbuf)
 for i=1,#walls do
  local w=walls[i]
  if _S3ProjWall(w) then _AddWallToHbuf(hbuf,w) end
 end
 -- Now hbuf has info about all the walls that we have
 -- to draw, per screen X coordinate.
 -- Fill in the top and bottom y coord per column as
 -- well.
 for x=0,SCRW-1 do
  local hb=hbuf[x+1] -- hbuf is 1-indexed
  if hb.wall then
   local w=hb.wall
   hb.ty=_S3Interp(w.slx,w.slty,w.srx,w.srty,x)
   hb.by=_S3Interp(w.slx,w.slby,w.srx,w.srby,x)
  end
 end
end

function _AddWallToHbuf(hbuf,w)
 local startx=max(0,S3Round(w.slx))
 local endx=min(SCRW-1,S3Round(w.srx))
 for x=startx,endx do
  -- hbuf is 1-indexed (because Lua)
  local hbx=hbuf[x+1]
  local z=_S3Interp(w.slx,w.slz,w.srx,w.srz,x)
  if hbx.z>z then  -- depth test.
   hbx.z,hbx.wall=z,w  -- write new depth.
  end
 end
end

function _RendHbuf(hbuf)
 local scrw=SCRW
 for x=0,scrw-1 do
  local hb=hbuf[x+1]  -- hbuf is 1-indexed
  local w=hb.wall
  if w then _RendTexCol(w.tid,x,hb.ty,hb.by,
    (x-w.slx)/(w.srx-w.slx)) end
 end
end

-- Renders a vertical column of a texture to
-- the screen given:
--   tid: texture ID
--   x: x coordinate
--   ty,by: top and bottom y coordinate.
--   u: horizontal texture coordinate (0 to 1)
function _RendTexCol(tid,x,ty,by,u)
 -- TODO: actually sample the texture
 line(x,ty,x,by,tid)
end

function S3Round(x) return floor(x+0.5) end

function _S3Interp(x1,y1,x2,y2,x)
 if x2<x1 then
  x1,x2=x2,x1
  y1,y2=y2,y1
 end
 return x<=x1 and y1 or (x>=x2 and y2 or
   (y1+(y2-y1)*(x-x1)/(x2-x1)))
end

--------------------------------------------------
Boot()
