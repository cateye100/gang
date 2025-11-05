-- ct-gang / config.lua
-- Här skapar du alla gäng och deras ranker.
-- OBS: Namnet (nyckeln) används av /gangset. Håll det i lowercase och utan mellanslag.

Config = Config or {}

Config.Gangs = {
    lostmc = {
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
