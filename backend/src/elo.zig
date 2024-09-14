const std = @import("std");
const sqlite = @import("sqlite");
const Alloc = std.mem.Allocator;

const Self = @This();

pub const EloError = error{
    NotFound,
    BadId,
    BadJson,
    AlreadyExists,
    NoResult,
    TooMany,
};

// in-mem saved per match
const Match = struct {
    l_rowid: i64,
    r_rowid: i64,
    timestamp: i64,
};

alloc: std.mem.Allocator,
db_options: sqlite.InitOptions,
db_pool: []sqlite.Db,
active_matches: std.AutoHashMap(u48, Match),
active_matches_mtx: std.Thread.Mutex,

const ThreadIndex = struct {
    var counter = std.atomic.Value(u32).init(0);
    threadlocal var index: ?u32 = null;
};

/// get thread specific sqlite.Db
fn db(self: *Self) *sqlite.Db {
    // static values

    if (ThreadIndex.index) |i| {
        return &self.db_pool[i];
    } else {
        const count = ThreadIndex.counter.fetchAdd(1, .monotonic);
        if (count >= self.db_pool.len) @panic("too many threads");
        ThreadIndex.index = count;
        self.db_pool[count] = sqlite.Db.init(self.db_options) catch {
            @panic("sqlite init failed");
        };
        _ = self.db_pool[count].pragma(void, .{}, "busy_timeout", "3000") catch { // mitigate most SQLITE_BUSY
            @panic("sqlite pragma failed");
        };
        return &self.db_pool[count];
    }
}

/// max_threads: maximum total number of different threads that will ever access the DB
pub fn init(alloc: std.mem.Allocator, db_path: []const u8, max_threads: u32) !Self {
    var this: Self = .{
        .alloc = alloc,
        .db_options = .{
            .mode = sqlite.Db.Mode{ .File = try alloc.dupeZ(u8, db_path) },
            .open_flags = .{
                .write = true,
                .create = true,
            },
            .threading_mode = .MultiThread,
        },
        .db_pool = try alloc.alloc(sqlite.Db, max_threads),
        .active_matches = std.AutoHashMap(u48, Match).init(alloc),
        .active_matches_mtx = std.Thread.Mutex{},
    };
    _ = db(&this); // ensure 1 initial init
    return this;
}

/// make sure no more threads are accessing the db before calling
pub fn deinit(self: *Self) void {
    // fails on starting another instance...
    for (0..ThreadIndex.counter.load(.monotonic)) |i|
        self.db_pool[i].deinit();
    self.alloc.free(self.db_pool);
    self.alloc.free(self.db_options.mode.File);
    self.active_matches.deinit();
}

/// delte a group
/// returns number of entries removed (0 if it didn't exist)
pub fn deleteGroup(self: *Self, sid: []const u8) !usize {
    const id = try idFromSid(sid);

    const query =
        \\DELETE FROM entries WHERE group_id = ?
    ;
    try self.db().exec(query, .{}, .{ .group_id = id });
    return self.db().rowsAffected();
}

const ImgPos = struct { x: i64, y: i64, width: i64, height: i64 };
const EntryCreate = struct { name: []const u8, img: []const u8 = "", img_pos: ?ImgPos = null };

/// create a group by json string, returns id
pub fn createGroup(self: *Self, json: []const u8) ![8]u8 {
    const id = Rand.get().int(u48);
    const sid = try sidFromId(id);

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    const parsed = try std.json.parseFromSliceLeaky(
        []EntryCreate,
        arena.allocator(),
        json,
        .{ .allocate = .alloc_if_needed },
    );
    if (parsed.len < 2) return error.BadJson;
    if (parsed.len > 256) return error.TooMany;

    var savepoint = try self.db().savepoint("addGroup");
    defer savepoint.rollback();

    // checking for existance seems pointless, it's a random 48 bit id
    // should only be possible if the rng is broken
    const count = try self.db().one(i64,
        \\SELECT count(*) FROM entries WHERE group_id = ?
    , .{}, .{ .group_id = id });
    if (count != 0) return error.AlreadyExists;

    {
        var stmt = try self.db().prepare(
            \\INSERT INTO entries (group_id, name, img, img_pos, rating) VALUES (?, ?, ?, ?, 1500)
        );
        defer stmt.deinit();
        for (parsed) |e| {
            stmt.reset();
            try stmt.exec(.{}, .{
                .group_id = id,
                .name = e.name,
                .img = e.img,
                .img_pos = if (e.img_pos) |img_pos| try std.json.stringifyAlloc(arena.allocator(), img_pos, .{}) else null,
            });
        }
    }
    savepoint.commit();

    return sid;
}

