const std = @import("std");
const zap = @import("zap");
const Elo = @import("elo.zig");

const Self = @This();

const routes = [_]Route{
    .{ .path = "/group", .handler = ep_group },
};

// global/static because passing context through the request handler in Zap is not recommended
var elo: *Elo = undefined;
handler: zap.HttpRequestFn,

/// Create endpoint router
/// uses static state, just create one
pub fn init(e: *Elo) Self {
    elo = e;
    return .{
        .handler = on_request,
    };
}

const Route = struct {
    path: []const u8,
    handler: *const fn (req: *const zap.Request, path: []const u8) anyerror!void,
};

fn status(err: anyerror) zap.StatusCode {
    const c = zap.StatusCode;
    return switch (err) {
        error.BadId => c.bad_request,
        error.NotFound => c.not_found,
        else => c.internal_server_error,
    };
}

/// root request handler, doing the routing
fn on_request(req: zap.Request) void {
    req.setHeader("Access-Control-Allow-Origin", "*") catch {};

    if (req.path) |p| {
        for (routes) |route| {
            if (std.mem.startsWith(u8, p, route.path)) {
                return route.handler(&req, p[route.path.len..]) catch |e| {
                    return req.setStatus(status(e));
                };
            }
        }
    }

    req.setStatus(.not_found);
}

fn ep_group(req: *const zap.Request, path: []const u8) !void {
    if (path.len < 2 or path[0] != '/') {
        return req.setStatus(.bad_request);
    }
    const id = path[1..];
    const s = try elo.getGroup(id);
    defer elo.alloc.free(s);
    try req.setContentType(.JSON);
    try req.sendBody(s);
}
