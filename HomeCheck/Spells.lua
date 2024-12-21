HomeCheck.spells = {
    -- PS
    [33206] = {
        cd = 120,
        class = "PRIEST",
        talentTab = 1,
        talentIndex = 22
    },
	-- Fear Ward
    [6346] = {
        cd = 180,
        class = "PRIEST"
    },
	-- Shadowfiend
    [34433] = {
        cd = 300,
        class = "PRIEST"
    },
	-- PI
    [37274] = {
        cd = 180,
        class = "PRIEST",
        talentTab = 1,
        talentIndex = 19
    },

    -- Blessing of Sacrifice
    [27148] = {
        cd = 30,
        class = "PALADIN"
    },
    -- BoF
    [1044] = {
        cd = 25,
        class = "PALADIN"
    },
	-- Divine Shield
    [1020] = {
        cd = 300,
        class = "PALADIN",
        tanksonly = true
    },
    -- BoP
    [10278] = {
        cd = 300,
        class = "PALADIN"
    },
	-- Avenging Wrath
    [31884] = {
        cd = 180,
        class = "PALADIN"
    },
    -- Divine Protection
    [498] = {
        cd = 180,
        class = "PALADIN",
        tanksonly = true
    },
    -- Lay on Hands
    [27154] = {
        cd = 1200,
        class = "PALADIN"
    },

	-- Holy Wrath
    [27139] = {
        cd = 60,
        class = "PALADIN",
        notarget = true
    },

	-- Divine Intervention
    [19752] = {
        cd = 3600,
        class = "PALADIN"
    },

    -- Rebirth
    [20484] = {
        cd = 1200,
        class = "DRUID"
    },
    -- Innervate
    [29166] = {
        cd = 360,
        class = "DRUID"
    },
	-- Barkskin
    [22812] = {
        cd = 60,
        class = "DRUID",
        tanksonly = true
    },

    -- Tranquility
    [26983] = {
        cd = 600,
        class = "DRUID",
        notarget = true
    },
    -- Frenzied Regeneration
    [26983] = {
        cd = 180,
        class = "DRUID",
        tanksonly = true
    },
	-- "Challenging Roar
    [5209] = {
        cd = 600,
        class = "DRUID",
        tanksonly = true
    },
    -- Misdirection initial cast
    [34477] = {
        cd = 30,
        class = "HUNTER",
        parent = 35079,
        noself = true
    },
    -- Misdirection
    [35079] = {
        cd = 120,
        class = "HUNTER",
        noself = true
    },
	-- Readiness
    [23989] = {
        cd = 180,
        class = "HUNTER",
        talentTab = 3,
        talentIndex = 23,
        notarget = true
    },
	-- Feign Death
    [5384] = {
        cd = 30,
        class = "HUNTER",
       -- talentTab = 2,
       -- talentIndex = 14,
        notarget = true
    },
	-- Tranquilizing Shot
    [19801] = {
        cd = 20,
        class = "HUNTER"
    },
	-- Silencing Shot
    [34490] = {
        cd = 20,
        class = "HUNTER"
    },
	
	-- kick
	
    [1766] = {
        cd = 10,
        class = "ROGUE"
    },

    -- Reincarnation
    --added for healing spec, Enh and ele will be a cd of 3600
    [21169] = {
        cd = 3600,
        class = "SHAMAN",
		talentTab = 3,
		talentIndex = 3,
		talentReduction = {600, 1200} -- Reduction values for 1 and 2 talent points
    },
    
    
    -- Mana Tide Totem
    [16190] = {
        cd = 300,
        class = "SHAMAN",
        talentTab = 3,
        talentIndex = 16
    },
    -- Heroism
    [32182] = {
        cd = 600,
        class = "SHAMAN"
    },
    -- Bloodlust
    [2825] = {
        cd = 600,
        class = "SHAMAN"
    },
    
    
    
    
    -- Stoneform
    [20594] = {
        cd = 180,
        race = "Dwarf",
        tanksonly = true
    },
    
    
    
    -- Ice Block
    [45438] = {
        cd = 300,
        class = "MAGE"
    },
    
    -- Invisibility
    [66] = {
        cd = 180,
        class = "MAGE"
    },
	-- Counterspell
    [2139] = {
        cd = 24,
        class = "MAGE"
    },
    -- Evocation
    [12051] = {
        cd = 240,
        class = "MAGE"
    },
	
    -- Shield Wall
    [871] = {
        cd = 180,
        class = "WARRIOR",
        tanksonly = true
    },
	-- Challenging Shout
    [1161] = {
        cd = 600,
        class = "WARRIOR",
        tanksonly = true
    },
    -- Last Stand
    [12975] = {
        cd = 480,
        class = "WARRIOR",
        talentTab = 3,
        talentIndex = 6,
        tanksonly = true
    },
    
    -- Death Wish
    [12292] = {
        cd = 180,
        class = "WARRIOR",
        talentTab = 1,
        talentIndex = 13
    },   
    -- Disarm
    [676] = {
        cd = 60,
        class = "WARRIOR"
    },
	-- Pummel
    [6554] = {
        cd = 10,
        class = "WARRIOR"
    },
	
    -- Soulstone Resurrection buff
    [27238] = {
        cd = 1800,
        class = "WARLOCK"
    },
	-- Soulshatter
    [29858] = {
        cd = 300,
        class = "WARLOCK"
    },
}
