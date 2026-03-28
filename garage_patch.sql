-- ============================================================
--  d4rk_emergency — Garage System SQL Patch
--  Add to existing d4rk_emergency.sql or run separately
-- ============================================================

-- Fleet: how many of each vehicle type exist per department
CREATE TABLE IF NOT EXISTS `d4rk_emergency_fleet` (
  `id`        INT          NOT NULL AUTO_INCREMENT,
  `dept_key`  VARCHAR(50)  NOT NULL,
  `model`     VARCHAR(50)  NOT NULL,
  `available` INT          NOT NULL DEFAULT 0,
  `max_count` INT          NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dept_model` (`dept_key`, `model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Active vehicles: currently spawned vehicles with their plates
CREATE TABLE IF NOT EXISTS `d4rk_emergency_active_vehicles` (
  `id`         INT         NOT NULL AUTO_INCREMENT,
  `dept_key`   VARCHAR(50) NOT NULL,
  `model`      VARCHAR(50) NOT NULL,
  `plate`      VARCHAR(8)  NOT NULL,
  `identifier` VARCHAR(50) NOT NULL,
  `spawned_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_plate` (`plate`),
  INDEX `idx_dept` (`dept_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;