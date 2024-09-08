CREATE TABLE entries (
  group_id INTEGER,
  name TEXT NOT NULL,
  rating INTEGER
);
CREATE INDEX idx_entries_group ON entries (group_id);

