function To2Dig(n)
 n=floor(n)
 return n<0 and "00" or
   (n<10 and "0"..n or ((n<100) and n or 99))
end

-- Returns if the given position is valid as a 
-- player position (that is, doesn't collide with
-- any solid tiles).
function IsPosValid(x,z)
 local cs=PLR_CS
 -- Test four corners of player's collision rect.
 return not IsInSolidTile(x-cs,z-cs) and
   not IsInSolidTile(x-cs,z+cs) and
   not IsInSolidTile(x+cs,z-cs) and
   not IsInSolidTile(x+cs,z+cs)
end

-- Returns whether the given position lies within
-- a solid tile.
function IsInSolidTile(x,z)
 local c,r=floor(x/TSIZE),floor(z/TSIZE)
 local t=LvlTile(c,r)
 local td=TD[t]
 if not td then return false end
 return 0==td.f&TF.NSLD
end

-- Rotate point P=px,pz about point O=ox,oz
-- by an angle of alpha radians.
function RotPoint(ox,oz,px,pz,alpha)
 local ux,uz=px-ox,pz-oz
 local c,s=cos(alpha),sin(alpha)
 return ox+ux*c-uz*s,oz+uz*c+ux*s
end

-- Overlays (deeply) the fields of table b over the
-- fields of table a. So if a={x=1,y=2,z=3} and
-- b={y=42,foo="bar"}, then this will return:
-- {x=1,y=42,z=3,foo="bar"}.
function Overlay(a,b)
 local result=DeepCopy(a)
 for k,v in pairs(b) do
  if result[k] and type(result[k])=="table" and
    type(v)=="table" then
   -- Recursive overlay.
   result[k]=Overlay(result[k],v)
  else
   result[k]=DeepCopy(v)
  end
 end
 return result
end

function DistSqXZ(x1,z1,x2,z2)
 return (x1-x2)*(x1-x2)+(z1-z2)*(z1-z2)
end

function DistXZ(x1,z1,x2,z2)
 return sqrt(DistSqXZ(x1,z1,x2,z2))
end

function DistSqToPlr(x,z)
 return DistSqXZ(x,z,G.ex,G.ez)
end

function DistToPlr(x,z)
 return DistXZ(x,z,G.ex,G.ez)
end

function PlrFwdVec(scale)
 scale=scale or 1
 return -sin(G.yaw)*scale,-cos(G.yaw)*scale
end

function V2Mag(x,z)
 return sqrt(x*x+z*z)
end

function V2Normalize(x,z)
 local mag=V2Mag(x,z)
 if mag>0.001 then return x/mag,z/mag
 else return 0,0 end
end

function DeepCopy(t)
 if type(t)~="table" then return t end
 local r={}
 for k,v in pairs(t) do
  if type(v)=="table" then
   r[k]=DeepCopy(v)
  else
   r[k]=v
  end
 end
 return r
end

-- Returns col,row where the given map page starts.
function MapPageStart(pg)
 return (pg%8)*30,(pg//8)*17
end

-- Gets the meta "value" of the given tile, or nil
-- if it has none.
function MetaValue(t)
 if t>=S.META_0 and t<=S.META_0+9 then
  return t-S.META_0
 end
end

-- Gets the meta value of a meta tile that's adjacent
-- to the given tile, nil if not found. This is called
-- the tile "label".
function TileLabel(tc,tr)
 for c=tc-1,tc+1 do
  for r=tr-1,tr+1 do
   local mv=MetaValue(LvlTile(c,r))
   if mv then return mv end
  end
 end
 return nil
end

