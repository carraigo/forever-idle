-- The game itself: gold, hirelings, upgrades, expeditions, Renown and
-- offline gains. No frames here apart from the event driver, so the whole
-- loop can be tested outside the client.

local ADDON, ns = ...

local G = {}
ns.Game = G

local floor, min, max, log = math.floor, math.min, math.max, math.log
local now = function() return time() end

local byId = {}
for i, h in ipairs(ns.HIRELINGS) do h.index = i byId[h.id] = h end
local zoneById = {}
for i, z in ipairs(ns.ZONES) do z.index = i zoneById[z.id] = z end
G.hireling, G.zone = byId, zoneById

-- Every upgrade in one list: four per hireling, then the global ones.
G.UPGRADES, G.upgradeById = {}, {}
for _, h in ipairs(ns.HIRELINGS) do
    for tier, at in ipairs(ns.TIER_AT) do
        local u = {
            id = h.id .. ":" .. tier, hireling = h.id, need = at,
            name = ns.TIER_NAMES[h.id][tier], icon = h.icon,
            cost = h.cost * ns.TIER_COST[tier],
            text = h.name .. "s mine twice as much.",
        }
        G.UPGRADES[#G.UPGRADES + 1] = u
    end
end
for _, u in ipairs(ns.GLOBAL_UPGRADES) do G.UPGRADES[#G.UPGRADES + 1] = u end
for _, u in ipairs(G.UPGRADES) do G.upgradeById[u.id] = u end

-- Saved data ------------------------------------------------------------------------------

local DEFAULTS = {
    version = 1,
    gold = 0, runEarned = 0, renown = 0,
    hire = {}, upgrades = {}, cleared = {}, seen = {},
    chars = {}, visited = {}, realOre = 0, lastHearth = 0,
    expedition = nil, frenzyEnds = 0,
    lastSeen = nil, loggedOutRested = false,
    buyMode = 1, tab = "hire", compact = false,
    settings = { sound = true, courier = true, bonuses = true },
    stats = { clicks = 0, clickGold = 0, couriers = 0, expeditions = 0, hearths = 0, lifetime = 0, bestGps = 0, dings = 0, quests = 0, realHearths = 0 },
}

local function fill(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            if type(v) == "table" then t[k] = {} fill(t[k], v) else t[k] = v end
        elseif type(v) == "table" and type(t[k]) == "table" then
            fill(t[k], v)
        end
    end
end

function G.Init(db)
    fill(db, DEFAULTS)
    -- Guard against a bad save (NaN or infinity would stick forever).
    for _, k in ipairs({ "gold", "runEarned", "renown" }) do
        local v = db[k]
        if type(v) ~= "number" or v ~= v or v == math.huge or v < 0 then db[k] = 0 end
    end
    G.db = db
    return db
end

-- Formatting ------------------------------------------------------------------------------

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function G.Short(n)
    n = n or 0
    if n < 1000 then
        if n < 10 and n ~= floor(n) then return ("%.1f"):format(floor(n * 10) / 10) end
        return tostring(floor(n))
    end
    local i = 0
    while n >= 1000 and i < #SUFFIXES do n = n / 1000 i = i + 1 end
    if n >= 1000 then return ("%.2e"):format(n * 1000 ^ i) end
    if n >= 100 then return ("%d%s"):format(floor(n), SUFFIXES[i]) end
    return ("%.2f%s"):format(floor(n * 100) / 100, SUFFIXES[i])
end

G.COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
function G.Gold(n) return G.Short(n) .. G.COIN end

function G.Duration(s)
    s = max(0, floor(s or 0))
    if s >= 3600 then return ("%dh %02dm"):format(floor(s / 3600), floor(s % 3600 / 60)) end
    if s >= 60 then return ("%dm %02ds"):format(floor(s / 60), s % 60) end
    return ("%ds"):format(s)
end

-- Bonuses ---------------------------------------------------------------------------------

-- Adds up one kind of bonus from bought global upgrades and cleared relics.
function G.Bonus(kind)
    local db, total = G.db, 0
    for _, u in ipairs(ns.GLOBAL_UPGRADES) do
        if u.kind == kind and db.upgrades[u.id] then total = total + u.value end
    end
    for _, z in ipairs(ns.ZONES) do
        if z.relic.kind == kind and db.cleared[z.id] then total = total + z.relic.value end
    end
    return total
end

function G.Owned(id) return G.db.hire[id] or 0 end

function G.TotalHired()
    local n = 0
    for _, c in pairs(G.db.hire) do n = n + c end
    return n
end

function G.Frenzy()
    return (G.db.frenzyEnds or 0) > now()
end

-- Everything that multiplies all mining, before the courier frenzy.
function G.GlobalMultiplier()
    return (1 + G.Bonus("gps")) * (1 + ns.RENOWN_BONUS * G.db.renown) * (1 + G.CharacterBonus())
end

-- Your real characters ---------------------------------------------------------------------

-- Each character on the account, keyed "Name-Realm".
function G.CharKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or ""
    return name .. "-" .. realm
end

-- Notes this character's level, class and wallet. Run on login, level-up
-- and whenever money changes.
function G.UpdateChar()
    local key = G.CharKey()
    local c = G.db.chars[key] or { peak = 0 }
    G.db.chars[key] = c
    c.name = UnitName and UnitName("player") or "?"
    c.level = UnitLevel and UnitLevel("player") or c.level or 1
    local _, class = UnitClass and UnitClass("player")
    c.class = class or c.class
    local money = GetMoney and GetMoney() or 0
    if money > (c.peak or 0) then c.peak = money end
    return c
end

-- The three ways your real characters boost the mine, each as a fraction.
function G.Warband()
    local levels = 0
    for _, c in pairs(G.db.chars) do levels = levels + (c.level or 0) end
    return levels * ns.WARBAND_PER_LEVEL, levels
end

function G.Patronage()
    local copper = 0
    for _, c in pairs(G.db.chars) do copper = copper + (c.peak or 0) end
    local gold = floor(copper / 10000)
    return min(ns.PATRON_CAP, gold * ns.PATRON_PER_GOLD), gold
end

function G.FieldWork()
    local ore = G.db.realOre or 0
    return min(ns.ORE_CAP, floor(ore / ns.ORE_PER_BONUS) * ns.ORE_BONUS), ore
end

function G.CharacterBonus()
    return G.Warband() + G.Patronage() + G.FieldWork()
end

-- Remembers where your characters have really been.
function G.Visit(zone)
    if zone and zone ~= "" and not G.db.visited[zone] then
        G.db.visited[zone] = now()
        return true
    end
end

function G.Scouted(z)
    return G.db.visited[z.name] ~= nil
end

-- Reads a loot line. Returns the ore name and count if it was your own ore.
function G.ParseOreLoot(msg)
    if type(msg) ~= "string" then return end
    -- Only your own loot: the line starts like "You receive loot".
    local prefix = (LOOT_ITEM_SELF or "You receive loot: %s."):match("^(.-)%%s")
    if prefix and msg:sub(1, #prefix) ~= prefix then return end
    local id = tonumber(msg:match("|Hitem:(%d+)"))
    local ore = id and ns.ORE_IDS[id]
    if not ore then return end
    local count = tonumber(msg:match("|r%s*x(%d+)")) or 1
    return ore, count
end

-- What one hireling of this kind mines per second, upgrades included.
function G.HirelingGPS(h)
    local mult = 1
    for tier = 1, #ns.TIER_AT do
        if G.db.upgrades[h.id .. ":" .. tier] then mult = mult * 2 end
    end
    return h.gps * mult * G.GlobalMultiplier()
end

function G.GPS(ignoreFrenzy)
    local total = 0
    for _, h in ipairs(ns.HIRELINGS) do
        local c = G.Owned(h.id)
        if c > 0 then total = total + c * G.HirelingGPS(h) end
    end
    if not ignoreFrenzy and G.Frenzy() then total = total * ns.FRENZY_MULT end
    return total
end

function G.ClickValue()
    local base = 1 * (1 + G.Bonus("click")) * (1 + ns.RENOWN_BONUS * G.db.renown)
    local v = base + G.GPS(true) * G.Bonus("clickgps")
    if G.Frenzy() then v = v * ns.FRENZY_MULT end
    return v
end

-- Earning ---------------------------------------------------------------------------------

function G.Earn(amount)
    if not amount or amount <= 0 or amount ~= amount then return end
    local db = G.db
    db.gold = db.gold + amount
    db.runEarned = db.runEarned + amount
    db.stats.lifetime = db.stats.lifetime + amount
end

function G.Spend(amount)
    if G.db.gold + 1e-9 < amount then return false end
    G.db.gold = max(0, G.db.gold - amount)
    return true
end

function G.Click()
    local v = G.ClickValue()
    G.Earn(v)
    G.db.stats.clicks = G.db.stats.clicks + 1
    G.db.stats.clickGold = G.db.stats.clickGold + v
    return v
end

-- Called every few frames by the driver.
function G.Tick(dt)
    local gps = G.GPS()
    G.Earn(gps * dt)
    if gps > G.db.stats.bestGps then G.db.stats.bestGps = gps end
    G.db.lastSeen = now()
    G.CheckExpedition()
end

function G.Vein()
    local vein = ns.VEINS[1]
    for _, v in ipairs(ns.VEINS) do
        if G.db.stats.lifetime >= v.at then vein = v end
    end
    return vein
end

-- Hirelings -------------------------------------------------------------------------------

local function unitCost(h)
    return h.cost * ns.GROWTH ^ G.Owned(h.id) * max(0.5, 1 - G.Bonus("discount"))
end

-- Price of the next n of this hireling.
function G.Cost(h, n)
    n = n or 1
    local g = ns.GROWTH
    return unitCost(h) * (g ^ n - 1) / (g - 1)
end

-- How many you could buy right now (at least 0).
function G.MaxAffordable(h)
    local g = ns.GROWTH
    local n = floor(log(G.db.gold * (g - 1) / unitCost(h) + 1) / log(g))
    -- Rounding can be off by one either way.
    while n > 0 and G.Cost(h, n) > G.db.gold do n = n - 1 end
    while G.Cost(h, n + 1) <= G.db.gold do n = n + 1 end
    return max(0, n)
end

-- How many the current buy mode would buy (Max buys what you can afford,
-- or shows the price of one).
function G.BuyCount(h)
    local mode = G.db.buyMode
    if mode == "max" then return max(1, G.MaxAffordable(h)) end
    return mode
end

function G.Visible(h)
    if h.index == 1 or G.db.seen[h.id] or G.Owned(h.id) > 0 then return true end
    local prev = ns.HIRELINGS[h.index - 1]
    if G.Owned(prev.id) > 0 or G.db.stats.lifetime >= h.cost * 0.5 then
        G.db.seen[h.id] = true
        return true
    end
    return false
end

function G.Hire(id, n)
    local h = byId[id]
    if not h then return false end
    n = n or G.BuyCount(h)
    if n < 1 then return false end
    if not G.Spend(G.Cost(h, n)) then return false end
    G.db.hire[id] = G.Owned(id) + n
    G.db.seen[id] = true
    return true
end

-- Upgrades --------------------------------------------------------------------------------

function G.UpgradeUnlocked(u)
    if u.hireling then return G.Owned(u.hireling) >= u.need end
    return G.TotalHired() >= (u.need or 0)
end

-- Unlocked and not bought yet, cheapest first.
function G.AvailableUpgrades()
    local list = {}
    for _, u in ipairs(G.UPGRADES) do
        if not G.db.upgrades[u.id] and G.UpgradeUnlocked(u) then list[#list + 1] = u end
    end
    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

function G.BoughtUpgrades()
    local list = {}
    for _, u in ipairs(G.UPGRADES) do
        if G.db.upgrades[u.id] then list[#list + 1] = u end
    end
    return list
end

function G.BuyUpgrade(id)
    local u = G.upgradeById[id]
    if not u or G.db.upgrades[id] or not G.UpgradeUnlocked(u) then return false end
    if not G.Spend(u.cost) then return false end
    G.db.upgrades[id] = true
    return true
end

-- Expeditions -----------------------------------------------------------------------------

function G.ZoneOpen(z)
    return z.index == 1 or G.db.cleared[ns.ZONES[z.index - 1].id] ~= nil
end

function G.ExpeditionSeconds(z)
    local scouted = G.Scouted(z) and ns.SCOUTED_TIME or 1
    return floor(z.minutes * 60 * max(0.25, 1 - G.Bonus("haste")) * scouted)
end

-- Why you can't send an expedition here, or nil if you can.
function G.CantSend(z)
    if G.db.expedition then return "An expedition is already out." end
    if not G.ZoneOpen(z) then return "Clear the zone before it first." end
    if G.TotalHired() < z.need then return ("Needs %d hirelings."):format(z.need) end
    if G.db.gold < z.cost then return "Not enough gold for supplies." end
end

function G.SendExpedition(id)
    local z = zoneById[id]
    if not z or G.CantSend(z) then return false end
    G.Spend(z.cost)
    local secs = G.ExpeditionSeconds(z)
    -- The haul is set when they leave: supplies back three times over, plus
    -- a quarter of what your crew would mine in that time. Twice that if one
    -- of your characters has been there and could tell them the way.
    local scouted = G.Scouted(z)
    G.db.expedition = {
        zone = id, started = now(), ends = now() + secs, scouted = scouted,
        reward = (z.cost * 3 + G.GPS(true) * secs * 0.25) * (scouted and ns.SCOUTED_GOLD or 1),
    }
    return true
end

-- Brings an expedition home if its time is up. Returns a report table.
function G.CheckExpedition()
    local e = G.db.expedition
    if not e or now() < e.ends then return end
    local z = zoneById[e.zone]
    G.db.expedition = nil
    if not z then return end
    G.Earn(e.reward)
    G.db.stats.expeditions = G.db.stats.expeditions + 1
    local report = { zone = z, gold = e.reward }
    if not G.db.cleared[z.id] then
        G.db.cleared[z.id] = now()
        report.relic = z.relic
    end
    if ns.OnExpeditionHome then ns.OnExpeditionHome(report) end
    return report
end

-- Couriers --------------------------------------------------------------------------------

-- A caught courier either pays five minutes of mining or starts a frenzy.
function G.CatchCourier(roll)
    roll = roll or math.random()
    G.db.stats.couriers = G.db.stats.couriers + 1
    if roll < 0.35 then
        G.db.frenzyEnds = now() + ns.FRENZY_SECONDS
        return "frenzy"
    end
    local gold = max(25, G.GPS(true) * 300, G.db.gold * 0.05)
    gold = min(gold, max(25, G.GPS(true) * 900))
    G.Earn(gold)
    return "gold", gold
end

-- Renown ----------------------------------------------------------------------------------

function G.PendingRenown()
    -- A tiny epsilon so exact cubes don't round down.
    return floor((G.db.runEarned / ns.RENOWN_DIVISOR) ^ (1 / 3) + 1e-9)
end

-- Gold this run needed for one more point of Renown.
function G.NextRenownAt()
    local p = G.PendingRenown() + 1
    return p * p * p * ns.RENOWN_DIVISOR
end

function G.Standing(renown)
    renown = renown or G.db.renown
    local s, nextS = ns.STANDINGS[1], nil
    for i, st in ipairs(ns.STANDINGS) do
        if renown >= st.at then s, nextS = st, ns.STANDINGS[i + 1] end
    end
    return s, nextS
end

-- Start over for Renown. Relics, cleared zones and stats stay.
function G.HearthHome()
    local gain = G.PendingRenown()
    if gain < 1 then return false end
    local db = G.db
    db.renown = db.renown + gain
    db.gold, db.runEarned = 0, 0
    db.hire, db.upgrades, db.seen = {}, {}, {}
    db.expedition, db.frenzyEnds = nil, 0
    db.stats.hearths = db.stats.hearths + 1
    return gain
end

-- Offline and real-game bonuses -----------------------------------------------------------

-- Splits time away into full-pace and half-pace seconds. Rested: a full
-- shift, then half pace until the long shift ends. Not rested: a half-pace
-- shift and nothing after.
function G.Shift(away, rested)
    local shift = (ns.SHIFT_HOURS + G.Bonus("offline")) * 3600
    if rested then
        local full = min(away, shift)
        local slow = min(away, max(shift, ns.LONG_SHIFT_HOURS * 3600)) - full
        return full, slow, full + slow
    end
    local slow = min(away, shift)
    return 0, slow, slow
end

-- Works out what the crew mined while you were away. Returns a report, or
-- nil if it's been under a minute.
function G.ApplyOffline(t)
    local db = G.db
    t = t or now()
    local last = db.lastSeen
    db.lastSeen = t
    if not last or t - last < 60 then return end
    local away = t - last
    local full, slow, counted = G.Shift(away, db.loggedOutRested)
    local gold = G.GPS(true) * (full + slow * ns.OFFLINE_SLOW)
    G.Earn(gold)
    local report = { away = away, counted = counted, full = full, slow = slow, gold = gold, rested = db.loggedOutRested }
    -- An expedition that finished while you were gone comes home now.
    report.expedition = G.CheckExpedition()
    return report
end

-- A burst worth this many seconds of mining (at least a little early on).
function G.Bonanza(seconds, floorGold)
    local gold = max(floorGold or 0, G.GPS(true) * seconds)
    G.Earn(gold)
    return gold
end

-- Sound -----------------------------------------------------------------------------------

function ns.Sound(key)
    if not (G.db and G.db.settings.sound) then return end
    local id = SOUNDKIT and SOUNDKIT[key]
    if id and PlaySound then pcall(PlaySound, id, "SFX") end
end

function ns.Print(msg)
    print("|cffe6b34dForever Idle|r: " .. msg)
end

-- Events ----------------------------------------------------------------------------------

local driver = CreateFrame("Frame")
ns.driver = driver
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if not G.db then return end
    acc = acc + elapsed
    if acc >= 0.2 then
        G.Tick(acc)
        acc = 0
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    end
end)

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("PLAYER_LEVEL_UP")
driver:RegisterEvent("QUEST_TURNED_IN")
driver:RegisterEvent("PLAYER_MONEY")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("CHAT_MSG_LOOT")
driver:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

local HEARTHSTONE = 8690
local function noteZone()
    local zone = GetRealZoneText and GetRealZoneText()
    if G.Visit(zone) then
        for _, z in ipairs(ns.ZONES) do
            if z.name == zone then
                ns.Print(("You've scouted %s. Expeditions there now take half the time and bring back twice the gold."):format(zone))
                if ns.UI then ns.UI.Toast("Scouted: " .. zone, "Expeditions here: half the time, twice the gold.", z.relic.icon) end
            end
        end
    end
end

driver:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        ForeverIdleDB = ForeverIdleDB or {}
        G.Init(ForeverIdleDB)
    elseif not G.db then
        return
    elseif event == "PLAYER_LOGIN" then
        G.UpdateChar()
        local report = G.ApplyOffline()
        if report and report.gold > 0 and ns.UI then ns.UI.ShowOffline(report) end
    elseif event == "PLAYER_LOGOUT" then
        G.db.lastSeen = now()
        G.db.loggedOutRested = IsResting and IsResting() and true or false
    elseif event == "PLAYER_MONEY" then
        G.UpdateChar()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        noteZone()
    elseif event == "CHAT_MSG_LOOT" then
        local ore, count = G.ParseOreLoot(arg1)
        if ore then
            local before = G.FieldWork()
            G.db.realOre = G.db.realOre + count
            if G.db.settings.bonuses then G.Bonanza(ns.ORE_SECONDS * count, 5 * count) end
            if G.FieldWork() > before and ns.UI then
                ns.UI.Toast("Field work", ("%d real ore mined. Your crew mines %d%% more."):format(G.db.realOre, floor(G.FieldWork() * 100 + 0.5)), "Interface\\Icons\\Trade_Mining")
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Classic Era passes (unit, castGUID, spellID).
        if arg1 == "player" and arg3 == HEARTHSTONE and G.db.settings.bonuses and now() - G.db.lastHearth >= ns.HEARTH_COOLDOWN then
            G.db.lastHearth = now()
            G.db.stats.realHearths = G.db.stats.realHearths + 1
            local gold = G.Bonanza(ns.HEARTH_SECONDS, 50)
            if ns.UI then ns.UI.Toast("Home for supper", "You hearthed, so the crew put in a double shift: +" .. G.Gold(gold), "Interface\\Icons\\INV_Misc_Rune_01") end
        end
    elseif event == "PLAYER_LEVEL_UP" then
        G.UpdateChar()
        if arg1 then G.db.chars[G.CharKey()].level = arg1 end
        if not G.db.settings.bonuses then return end
        local gold = G.Bonanza(ns.DING_SECONDS, 100)
        G.db.stats.dings = G.db.stats.dings + 1
        ns.Print(("Ding! Level %s. Your crew celebrates and digs up %s."):format(tostring(arg1), G.Gold(gold)))
        if ns.UI then ns.UI.Toast("Ding! Level " .. tostring(arg1), "+" .. G.Gold(gold), "Interface\\Icons\\Spell_Holy_SurgeOfLight") end
    elseif event == "QUEST_TURNED_IN" and G.db.settings.bonuses then
        local gold = G.Bonanza(ns.QUEST_SECONDS, 10)
        G.db.stats.quests = G.db.stats.quests + 1
        if ns.UI then ns.UI.Toast("Quest complete", "Your crew gets a tip: +" .. G.Gold(gold), "Interface\\Icons\\INV_Misc_Note_01") end
    end
end)

-- Slash commands --------------------------------------------------------------------------

local function toggleSetting(key, label)
    G.db.settings[key] = not G.db.settings[key]
    ns.Print(label .. (G.db.settings[key] and " on." or " off."))
end

SLASH_FOREVERIDLE1 = "/idle"
SLASH_FOREVERIDLE2 = "/fidle"
SLASH_FOREVERIDLE3 = "/foreveridle"
SlashCmdList.FOREVERIDLE = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if not G.db then return end
    if msg == "" then
        if ns.UI then ns.UI.Toggle() end
    elseif msg == "status" then
        ns.Print(("%s, mining %s a second. Renown %d."):format(G.Gold(G.db.gold), G.Gold(G.GPS()), G.db.renown))
    elseif msg == "sound" then
        toggleSetting("sound", "Sound")
    elseif msg == "courier" then
        toggleSetting("courier", "Lost couriers")
    elseif msg == "bonus" or msg == "bonuses" then
        toggleSetting("bonuses", "Level-up and quest bonuses")
    elseif msg == "reset" then
        if ns.UI then ns.UI.ConfirmWipe() end
    else
        ns.Print("/idle opens the game. Also: /idle status, /idle sound, /idle courier, /idle bonus, /idle reset.")
    end
end

function ForeverIdle_OnAddonCompartmentClick()
    if ns.UI then ns.UI.Toggle() end
end

-- Wipes everything, including Renown and relics. What your real characters
-- did (levels, wallets, ore, places) stays, because that really happened.
function G.Wipe()
    local keep = { chars = G.db.chars, visited = G.db.visited, realOre = G.db.realOre }
    for k in pairs(G.db) do G.db[k] = nil end
    for k, v in pairs(keep) do G.db[k] = v end
    G.Init(G.db)
    G.db.lastSeen = now()
end
