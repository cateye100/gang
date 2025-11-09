CREATE TABLE IF NOT EXISTS `ct_gang_territory_owners` (
  `territory_key` varchar(100) PRIMARY KEY,
  `owner` varchar(50),
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
