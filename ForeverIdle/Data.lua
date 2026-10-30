-- Everything you can hire, buy and explore. Numbers live here so balancing
-- is a matter of editing tables, not code. Icons are the game's own, by path.

local _, ns = ...

local I = "Interface\\Icons\\"

-- Hirelings: cost grows by GROWTH for each one you own.
ns.GROWTH = 1.14

ns.HIRELINGS = {
    { id = "peasant", name = "Peasant Prospector", icon = I .. "Trade_Mining", cost = 12, gps = 0.15,
      text = "Swings a pick in the Jasperlode Mine for a copper a day and a warm meal." },
    { id = "kobold", name = "Kobold Tunneler", icon = I .. "Spell_Fire_Fire", cost = 110, gps = 1,
      text = "You no take candle. Kobold take ore, give you half. Fair deal." },
    { id = "dwarf", name = "Ironforge Delver", icon = I .. "Trade_BlackSmithing", cost = 1000, gps = 6,
      text = "Has been digging since before the Third War and sees no reason to stop." },
    { id = "gnome", name = "Gnomish Ore-Sorter", icon = I .. "Trade_Engineering", cost = 9500, gps = 36,
      text = "Sorts ore at tremendous speed. Explodes slightly less than the last model." },
    { id = "shredder", name = "Goblin Shredder", icon = I .. "INV_Misc_Gear_01", cost = 95000, gps = 210,
      text = "Time is money, friend, and this thing is very fast." },
    { id = "kodo", name = "Kodo Caravan", icon = I .. "Ability_Mount_Kodo_01", cost = 1.0e6, gps = 1250,
      text = "Hauls ore across the Barrens. Mind the centaur." },
    { id = "auction", name = "Auction House Flipper", icon = I .. "INV_Misc_Coin_02", cost = 1.1e7, gps = 7500,
      text = "Buys every Copper Bar under vendor price and relists at 400%." },
    { id = "alchemist", name = "Arcanite Transmuter", icon = I .. "Trade_Alchemy", cost = 1.3e8, gps = 46000,
      text = "Turns thorium into arcanite, and arcanite into a lot of gold." },
    { id = "fleet", name = "Steamwheedle Fleet", icon = I .. "INV_Misc_Map_01", cost = 1.6e9, gps = 290000,
      text = "Ships your ore from Booty Bay to every port that pays." },
    { id = "hoard", name = "Dragon Hoard Lease", icon = I .. "INV_Misc_Head_Dragon_01", cost = 2.1e10, gps = 1.9e6,
      text = "The dragon is asleep. Probably. Lease is month to month." },
}

-- Each hireling gets five upgrades, each doubling that hireling's output.
-- They unlock at these head counts and cost the hireling's base cost times
-- the matching multiplier.
ns.TIER_AT = { 10, 25, 50, 100, 200 }
ns.TIER_COST = { 15, 150, 2500, 60000, 3e10 }
ns.TIER_NAMES = {
    peasant = { "Sturdier Picks", "Miner's Lamp", "Union of Prospectors", "Stormwind Mining Charter", "Lord of the Jasperlode" },
    kobold = { "Bigger Candles", "Two Candles Each", "Kobold Overseer", "Candle Wax Futures", "Kobold King's Blessing" },
    dwarf = { "Thunderbrew Rations", "Explorers' League Maps", "Deeprun Shortcut", "Ironforge Council Grant", "Bronzebeard Seal" },
    gnome = { "Calibrated Cogs", "Fewer Explosions", "Mechanostrider Couriers", "Tinker Town Patent", "Ultrasafe Personnel Launcher" },
    shredder = { "Overclocked Saw", "Extra Fuel Tank", "Shredder Pilot Union", "Trade Prince Approval", "Shredder Mk. Infinity" },
    kodo = { "Saddlebags", "Bigger Kodos", "Crossroads Waystation", "Thunder Bluff Contract", "Great Kodo Migration" },
    auction = { "Lower Deposit", "Undercut by One Copper", "Neutral Auction House", "Cornered Market", "Every Auction House at Once" },
    alchemist = { "Philosopher's Stone", "Transmute Mastery", "Alchemist's Lab", "Elixir of Greed", "Transmute: Gold" },
    fleet = { "Faster Sails", "Cannon Escort", "Ratchet Harbour", "Gadgetzan Trade Pact", "Blackwater Raider Truce" },
    hoard = { "Quieter Footsteps", "Longer Lease", "Dragonkin Accountant", "Sleeping Draught", "Dragonflight Accord" },
}