const EntryGet = struct { name: []const u8, rating: i64, img: []u8, img_pos: ?[]u8 };

/// get group json string
/// need to free() returned value
///
///     const grp = try elo.getGroup(sid);
///     defer elo.alloc.free(grp);
pub fn getGroup(self: *Self, sid: []const u8) ![]const u8 {
    // TODO: cache this

    const id = try idFromSid(sid);

    const query =
        \\SELECT name,rating,img,img_pos FROM entries WHERE group_id = ?
    ;
    var stmt = try self.db().prepare(query);
    defer stmt.deinit();

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    const data = try stmt.all(
        EntryGet,
        arena.allocator(),
        .{},
        .{ .group_id = id },
    );
    if (data.len == 0) return error.NotFound;

    return std.json.stringifyAlloc(self.alloc, data, .{});
}

const Rand = struct {
    threadlocal var rng: ?std.rand.DefaultPrng = null;
    fn get() std.rand.Random {
        if (rng == null) {
            rng = std.rand.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                std.posix.getrandom(std.mem.asBytes(&seed)) catch @panic("getrandom failed");
                break :blk seed;
            });
        }
        return rng.?.random();
    }
};

const EntryMatch = struct { rowid: i64, matches: i64, name: []u8, rating: i64, img: []u8, img_pos: ?[]u8 };

pub fn getMatch(self: *Self, sid: []const u8) ![]const u8 {
    // TODO: cache the fetch
    // TODO: limit this per user/session
    // TODO: cleanup unused active_matches

    const id = try idFromSid(sid);

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    //const full: []MatchmakingRow = blk: {
    //    // don't want to do the random selection in DB (supposedly expensive)
    //    // not selecting first N `ORDER BY matches` because I think there is unfairness
    //    // should keep cached groups at some point
    //    var stmt = try self.db().prepare(
    //        \\SELECT rowid,rating,matches
    //        \\FROM entries WHERE group_id = ?
    //    );
    //    defer stmt.deinit();
    //    break :blk try stmt.all(MatchmakingRow, arena.allocator(), .{}, .{ .group_id = id });
    //};
    //if (full.len < 2) return error.NotFound;
    //const preselect_size = 8;
    //const preselected = try preselect(full, preselect_size);

    const preselected: []const EntryMatch = blk: {
        // that's supposedly way more performant
        // https://stackoverflow.com/questions/4114940/select-random-rows-in-sqlite
        var stmt = try self.db().prepare(
            \\SELECT rowid,matches,name,rating,img,img_pos FROM entries WHERE rowid IN
            \\    (SELECT rowid FROM entries WHERE group_id = ? ORDER BY RANDOM() LIMIT 8)
        );
        defer stmt.deinit();
        break :blk try stmt.all(EntryMatch, arena.allocator(), .{}, .{ .group_id = id });
    };
    if (preselected.len < 2) return error.NotFound;

    const sel = try matchmake(preselected);

    const match_id = Rand.get().int(u48);
    const match_sid = try sidFromId(match_id);

    //const final_match = blk: {
    //    var stmt = try self.db().prepare(
    //        \\SELECT rowid,name,rating,img
    //        \\FROM entries WHERE rowid IN (?, ?)
    //    );
    //    defer stmt.deinit();
    //    break :blk try stmt.all(struct { rowid: i64, name: []u8, rating: i64, img: []u8 }, arena.allocator(), .{}, .{ selected[0].rowid, selected[1].rowid });
    //};
    //if (final_match.len < 2) return error.NotFound;

    // store match
    {
        self.active_matches_mtx.lock();
        defer self.active_matches_mtx.unlock();
        try self.active_matches.put(match_id, .{
            .l_rowid = sel[0].rowid,
            .r_rowid = sel[1].rowid,
            .timestamp = std.time.timestamp(),
        });
    }

    return std.json.stringifyAlloc(self.alloc, .{
        .match_id = match_sid,
        .l = .{
            .name = sel[0].name,
            .rating = sel[0].rating,
            .img = sel[0].img,
            .img_pos = if (sel[0].img_pos) |p| try std.json.parseFromSliceLeaky(ImgPos, arena.allocator(), p, .{}) else null,
        },
        .r = .{
            .name = sel[1].name,
            .rating = sel[1].rating,
            .img = sel[1].img,
            .img_pos = if (sel[1].img_pos) |p| try std.json.parseFromSliceLeaky(ImgPos, arena.allocator(), p, .{}) else null,
        },
    }, .{});
}

