const std = @import("std");
const sqlite = @import("sqlite");
const Alloc = std.mem.Allocator;

const Self = @This();

pub const EloError = error{
    NotFound,
    BadId,
    BadJson,
    AlreadyExists,
};

const Entry = struct {
    name: []const u8,
    rating: i64,
};
const Group = []Entry;

const Match = struct {
    const Side = struct { rowid: i64, rating: i64 };
    l: Side,
    r: Side,
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
            @panic("sqlite init in extra thread failed");
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
        \\SELECT name,rating FROM entries WHERE group_id = ?
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

pub fn getMatch(self: *Self, sid: []const u8) ![]const u8 {
    // TODO: some form of matchmaking, also remember number of matches per item
    // TODO: limit this per user/session
    // TODO: cleanup unused active_matches

    const id = try idFromSid(sid);

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    const query =
        \\SELECT rowid,name,rating
        \\FROM entries WHERE group_id = ?
        \\ORDER BY RANDOM() LIMIT 2
    ;
    var stmt = try self.db().prepare(query);
    defer stmt.deinit();

    const Row = struct {
        rowid: i64,
        name: []u8,
        rating: i64,
    };
    const data = try stmt.all(
        Row,
        arena.allocator(),
        .{},
        .{ .group_id = id },
    );
    if (data.len != 2) return error.NotFound;

    const rand = try Rand.get();
    const match_id = rand.int(u48);
    const match_sid = try sidFromId(match_id);

    // what the client will get back
    const ret = .{
        .match_id = match_sid,
        .l = .{ .name = data[0].name, .rating = data[0].rating },
        .r = .{ .name = data[1].name, .rating = data[1].rating },
    };

    // what we store
    const store = .{
        .l = .{ .rowid = data[0].rowid, .rating = data[0].rating },
        .r = .{ .rowid = data[1].rowid, .rating = data[1].rating },
        .timestamp = std.time.timestamp(),
    };

    {
        self.active_matches_mtx.lock();
        defer self.active_matches_mtx.unlock();
        try self.active_matches.put(match_id, store);
    }

    return std.json.stringifyAlloc(self.alloc, ret, .{});
}

pub fn finMatch(self: *Self, match_sid: []const u8, result: u8) !void {
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

    switch (result) {
        'l' => {},
        'r' => {},
        'd' => {},
        else => { return; },
    }

    _=match;

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
