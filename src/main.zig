//
// This program is a demonstration of the usage of Ollama API with Zig.
// https://github.com/ollama/ollama/blob/main/docs/api.md
//

const std = @import("std");
const http = std.http;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = std.Uri.parse("http://localhost:11434/api/chat") catch unreachable;

    const server_header_buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(server_header_buffer);
    var request = try client.open(.POST, uri, .{
        .server_header_buffer = server_header_buffer,
    });
    defer request.deinit();
    request.transfer_encoding = .chunked;

    try request.send();
    try request.writeAll(
        \\{
        \\  "model": "dolphin-mixtral:8x7b-v2.5-q3_K_S",
        \\  "messages": [
        \\    {
        \\      "role": "user",
        \\      "content": "why is the sky blue?"
        \\    }
        \\  ],
        \\  "stream": false
        \\}
    );
    try request.finish();
    try request.wait();

    const body = request.reader().readAllAlloc(allocator, 8192) catch unreachable;
    defer allocator.free(body);
    const OllamaResponse = struct {
        model: []const u8,
        created_at: []const u8,
        message: Message,
        done: bool,
        total_duration: u64,
        load_duration: u64,
        prompt_eval_count: u64,
        prompt_eval_duration: u64,
        eval_count: u64,
        eval_duration: u64,

        const Message = struct {
            role: []const u8,
            content: []const u8,
        };
    };
    const parsed_json = try std.json.parseFromSlice(OllamaResponse, allocator, body, .{});
    defer parsed_json.deinit();

    std.debug.print("{s}: {s}\n", .{ parsed_json.value.message.role, parsed_json.value.message.content });
}
