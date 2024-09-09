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
};

const Entry = struct { name: []const u8, rating: i64, img: []const u8 = "" };
const Group = []Entry;

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

/// insert group by json string
pub fn addGroup(self: *Self, sid: []const u8, json: []const u8) !void {
    const id = try idFromSid(sid);
    const parsed = try std.json.parseFromSlice([]Entry, self.alloc, json, .{ .allocate = .alloc_if_needed });
    defer parsed.deinit();

    var savepoint = try self.db().savepoint("addGroup");
    defer savepoint.rollback();

    {
        const query =
            \\SELECT count(*) FROM entries WHERE group_id = ?
        ;
        const count = try self.db().one(i64, query, .{}, .{ .group_id = id });
        if (count != 0) return error.AlreadyExists;
    }
    {
        const query =
            \\INSERT INTO entries (group_id, name, rating) VALUES (?, ?, ?)
        ;
        var stmt = try self.db().prepare(query);
        defer stmt.deinit();
        for (parsed.value) |e| {
            stmt.reset();
            try stmt.exec(.{}, .{
                .group_id = id,
                .name = e.name,
                .rating = e.rating,
            });
        }
    }
    savepoint.commit();
}

/// get group json string
/// need to free() returned value
///
///     const grp = try elo.getGroup(sid);
///     defer elo.alloc.free(grp);
pub fn getGroup(self: *Self, sid: []const u8) ![]const u8 {
    // TODO: cache this

    const id = try idFromSid(sid);

    const query =
        \\SELECT name,rating,img FROM entries WHERE group_id = ?
    ;
    var stmt = try self.db().prepare(query);
    defer stmt.deinit();

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    const data = try stmt.all(
        Entry,
        arena.allocator(),
        .{},
        .{ .group_id = id },
    );
    if (data.len == 0) return error.NotFound;

    return std.json.stringifyAlloc(self.alloc, data, .{});
}

const Rand = struct {
    threadlocal var rng: ?std.rand.DefaultPrng = null;
    fn get() !std.rand.Random {
        if (rng == null) {
            rng = std.rand.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
        }
        return rng.?.random();
    }
};

const MatchmakingRow = struct { rowid: i64, rating: i64, matches: i64 };

pub fn getMatch(self: *Self, sid: []const u8) ![]const u8 {
    // TODO: cache the fetch
    // TODO: limit this per user/session
    // TODO: cleanup unused active_matches

    const id = try idFromSid(sid);

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    const full: []MatchmakingRow = blk: {
        // don't want to do the random selection in DB (supposedly expensive)
        // not selecting first N `ORDER BY matches` because I think there is unfairness
        // should keep cached groups at some point
        var stmt = try self.db().prepare(
            \\SELECT rowid,rating,matches
            \\FROM entries WHERE group_id = ?
        );
        defer stmt.deinit();
        break :blk try stmt.all(MatchmakingRow, arena.allocator(), .{}, .{ .group_id = id });
    };
    if (full.len < 2) return error.NotFound;

    const preselect_size = 8;
    const preselected = try preselect(full, preselect_size);
    const selected = try matchmake(preselected);

    const rand = try Rand.get();
    const match_id = rand.int(u48);
    const match_sid = try sidFromId(match_id);

    const final_match = blk: {
        var stmt = try self.db().prepare(
            \\SELECT rowid,name,rating,img
            \\FROM entries WHERE rowid IN (?, ?)
        );
        defer stmt.deinit();
        break :blk try stmt.all(struct { rowid: i64, name: []u8, rating: i64, img: []u8 }, arena.allocator(), .{}, .{ selected[0].rowid, selected[1].rowid });
    };
    if (final_match.len < 2) return error.NotFound;

    // what the client will get back
    const ret = .{
        .match_id = match_sid,
        .l = .{ .name = final_match[0].name, .rating = final_match[0].rating, .img = final_match[0].img },
        .r = .{ .name = final_match[1].name, .rating = final_match[1].rating, .img = final_match[1].img },
    };

    // what we store
    const store = .{
        .l_rowid = final_match[0].rowid,
        .r_rowid = final_match[1].rowid,
        .timestamp = std.time.timestamp(),
    };

    {
        self.active_matches_mtx.lock();
        defer self.active_matches_mtx.unlock();
        try self.active_matches.put(match_id, store);
    }

    return std.json.stringifyAlloc(self.alloc, ret, .{});
}

/// preselect random `n` rows
/// modifies `list`
fn preselect(list: []MatchmakingRow, n: usize) ![]MatchmakingRow {
    if (list.len <= n) return list;
    const rng = try Rand.get();

    if (list.len >= n * 2) {
        // move n random lines to the top
        // selecting random lines to be returned
        for (0..n) |i| {
            // random index from range [i+1, len)
            const other = rng.uintLessThanBiased(usize, list.len - i - 1) + i + 1;
            std.mem.swap(MatchmakingRow, &list[i], &list[other]);
        }
    } else {
        // move len-n random lines to the bottom
        // selecting random lines NOT to be returned
        for (list.len..n) |i| {
            // random index from range [0, i-1)
            const other = rng.uintLessThanBiased(usize, i - 1);
            std.mem.swap(MatchmakingRow, &list[i - 1], &list[other]);
        }
    }

    return list[0..n];
}

