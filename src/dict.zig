const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;


pub fn Dict(comptime W: type, comptime D: type, comptime lt: fn (W, W) bool, comptime eq: fn (W, W) bool) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            word: W,
            definition: D,
        };

        len: usize,
        entries: ArrayList(*Entry),
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{
                .len = 0,
                .allocator = allocator,
                .entries = ArrayList(*Entry).init(allocator),
            };
        }

        /// uses binary search to identify the index of the desired entry
        /// if it finds a match, it returns the word of that entry. otherwise,
        /// returns nothing
        pub fn lookup(self: *Self, word: W) ?D {
            if (self.index(word)) |idx|
                return self.entries.items[idx].definition;

            return null;
        }

        pub fn define(self: *Self, word: W, definition: D) Allocator.Error!void {
            if (self.insertion_index(word)) |idx| {
                if (eq(self.entries.items[idx].word, word)) {
                    self.entries.items[idx].definition = definition;
                    return;
                } else {
                    var entry = try self.allocator.create(Entry);
                    entry.word = word;
                    entry.definition = definition;
                    try self.entries.insert(idx, entry);
                    self.len += 1;
                    return;
                }
            } else {
                var entry = try self.allocator.create(Entry);
                try self.entries.append(entry);
                self.len += 1;
                return;
            }
        }

        fn index(self: *Self, word: W) ?usize {
            var low: usize = 0;
            var high: usize = self.len - 1;

            while (low < high) {
                var mid = low + ((high - low) >> 1);
                var midword = self.entries.items[mid].word;

                if (eq(midword, word))
                    return mid
                else if (lt(midword, word))
                    low = mid + 1
                else
                    high = mid - 1;
            }

            if (low == high and eq(self.entries.items[low].word, word))
                return low;

            return null;
        }

        fn insertion_index(self: *Self, word: W) ?usize {
            if (self.len == 0)
                return null;

            var low: usize = 0;
            var high: usize = self.len - 1;

            while (low < high) {
                var mid = low + ((high - low) >> 1);
                var midword = self.entries.items[mid].word;

                if (eq(midword, word)) {
                    return mid;
                }
                else if (lt(midword, word)) {
                    low = mid + 1;
                    var lowword = self.entries.items[low].word;
                    if (lt(word, lowword) or eq(word, lowword))
                        return low;
                }
                else {
                    high = mid - 1;
                    var highword = self.entries.items[high].word;
                    if (lt(highword, word) or eq(highword, word))
                        return mid;
                }
            }

            if (high == 0 and lt(word, self.entries.items[0].word))
                return 0;

            return null;
        }

        pub fn erase(self: *Self, word: W) !?D {
            if (self.bsearch(word)) |idx| {
                var entry = self.entries.items[idx];
                try self.shiftLeft(idx);
                var definition = entry.definition;
                self.allocator.destroy(entry);
                return definition;
            }
        }
    };
}

fn ltAlphabetical(left: []u8, right: []u8) bool {
    if (left.len < right.len)
        return true;

    if (left.len > right.len)
        return false;

    var i: usize = 0;
    while (i < left.len) : (i += 1) {
        var l = left[i];
        var r = right[i];
        if (l < r) return true;
        if (l > r) return false;
    }

    return false;
}

test "ltAlphabetical" {
    var something = "something".*;
    var nothing = "nothing".*;
    try testing.expect(ltAlphabetical(&nothing, &something));
}

fn eqAlphabetical(left: []u8, right: []u8) bool {
    if (left.len != right.len)
        return false;

    var i: usize = 0;
    while (i < left.len) : (i += 1)
        if (left[i] != right[i]) return false;

    return true;
}

test "eqAlphabetical" {
    var something = "something".*;
    var something_else = "something".*;
    try testing.expect(eqAlphabetical(&something, &something_else));
}

fn eqAlphabeticalSentinel(left: []const u8, right: []const u8) bool {
    if (left.len != right.len)
        return false;

    var i: usize = 0;
    while (i < left.len) : (i += 1)
        if (left[i] != right[i]) return false;

    return true;
}

test "eqAlphabeticalSentinel" {
    const something = "something";
    try testing.expect(eqAlphabeticalSentinel(something, something));
}

fn u8lt(left: u8, right: u8) bool {
    return left < right;
}

fn u8eq(left: u8, right: u8) bool {
    return left == right;
}


test "Dict(u8, u8, lt, eq)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var dict = Dict(u8, u8, u8lt, u8eq).init(allocator);
    _ = try dict.define(0, 1);
    _ = try dict.define(1, 2);
    _ = try dict.define(3, 4);
    _ = try dict.define(2, 3);

    if (dict.lookup(0)) |expectation|
        try testing.expect(expectation == 1);

    if (dict.lookup(2)) |expectation|
        try testing.expect(expectation == 3);
}