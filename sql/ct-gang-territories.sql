CREATE TABLE IF NOT EXISTS `ct_gang_territories` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `gang` VARCHAR(64) NULL,
  `owner_citizenid` VARCHAR(64) NULL,
  `owner_identifier` VARCHAR(100) NULL,
  `label` VARCHAR(120) NULL,
  `polygon_pixels` JSON NOT NULL,
  `polygon_world` JSON NULL,
  `fill` VARCHAR(32) DEFAULT 'rgba(0,255,0,0.15)',
  `stroke` VARCHAR(32) DEFAULT 'rgba(0,255,0,0.9)',
  `stroke_width` INT DEFAULT 2,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;