// no longer needed, doing it in SQL query
/// preselect random `n` rows
/// modifies `list`
//fn preselect(list: []MatchmakingRow, n: usize) ![]MatchmakingRow {
//    if (list.len <= n) return list;
//    const rng = try Rand.get();
//
//    if (list.len >= n * 2) {
//        // move n random lines to the top
//        // selecting random lines to be returned
//        for (0..n) |i| {
//            // random index from range [i+1, len)
//            const other = rng.uintLessThanBiased(usize, list.len - i - 1) + i + 1;
//            std.mem.swap(MatchmakingRow, &list[i], &list[other]);
//        }
//    } else {
//        // move len-n random lines to the bottom
//        // selecting random lines NOT to be returned
//        for (list.len..n) |i| {
//            // random index from range [0, i-1)
//            const other = rng.uintLessThanBiased(usize, i - 1);
//            std.mem.swap(MatchmakingRow, &list[i - 1], &list[other]);
//        }
//    }
//
//    return list[0..n];
//}

/// select a match
/// based on matches, close elo, randomness
/// modifies `list`
/// O(n^2) -> preselect the list
fn matchmake(list: []const EntryMatch) ![2]*const EntryMatch {
    if (list.len <= 2) return .{ &list[0], &list[1] };

    const rng = Rand.get();

    // algo calculates a [skill, matches, rng] score for every combo
    // score is normalized 0 to 100
    // scores multiplied with weight and summed for final score
    const skill_weight = 8;
    const matches_weight = 10;
    const random_weight = 10;

    const skill_K = 400; // rating diff where score becomes 0 (linear, goes below)
    const matches_K = 20; // extra matches where score becomes 0 (linear with floor)

    // find least amount of matches an entry has
    // subtract it later from every matches count
    var min_matches = list[0].matches;
    for (list) |*e| {
        if (min_matches > e.matches)
            min_matches = e.matches;
    }

    // for every combo calc a score and keep the 2 highest
    var canidates: [2]*const EntryMatch = undefined;
    var max_score: i64 = std.math.minInt(i64);

    //std.log.debug("i j    Sdif Mdif      S       M       R            S       M       R    SCORE", .{});

    for (0..list.len) |i| {
        for (i + 1..list.len) |j| {
            const skill_diff: i64 = @intCast(@abs(list[i].rating - list[j].rating));
            const extra_matches = (list[i].matches - min_matches) + (list[j].matches - min_matches);

            const skill_score = (100 - @divTrunc(skill_diff * 100, skill_K));
            const matches_score = if (extra_matches < matches_K) (100 - @divTrunc(extra_matches * 100, matches_K)) else 0;
            const random_score = rng.intRangeAtMostBiased(i64, 0, 100);

            const score = skill_score * skill_weight + matches_score * matches_weight + random_score * random_weight;
            if (score > max_score) {
                max_score = score;
                canidates = .{ &list[i], &list[j] };
            }

            //std.log.debug("{}-{} | {:4}S {:3}M | {:4}*{:2} {:4}*{:2} {:4}*{:2}  =  {:5} + {:5} + {:5}  = {:5}   {s}", .{
            //    i,
            //    j,
            //    skill_diff,
            //    extra_matches,
            //    skill_score,
            //    skill_weight,
            //    matches_score,
            //    matches_weight,
            //    random_score,
            //    random_weight,
            //    skill_score * skill_weight,
            //    matches_score * matches_weight,
            //    random_score * random_weight,
            //    score,
            //    if (canidates[0] == &list[i] and canidates[1] == &list[j]) "<--" else "",
            //});
        }
    }

    return canidates;
}

const Winner = enum { left, right, draw };
const LRPair = struct { l: i64, r: i64 };

/// finish match
/// adjusts elo based on result
/// result is 'l','r','d' for left, right, draw; anything else to cancel match
/// returns changes in rating, like:
///     '{ "l_change":13, "r_change":-12 }'
/// free() result using Elo's alloc
pub fn finMatch(self: *Self, match_sid: []const u8, result: u8) ![]u8 {
    const match_id = try idFromSid(match_sid);
    const match = blk: {
        self.active_matches_mtx.lock();
        defer self.active_matches_mtx.unlock();

        if (self.active_matches.fetchRemove(match_id)) |kv| {
            break :blk kv.value;
        } else {
            return error.NotFound;
        }
    };

    const winner: Winner = switch (result) {
        'l' => .left,
        'r' => .right,
        'd' => .draw,
        else => {
            return try self.alloc.dupe(u8,
                \\{"l":0,"r":0}
            );
        },
    };

    // there could be a rating change after this lookup, which makes the elo calc slightly off
    // but that's super minor (and rare), don't want to lock for it
    var ratings: LRPair = .{ .l = 0, .r = 0 };
    {
        var stmt_get = try self.db().prepare(
            \\SELECT rowid,rating FROM entries WHERE rowid IN (?, ?)
        );
        defer stmt_get.deinit();

        var iter = try stmt_get.iterator(
            struct { rowid: i64, rating: i64 },
            .{ match.l_rowid, match.r_rowid },
        );

        for (0..2) |_| {
            const row = (try iter.next(.{})) orelse return error.NotFound;
            if (row.rowid == match.l_rowid) {
                ratings.l = row.rating;
            } else {
                ratings.r = row.rating;
            }
        }
    }

    const change = ratingChanges(ratings, winner);

    try self.db().exec(
        \\UPDATE entries
        \\SET rating = CASE
        \\               WHEN rowid == ? THEN rating + ?
        \\               WHEN rowid == ? THEN rating + ?
        \\             END,
        \\    matches = matches + 1
        \\WHERE rowid IN (?, ?)
    , .{}, .{
        match.l_rowid,
        change.l,
        match.r_rowid,
        change.r,
        match.l_rowid,
        match.r_rowid,
    });

    return std.json.stringifyAlloc(self.alloc, change, .{});
}

