const std = @import("std");
const unicode = std.unicode;

// @TODO Utf32le?
pub const Encoding = enum {
    ascii,
    utf8,
    utf16le,
    codepoint,

    pub fn CharT(comptime self: Encoding) type {
        return switch (self) {
            .ascii, .utf8 => u8,
            .utf16le => u16,
            .codepoint => u21,
        };
    }

    pub fn needsDecoding(comptime encoding: Encoding) bool {
        return switch (encoding) {
            .ascii, .codepoint => false,
            else => true,
        };
    }

    pub inline fn readCodepoint(
        comptime encoding: Encoding,
        reader: *std.io.Reader,
    ) !u21 {
        switch (encoding) {
            .ascii => try reader.takeByte(),
            .utf8 => {
                const n = unicode.utf8ByteSequenceLength(try reader.peekByte()) catch return error.DecodeError;
                return unicode.utf8Decode(try reader.take(n)) catch error.DecodeError;
            },
            .utf16le => {
                const n = unicode.utf16CodeUnitSequenceLength(try reader.peekInt(u16, .little)) catch return error.DecodeError;
                const it: unicode.Utf16LeIterator = .{ .bytes = try reader.take(n * @sizeOf(u16)), .index = 0 };
                return it.nextCodepoint() catch error.DecodeError;
            },
            .codepoint => {
                const cp = try reader.takeInt(u32, unicode.nativeEndian);
                return @truncate(cp);
            },
        }
    }

    pub inline fn give(
        comptime encoding: Encoding,
        reader: *std.io.Reader,
        cp: u21,
    ) void {
        switch (encoding) {
            .utf8 => reader.seek -= unicode.utf8CodepointSequenceLength(cp) catch unreachable,
            .utf16le => reader.seek -= @sizeOf(u16) * unicode.utf16CodepointSequenceLength(cp) catch unreachable,
            else => unreachable,
        }
    }
};