-- Upgrades that aren't tied to one hireling. kind: click (+% to the base
-- click), clickgps (each click also gives this fraction of your gold per
-- second), gps (+% to everything).
ns.GLOBAL_UPGRADES = {
    { id = "pick", name = "Sharpened Pick", icon = I .. "INV_Pick_02", cost = 75, kind = "click", value = 1,
      text = "Clicks mine twice as much." },
    { id = "mining75", name = "Journeyman Mining", icon = I .. "Trade_Mining", cost = 2500, kind = "clickgps", value = 0.03, need = 10,
      text = "Each click also mines 3% of your gold per second." },
    { id = "charter", name = "Guild Charter", icon = I .. "INV_Misc_Note_01", cost = 25000, kind = "gps", value = 0.10, need = 25,
      text = "Your crew works as a guild. +10% to all mining." },
    { id = "mining150", name = "Expert Mining", icon = I .. "Trade_Mining", cost = 4e5, kind = "clickgps", value = 0.03, need = 50,
      text = "Each click mines another 3% of your gold per second." },
    { id = "tabard", name = "Guild Tabard", icon = I .. "INV_Shirt_GuildTabard_01", cost = 5e6, kind = "gps", value = 0.15, need = 80,
      text = "Matching tabards. Morale soars. +15% to all mining." },
    { id = "mining225", name = "Artisan Mining", icon = I .. "Trade_Mining", cost = 2e8, kind = "clickgps", value = 0.04, need = 120,
      text = "Each click mines another 4% of your gold per second." },
    { id = "guildbank", name = "Guild Bank", icon = I .. "INV_Misc_Bag_10", cost = 5e9, kind = "gps", value = 0.25, need = 160,
      text = "Somewhere safe to keep it all. +25% to all mining." },
    { id = "mining300", name = "Master Miner", icon = I .. "Trade_Mining", cost = 4e11, kind = "clickgps", value = 0.05, need = 220,
      text = "Each click mines another 5% of your gold per second." },
}

-- The vein you click changes as your empire grows (by lifetime gold).
ns.VEINS = {
    { at = 0, name = "Copper Vein", icon = I .. "INV_Ore_Copper_01" },
    { at = 1e3, name = "Tin Vein", icon = I .. "INV_Ore_Tin_01" },
    { at = 3e4, name = "Iron Deposit", icon = I .. "INV_Ore_Iron_01" },
    { at = 1e6, name = "Mithril Deposit", icon = I .. "INV_Ore_Mithril_02" },
    { at = 5e7, name = "Truesilver Deposit", icon = I .. "INV_Ore_TrueSilver_01" },
    { at = 2e9, name = "Rich Thorium Vein", icon = I .. "INV_Ore_Thorium_02" },
    { at = 1e11, name = "Arcanite Lode", icon = I .. "INV_Misc_StoneTablet_05" },
}

-- Expeditions: one at a time. need = hirelings you must own, minutes = how
-- long it takes, cost = supplies paid up front. The first clear of each
-- zone brings home its relic; later runs bring gold.
-- Relic kinds: gps (+% to everything), click (+% to the base click),
-- discount (hirelings cost % less), offline (+hours of full-pace offline mining),
-- haste (expeditions take % less time).
ns.ZONES = {
    { id = "elwynn", name = "Elwynn Forest", need = 5, minutes = 2, cost = 40,
      relic = { name = "Hogger's Collar", icon = I .. "INV_Jewelry_Necklace_01", kind = "click", value = 1,
                text = "Clicks mine twice as much again." } },
    { id = "westfall", name = "Westfall", need = 15, minutes = 5, cost = 600,
      relic = { name = "Defias Bandana", icon = I .. "INV_Misc_Bandana_03", kind = "gps", value = 0.10,
                text = "+10% to all mining." } },
    { id = "redridge", name = "Redridge Mountains", need = 25, minutes = 10, cost = 7000,
      relic = { name = "Gnoll War Banner", icon = I .. "INV_BannerPVP_02", kind = "discount", value = 0.05,
                text = "Hirelings cost 5% less." } },
    { id = "duskwood", name = "Duskwood", need = 40, minutes = 20, cost = 8e4,
      relic = { name = "Night Watch Lantern", icon = I .. "INV_Misc_Lantern_01", kind = "offline", value = 4,
                text = "Your crew works at full pace 4 hours longer while you're away." } },
    { id = "stranglethorn", name = "Stranglethorn Vale", need = 60, minutes = 30, cost = 1e6,
      relic = { name = "Pirate's Doubloon", icon = I .. "INV_Misc_Coin_04", kind = "gps", value = 0.15,
                text = "+15% to all mining." } },
    { id = "badlands", name = "Badlands", need = 80, minutes = 45, cost = 1.2e7,
      relic = { name = "Uldaman Tablet", icon = I .. "INV_Misc_StoneTablet_01", kind = "haste", value = 0.15,
                text = "Expeditions take 15% less time." } },
    { id = "searing", name = "Searing Gorge", need = 100, minutes = 60, cost = 1.5e8,
      relic = { name = "Dark Iron Pick", icon = I .. "INV_Pick_03", kind = "click", value = 2,
                text = "+200% to your base click." } },
    { id = "steppes", name = "Burning Steppes", need = 125, minutes = 90, cost = 2e9,
      relic = { name = "Black Dragon Scale", icon = I .. "INV_Misc_MonsterScales_15", kind = "gps", value = 0.20,
                text = "+20% to all mining." } },
    { id = "wpl", name = "Western Plaguelands", need = 150, minutes = 120, cost = 3e10,
      relic = { name = "Skeleton Key", icon = I .. "INV_Misc_Key_11", kind = "offline", value = 6,
                text = "Your crew works at full pace 6 hours longer while you're away." } },
    { id = "epl", name = "Eastern Plaguelands", need = 180, minutes = 180, cost = 4e11,
      relic = { name = "Argent Dawn Commission", icon = I .. "INV_Misc_Ribbon_01", kind = "discount", value = 0.05,
                text = "Hirelings cost another 5% less." } },
    { id = "mc", name = "Molten Core", need = 220, minutes = 240, cost = 6e12,
      relic = { name = "Sulfuron Ingot", icon = I .. "INV_Ingot_08", kind = "gps", value = 0.30,
                text = "+30% to all mining." } },
    { id = "bwl", name = "Blackwing Lair", need = 260, minutes = 360, cost = 1e14,
      relic = { name = "Head of Nefarian", icon = I .. "INV_Misc_Head_Dragon_Black", kind = "haste", value = 0.15,
                text = "Expeditions take another 15% less time." } },
    { id = "naxx", name = "Naxxramas", need = 300, minutes = 480, cost = 2e15,
      relic = { name = "Frozen Rune", icon = I .. "INV_Misc_Rune_09", kind = "gps", value = 0.50,
                text = "+50% to all mining." } },
}

