rm ./test.db
sqlite3 ./test.db < "$(dirname "$0")/schema.sql"
sqlite3 ./test.db <<'__END__'
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Zebra", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Plains_Zebra_Equus_quagga.jpg/220px-Plains_Zebra_Equus_quagga.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Hyena", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/Crocuta_crocuta.jpg/1920px-Crocuta_crocuta.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Antilope", 1500, "https://encrypted-tbn3.gstatic.com/images?q=tbn:ANd9GcSgaYz-FzBEpQ1OM6ssUOs5bvDxfsvKdAK5V_Xx8_god-h-1Mcq");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Hippo", 1500, "https://www.earth.com/assets/_next/image/?url=https%3A%2F%2Fcff2.earth.com%2Fuploads%2F2022%2F12%2F28121822%2FHippopotamus3-1400x850.jpg&w=1200&q=75");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Lion", 1500, "https://media.4-paws.org/4/8/1/f/481f70cd4954eda750cb5777999bbad6dab732a3/VIER%20PFOTEN_2012-05-15_002%20%281%29-1927x1333-1920x1328.webp");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Elephant", 1500, "https://upload.wikimedia.org/wikipedia/commons/3/37/African_Bush_Elephant.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Tiger", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Tiger_Zoo_Vienna.jpg/640px-Tiger_Zoo_Vienna.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Giraffe", 1500, "https://www.thesafaricollection.com/?seraph_accel_gci=wp-content%2Fuploads%2F2022%2F07%2FThe-Safari-Collection-Hey-You-Giraffe-Manor.jpg&n=PcIJAVhfeobPIgu22WiXg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Panda", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Grosser_Panda.JPG/640px-Grosser_Panda.JPG");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Kangaroo", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/Kangaroo_Australia_01_11_2008_-_retouch.JPG/1920px-Kangaroo_Australia_01_11_2008_-_retouch.JPG");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Penguin", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Aptenodytes_forsteri_-Snow_Hill_Island%2C_Antarctica_-adults_and_juvenile-8.jpg/800px-Aptenodytes_forsteri_-Snow_Hill_Island%2C_Antarctica_-adults_and_juvenile-8.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Bald Eagle", 1500, "https://upload.wikimedia.org/wikipedia/commons/d/db/Bald_eagle_about_to_fly_in_Alaska_%282016%29.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Dolphin", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Tursiops_truncatus_01.jpg/1920px-Tursiops_truncatus_01.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Great White Shark", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9c/Great_white_shark_Dyer_Island.jpg/1920px-Great_white_shark_Dyer_Island.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Grizzly Bear", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/GrizzlyBearJeanBeaufort.jpg/1280px-GrizzlyBearJeanBeaufort.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Wolf", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Eurasian_wolf_2.jpg/1280px-Eurasian_wolf_2.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Cheetah", 1500, "https://upload.wikimedia.org/wikipedia/commons/7/75/Acinonyx_jubatus_Sabi_Sand.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Gorilla", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Western_Lowland_Gorilla_%28192%29.jpg/1920px-Western_Lowland_Gorilla_%28192%29.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Polar Bear", 1500, "https://upload.wikimedia.org/wikipedia/commons/6/66/Polar_Bear_-_Alaska_%28cropped%29.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Koala", 1500, "https://d1jyxxz9imt9yb.cloudfront.net/medialib/2188/image/p1300x1300/DR_2020-03-01_EastLismore-NSW-AU_Bushfires-FriendsOfTheKoala-KoalasInRehab_StaceyHedman-5D_0344_reduced.webp");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Leopard", 1500, "https://c02.purpledshub.com/uploads/sites/62/2024/01/leopard-facts.jpg?w=600&webp=1");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Rhinoceros", 1500, "https://upload.wikimedia.org/wikipedia/commons/6/69/Black_Rhino_at_Working_with_Wildlife.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Orca", 1500, "https://upload.wikimedia.org/wikipedia/commons/3/37/Killerwhales_jumping.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Crocodile", 1500, "https://c02.purpledshub.com/uploads/sites/62/2014/11/GettyImages-123529247-2a29d6c.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Human", 1500, "https://m.media-amazon.com/images/M/MV5BNTczMzk1MjU1MV5BMl5BanBnXkFtZTcwNDk2MzAyMg@@._V1_FMjpg_UX1000_.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Anaconda", 1500, "https://upload.wikimedia.org/wikipedia/commons/b/b4/Sucuri_verde.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "German Shepherd", 1500, "https://upload.wikimedia.org/wikipedia/commons/8/83/German_Shepherds_in_ravine.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Goat", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Nubian_Ibex_in_Negev.JPG/1280px-Nubian_Ibex_in_Negev.JPG");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Komodo Dragon", 1500, "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Komodo_dragon_%28Varanus_komodoensis%29.jpg/1280px-Komodo_dragon_%28Varanus_komodoensis%29.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Cobra", 1500, "https://www.naturesafariindia.com/wp-content/uploads/2023/10/King-cobra-in-Kaziranga-national-park-india.jpg");
INSERT INTO entries (group_id, name, rating, img) VALUES (4, "Cat", 1500, "https://www.vettimes.co.uk/app/uploads/2019/04/mieze-2314082-ftr.jpg");
__END__

