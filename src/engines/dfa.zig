const std = @import("std");
const builtin = @import("builtin");

const root = @import("../ctregex.zig");
const Encoding = @import("../unicode.zig").Encoding;
const FiniteAutomaton = @import("../fa/finite_automaton.zig");

const Operation = root.Operation;
const MatchOptions = root.MatchOptions;
const MatchError = root.MatchError;
const InputKind = root.InputKind;

fn NextChar(
    comptime encoding: Encoding,
    comptime single_char: bool,
) type {
    const decode_error = if (single_char or !encoding.needsDecoding())
        error{}
    else
        error{DecodeError};

    const return_type = if (single_char)
        encoding.CharT()
    else
        u21;

    return (std.io.Reader.Error || decode_error)!return_type;
}

inline fn readNextChar(
    comptime encoding: Encoding,
    comptime single_char: bool,
    reader: *std.io.Reader,
) NextChar(encoding, single_char) {
    return if (single_char)
        switch (encoding) {
            .ascii, .utf8 => try reader.takeByte(),
            .utf16le => try reader.takeInt(u16, .little),
            .codepoint => @truncate(try reader.takeInt(u32, builtin.cpu.arch.endian())),
        }
    else
        try encoding.readCodepoint(reader);
}

pub inline fn matchReader(
    comptime options: MatchOptions,
    comptime automaton: FiniteAutomaton,
    comptime operation: Operation,
    comptime single_char: bool,
    comptime input_kind: InputKind,
    reader: *std.io.Reader,
) MatchError(options.encoding, options.decodeErrorMode, input_kind)!bool {
    const decode_err_value = switch (options.decodeErrorMode) {
        .fail => false,
        else => error.DecodeError,
    };

    var state: std.math.IntFittingRange(0, automaton.stateCount() - 1) = 0;
    matching: while (true) {
        if (operation == .starts_with) {
            inline for (automaton.final_states) |fs| {
                if (state == fs) return true;
            }
        }

        const char = readNextChar(
            options.encoding,
            single_char,
            reader,
        ) catch |err| switch (err) {
            error.EndOfStream => {
                if (operation == .match) {
                    inline for (automaton.final_states) |fs| {
                        if (fs == state) return true;
                    }
                }
                return false;
            },
            error.DecodeError => return decode_err_value,
            error.ReadFailed => |e| return switch (input_kind) {
                .reader => e,
                else => unreachable, // std.io.Reader.fixed only returns EndOfStream
            },
        };

        inline for (automaton.transitions) |t| {
            if (t.source == state and t.label == char) {
                state = t.target;
                continue :matching;
            }
        }

        // Matched no transitions and not at end of stream
        // If we report decoding errors and we are in single char mode, check for an encoding error
        if (single_char and options.decodeErrorMode == .@"error") {
            _ = try options.encoding.readCodepointWithFirstChar(reader, char);
        }

        return false;
    }
}
