-- Convert schema '/home/dt/dev/repo/EPPlication/script/../lib/EPPlication/../../db_upgrades/_source/deploy/8/001-auto.yml' to '/home/dt/dev/repo/EPPlication/script/../lib/EPPlication/../../db_upgrades/_source/deploy/9/001-auto.yml':;

;
BEGIN;

;
CREATE INDEX step_idx_type on step (type);

;

COMMIT;

