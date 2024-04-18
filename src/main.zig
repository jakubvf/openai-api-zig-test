//
// This program is a demonstration of the usage of Ollama API with Zig.
// https://github.com/ollama/ollama/blob/main/docs/api.md
//

const std = @import("std");
const http = std.http;

const OllamaStreamingResponse = struct {
    model: []const u8,
    created_at: []const u8,
    message: Message,
    done: bool,

    const Message = struct {
        role: []const u8,
        content: []const u8,
        // TODO: Handle images
    };
};
const OllamaStreamingFinalResponse = struct {
    model: []const u8,
    created_at: []const u8,
    message: Message,
    done: bool,
    total_duration: u64,
    load_duration: u64,
    // prompt_eval_count: u64, This one is not present in the final response?
    prompt_eval_duration: u64,
    eval_count: u64,
    eval_duration: u64,
    const Message = struct {
        role: []const u8,
        content: []const u8,
        // TODO: Handle images
    };
};
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
        // TODO: Handle images
    };
};
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
    const stream = true;
    try request.writeAll(
        \\{
        \\  "model": "dolphin-mixtral:8x7b-v2.5-q3_K_S",
        \\  "messages": [
        \\    {
        \\      "role": "user",
        \\      "content": "why is the sky blue?"
        \\    }
        \\  ]
        \\}
    );
    try request.finish();
    try request.wait();

    const buffer = try allocator.alloc(u8, 8192);
    defer allocator.free(buffer);

    if (stream) {
        var done = false;
        var len: usize = 0;

        while (!done) {
            len = try request.read(buffer);
            const parsed_response = std.json.parseFromSlice(OllamaStreamingResponse, allocator, buffer[0..len], .{}) catch break;
            defer parsed_response.deinit();
            done = parsed_response.value.done;
            std.debug.print("{s}", .{parsed_response.value.message.content});
        }
        const parsed_final_response = try std.json.parseFromSlice(OllamaStreamingFinalResponse, allocator, buffer[0..len], .{});
        defer parsed_final_response.deinit();
    } else {
        const body = request.reader().readAll(buffer) catch unreachable;
        defer allocator.free(body);
        const parsed_final_response = try std.json.parseFromSlice(OllamaResponse, allocator, body, .{});
        defer parsed_final_response.deinit();
        std.debug.print("{s}: {s}\n", .{ parsed_final_response.value.message.role, parsed_final_response.value.message.content });
    }
}
