-- Convert schema '/home/david/dev/EPPlication/script/../lib/EPPlication/../../db_upgrades/_source/deploy/30/001-auto.yml' to '/home/david/dev/EPPlication/script/../lib/EPPlication/../../db_upgrades/_source/deploy/31/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE step ADD COLUMN active boolean DEFAULT '1' NOT NULL;

;

COMMIT;

