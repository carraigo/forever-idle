-- The window: your vein and your character on the left, four pages on the
-- right (Hirelings, Upgrades, Expeditions, Renown), plus toasts and the lost
-- courier. Built from plain textures in the same flat style as Forever Told,
-- with the game's own icons, coin art, status bar and sounds.

local _, ns = ...
local G = ns.Game

local UI = {}
ns.UI = UI

local C = {
    bg = { 0.055, 0.06, 0.07, 0.97 },
    panel = { 0.085, 0.09, 0.105, 1 },
    raised = { 0.12, 0.125, 0.145, 1 },
    line = { 1, 1, 1, 0.08 },
    accent = { 0.90, 0.70, 0.30, 1 },
    text = { 0.94, 0.93, 0.89, 1 },
    muted = { 0.60, 0.59, 0.55, 1 },
    good = { 0.45, 0.85, 0.40, 1 },
    danger = { 0.92, 0.36, 0.30, 1 },
}
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
local BODY = LATIN[GetLocale and GetLocale() or "enUS"] and "Fonts\\ARIALN.TTF" or STANDARD_TEXT_FONT
local TITLE = STANDARD_TEXT_FONT
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
ns.LOGO = "Interface\\AddOns\\ForeverIdle\\Media\\Logo"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"

-- Widget kit ------------------------------------------------------------------------------

local function Fill(frame, colour, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(unpack(colour))
    return t
end

local function Border(frame, colour)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(colour or C.line))
        if side == "TOP" or side == "BOTTOM" then
            t:SetHeight(1) t:SetPoint(side .. "LEFT") t:SetPoint(side .. "RIGHT")
        else
            t:SetWidth(1) t:SetPoint("TOP" .. side) t:SetPoint("BOTTOM" .. side)
        end
        edges[#edges + 1] = t
    end
    frame.SetBorderColour = function(_, r, g, b, a)
        for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a) end
    end
end

local function Text(parent, size, colour, font, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or BODY, size or 13, flags or "")
    fs:SetTextColor(unpack(colour or C.text))
    fs:SetJustifyH("LEFT")
    return fs
end

local function Button(parent, label, w, h, kind)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 100, h or 24)
    b.bg = Fill(b, kind == "primary" and C.accent or C.raised)
    Border(b, { 1, 1, 1, 0.14 })
    b.label = Text(b, 12, kind == "primary" and { 0.1, 0.08, 0.03, 1 } or C.text)
    b.label:SetPoint("CENTER")
    b.label:SetText(label)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.07)
    return b
end

-- An icon with a thin border, cropped like the action bars do.
local function Icon(parent, size, path)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon:SetTexture(path or QUESTION)
    Fill(f, { 0, 0, 0, 1 })
    Border(f, { 1, 1, 1, 0.25 })
    return f
end

local function Tooltip(owner, build)
    owner:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        build(self)
        GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Desaturate(tex, on)
    if tex.SetDesaturated then tex:SetDesaturated(on and true or false) end
end

local function hex(c) return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local GOOD, BAD, MUTED, ACCENT = hex(C.good), hex(C.danger), hex(C.muted), hex(C.accent)
local function paint(colour, s) return "|cff" .. colour .. s .. "|r" end

-- Main window ---------------------------------------------------------------------------

local W, H, LEFT_W = 760, 508, 250
local refreshYou
local frame, pages, tabs = nil, {}, {}

