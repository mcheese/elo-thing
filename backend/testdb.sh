rm ./test.db
sqlite3 ./test.db < "$(dirname "$0")/schema.sql"
sqlite3 ./test.db <<'__END__'
INSERT INTO entries (group_id, name, rating) VALUES (4, "Elephant", 1530);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Zebra", 1450);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Giraffe", 1590);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Rino", 1550);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Tiger", 1480);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Lion", 1488);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Hyena", 1500);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Antilope", 1399);
INSERT INTO entries (group_id, name, rating) VALUES (4, "Hippo", 1500);
__END__

