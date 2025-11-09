-- ct-gang / config.lua
-- Här skapar du alla gäng och deras ranker.
-- OBS: Namnet (nyckeln) används av /gangset. Håll det i lowercase och utan mellanslag.

Config = Config or {}

Config.Gangs = {
    lostmc = {
        color = { 255, 255, 255 },
        label = "Lost MC",
        grades = {
            [0] = { label = "Member" },
            [1] = { label = "Enforcer" },
            [2] = { label = "Lieutenant" },
            [3] = { label = "Underboss" },
            [4] = { label = "Boss" },
        }
    },
    ballas = {
        label = "Ballas",
        grades = {
            [0] = { label = "Member" },
            [1] = { label = "Shooter" },
            [2] = { label = "OG" },
            [3] = { label = "Shotcaller" },
            [4] = { label = "Boss" },
        }
    },
    vagos = {
        label = "Vagos",
        grades = {
            [0] = { label = "Member" },
            [1] = { label = "Soldado" },
            [2] = { label = "Teniente" },
            [3] = { label = "Jefe" },
            [4] = { label = "El Patron" },
        }
    }
}

-- Vem får använda /gangset?
-- 'qb' = använd qb-core permissions (admin/god), 'ace' = använd ACE (command.gangset), 'all' = alla
Config.PermissionMode = 'qb'  -- 'qb' | 'ace' | 'all'

-- Hur ofta ska servern läsa från SQL och synka spelarnas gäng?
Config.SyncIntervalSeconds = 60  -- sekunder

Config.Territories = Config.Territories or {}

-- Teritorium Hamnen (world coords)
table.insert(Config.Territories, {
    label = "Hamnen",
    polygon_world = {
        vector2(-504.66, -2941.43), vector2(-508.5, -2942.44), vector2(-512.27, -2941.76),
        vector2(-515.95, -2938.54), vector2(-571.79, -2818.43), vector2(-526.44, -2772.78),
        vector2(-493.84, -2805.25), vector2(-448.32, -2759.07), vector2(-390.88, -2758.78),
        vector2(-368.28, -2781.3),   vector2(-368.21, -2792.61), vector2(-356.2,  -2805.0),
        vector2(-412.98, -2862.43),  vector2(-425.5,  -2862.9),  vector2(-501.34, -2938.78),
        vector2(-504.5,  -2941.28)
    },
    fill = "rgba(255, 255, 255, 0.10)",
    stroke = "rgba(255, 255, 255, 0.85)",
    stroke_width = 2
})

Config.Gangs.ballas = {
        color = { 142, 0, 201 },
    label = 'Ballas',
}

Config.Gangs.vagos = {
        color = { 255, 209, 26 },
    label = 'Vagos',
}

Config.Gangs.families = {
        color = { 0, 190, 0 },
    label = 'Families',
}

Config.Gangs.lostmc = {
        color = { 220, 220, 220 },
    label = 'Lostmc',
}

Config.Gangs.triads = {
        color = { 200, 30, 30 },
    label = 'Triads',
}

Config.Gangs.mafia = {
        color = { 20, 20, 20 },
    label = 'Mafia',
}

Config.Gangs.cartel = {
        color = { 0, 120, 180 },
    label = 'Cartel',
}

Config.Gangs.bloods = {
        color = { 180, 0, 0 },
    label = 'Bloods',
}

Config.Gangs.crips = {
        color = { 0, 60, 200 },
    label = 'Crips',
}