local function build()
    frame = CreateFrame("Frame", "ForeverIdleFrame", UIParent)
    frame:SetSize(W, H)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        G.db.pos = { point, rel, x, y }
    end)
    local pos = G.db.pos
    if pos then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("CENTER") end
    Fill(frame, C.bg)
    Border(frame, { 1, 1, 1, 0.12 })
    frame:Hide()

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.LOGO)
    logo:SetSize(22, 22)
    logo:SetPoint("TOPLEFT", 10, -7)
    local title = Text(frame, 15, C.accent, TITLE)
    title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    title:SetText("Forever Idle")
    frame.subtitle = Text(frame, 12, C.muted)
    frame.subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)

    local close = Button(frame, "x", 22, 22)
    close:SetPoint("TOPRIGHT", -8, -7)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Switches between the full window and the compact one.
    local size = Button(frame, "-", 22, 22)
    size:SetPoint("RIGHT", close, "LEFT", -4, 0)
    size:SetScript("OnClick", function() UI.SetCompact(not G.db.compact) end)
    Tooltip(size, function()
        GameTooltip:SetText(G.db.compact and "Full window" or "Compact window")
        GameTooltip:AddLine(G.db.compact and "Show the hirelings, upgrades and everything else." or "Just the vein, your gold and a quick hire button.", 1, 1, 1, true)
    end)
    frame.size = size

    -- Left: gold, the vein, your character.
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT", 10, -38)
    left:SetSize(LEFT_W, H - 48)
    Fill(left, C.panel)
    local rock = left:CreateTexture(nil, "BACKGROUND", nil, 1)
    rock:SetAllPoints()
    rock:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
    rock:SetAlpha(0.18)
    Border(left)
    frame.left = left

    frame.gold = Text(left, 24, C.accent, TITLE)
    frame.gold:SetPoint("TOP", 0, -14)
    frame.gps = Text(left, 13, C.muted)
    frame.gps:SetPoint("TOP", frame.gold, "BOTTOM", 0, -4)

    local vein = Icon(left, 96, ns.VEINS[1].icon)
    vein:SetPoint("TOP", 0, -70)
    vein:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    vein:SetScript("OnMouseDown", function(self) self.icon:SetPoint("TOPLEFT", 3, -3) self.icon:SetPoint("BOTTOMRIGHT", -3, 3) end)
    vein:SetScript("OnMouseUp", function(self) self.icon:SetPoint("TOPLEFT", 1, -1) self.icon:SetPoint("BOTTOMRIGHT", -1, 1) end)
    vein:SetScript("OnClick", function() UI.ClickVein() end)
    Tooltip(vein, function()
        GameTooltip:SetText(G.Vein().name)
        GameTooltip:AddLine("Click to mine " .. G.Gold(G.ClickValue()) .. ".", 1, 1, 1)
    end)
    frame.vein = vein
    frame.veinName = Text(left, 12, C.text)
    frame.veinName:SetPoint("TOP", vein, "BOTTOM", 0, -6)

    -- Your own character, standing by the vein.
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, left)
    if ok and model then
        model:SetPoint("BOTTOMLEFT", 4, 34)
        model:SetPoint("BOTTOMRIGHT", -4, 34)
        model:SetHeight(190)
        model:SetScript("OnShow", function(self) pcall(self.SetUnit, self, "player") end)
        pcall(model.SetUnit, model, "player")
        frame.model = model
    end

    frame.status = Text(left, 12, C.muted)
    frame.status:SetPoint("BOTTOMLEFT", 10, 10)
    frame.status:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.status:SetJustifyH("CENTER")

    -- Floating "+12" numbers over the vein.
    frame.floats = {}
    for i = 1, 8 do
        local fs = Text(left, 16, C.accent, TITLE, "OUTLINE")
        fs:Hide()
        frame.floats[i] = fs
    end
    left:SetScript("OnUpdate", function()
        local t = GetTime()
        for _, fs in ipairs(frame.floats) do
            if fs.born then
                local age = t - fs.born
                if age > 1 then fs.born = nil fs:Hide() else
                    fs:SetPoint("CENTER", vein, "CENTER", fs.dx, 30 + age * 50)
                    fs:SetAlpha(1 - age)
                end
            end
        end
    end)

    -- Right: tabs and pages.
    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.right = right
    local names = { { "hire", "Hirelings" }, { "upgrades", "Upgrades" }, { "expeditions", "Expeditions" }, { "you", "You" }, { "renown", "Renown" } }
    for i, t in ipairs(names) do
        local b = Button(right, t[2], 92, 26)
        b:SetPoint("TOPLEFT", (i - 1) * 96, 0)
        b:SetScript("OnClick", function() UI.ShowPage(t[1]) end)
        tabs[t[1]] = b
        local page = CreateFrame("Frame", nil, right)
        page:SetPoint("TOPLEFT", 0, -34)
        page:SetPoint("BOTTOMRIGHT")
        page:Hide()
        pages[t[1]] = page
    end
    UI.BuildHire(pages.hire)
    UI.BuildUpgrades(pages.upgrades)
    UI.BuildExpeditions(pages.expeditions)
    UI.BuildRenown(pages.renown)
    UI.BuildYou(pages.you)
    UI.BuildCourier(left)
    UI.BuildAway(frame)

    -- Compact mode's one shortcut: hire whichever hireling is the best deal.
    local quick = Button(left, "", LEFT_W - 20, 24)
    quick:SetPoint("BOTTOM", 0, 30)
    quick:SetScript("OnClick", function()
        local h = UI.BestHire()
        if h and G.Hire(h.id, 1) then ns.Sound("LOOT_WINDOW_COIN_SOUND") UI.Refresh(true) end
    end)
    Tooltip(quick, function()
        local h = UI.BestHire()
        if not h then return end
        GameTooltip:SetText(h.name)
        GameTooltip:AddLine(("The most gold a second for your gold. Each mines %s a second."):format(G.Gold(G.HirelingGPS(h))), 1, 1, 1, true)
    end)
    quick:Hide()
    frame.quick = quick
    UI.SetCompact(G.db.compact)

    frame:SetScript("OnShow", function()
        ns.Sound("IG_MAINMENU_OPEN")
        UI.ShowPage(G.db.tab or "hire")
        if UI.pendingAway then UI.ShowAway(UI.pendingAway) UI.pendingAway = nil end
    end)
    frame:SetScript("OnHide", function() ns.Sound("IG_MAINMENU_CLOSE") end)
end

function UI.Frame() return frame end

function UI.Toggle()
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function UI.ShowPage(key)
    if not pages[key] then key = "hire" end
    G.db.tab = key
    for k, p in pairs(pages) do
        p:SetShown(k == key)
        tabs[k].bg:SetColorTexture(unpack(k == key and { 0.22, 0.18, 0.10, 1 } or C.raised))
        tabs[k].label:SetTextColor(unpack(k == key and C.accent or C.text))
    end
    UI.Refresh(true)
end

local lastClickSound = 0
function UI.ClickVein()
    local v = G.Click()
    local t = GetTime()
    if t - lastClickSound > 0.12 then ns.Sound("LOOT_WINDOW_COIN_SOUND") lastClickSound = t end
    for _, fs in ipairs(frame.floats) do
        if not fs.born then
            fs.born, fs.dx = t, math.random(-30, 30)
            fs:SetText("+" .. G.Short(v))
            fs:SetAlpha(1)
            fs:Show()
            break
        end
    end
    UI.Refresh()
end

-- Compact mode ---------------------------------------------------------------------------

local COMPACT_W, COMPACT_H = LEFT_W + 20, 262

function UI.SetCompact(on)
    G.db.compact = on and true or false
    local left = frame.left
    frame:SetSize(on and COMPACT_W or W, on and COMPACT_H or H)
    left:SetSize(LEFT_W, (on and COMPACT_H or H) - 48)
    frame.right:SetShown(not on)
    frame.subtitle:SetShown(not on)
    if frame.model then frame.model:SetShown(not on) end
    frame.quick:SetShown(on)
    frame.vein:SetSize(on and 64 or 96, on and 64 or 96)
    frame.vein:SetPoint("TOP", 0, on and -64 or -70)
    frame.away:SetWidth(on and LEFT_W or 340)
    frame.size.label:SetText(on and "+" or "-")
    if frame.courier then frame.courier:Hide() end
    UI.Refresh(true)
end

-- The visible hireling that gives the most gold a second per gold spent.
function UI.BestHire()
    local best, bestValue
    for _, h in ipairs(ns.HIRELINGS) do
        if G.Visible(h) then
            local value = G.HirelingGPS(h) / G.Cost(h, 1)
            if not bestValue or value > bestValue then best, bestValue = h, value end
        end
    end
    return best
