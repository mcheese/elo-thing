const std = @import("std");

const Self = @This();

pub const EloError = error{
    NotFound,
};

pub fn init() Self {
    return .{};
}

pub fn getStandings(self: *Self, id: []const u8) EloError![]const u8 {
    _ = self;

    if (!std.mem.eql(u8, "1234", id)) return EloError.NotFound;

    return 
    \\[
    \\{ "rank": 1, "name": "first", "rating": 1335 },
    \\{ "rank": 2, "name": "second", "rating": 1290 },
    \\{ "rank": 3, "name": "third", "rating": 1189 },
    \\{ "rank": 4, "name": "fourth", "rating": 999 }
    \\]
    ;
}
