-- Team Radio game data (D1, binding DB). Everything players write lives
-- here: one row per player, updated in a single statement, so two players
-- saving at the same moment never overwrite each other, and nothing expires.
-- Apply: npx wrangler d1 execute teamradio --remote --file schema.sql

-- Weekly arcade boards, kept forever (week = the Monday, UTC).
-- Lights Out: lowest ms wins. Reaction Wall: highest score wins.
CREATE TABLE IF NOT EXISTS reaction (
  env TEXT NOT NULL, week TEXT NOT NULL, user TEXT NOT NULL,
  name TEXT NOT NULL, ms INTEGER NOT NULL, at INTEGER NOT NULL,
  PRIMARY KEY (env, week, user)
);
CREATE TABLE IF NOT EXISTS wall (
  env TEXT NOT NULL, week TEXT NOT NULL, user TEXT NOT NULL,
  name TEXT NOT NULL, score INTEGER NOT NULL, at INTEGER NOT NULL,
  PRIMARY KEY (env, week, user)
);

-- All-time personal bests ("lights" in ms, lower is better; "wall" in
-- points, higher is better), so a new phone or a reinstall keeps them.
CREATE TABLE IF NOT EXISTS best (
  env TEXT NOT NULL, game TEXT NOT NULL, user TEXT NOT NULL,
  name TEXT NOT NULL, value INTEGER NOT NULL, at INTEGER NOT NULL,
  PRIMARY KEY (env, game, user)
);

-- Private leagues and their members.
CREATE TABLE IF NOT EXISTS league (
  env TEXT NOT NULL, code TEXT NOT NULL, title TEXT NOT NULL,
  owner TEXT NOT NULL, created_at INTEGER NOT NULL,
  PRIMARY KEY (env, code)
);
CREATE TABLE IF NOT EXISTS league_member (
  env TEXT NOT NULL, code TEXT NOT NULL, user TEXT NOT NULL,
  name TEXT NOT NULL, joined_at INTEGER NOT NULL,
  PRIMARY KEY (env, code, user)
);

-- Daily submission counters (anti-spam); rows older than a few days are
-- the only thing ever cleared.
CREATE TABLE IF NOT EXISTS rate (
  day TEXT NOT NULL, kind TEXT NOT NULL, user TEXT NOT NULL, n INTEGER NOT NULL,
  PRIMARY KEY (day, kind, user)
);

-- Nightly copy of the game data kept in KV (round and season tables, the
-- AI Strategist's picks, vote tallies), so D1's point-in-time restore
-- covers it too.
CREATE TABLE IF NOT EXISTS kv_backup (
  key TEXT PRIMARY KEY, value TEXT NOT NULL, updated INTEGER NOT NULL
);