end

-- Hirelings page --------------------------------------------------------------------------

local MODES = { 1, 10, 100, "max" }

function UI.BuildHire(page)
    page.total = Text(page, 13, C.muted)
    page.total:SetPoint("TOPLEFT", 2, -4)
    page.modes = {}
    for i = #MODES, 1, -1 do
        local m = MODES[i]
        local b = Button(page, m == "max" and "Max" or ("x" .. m), 44, 20)
        b:SetPoint("TOPRIGHT", -(#MODES - i) * 48, 0)
        b:SetScript("OnClick", function() G.db.buyMode = m UI.Refresh(true) end)
        page.modes[m] = b
    end
    page.rows = {}
    for i, h in ipairs(ns.HIRELINGS) do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", 0, -26 - (i - 1) * 36)
        row:SetPoint("RIGHT")
        row:SetHeight(34)
        Fill(row, C.panel)
        row.icon = Icon(row, 30)
        row.icon:SetPoint("LEFT", 2, 0)
        row.name = Text(row, 13, C.text)
        row.name:SetPoint("TOPLEFT", 40, -3)
        row.info = Text(row, 11, C.muted)
        row.info:SetPoint("BOTTOMLEFT", 40, 4)
        row.owned = Text(row, 18, C.accent, TITLE)
        row.owned:SetPoint("RIGHT", -140, 0)
        row.buy = Button(row, "", 128, 26)
        row.buy:SetPoint("RIGHT", -4, 0)
        row.buy:SetScript("OnClick", function()
            if G.Hire(h.id) then ns.Sound("LOOT_WINDOW_COIN_SOUND") UI.Refresh(true) end
        end)
        Tooltip(row.icon, function()
            if not G.Visible(h) then GameTooltip:SetText("Unknown hireling") GameTooltip:AddLine("Keep mining to find out.", 1, 1, 1) return end
            GameTooltip:SetText(h.name)
            GameTooltip:AddLine(h.text, 1, 0.82, 0, true)
            GameTooltip:AddLine(("Each mines %s a second."):format(G.Gold(G.HirelingGPS(h))), 1, 1, 1)
            local owned = G.Owned(h.id)
            if owned > 0 then
                GameTooltip:AddLine(("Your %d mine %s a second."):format(owned, G.Gold(owned * G.HirelingGPS(h))), 1, 1, 1)
            end
        end)
        row.h = h
        page.rows[i] = row
    end
end

local function refreshHire(page)
    page.total:SetText(("%d hired"):format(G.TotalHired()))
    for m, b in pairs(page.modes) do
        b.label:SetTextColor(unpack(G.db.buyMode == m and C.accent or C.muted))
    end
    for _, row in ipairs(page.rows) do
        local h = row.h
        if G.Visible(h) then
            local n = G.BuyCount(h)
            local cost = G.Cost(h, n)
            local can = G.db.gold >= cost
            row.icon.icon:SetTexture(h.icon)
            Desaturate(row.icon.icon, false)
            row.name:SetText(h.name)
            row.info:SetText(("+%s/s each"):format(G.Short(G.HirelingGPS(h))))
            local owned = G.Owned(h.id)
            row.owned:SetText(owned > 0 and owned or "")
            row.buy.label:SetText(("Hire %d  %s"):format(n, G.Gold(cost)))
            row.buy.label:SetTextColor(unpack(can and C.text or C.danger))
            row.buy:Show()
        else
            row.icon.icon:SetTexture(QUESTION)
            Desaturate(row.icon.icon, true)
            row.name:SetText(paint(MUTED, "???"))
            row.info:SetText("")
            row.owned:SetText("")
            row.buy:Hide()
        end
    end
end

-- Upgrades page ---------------------------------------------------------------------------

local function upgradeTooltip(btn)
    local u = btn.u
    if not u then return end
    GameTooltip:SetText(u.name)
    GameTooltip:AddLine(u.text, 1, 1, 1, true)
    if G.db.upgrades[u.id] then
        GameTooltip:AddLine("Bought", 0.45, 0.85, 0.40)
    else
        local can = G.db.gold >= u.cost
        GameTooltip:AddLine("Costs " .. G.Gold(u.cost), can and 1 or 0.92, can and 1 or 0.36, can and 1 or 0.30)
        GameTooltip:AddLine("Click to buy.", 0.6, 0.6, 0.6)
    end
end

function UI.BuildUpgrades(page)
    page.head = Text(page, 13, C.muted)
    page.head:SetPoint("TOPLEFT", 2, -4)
    page.avail, page.bought = {}, {}
    for i = 1, 30 do
        local b = Icon(page, 40)
        b:SetPoint("TOPLEFT", ((i - 1) % 10) * 47, -26 - math.floor((i - 1) / 10) * 47)
        b:SetScript("OnClick", function(self)
            if self.u and G.BuyUpgrade(self.u.id) then ns.Sound("LOOT_WINDOW_COIN_SOUND") UI.Refresh(true) end
        end)
        Tooltip(b, upgradeTooltip)
        page.avail[i] = b
    end
    page.boughtHead = Text(page, 13, C.muted)
    page.boughtHead:SetPoint("TOPLEFT", 2, -176)
    for i = 1, 64 do
        local b = Icon(page, 26)
        b:SetPoint("TOPLEFT", ((i - 1) % 16) * 29, -198 - math.floor((i - 1) / 16) * 29)
        Tooltip(b, upgradeTooltip)
        page.bought[i] = b
    end
    page.empty = Text(page, 12, C.muted)
    page.empty:SetPoint("TOPLEFT", 2, -30)
    page.empty:SetText("Nothing to buy yet. Upgrades unlock as you hire more.")
end

local function refreshUpgrades(page)
    local avail, bought = G.AvailableUpgrades(), G.BoughtUpgrades()
    page.head:SetText(("Available (%d)"):format(#avail))
    page.empty:SetShown(#avail == 0)
    for i, b in ipairs(page.avail) do
        local u = avail[i]
        b.u = u
        if u then
            local can = G.db.gold >= u.cost
            b.icon:SetTexture(u.icon)
            Desaturate(b.icon, not can)
            b:SetBorderColour(unpack(can and C.accent or { 1, 1, 1, 0.25 }))
            b:Show()
        else
            b:Hide()
        end
    end
    page.boughtHead:SetText(("Bought (%d of %d)"):format(#bought, #G.UPGRADES))
    for i, b in ipairs(page.bought) do
        local u = bought[i]
        b.u = u
        if u then b.icon:SetTexture(u.icon) b:Show() else b:Hide() end
    end
end

-- Expeditions page ------------------------------------------------------------------------

function UI.BuildExpeditions(page)
    local cur = CreateFrame("Frame", nil, page)
    cur:SetPoint("TOPLEFT")
    cur:SetPoint("RIGHT")
    cur:SetHeight(52)
    Fill(cur, C.panel)
    Border(cur)
    cur.title = Text(cur, 13, C.text)
    cur.title:SetPoint("TOPLEFT", 10, -7)
    cur.bar = CreateFrame("StatusBar", nil, cur)
    cur.bar:SetStatusBarTexture(BAR)
    cur.bar:SetStatusBarColor(0.85, 0.62, 0.20)
    cur.bar:SetMinMaxValues(0, 1)
    cur.bar:SetPoint("BOTTOMLEFT", 10, 8)
    cur.bar:SetPoint("BOTTOMRIGHT", -10, 8)
    cur.bar:SetHeight(14)
    Fill(cur.bar, { 0, 0, 0, 0.5 })
    cur.time = Text(cur.bar, 11, C.text, nil, "OUTLINE")
    cur.time:SetPoint("CENTER")
    page.cur = cur

    -- One row per zone, then the Forever Deep at the bottom. The Deep's row
    -- asks for its zone each time because every depth is different.
    page.rows = {}
    local list = {}
    for _, z in ipairs(ns.ZONES) do list[#list + 1] = function() return z end end
    list[#list + 1] = function() return G.Deep() end
    for i, zoneOf in ipairs(list) do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", 0, -58 - (i - 1) * 26)
        row:SetPoint("RIGHT")
        row:SetHeight(24)
        Fill(row, C.panel)
        row.relic = Icon(row, 22)
        row.relic:SetPoint("LEFT", 1, 0)
        row.rank = Text(row.relic, 10, C.accent, TITLE, "OUTLINE")
        row.rank:SetPoint("BOTTOMRIGHT", 1, -1)
        Tooltip(row.relic, function()
            local z = zoneOf()
            if z.deep then
                GameTooltip:SetText(ns.DEEP.name)
                GameTooltip:AddLine(("A shaft with no bottom. Every depth you reach adds %d%% to all mining for good."):format(G.DeepPercent(1)), 1, 1, 1, true)
                GameTooltip:AddLine(("Deepest so far: %d (+%d%%)."):format(G.db.depth, G.DeepPercent()), 0.45, 0.85, 0.40)
                return
            end
            if not G.ZoneOpen(z) then GameTooltip:SetText("Unknown relic") return end
            UI.RelicTooltip(z)
            if not G.db.cleared[z.id] then GameTooltip:AddLine("Found on your first clear of " .. z.name .. ".", 0.6, 0.6, 0.6) end
        end)
        row.name = Text(row, 13, C.text)
        row.name:SetPoint("LEFT", 30, 0)
        row.info = Text(row, 11, C.muted)
        row.info:SetPoint("RIGHT", -84, 0)
        row.send = Button(row, "Send", 76, 20)
        row.send:SetPoint("RIGHT", -2, 0)
        row.send:SetScript("OnClick", function()
            if G.SendExpedition(zoneOf().id) then ns.Sound("IG_MAINMENU_OPEN") UI.Refresh(true) end
        end)
        Tooltip(row.send, function()
            local z = zoneOf()
            local why = G.CantSend(z)
            GameTooltip:SetText(z.name)
            GameTooltip:AddLine(("Takes %s. Supplies cost %s."):format(G.Duration(G.ExpeditionSeconds(z)), G.Gold(z.cost)), 1, 1, 1)
            GameTooltip:AddLine("Brings back your supplies three times over, plus a quarter of what your crew mines meanwhile.", 0.8, 0.8, 0.8, true)
            if z.deep then
                GameTooltip:AddLine(("Reaching depth %d adds another %d%% to all mining for good."):format(z.depth, G.DeepPercent(1)), 0.45, 0.85, 0.40, true)
            else
                local rank = G.RelicRank(z)
                if rank >= 1 and rank < ns.RELIC_MAX_RANK then
                    GameTooltip:AddLine(("Clearing it again raises the %s to rank %d: %s"):format(z.relic.name, rank + 1, G.DescribeBonus(z.relic.kind, G.RelicValue(z, rank + 1))), 0.45, 0.85, 0.40, true)
                end
                if G.Scouted(z) then
                    GameTooltip:AddLine("Scouted: you've been here, so it's half the time and twice the gold.", 0.45, 0.85, 0.40, true)
                else
                    GameTooltip:AddLine("Visit " .. z.name .. " on any character to scout it: half the time, twice the gold.", 0.6, 0.6, 0.6, true)
                end
            end
            if why then GameTooltip:AddLine(why, 0.92, 0.36, 0.30) end
        end)
        row.zoneOf = zoneOf
        page.rows[i] = row
    end
end

local function refreshExpeditions(page)
    local e = G.db.expedition
    local cur = page.cur
    if e then
        local z = G.ZoneFor(e.zone, e.depth)
        local total = math.max(1, e.ends - e.started)
        local left = e.ends - G.Now()
        cur.title:SetText(("Expedition to %s  ·  bringing home %s"):format(z and z.name or "?", G.Gold(e.reward)))
        cur.bar:SetValue(1 - left / total)
        cur.time:SetText(G.Duration(left) .. " left")
    else
        cur.title:SetText(paint(MUTED, "No expedition out. Pick a zone below."))
        cur.bar:SetValue(0)
        cur.time:SetText("")
    end
    local hired = G.TotalHired()
    for _, row in ipairs(page.rows) do
        local z = row.zoneOf()
        local open = G.ZoneOpen(z)
        local name, done
        if z.deep then
            row.relic.icon:SetTexture(open and z.icon or QUESTION)
            done = G.db.depth > 0
            row.rank:SetText(done and G.db.depth or "")
            name = open and z.name or paint(MUTED, ns.DEEP.name)
        else
            local rank = G.RelicRank(z)
            row.relic.icon:SetTexture(open and z.relic.icon or QUESTION)
            done = rank > 0
            row.rank:SetText(rank > 1 and rank or "")
            name = (open and z.name or paint(MUTED, z.name)) .. (G.Scouted(z) and paint(GOOD, "  scouted") or "")
        end
        Desaturate(row.relic.icon, not done)
        row.name:SetText(name)
        local need = hired >= z.need and tostring(z.need) or paint(BAD, tostring(z.need))
        local cost = G.db.gold >= z.cost and G.Gold(z.cost) or paint(BAD, G.Short(z.cost)) .. G.COIN
        row.info:SetText(open and ("%s hired · %s · %s"):format(need, G.Duration(G.ExpeditionSeconds(z)), cost) or "")
        row.send:SetShown(open)
        row.send.label:SetText(e and e.zone == z.id and "Out" or (z.deep and "Descend" or (done and "Again" or "Send")))
        row.send.label:SetTextColor(unpack(G.CantSend(z) and C.muted or C.text))
    end
end

-- Renown page -----------------------------------------------------------------------------

-- A relic's name, what it does at its current rank and what the next rank brings.
function UI.RelicTooltip(z)
    local rank = G.RelicRank(z)
    GameTooltip:SetText(z.relic.name)
    if rank < 1 then
        GameTooltip:AddLine(z.relic.text, 1, 1, 1, true)
        return
    end
    GameTooltip:AddLine(("Rank %d of %d: %s"):format(rank, ns.RELIC_MAX_RANK, G.DescribeBonus(z.relic.kind, G.RelicValue(z))), 1, 1, 1, true)
    if rank < ns.RELIC_MAX_RANK then
        GameTooltip:AddLine(("Clear %s again for rank %d: %s"):format(z.name, rank + 1, G.DescribeBonus(z.relic.kind, G.RelicValue(z, rank + 1))), 0.6, 0.6, 0.6, true)
    else
        GameTooltip:AddLine("Fully ranked.", 0.45, 0.85, 0.40)
    end
end

local function relicTooltip(btn)
    local z = btn.z
    if G.db.cleared[z.id] then UI.RelicTooltip(z) return end
    GameTooltip:SetText("Unknown relic")
    GameTooltip:AddLine("Clear " .. z.name .. " to find it.", 1, 1, 1, true)
end

function UI.BuildRenown(page)
    page.renown = Text(page, 22, C.accent, TITLE)
    page.renown:SetPoint("TOPLEFT", 2, -4)
    page.standing = Text(page, 14, C.text)
    page.standing:SetPoint("TOPLEFT", page.renown, "BOTTOMLEFT", 0, -4)
    page.bar = CreateFrame("StatusBar", nil, page)
    page.bar:SetStatusBarTexture(BAR)
    page.bar:SetStatusBarColor(0, 0.6, 0.1)
    page.bar:SetMinMaxValues(0, 1)
    page.bar:SetPoint("TOPLEFT", page.standing, "BOTTOMLEFT", 0, -6)
    page.bar:SetSize(300, 12)
    Fill(page.bar, { 0, 0, 0, 0.5 })
    page.barText = Text(page.bar, 10, C.text, nil, "OUTLINE")
    page.barText:SetPoint("CENTER")

    page.hearth = Button(page, "Hearth home", 150, 30, "primary")
    page.hearth:SetPoint("TOPRIGHT", -2, -4)
    page.hearth.icon = page.hearth:CreateTexture(nil, "OVERLAY")
    page.hearth.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    page.hearth.icon:SetSize(22, 22)
    page.hearth.icon:SetPoint("LEFT", 5, 0)
    page.hearth:SetScript("OnClick", function()
        if G.PendingRenown() >= 1 then StaticPopup_Show("FOREVERIDLE_HEARTH", G.PendingRenown()) end
    end)
    page.pending = Text(page, 12, C.muted)
    page.pending:SetPoint("TOPRIGHT", page.hearth, "BOTTOMRIGHT", 0, -6)
    page.pending:SetJustifyH("RIGHT")
    page.pending:SetWidth(200)

    local rh = Text(page, 13, C.muted)
    rh:SetPoint("TOPLEFT", 2, -96)
    rh:SetText("Relics")
    page.relics = {}
    for i, z in ipairs(ns.ZONES) do
        local b = Icon(page, 30)
        b:SetPoint("TOPLEFT", (i - 1) * 35, -116)
        b.rank = Text(b, 11, C.accent, TITLE, "OUTLINE")
        b.rank:SetPoint("BOTTOMRIGHT", 1, -1)
        b.z = z
        Tooltip(b, relicTooltip)
        page.relics[i] = b
    end

    local sh = Text(page, 13, C.muted)
    sh:SetPoint("TOPLEFT", 2, -162)
    sh:SetText("Stats")
    page.stats = Text(page, 12, C.text)
    page.stats:SetPoint("TOPLEFT", 2, -182)
    page.stats:SetWidth(300)
    page.stats:SetSpacing(3)

    -- Settings, as little on/off buttons.
    page.toggles = {}
    local opts = { { "sound", "Sound" }, { "courier", "Lost couriers" }, { "bonuses", "Level-up and quest bonuses" } }
    for i, o in ipairs(opts) do
        local b = Button(page, "", 160, 22)
        b:SetPoint("TOPRIGHT", -2, -176 - (i - 1) * 28)
        b:SetScript("OnClick", function()
            G.db.settings[o[1]] = not G.db.settings[o[1]]
            UI.Refresh(true)
        end)
        b.key, b.text = o[1], o[2]
        page.toggles[i] = b
    end
end

local function refreshRenown(page)
    local db = G.db
    local s, nextS = G.Standing()
    page.renown:SetText(("Renown %d"):format(db.renown))
    page.standing:SetText(("%s  ·  +%d%% to all mining"):format(paint(s.colour, s.name), math.floor(db.renown * ns.RENOWN_BONUS * 100 + 0.5)))
    if nextS then
        page.bar:SetValue((db.renown - s.at) / (nextS.at - s.at))
        page.barText:SetText(("%d / %d to %s"):format(db.renown, nextS.at, nextS.name))
    else
        page.bar:SetValue(1)
        page.barText:SetText("Exalted with the Miners of Azeroth")
    end
    local p = G.PendingRenown()
    page.hearth.label:SetText(p >= 1 and ("Hearth home  +" .. p) or "Hearth home")
    page.hearth:SetAlpha(p >= 1 and 1 or 0.45)
    page.pending:SetText(("Next Renown at %s mined this run."):format(G.Gold(G.NextRenownAt())))
    for _, b in ipairs(page.relics) do
        local rank = G.RelicRank(b.z)
        b.icon:SetTexture(rank > 0 and b.z.relic.icon or QUESTION)
        Desaturate(b.icon, rank == 0)
        b.rank:SetText(rank > 1 and rank or "")
    end
    local st = db.stats
    page.stats:SetText(table.concat({
        "Gold mined, all time: " .. G.Gold(st.lifetime),
        "Gold mined this run: " .. G.Gold(db.runEarned),
        "Best gold a second: " .. G.Gold(st.bestGps),
        ("Clicks: %d (%s)"):format(st.clicks, G.Gold(st.clickGold)),
        ("Expeditions: %d  ·  Couriers caught: %d"):format(st.expeditions, st.couriers),
        ("Hearthed home: %d  ·  Real level-ups: %d"):format(st.hearths, st.dings),
        db.depth > 0 and ("Forever Deep: depth %d (+%d%%)"):format(db.depth, G.DeepPercent()) or nil,
    }, "\n"))
    for _, b in ipairs(page.toggles) do
        local on = db.settings[b.key]
        b.label:SetText(b.text .. ": " .. (on and paint(GOOD, "on") or paint(MUTED, "off")))
    end
end

StaticPopupDialogs["FOREVERIDLE_HEARTH"] = {
    text = "Hearth home for %d Renown?\n\nYour gold, hirelings, upgrades and any expedition are reset. Renown, relics, cleared zones and the Forever Deep stay.",
    button1 = "Hearth home", button2 = CANCEL or "Cancel",
    OnAccept = function()
        local gain = G.HearthHome()
        if gain then
            ns.Sound("LEVELUP")
            UI.Toast("Hearthed home", ("+%d Renown. Every hireling now mines %d%% more."):format(gain, math.floor(G.db.renown * ns.RENOWN_BONUS * 100 + 0.5)), "Interface\\Icons\\INV_Misc_Rune_01")
            UI.Refresh(true)
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["FOREVERIDLE_WIPE"] = {
    text = "Wipe Forever Idle completely? Renown and relics go too. This can't be undone.",
    button1 = "Wipe", button2 = CANCEL or "Cancel",
    OnAccept = function() G.Wipe() UI.Refresh(true) ns.Print("Wiped. A fresh copper vein awaits.") end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.ConfirmWipe() StaticPopup_Show("FOREVERIDLE_WIPE") end

-- The lost courier ------------------------------------------------------------------------

local nextCourier
function UI.BuildCourier(parent)
    local b = Icon(parent, 36, "Interface\\Icons\\Ability_Rogue_Sprint")
    b:SetFrameLevel(parent:GetFrameLevel() + 10)
    b:SetBorderColour(unpack(C.accent))
    b:Hide()
    b:SetScript("OnClick", function(self)
        self:Hide()
        local kind, gold = G.CatchCourier()
        ns.Sound("LOOT_WINDOW_COIN_SOUND")
        if kind == "frenzy" then
            UI.Toast("Battle Shout!", ("The courier rallies your crew: everything mines x%d for %ds."):format(ns.FRENZY_MULT, ns.FRENZY_SECONDS), "Interface\\Icons\\Ability_Warrior_BattleShout")
        else
            UI.Toast("Courier caught", "He was carrying " .. G.Gold(gold) .. ".", "Interface\\Icons\\Ability_Rogue_Sprint")
        end
        UI.Refresh()
    end)
    Tooltip(b, function()
        GameTooltip:SetText("A lost courier")
        GameTooltip:AddLine("Catch him before he runs off.", 1, 1, 1)
    end)
    frame.courier = b
end

local function courierTick()
    local b = frame.courier
    local t = G.Now()
    if b:IsShown() then
        if t > (b.leaves or 0) then b:Hide() end
        return
    end
    if not G.db.settings.courier then return end
    nextCourier = nextCourier or t + math.random(ns.COURIER_MIN, ns.COURIER_MAX)
    if t >= nextCourier then
        nextCourier = t + math.random(ns.COURIER_MIN, ns.COURIER_MAX)
        b.leaves = t + ns.COURIER_LIFETIME
        b:ClearAllPoints()
        b:SetPoint("CENTER", frame.left, "TOPLEFT", math.random(30, LEFT_W - 30), -(G.db.compact and math.random(60, 150) or math.random(190, 380)))
        b:Show()
    end
end

-- While you were away ---------------------------------------------------------------------

function UI.BuildAway(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(340, 150)
    p:SetPoint("CENTER")
    p:SetFrameLevel(parent:GetFrameLevel() + 20)
    p:EnableMouse(true)
    Fill(p, C.raised)
    Border(p, C.accent)
    p.title = Text(p, 16, C.accent, TITLE)
    p.title:SetPoint("TOP", 0, -12)
    p.title:SetText("While you were away")
    p.text = Text(p, 13, C.text)
    p.text:SetPoint("TOPLEFT", 16, -40)
    p.text:SetPoint("TOPRIGHT", -16, -40)
    p.text:SetJustifyH("CENTER")
    p.text:SetSpacing(3)
    local ok = Button(p, "Collect", 100, 24, "primary")
    ok:SetPoint("BOTTOM", 0, 12)
    ok:SetScript("OnClick", function() p:Hide() ns.Sound("LOOT_WINDOW_COIN_SOUND") end)
    p:Hide()
    parent.away = p
end

local function awayText(r)
    local lines = {
        ("You were gone %s. Your crew mined %s."):format(G.Duration(r.away), G.Gold(r.gold)),
        r.rested and paint(GOOD, ("You logged out rested: %s at full pace, %s at half."):format(G.Duration(r.full), G.Duration(r.slow)))
            or paint(MUTED, ("A half-pace shift of %s. Log out in an inn or a city for a full one."):format(G.Duration(r.slow))),
    }
    if r.counted < r.away then
        lines[#lines + 1] = paint(MUTED, ("After %s the crew downed tools."):format(G.Duration(r.counted)))
    end
    if r.expedition then
        local x = r.expedition
        local extra = x.relic and (" and the " .. x.relic.name)
            or x.rank and (", and the %s is now rank %d"):format(x.zone.relic.name, x.rank)
            or ""
        lines[#lines + 1] = ("Your expedition to %s came home with %s%s."):format(x.zone.name, G.Gold(x.gold), extra)
    end
    return table.concat(lines, "\n")
end

function UI.ShowAway(r)
    frame.away.text:SetText(awayText(r))
    frame.away:Show()
end

function UI.ShowOffline(r)
    ns.Print(("Welcome back. While you were away your crew mined %s. Type /idle to collect."):format(G.Gold(r.gold)))
    if frame and frame:IsShown() then UI.ShowAway(r) else UI.pendingAway = r end
end

-- Toasts ----------------------------------------------------------------------------------

local toast
local function buildToast()
    toast = CreateFrame("Frame", nil, UIParent)
    toast:SetSize(320, 54)
    toast:SetPoint("TOP", 0, -140)
    toast:SetFrameStrata("DIALOG")
    Fill(toast, C.raised)
    Border(toast, C.accent)
    toast.icon = Icon(toast, 38)
    toast.icon:SetPoint("LEFT", 8, 0)
    toast.title = Text(toast, 14, C.accent, TITLE)
    toast.title:SetPoint("TOPLEFT", 54, -9)
    toast.text = Text(toast, 12, C.text)
    toast.text:SetPoint("TOPLEFT", 54, -28)
    toast.text:SetPoint("RIGHT", -8, 0)
    toast:SetScript("OnUpdate", function(self)
        local age = GetTime() - (self.born or 0)
        if age > 5 then self:Hide() elseif age > 4 then self:SetAlpha(5 - age) end
    end)
    toast:Hide()
end

function UI.Toast(title, text, icon)
    if not toast then buildToast() end
    toast.title:SetText(title)
    toast.text:SetText(text)
    toast.icon.icon:SetTexture(icon or ns.VEINS[1].icon)
    toast.born = GetTime()
    toast:SetAlpha(1)
    toast:Show()
end
UI.toast = function() return toast end

ns.OnExpeditionHome = function(report)
    ns.Sound("LOOT_WINDOW_COIN_SOUND")
    if report.relic then
        UI.Toast("Relic found: " .. report.relic.name, report.relic.text, report.relic.icon)
        ns.Print(("Your expedition to %s found the %s! %s"):format(report.zone.name, report.relic.name, report.relic.text))
    elseif report.rank then
        local z = report.zone
        UI.Toast(("%s: rank %d"):format(z.relic.name, report.rank), G.DescribeBonus(z.relic.kind, G.RelicValue(z)), z.relic.icon)
    elseif report.depth then
        UI.Toast(("%s: depth %d"):format(ns.DEEP.name, report.depth), ("+%s, and all mining is now +%d%% from the Deep."):format(G.Gold(report.gold), G.DeepPercent()), ns.DEEP.icon)
    else
        UI.Toast(report.zone.name, "Your expedition is home with " .. G.Gold(report.gold) .. ".", "Interface\\Icons\\INV_Misc_Map_01")
    end
end


-- You page: what your real characters bring --------------------------------------------

local function classColour(class)
    local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
    if c then return ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
    return hex(C.text)
end

function UI.BuildYou(page)
    page.head = Text(page, 14, C.accent, TITLE)
    page.head:SetPoint("TOPLEFT", 2, -4)
    page.cards = {}
    local cards = {
        { "warband", "Interface\\Icons\\INV_Misc_Head_Human_01", "Warband" },
        { "patron", "Interface\\Icons\\INV_Misc_Coin_01", "Patronage" },
        { "field", "Interface\\Icons\\Trade_Mining", "Field work" },
    }
    for i, c in ipairs(cards) do
        local card = CreateFrame("Frame", nil, page)
        card:SetPoint("TOPLEFT", 0, -28 - (i - 1) * 46)
        card:SetPoint("RIGHT")
        card:SetHeight(42)
        Fill(card, C.panel)
        card.icon = Icon(card, 34, c[2])
        card.icon:SetPoint("LEFT", 4, 0)
        card.title = Text(card, 13, C.text)
        card.title:SetPoint("TOPLEFT", 46, -5)
        card.info = Text(card, 11, C.muted)
        card.info:SetPoint("BOTTOMLEFT", 46, 6)
        card.info:SetPoint("RIGHT", -8, 0)
        card.bonus = Text(card, 16, C.accent, TITLE)
        card.bonus:SetPoint("TOPRIGHT", -8, -5)
        card.label = c[3]
        page.cards[c[1]] = card
    end
    page.rest = Text(page, 12, C.text)
    page.rest:SetPoint("TOPLEFT", 2, -170)
    page.rest:SetPoint("RIGHT", -2, 0)
    local ch = Text(page, 13, C.muted)
    ch:SetPoint("TOPLEFT", 2, -196)
    ch:SetText("Characters")
    page.chars = Text(page, 12, C.text)
    page.chars:SetPoint("TOPLEFT", 2, -214)
    page.chars:SetWidth(230)
    page.chars:SetSpacing(2)
    local sh = Text(page, 13, C.muted)
    sh:SetPoint("TOPLEFT", 240, -196)
    sh:SetText("Real-life bonuses")
    page.perks = Text(page, 12, C.text)
    page.perks:SetPoint("TOPLEFT", 240, -214)
    page.perks:SetPoint("RIGHT", -2, 0)
    page.perks:SetSpacing(2)
end

local function pct(f) return ("+%d%%"):format(math.floor(f * 100 + 0.5)) end

function refreshYou(page)
    local db = G.db
    page.head:SetText(("Your real characters add %s to all mining"):format(pct(G.CharacterBonus())))
    local wb, levels = G.Warband()
    local count = 0
    for _ in pairs(db.chars) do count = count + 1 end
    local cards = page.cards
    cards.warband.title:SetText("Warband")
    cards.warband.bonus:SetText(pct(wb))
    cards.warband.info:SetText(("%d levels across %d character%s. Every level on every character adds 0.5%%."):format(levels, count, count == 1 and "" or "s"))
    local pb, gold = G.Patronage()
    cards.patron.title:SetText("Patronage")
    cards.patron.bonus:SetText(pct(pb))
    cards.patron.info:SetText(("Your characters' richest-ever wallets add up to %dg. Each real gold adds 1%%, up to +100%%."):format(gold))
    local fb, ore = G.FieldWork()
    cards.field.title:SetText("Field work")
    cards.field.bonus:SetText(pct(fb))
    cards.field.info:SetText(("%d real ore looted. Every 10 adds 1%%, up to +100%%, and each one pays 20 seconds of mining."):format(ore))

    local resting = IsResting and IsResting()
    page.rest:SetText(resting and paint(GOOD, "You're rested. Log out here and your crew works a full 8-hour shift, then half pace up to 36 hours.")
        or paint(MUTED, "Not rested. Logging out here gets an 8-hour shift at half pace. Find an inn or a city for a full one."))

    local list = {}
    for key, c in pairs(db.chars) do list[#list + 1] = c end
    table.sort(list, function(a, b) return (a.level or 0) > (b.level or 0) end)
    local lines = {}
    for i = 1, math.min(8, #list) do
        local c = list[i]
        lines[#lines + 1] = ("%s  %s  %s"):format(paint(classColour(c.class), c.name or "?"), paint(MUTED, "lvl " .. (c.level or "?")), paint(MUTED, math.floor((c.peak or 0) / 10000) .. "g"))
    end
    if #list > 8 then lines[#lines + 1] = paint(MUTED, ("and %d more"):format(#list - 8)) end
    page.chars:SetText(table.concat(lines, "\n"))

    local scouted = 0
    for _, z in ipairs(ns.ZONES) do if G.Scouted(z) then scouted = scouted + 1 end end
    local st = db.stats
    local hearthReady = G.Now() - (db.lastHearth or 0) >= ns.HEARTH_COOLDOWN
    page.perks:SetText(table.concat({
        ("Scouted %d of %d expedition zones"):format(scouted, #ns.ZONES),
        ("Level-ups: %d (10 minutes of mining each)"):format(st.dings),
        ("Quests: %d (30 seconds each)"):format(st.quests or 0),
        ("Hearthstones: %d (5 minutes, %s)"):format(st.realHearths or 0, hearthReady and paint(GOOD, "ready") or paint(MUTED, "resting")),
        db.settings.bonuses and "" or paint(BAD, "Bonuses are off (Renown page)."),
    }, "\n"))
end

-- Refresh ---------------------------------------------------------------------------------

local slow = 0
function UI.Refresh(force)
    if not frame or not frame:IsShown() then return end
    frame.gold:SetText(G.Gold(G.db.gold))
    local gps = G.GPS()
    frame.gps:SetText((G.Frenzy() and paint(ACCENT, "x" .. ns.FRENZY_MULT .. " ") or "") .. G.Short(gps) .. " a second")
    local vein = G.Vein()
    frame.vein.icon:SetTexture(vein.icon)
    frame.veinName:SetText(vein.name)
    frame.subtitle:SetText(paint(G.Standing().colour, G.Standing().name) .. paint(MUTED, ("  ·  Renown %d"):format(G.db.renown)))
    local e = G.db.expedition
    if G.Frenzy() then
        frame.status:SetText(paint(ACCENT, ("Battle Shout: %ds"):format(G.db.frenzyEnds - G.Now())))
    elseif e and G.ZoneFor(e.zone, e.depth) then
        frame.status:SetText(("%s: %s left"):format(G.ZoneFor(e.zone, e.depth).name, G.Duration(e.ends - G.Now())))
    else
        frame.status:SetText("Click the vein to mine.")
    end
    courierTick()
    if G.db.compact then
        local h = UI.BestHire()
        if h then
            local cost = G.Cost(h, 1)
            frame.quick.label:SetText(("Hire %s  %s"):format(h.name, G.Gold(cost)))
            frame.quick.label:SetTextColor(unpack(G.db.gold >= cost and C.text or C.danger))
        end
        return
    end
    -- Pages with many rows refresh twice a second unless something changed.
    slow = slow + 1
    if not force and slow % 2 == 1 then return end
    local tab = G.db.tab
    if tab == "hire" then refreshHire(pages.hire)
    elseif tab == "upgrades" then refreshUpgrades(pages.upgrades)
    elseif tab == "expeditions" then refreshExpeditions(pages.expeditions)
    elseif tab == "renown" then refreshRenown(pages.renown)
    elseif tab == "you" then refreshYou(pages.you) end
end
