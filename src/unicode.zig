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

    inline fn utf8DoNextByte(reader: *std.io.Reader, value: *u21) (std.io.Reader.Error || error{DecodeError})!void {
        const c = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => return error.DecodeError,
            else => |e| return e,
        };
        if (c & 0b1100_0000 != 0b100_00000) return error.DecodeError;
        value.* <<= 6;
        value.* |= c & 0b0011_1111;
    }

    pub inline fn readCodepointWithFirstChar(
        comptime encoding: Encoding,
        reader: *std.io.Reader,
        c: encoding.CharT(),
    ) !u21 {
        switch (encoding) {
            .ascii => return c,
            .utf8 => {
                const length = unicode.utf8ByteSequenceLength(c) catch return error.DecodeError;
                switch (length) {
                    1 => return c,
                    2 => {
                        const c0: u21 = c;
                        var value: u21 = c0 & 0b0001_1111;
                        try utf8DoNextByte(reader, &value);
                        if (value < 0x80) return error.DecodeError;
                        return value;
                    },
                    3 => {
                        const c0: u21 = c;
                        var value: u21 = c0 & 0b0000_1111;
                        try utf8DoNextByte(reader, &value);
                        try utf8DoNextByte(reader, &value);
                        if (value < 0x800 or (0xd800 <= value and value <= 0xdfff))
                            return error.DecodeError;
                        return value;
                    },
                    4 => {
                        const c0: u21 = c;
                        var value: u21 = c0 & 0b0000_0111;
                        try utf8DoNextByte(reader, &value);
                        try utf8DoNextByte(reader, &value);
                        try utf8DoNextByte(reader, &value);

                        if (value < 0x1_0000 or value > 0x10_FFFF) return error.DecodeError;
                        return value;
                    },
                    else => unreachable,
                }
            },
            .utf16le => {
                const c0: u21 = c;
                if (unicode.utf16IsHighSurrogate(c0)) {
                    const c1: u21 = reader.takeInt(u16, .little) catch |err| switch (err) {
                        error.EndOfStream => return error.DecodeError,
                        else => |e| return e,
                    };
                    return unicode.utf16DecodeSurrogatePair(&.{ c0, c1 }) catch |err| switch (err) {
                        error.ExpectedSecondSurrogateHalf => error.DecodeError,
                        else => |e| e,
                    };
                } else if (unicode.utf16IsLowSurrogate(c0)) {
                    return error.DecodeError;
                } else {
                    return c0;
                }
            },
            .codepoint => return c,
        }
    }

    pub inline fn readCodepoint(
        comptime encoding: Encoding,
        reader: *std.io.Reader,
    ) !u21 {
        switch (encoding) {
            .ascii, .codepoint => unreachable,
            .utf8 => {
                const c0 = try reader.takeByte();
                return try encoding.readCodepointWithFirstChar(reader, c0);
            },
            .utf16le => {
                const c0 = try reader.takeInt(u16, .little);
                return try encoding.readCodepointWithFirstChar(reader, c0);
            },
        }
    }
};

pub fn utf16leDecode(code_units: []const u16) !u21 {
    return if (unicode.utf16IsHighSurrogate(code_units[0]))
        try unicode.utf16DecodeSurrogatePair(&code_units)
    else if (unicode.utf16IsLowSurrogate(code_units[0]))
        error.UnexpectedSecondSurrogateHalf
    else
        code_units[0];
}
