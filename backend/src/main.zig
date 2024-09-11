const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Endpoints = @import("endpoints.zig");
const Elo = @import("elo.zig");

const dbg = builtin.mode == .Debug;

// otherwise there are no info logs in release mode
pub const std_options = .{ .log_level = if (dbg) .debug else .info };

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.debug.print("Requires path to db file as first argument.\n", .{});
        return;
    }

    // TODO: config file or cmd args
    // hardcode everything for now
    const cfg = .{
        .port = 1337,
        .interface = if (dbg) "127.0.0.1" else "0.0.0.0",
        .threads = if (dbg) 4 else 8,
        .workers = 1,
        .db_file = std.mem.span(std.os.argv[1]),
        .log_connections = true,
        .ssl = !dbg,
        .ssl_cert = "cert.pem",
        .ssl_cert_key = "key.pem",
        .ssl_servername = "api.elothing.top:1337",
    };

    // in debug use GPA and check leaks, in release use malloc
    var gpa: if (dbg) std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) else void = {};
    defer if (dbg) std.debug.assert(!gpa.detectLeaks());
    const alloc = if (dbg) gpa.allocator() else std.heap.c_allocator;

    var elo = try Elo.init(alloc, cfg.db_file, 1 + cfg.threads * cfg.workers);
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
        },
    );

    try listener.listen();

    std.log.info("listening on {s}:{}", .{ cfg.interface, cfg.port });

    zap.start(.{
        .threads = cfg.threads,
        .workers = cfg.workers,
    });
}
