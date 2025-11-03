# Zig compile time regular expressions
Generating fast code since 2020

I learned in November 2025 that Alex Naskos, the original maintainer of `ctregex.zig` passed away in September 2023.
He left an incomplete `rewrite` branch behind which I would like to push ahead to honor his memory.

## Features
- Comptime regular expression compilation
- Comptime and runtime matching
- UTF8, UTF16le, ASCII, codepoint array support
- Captures (with named `(:<name>...)` support)
- `|`, `*`, `+`, `?`, `(:?...)`, `[...]`, `[^...]`, `{N}`, `{min,}`, `{min,max}`
- '\d', '\s' character classes

## TODO
- Faster generated code using DFAs when possible
- search, findAll, etc.
- More character classes
- More features (backreferences etc.)

## Example

```zig
test "runtime matching" {
    @setEvalBranchQuota(1250);
    // The encoding is utf8 by default, you can use .ascii, .utf16le, .codepoint here instead.
    if (try match("(?<test>def|abc)([😇ω])+", .{.encoding = .utf8}, "abc😇ωωωωω")) |res| {
        std.debug.warn("Test: {}, 1: {}\n", .{ res.capture("test"), res.captures[1] });
    }
}

test "comptime matching" {
    @setEvalBranchQuota(2700);
    if (comptime try match("(?<test>def|abc)([😇ω])+", .{}, "abc😇ωωωωω")) |res| {
        @compileError("Test: " ++ res.capture("test").? ++ ", 1: " ++ res.captures[1].?);
    }
}
```

See tests.zig for more examples.  
[Small benchmark with ctregex, PCRE2](https://gist.github.com/alexnask/c537360ae0163863564fba6e660f442b)  