-- Renown: each point adds RENOWN_BONUS to everything. Standings are cosmetic.
ns.RENOWN_BONUS = 0.03
ns.RENOWN_DIVISOR = 1e6 -- renown for a run = cube root of (gold earned / this)
ns.STANDINGS = {
    { at = 0, name = "Neutral", colour = "ffff00" },
    { at = 5, name = "Friendly", colour = "00ff00" },
    { at = 25, name = "Honored", colour = "00ff88" },
    { at = 100, name = "Revered", colour = "00ffcc" },
    { at = 400, name = "Exalted", colour = "00ffff" },
}

-- Relic ranks: every clear after the first raises that zone's relic a rank,
-- up to RELIC_MAX_RANK. Each rank adds RELIC_RANK_BONUS of the relic's base
-- value again (so rank 5 is three times rank 1). Ranks are kept on Hearth.
ns.RELIC_MAX_RANK = 5
ns.RELIC_RANK_BONUS = 0.5

-- The Forever Deep: opens once Naxxramas is cleared and never runs out.
-- Each depth takes longer, costs more and needs more hirelings, and every
-- depth reached adds DEEP_BONUS to all mining for good (kept on Hearth).
ns.DEEP = {
    name = "The Forever Deep", icon = I .. "Spell_Shadow_ShadowWordPain",
    minutes = 120, minutesPerDepth = 30, maxMinutes = 720,
    cost = 5e15, costGrowth = 3,
    need = 300, needPerDepth = 10,
    bonus = 0.05,
}

-- Offline gains work like rested XP. Log out rested (an inn or a city) and
-- the crew works a full-pace shift, then carries on at half pace for the
-- rest of the long shift. Log out anywhere else and they work a half-pace
-- shift and then down tools.
ns.SHIFT_HOURS = 8          -- the full-pace shift (relics add to it)
ns.LONG_SHIFT_HOURS = 36    -- how long a rested crew keeps going in all
ns.OFFLINE_SLOW = 0.5

-- Real-game bonuses, in seconds of production.
ns.DING_SECONDS = 600
ns.QUEST_SECONDS = 30
ns.HEARTH_SECONDS = 300     -- casting your real Hearthstone
ns.HEARTH_COOLDOWN = 1800
ns.ORE_SECONDS = 20         -- each real ore you loot

-- Your real characters make the mine stronger. All are % to everything.
ns.WARBAND_PER_LEVEL = 0.005  -- each level of each character on the account
ns.PATRON_PER_GOLD = 0.01     -- each real gold of your richest-ever wallet...
ns.PATRON_CAP = 1.0           -- ...up to +100%
ns.ORE_PER_BONUS = 10         -- every 10 real ore looted...
ns.ORE_BONUS = 0.01           -- ...adds 1%...
ns.ORE_CAP = 1.0              -- ...up to +100%

-- Expeditions to a zone one of your characters has really been to.
ns.SCOUTED_TIME = 0.5       -- take half the time
ns.SCOUTED_GOLD = 2         -- and bring back twice the gold

-- Real ore, by item id.
ns.ORE_IDS = {
    [2770] = "Copper Ore", [2771] = "Tin Ore", [2775] = "Silver Ore", [2772] = "Iron Ore",
    [2776] = "Gold Ore", [3858] = "Mithril Ore", [7911] = "Truesilver Ore", [10620] = "Thorium Ore",
    [11370] = "Dark Iron Ore",
}

-- The lost courier: shows up now and then while the window is open.
ns.COURIER_MIN, ns.COURIER_MAX = 240, 540
ns.COURIER_LIFETIME = 13
ns.FRENZY_SECONDS, ns.FRENZY_MULT = 30, 3
