-- ct-gang.sql
-- Skapa tabell för att spara spelares gäng och rank
CREATE TABLE IF NOT EXISTS `ct_gang_members` (
  `citizenid` varchar(50) NOT NULL,
  `gang` varchar(50) NOT NULL,
  `rank` int NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Exempel: manuellt sätta en spelare
-- INSERT INTO ct_gang_members (citizenid, gang, rank) VALUES ('ABC12345', 'lostmc', 2)
--   ON DUPLICATE KEY UPDATE gang=VALUES(gang), rank=VALUES(rank);
