CREATE TABLE entries (
  group_id INTEGER,
  name TEXT NOT NULL,
  img TEXT,
  rating INTEGER DEFAULT 1500,
  matches INTEGER DEFAULT 0,
  img_pos TEXT DEFAULT NULL
);
CREATE INDEX IX_entries ON entries (group_id);

