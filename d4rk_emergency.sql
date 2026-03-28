-- d4rk_emergency — Database Schema
-- Run once, then let the resource seed from Config.Departments

CREATE TABLE IF NOT EXISTS `d4rk_emergency_departments` (
  `dept_key`    VARCHAR(50)   NOT NULL,
  `label`       VARCHAR(100)  NOT NULL,
  `short_label` VARCHAR(20)   NOT NULL,
  `job_name`    VARCHAR(50)   NOT NULL,
  `color`       VARCHAR(10)   NOT NULL DEFAULT '#FFFFFF',
  `config_json` LONGTEXT      NOT NULL COMMENT 'zones, grades, armory, vehicles as plain JSON',
  `updated_at`  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`dept_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional duty log (unchanged from v1.0)
CREATE TABLE IF NOT EXISTS `emergency_duty_log` (
  `id`         INT          NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(50)  NOT NULL,
  `department` VARCHAR(20)  NOT NULL,
  `grade`      INT          NOT NULL DEFAULT 0,
  `action`     ENUM('on','off') NOT NULL,
  `timestamp`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
