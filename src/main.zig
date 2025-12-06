const std = @import("std");
const zig_million_line_challenge = @import("zig_million_line_challenge");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    _ = try getData(std.heap.page_allocator, "billion_measurements.txt");
}

fn getMeasumentFileContents(gpa: std.mem.Allocator, fileName: []const u8) ![]const u8 {
    const inputFile = try std.fs.cwd().openFile(fileName, .{ .mode = .read_only });
    defer inputFile.close();
    const stat = try inputFile.stat();
    const buffer = try gpa.alloc(u8, stat.size);

    _ = try inputFile.readAll(buffer);
    return buffer;
}

const Station = struct {
    max: f32,
    min: f32,
    count: f32,
    sum: f64,
};
fn sortStationsAlpha(_: @TypeOf(.{}), a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}
fn getData(gpa: std.mem.Allocator, fileName: []const u8) ![]u8 {
    const fileContents = try getMeasumentFileContents(gpa, fileName);
    defer gpa.free(fileContents);
    var entries = std.StringHashMap(Station).init(gpa);
    try entries.ensureTotalCapacity(10_000);
    var stationNames: [10_000][]const u8 = undefined;
    var numberOfStations: u16 = 0;
    defer entries.deinit();

    var lines = std.mem.splitScalar(u8, fileContents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var station: []const u8 = undefined;
        for (line, 0..) |char, index| {
            if (char == ';') {
                station = line[0..index];
                const temp = try std.fmt.parseFloat(f32, line[index + 1 ..]);
                const entry = try entries.getOrPut(station);
                if (entry.found_existing) {
                    var stationEntry = entry.value_ptr;
                    stationEntry.max = @max(stationEntry.max, temp);
                    stationEntry.min = @min(stationEntry.min, temp);
                    stationEntry.count += 1;
                    stationEntry.sum += temp;
                } else {
                    const stationEntry = Station{ .sum = temp, .max = temp, .min = temp, .count = 1 };
                    stationNames[numberOfStations] = station;
                    numberOfStations += 1;
                    entry.value_ptr.* = stationEntry;
                }
            }
        }
    }
    std.debug.print("we got {d} entries", .{entries.count()});
    //var iter = entries.iterator();
    std.mem.sort([]const u8, stationNames[0..numberOfStations], .{}, sortStationsAlpha);
    var builder = try std.ArrayList(u8)
        .initCapacity(gpa, 4000);

    defer builder.deinit(gpa);

    for (stationNames[0..numberOfStations]) |stationName| {
        const entry = entries.getEntry(stationName).?;
        const station = entry.value_ptr;
        const avg: f64 = station.sum / station.count;
        std.debug.print("{s}={d:0>.1}/{d:0>.1}/{d:0>.1}\n", .{ entry.key_ptr.*, station.min, avg, station.max });
        const formatted_string = try std.fmt.allocPrint(gpa, "{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key_ptr.*, station.min, avg, station.max });
        try builder.appendSlice(gpa, formatted_string);
        defer gpa.free(formatted_string); 
        //stationNames[index] = formatted_string;
    }
    std.debug.print("\ncomplete\n\n", .{});
    return try builder.toOwnedSlice(gpa);

    //return &stationNames;

    //while(iter.next()) |entry| {

    //}

    //return &.{};
}

test "output matches" {
    const expectedOutput = try std.fs.cwd().openFile("verified_output.txt", .{ .mode = .read_only });
    defer expectedOutput.close();

    const alloc = std.testing.allocator;
    //const alloc = std.heap.page_allocator;
    const stat = try expectedOutput.stat();
    std.debug.print("the file size is {d}", .{stat.size});
    const buffer = try alloc.alloc(u8, stat.size);
    defer alloc.free(buffer);

    _ = try expectedOutput.readAll(buffer);

    const result = try getData(alloc, "measurements.txt");
    defer alloc.free(result);

    try std.testing.expectEqualStrings(buffer, result);
}