/// dynamic K factor, FIDE rules
/// not used right now
fn getKFactor(rating: i64, matches: i64) f64 {
    if (matches < 30) return 40;
    if (rating < 2400) return 20;
    return 10;
}

/// actual elo calc
/// returns rating change differences
///
/// ref: https://en.wikipedia.org/wiki/Elo_rating_system#Mathematical_details
///
///                     1
///     E_a = ---------------------
///                 (R_b - R_a)/400
///           1 + 10
///
///     E_a: expected chance for a to win
///     E_b = 1 - E_a
///
///     rating adjustment: K(S - E)
///     K = max adjustment
///     S = score (0: lose, 0.5: draw, 1: win)
///
fn ratingChanges(rating: LRPair, winner: Winner) LRPair {
    // K value is subject to change
    // FIDE would be 40 for the first 30 games, then 20. Or always 20 for blitz
    // more value early feels weird as it rewards ealry voters even more
    // 32 feels better than 20, and is in the original Elo formula
    // ultimately should be configurable based on the list
    const k = 32;

    const exp_l: f64 = @as(f64, @floatFromInt(rating.r - rating.l)) / 400;
    const e_l: f64 = 1 / (1 + std.math.pow(f64, 10, exp_l)); // expected score left
    const e_r: f64 = 1 - e_l; // expected score right

    // actual score left
    const s_l: f64 = switch (winner) {
        .left => 1,
        .right => 0,
        .draw => 0.5,
    };
    const s_r = 1 - s_l; // score right

    return .{
        .l = @intFromFloat(@round(k * (s_l - e_l))),
        .r = @intFromFloat(@round(k * (s_r - e_r))),
    };
}

/// valid SID is 8 [alnum,-,_] characters
/// url-base64-decode to u64 (48 lower bits)
fn idFromSid(str: []const u8) !u48 {
    if (str.len != 8) return error.BadId;

    var buf = std.mem.zeroes([8]u8);
    std.base64.url_safe_no_pad.Decoder.decode(&buf, str) catch {
        return error.BadId;
    };

    return std.mem.readInt(u48, buf[0..6], .little);
}

// valid id is lower 48 bit
// url-base64-encodes to 10 [alnum,-,_] chars
fn sidFromId(id: u48) ![8]u8 {
    var id_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &id_bytes, id, .little);

    var buf: [8]u8 = undefined;
    const span = std.base64.url_safe_no_pad.Encoder.encode(&buf, id_bytes[0..6]);
    std.debug.assert(span.len == 8);

    return buf;
}

test "sid id conversion" {
    try std.testing.expectEqual(idFromSid("AAAAAAAA"), 0);
    try std.testing.expectEqual(idFromSid("________"), (1 << 48) - 1);
    try std.testing.expectEqual(idFromSid("____AAAA"), 0xFFFFFF);
    try std.testing.expectEqual(idFromSid("AQAAAAAA"), 1);

    try std.testing.expectEqualSlices(u8, "AAAAAAAA", &try sidFromId(0));
    try std.testing.expectEqualSlices(u8, "________", &try sidFromId((1 << 48) - 1));
    try std.testing.expectEqualSlices(u8, "____AAAA", &try sidFromId(0xFFFFFF));
    try std.testing.expectEqualSlices(u8, "AQAAAAAA", &try sidFromId(1));

    var prng = std.rand.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));

    const rand = prng.random();

    for (0..40) |_| {
        const id = rand.int(u48);
        const sid = try sidFromId(id);
        const id2 = try idFromSid(&sid);
        for (sid) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') {
                unreachable;
            }
        }
        try std.testing.expectEqual(id, id2);
    }
}