/// select a match
/// based on matches, close elo, randomness
/// modifies `list`
/// O(n^2) -> preselect the list
fn matchmake(list: []MatchmakingRow) ![2]MatchmakingRow {
    if (list.len <= 2) return .{ list[0], list[1] };

    const rng = try Rand.get();

    // higher factor = higher influence on matchmaking selection
    const skill_weight = 1.0;
    const matches_weight = 1.2;
    const random_weight = 1.0;

    const skill_K: f64 = 400; // skill diff where score becomes 0 (linear with minimum)
    const matches_K: f64 = 20; // extra matches where score becomes 0 (linear with minimum)

    var min_matches = list[0].matches;
    for (list) |*e| {
        if (min_matches > e.matches)
            min_matches = e.matches;
    }

    var canidate: [2]usize = .{ 0, 1 };
    var max_score = std.math.floatMin(f64);
    // for every combo calc a score and keep the 2 highest
    for (0..list.len) |i| {
        for (i + 1..list.len) |j| {
            const skill_diff: f64 = @floatFromInt(@abs(list[i].rating - list[j].rating));
            const extra_matches: f64 = @floatFromInt((list[i].matches - min_matches) + (list[j].matches - min_matches));

            const skill_score = if (skill_diff < skill_K) (1 - skill_diff / skill_K) else 0;
            const matches_score = if (extra_matches < matches_K) (1 - extra_matches / matches_K) else 0;
            const random_score = rng.float(f64);

            const score = skill_score * skill_weight + matches_score * matches_weight + random_score * random_weight;
            if (score > max_score) {
                max_score = score;
                canidate = .{ i, j };
            }

            //std.debug.print("{}-{} | ", .{ i, j });
            //std.debug.print("{d:3.0}S {d:3.0}M | ", .{ skill_diff, extra_matches });
            //std.debug.print(
            //    "{d:5.3}*{d:.1} + {d:5.3}*{d:.1} + {d:5.3}*{d:.1}   =   ",
            //    .{ skill_score, skill_weight, matches_score, matches_weight, random_score, random_weight },
            //);
            //std.debug.print(
            //    "  {d:5.3} + {d:5.3} + {d:5.3}   =   {d:5.3}\n",
            //    .{ skill_score * skill_weight, matches_score * matches_weight, random_score * random_weight, score },
            //);
        }
    }

    //std.debug.print("WINNER {}-{}\n", .{ canidate[0], canidate[1] });

    return .{ list[canidate[0]], list[canidate[1]] };
}

const Winner = enum { left, right, draw };
const RatingPair = struct { l: i64, r: i64 };

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
                \\{"l_change":0,"r_change":0}
            );
        },
    };

    var stmt_get = try self.db().prepare(
        \\SELECT 
        \\  MAX(CASE WHEN rowid = ? THEN rating END) AS l,
        \\  MAX(CASE WHEN rowid = ? THEN rating END) AS r
        \\FROM entries
        \\WHERE rowid IN (?, ?)
    );
    defer stmt_get.deinit();
    var stmt_set = try self.db().prepare(
        \\UPDATE entries
        \\SET rating = @rating, matches = matches + 1
        \\WHERE rowid == @rowid
    );
    defer stmt_set.deinit();

    // transaction start
    var savepoint = try self.db().savepoint("finMatch");
    defer savepoint.rollback();

    const rating = try stmt_get.one(RatingPair, .{}, .{
        match.l_rowid,
        match.r_rowid,
        match.l_rowid,
        match.r_rowid,
    }) orelse {
        return error.NotFound;
    };
    const new_rating = adjustRatings(rating, winner);
    try stmt_set.exec(.{}, .{ .rating = new_rating.l, .rowid = match.l_rowid });
    stmt_set.reset();
    try stmt_set.exec(.{}, .{ .rating = new_rating.r, .rowid = match.r_rowid });

    // end transaction
    savepoint.commit();

    return std.json.stringifyAlloc(self.alloc, .{
        .l_change = new_rating.l - rating.l,
        .r_change = new_rating.r - rating.r,
    }, .{});
}

/// actual elo calc
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
///     new rating: R' = R' + K(S - E)
///     K = max adjustment
///     S = score (0: lose, 0.5: draw, 1: win)
///
fn adjustRatings(rating: RatingPair, winner: Winner) RatingPair {
    const k = 32; // could lower this towards 16 with amount of matches

    const exp = @as(f64, @floatFromInt(rating.r - rating.l)) / 400;
    const e_l = 1 / (1 + std.math.pow(f64, 10, exp));
    const e_r = 1 - e_l;

    const s_l: f64 = switch (winner) {
        .left => 1,
        .right => 0,
        .draw => 0.5,
    };
    const s_r = 1 - s_l;

    return .{
        .l = rating.l + @as(i64, @intFromFloat(k * (s_l - e_l))),
        .r = rating.r + @as(i64, @intFromFloat(k * (s_r - e_r))),
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
        std.debug.print(" * {s} <-> 0x{x:0>12}\n", .{ &sid, id });
        const id2 = try idFromSid(&sid);
        for (sid) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') {
                unreachable;
            }
        }
        try std.testing.expectEqual(id, id2);
    }
}
