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
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.assert(!gpa.detectLeaks());

    const port = 21337;
    const interface = "127.0.0.1";

    var elo = Elo.init();
    const endpoints = Endpoints.init(&elo);

    var listener = zap.HttpListener.init(
        .{
            .port = port,
            .on_request = endpoints.handler,
            .log = true,
            .interface = interface,
        },
    );

    try listener.listen();

    std.log.info("listening on {s}:{}", .{ interface, port });

    zap.start(.{
        .threads = 4,
        .workers = 1,
    });
}
