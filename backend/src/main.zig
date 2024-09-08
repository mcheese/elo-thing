const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Endpoints = @import("endpoints.zig");
const Elo = @import("elo.zig");

pub const std_options = .{
    // otherwise there are no info logs in release mode
    .log_level = if (builtin.mode == .Debug) .debug else .info,
};

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.debug.print("Requires path to db file as first argument.\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.assert(!gpa.detectLeaks());
    const alloc = gpa.allocator();

    const cfg = .{
        .port = 21337,
        .interface = "127.0.0.1",
        .threads = 4,
        .workers = 1,
        .db_file = std.mem.span(std.os.argv[1]),
        .log_connections = false,
    };

    var elo = try Elo.init(alloc, cfg.db_file, 1 + cfg.threads * cfg.workers);
    defer elo.deinit();

    {
        const c = try elo.deleteGroup("DEADBEEF");
        std.debug.print("Removed group DEADBEEF with {} entries.\n", .{c});
        try elo.addGroup("DEADBEEF",
            \\[{"name": "first", "rating": 1335 },
            \\ {"name": "second", "rating": 1290 },
            \\ {"name": "third", "rating": 1189 },
            \\ {"name": "fourth", "rating": 999 },
            \\ {"name": "fifth", "rating": 2000 }
            \\]
        );
    }

    const endpoints = Endpoints.init(&elo);
    var listener = zap.HttpListener.init(
        .{
            .port = cfg.port,
            .on_request = endpoints.handler,
            .log = cfg.log_connections,
            .interface = cfg.interface,
        },
    );

    try listener.listen();

    std.log.info("listening on {s}:{}", .{ cfg.interface, cfg.port });

    zap.start(.{
        .threads = cfg.threads,
        .workers = cfg.workers,
    });
}
