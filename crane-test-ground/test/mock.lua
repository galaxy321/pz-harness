-- Fake world for the Crane Test Ground mock test.
next = nil
local squares = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function list(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end, _t = t } end
Sprite = {}
function getSprite(name) return { getName = function() return name end, getProperties = function() return { has = function() return false end, Is = function() return false end } end } end
local function newObj(sq, spriteName)
    local o = { sq = sq, spr = getSprite(spriteName), md = nil, cont = nil, hp = 100, mhp = 100 }
    function o:getSprite() return self.spr end
    function o:setSprite(s) self.spr = s end
    function o:getSquare() return self.sq end
    function o:hasModData() return self.md ~= nil end
    function o:getModData() self.md = self.md or {}; return self.md end
    function o:getContainer() return self.cont end
    function o:setContainer(c) self.cont = c end
    function o:setIsContainer(b) if b then self.cont = ItemContainer.new("crate", sq, self) end end
    function o:removeAllContainers() self.cont = nil end
    function o:getObjectIndex() if not self.sq then return -1 end for i, v in ipairs(self.sq.objs) do if v == self then return i - 1 end end return -1 end
    function o:getHealth() return self.hp end
    function o:getMaxHealth() return self.mhp end
    function o:setHealth(h) self.hp = h end
    function o:setMaxHealth(h) self.mhp = h end
    function o:setOverlaySprite(n) self.overlay = n end
    function o:transmitModData() end
    function o:transmitCompleteItemToClients() end
    for _, m in ipairs({ "setIsDismantable", "setCanBarricade", "setIsHoppable", "setCanPassThrough", "setIsThumpable", "setBlockAllTheSquare", "setBreakSound", "setExplored" }) do o[m] = function() end end
    return o
end
ItemContainer = { new = function(typ, sq, parent)
    local c = { items = {}, typ = typ }
    function c:getItems() return list(self.items) end
    function c:AddItem(id) local it = type(id) == "table" and id or { id = id, w = (id == "Base.Log") and 10 or 1 }; table.insert(self.items, it); return it end
    function c:contains(it) for _, v in ipairs(self.items) do if v == it then return true end end return false end
    function c:Remove(it) self:DoRemoveItem(it) end
    function c:DoRemoveItem(it) for i, v in ipairs(self.items) do if v == it then table.remove(self.items, i) return end end end
    function c:removeAllItems() self.items = {} end
    function c:isEmpty() return #self.items == 0 end
    function c:getCapacityWeight() local w = 0 for _, v in ipairs(self.items) do w = w + v.w end return w end
    function c:setType() end; function c:setCapacity() end; function c:setExplored() end
    return c
end }
function newSquare(x, y, z, hasFloor)
    local sq = { x = x, y = y, z = z, objs = {} }
    if hasFloor then table.insert(sq.objs, newObj(sq, "floor_1")); sq.floor = sq.objs[1] end
    function sq:getX() return self.x end; function sq:getY() return self.y end; function sq:getZ() return self.z end
    function sq:getFloor() return self.floor end
    function sq:getObjects() return list(self.objs) end
    function sq:getProperties() return { has = function() return false end, Is = function() return false end } end
    function sq:getWindow() return nil end
    function sq:isVehicleIntersecting() return false end
    function sq:isFree() return not self.blocked end
    function sq:isSolid() return false end
    function sq:isSolidTrans() return false end
    function sq:HasStairs() if STAIRS_ERR then error('no such method') end return self.stairs == true end
    function sq:AddSpecialObject(o) o.sq = self; table.insert(self.objs, o) end
    function sq:AddTileObject(o) o.sq = self; table.insert(self.objs, o) end
    function sq:transmitRemoveItemFromSquare(o) for i, v in ipairs(self.objs) do if v == o then table.remove(self.objs, i); o.sq = nil; return end end end
    function sq:RecalcAllWithNeighbours() end
    function sq:EnsureSurroundNotNull() end
    function sq:AddWorldInventoryItem() end
    squares[key(x, y, z)] = sq
    return sq
