//! Error handling system for Ziglet VM
//! Provides detailed error context and unified logging for errors.
const std = @import("std");
const nexlog = @import("nexlog");

/// Provides detailed context about an error that occurred during VM operation.
pub const ErrorContext = struct {
    /// The operation that was being performed when the error occurred.
    operation: []const u8,
    /// Location information (optional).
    location: ?Location = null,
    /// Explanation of what went wrong.
    details: []const u8,
    /// Suggestion how to fix the error.
    suggestion: []const u8,

    pub const Location = struct {
        /// 1-based line number.
        line: usize,
        /// 1-based column number.
        column: usize,
        /// Optional source file reference.
        file: ?[]const u8 = null,
    };
};

/// A comprehensive list of errors.
pub const VMError = error{
    OutOfMemory,
    MemoryAccessViolation,
    StackOverflow,
    InvalidInstruction,
    UnsupportedOperation,
    DivisionByZero,
    TypeMismatch,
    ResourceExhausted,
    InvalidConfiguration,
    StackUnderflow,
    InvalidFunctionCall,
    InvalidMemoryAccess,
    InvalidAlignment,
    SecurityViolation,
};

pub const SecurityConfig = struct {
    max_memory: usize,
    max_stack_depth: usize,
    max_instructions: usize,
    allow_self_modify: bool,
};

/// Combined error type with context.
pub const Error = struct {
    err: VMError,
    context: ErrorContext,

    /// Formats the error for printing.
    pub fn format(
        self: Error,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("\nError: {s}\n", .{@errorName(self.err)});
        try writer.print("During: {s}\n", .{self.context.operation});
        if (self.context.location) |loc| {
            if (loc.file) |file| {
                try writer.print("In file: {s}\n", .{file});
            }
            try writer.print("At line {d}, column {d}\n", .{ loc.line, loc.column });
        }
        try writer.print("\nDetails: {s}\n", .{self.context.details});
        try writer.print("Suggestion: {s}\n\n", .{self.context.suggestion});
    }
};

/// Helper to generate consistent metadata for logging.
fn createErrorMetadata() nexlog.LogMetadata {
    return .{
        .timestamp = std.time.timestamp(),
        .thread_id = 0,
        .file = @src().file,
        .line = @src().line,
        .function = @src().fn_name,
    };
}

/// Runtime version of error creation. This function logs the error once,
/// using the provided information, and returns the error.
pub fn createRuntimeError(
    err: VMError,
    operation: []const u8,
    details: []const u8,
    suggestion: []const u8,
) VMError {
    const logger = nexlog.getDefaultLogger() orelse return err;
    const metadata = createErrorMetadata();

    logger.err(
        "Error: {s}\nDuring: {s}\nDetails: {s}\nSuggestion: {s}\n",
        .{ @errorName(err), operation, details, suggestion },
        metadata,
    );
    return err;
}
