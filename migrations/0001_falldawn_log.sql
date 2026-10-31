-- FallDawn permanent log (2026-10-31). Access events and AI questions.
CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  at TEXT NOT NULL,            -- ISO-8601 UTC
  event TEXT NOT NULL,         -- login_ok | login_fail | view_app | view_login | logout | ask | ask_refused
  ip TEXT, country TEXT, region TEXT, city TEXT, org TEXT, asn INTEGER, ua TEXT,
  detail TEXT                  -- JSON: username tried on login_fail, etc.
);
CREATE INDEX events_at ON events(at);
CREATE INDEX events_ip ON events(ip);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  at TEXT NOT NULL,
  ip TEXT,
  question TEXT NOT NULL,
  answer TEXT,
  status TEXT NOT NULL,        -- ok | refused | error | capped
  model TEXT,
  input_tokens INTEGER, cache_read_tokens INTEGER, cache_write_tokens INTEGER, output_tokens INTEGER,
  cost_usd REAL
);
CREATE INDEX questions_at ON questions(at);