end
local cell = {}
function cell:getGridSquare(x, y, z) return squares[key(x, y, z)] end
function cell:createNewGridSquare(x, y, z) return squares[key(x, y, z)] or newSquare(x, y, z, false) end
function getCell() return cell end
IsoThumpable = { new = function(_, sq, sprite) return newObj(sq, sprite) end }
IsoObject = { new = function(_, sq, spr) local o = newObj(sq, "x"); o.spr = spr; return o end }
function instanceof() return true end
function isServer() return false end
function isClient() return false end
function getSandboxOptions() return nil end
SandboxVars = {}
function ZombRandFloat(a) return a end
GridSquareEdgeFacingDirection = { NORTH_SOUTH = 1, EAST_WEST = 2 }
Metabolics = { HeavyWork = 1 }
Events = { OnGameStart = { Add = function(f) table.insert(StartFns, f) end }, LoadGridsquare = { Add = function() end }, OnTick = { Add = function() end } }
StartFns = {}
CLOCK = 1000
function getTimestampMs() return CLOCK end
-- timed actions: the queue runs one action, complete() lands after its maxTime ticks
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name) local c = { Type = name }; c.__index = c; setmetatable(c, { __index = ISBaseTimedAction }); return c end
function ISBaseTimedAction.new(cls, ch) local o = setmetatable({ character = ch }, cls); return o end
QUEUE = {}
ISTimedActionQueue = {
    add = function(a) table.insert(QUEUE, a); a.left = a.maxTime end,
    clear = function() QUEUE = {} end,
    isPlayerDoingAction = function() return #QUEUE > 0 end,
}
function runQueue()
    local a = QUEUE[1]
    if not a then return end
    a.left = a.left - 1
    if a.left <= 0 then table.remove(QUEUE, 1); a:complete() end
end
ISInventoryPage = { dirtyUI = function() end }
package.loaded["TimedActions/ISBaseTimedAction"] = true
function require(name) if package.loaded[name] then return end local f = assert(loadfile(LUAROOT .. name .. ".lua")); package.loaded[name] = true; f() end
PLAYER = { x = 0, y = 0, z = 0 }
function PLAYER:getX() return self.x end
function PLAYER:getY() return self.y end
PLAYER.inv = ItemContainer.new("inventory", nil, nil)
function PLAYER:getInventory() return self.inv end
function PLAYER:getZ()
    if FALL_ONCE and not FELL and self.z > 0 and CLOCK > (self.tpAt or 0) + 250 then FELL = true; self.z = 0 end
    if FALL_MID and not FELL and self.z > 0 and MIDCRANK and CLOCK > MIDCRANK then FELL = true; self.z = 0 end
    if FALL_ALWAYS and self.z > 0 and CLOCK > (self.tpAt or 0) + 250 then self.z = 0 end
    return self.z
end
function PLAYER:teleportTo(x, y, z) self.x, self.y, self.z = x, y, z; self.tpAt = CLOCK; TELEPORTS = (TELEPORTS or 0) + 1 end
ISInventoryTransferAction = ISBaseTimedAction:derive("ISInventoryTransferAction")
function ISInventoryTransferAction:new(p, item, from, to)
    local o = ISBaseTimedAction.new(self, p); o.item, o.from, o.to = item, from, to; o.maxTime = 5; return o
end
function ISInventoryTransferAction:complete()
    if TRANSFER_REFUSED then return end
    if self.from:contains(self.item) then self.from:DoRemoveItem(self.item); self.to:AddItem(self.item) end
end
function PLAYER:faceThisObject() end
function PLAYER:shouldBeTurning() return false end
function PLAYER:setMetabolicTarget() end
function PLAYER:isTimedActionInstant() return false end
function PLAYER:getEmitter() return { isPlaying = function() return false end } end
function PLAYER:playSound() return 1 end
function PLAYER:stopOrTriggerSound() end
TRACE = {}
TestGround = { addStep = function(kind, impl, group) STEP = impl; return true end, trace = function(l) table.insert(TRACE, l) end, note = function() end }
TestGroundInternal = { teleport = function(p, x, y, z) p:teleportTo(x + 0.5, y + 0.5, z) end }
