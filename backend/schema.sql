CREATE TABLE entries (
  group_id INTEGER,
  name TEXT NOT NULL,
  img TEXT,
  rating INTEGER,
  matches INTEGER DEFAULT 0
);
CREATE INDEX IX_entries ON entries (group_id);

