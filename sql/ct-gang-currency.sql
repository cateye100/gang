-- ct_gang_currency.sql
-- Gang-kassa (alla zoner bidrar till samma kassa per gäng)
CREATE TABLE IF NOT EXISTS `ct_gang_currency` (
  `gang` varchar(60) PRIMARY KEY,
  `balance` int NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- History över köp (för revision)
CREATE TABLE IF NOT EXISTS `ct_gang_purchases` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `gang` VARCHAR(60) NOT NULL,
  `citizenid` VARCHAR(64) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `price` INT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
