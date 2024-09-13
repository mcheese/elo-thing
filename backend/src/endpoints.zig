const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Elo = @import("elo.zig");

const Self = @This();

const routes = [_]Route{
    .{ .path = "/group", .handler = ep_group },
    .{ .path = "/match", .handler = ep_match },
    .{ .path = "/result", .handler = ep_result },
    .{ .path = "/create", .handler = ep_create },
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
        error.BadId, error.BadJson => c.bad_request,
        error.NotFound => c.not_found,
        error.TooMany => c.payload_too_large,
        else => c.internal_server_error,
    };
}

/// root request handler, doing the routing
fn on_request(req: zap.Request) void {
    req.setHeader(
        "Access-Control-Allow-Origin",
        if (builtin.mode == .Debug) "*" else "https://elothing.top",
    ) catch {};

    switch (req.methodAsEnum()) {
        .OPTIONS => {
            req.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS") catch return;
            req.setStatus(zap.StatusCode.no_content);
            req.markAsFinished(true);
            return;
        },
        .GET, .POST => {},
        else => {
            req.setStatus(.bad_request);
            return;
        },
    }

    if (req.path) |p| {
        for (routes) |route| {
            if (std.mem.startsWith(u8, p, route.path)) {
                return route.handler(&req, p[route.path.len..]) catch |e| {
                    std.log.err("{s} - {s}", .{ @errorName(e), route.path });
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
    try req.sendJson(s);
}

fn ep_match(req: *const zap.Request, path: []const u8) !void {
    if (path.len < 2 or path[0] != '/') {
        return req.setStatus(.bad_request);
    }
    const id = path[1..];

    const s = try elo.getMatch(id);
    defer elo.alloc.free(s);
    try req.sendJson(s);
}

fn ep_result(req: *const zap.Request, _: []const u8) !void {
    var buffer: [64]u8 = undefined; // just for parsing match_id and result
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const a = fba.allocator();

    if (req.body != null)
        try req.parseBody();
    req.parseQuery();

    const match_sid = try req.getParamStr(a, "match_id", false);
    const result = try req.getParamStr(a, "result", false);
    if (match_sid == null or result == null or result.?.str.len < 1)
        return req.setStatus(.bad_request);

    const s = try elo.finMatch(match_sid.?.str, result.?.str[0]);
    defer elo.alloc.free(s);
    try req.sendJson(s);
}

fn ep_create(req: *const zap.Request, _: []const u8) !void {
    if (req.body) |body| {
        const sid = try elo.createGroup(body);
        try req.setContentType(.TEXT);
        try req.sendBody(&sid);
    } else {
        return req.setStatus(.bad_request);
    }
}
