const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Endpoints = @import("endpoints.zig");
const Elo = @import("elo.zig");
const cfg = @import("cfg.zig");

const dbg = builtin.mode == .Debug;

// otherwise there are no info logs in release mode
pub const std_options = .{ .log_level = if (dbg) .debug else .info };

pub fn main() !void {
    const db_file = if (std.os.argv.len >= 2)
        std.mem.span(std.os.argv[1])
    else
        cfg.db_file;

    // in debug use GPA and check leaks, in release use malloc
    // contact me if you know a better syntax
    var gpa: if (dbg) std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) else void = if (dbg) .{};
    defer if (dbg) std.debug.assert(!gpa.detectLeaks());
    const alloc = if (dbg) gpa.allocator() else std.heap.c_allocator;

    var elo = try Elo.init(alloc, db_file, 1 + cfg.threads * cfg.workers);
    defer elo.deinit();

    const endpoints = Endpoints.init(&elo);

    const tls = if (cfg.ssl)
        try zap.Tls.init(.{
            .server_name = cfg.ssl_servername,
            .public_certificate_file = cfg.ssl_cert,
            .private_key_file = cfg.ssl_cert_key,
        })
    else
        null;

    var listener = zap.HttpListener.init(
        .{
            .port = cfg.port,
            .on_request = endpoints.handler,
            .log = cfg.log_connections,
            .interface = cfg.interface,
            .tls = tls,
            .max_body_size = 512 * 1024,
            .timeout = 5,
        },
    );

    try listener.listen();

    std.log.info("listening on {s}:{}", .{ cfg.interface, cfg.port });

    zap.start(.{
        .threads = cfg.threads,
        .workers = cfg.workers,
    });
}
