//! constant config
// why even build a dynamic config?
// it's just supposed to run on my server anyway

const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == .Debug;

pub const db_file = "elothing.db";
pub const port: u64 = 1337;
pub const interface = if (dbg) "127.0.0.1" else "0.0.0.0";
pub const threads = if (dbg) 4 else 8;
pub const workers = 1;
pub const log_connections = true;
pub const ssl = !dbg;
pub const ssl_cert = "cert.pem";
pub const ssl_cert_key = "key.pem";
pub const ssl_servername = "api.elothing.top:1337";
