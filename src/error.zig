//! Error handling system for Ziglet VM
//!
//! This module provides a comprehensive error handling system that helps users
//! diagnose and fix issues when using the Ziglet VM. It includes detailed error
//! contexts, locations, and actionable suggestions.
//!
//! Example:
//! ```zig
//! const ziglet = @import("ziglet");
//!
//! fn main() !void {
//!     var vm = try ziglet.VM.init(allocator);
//!     vm.execute() catch |err| {
//!         // Prints detailed error information with context
//!         std.debug.print("{}\n", .{err});
//!         return err;
//!     };
//! }
//! ```

const std = @import("std");

/// Provides detailed context about an error that occurred during VM operation.
/// This structure ensures that users receive comprehensive information about
/// what went wrong and how to fix it.
pub const ErrorContext = struct {
    /// The specific operation or action that was being performed when the error occurred.
    /// This helps users understand what the VM was trying to do.
    /// Example: "executing ADD instruction" or "allocating memory for stack"
    operation: []const u8,

    /// The precise location where the error occurred in the user's code or script.
    /// This field is optional as not all errors have a specific location.
    /// For example, initialization errors might not have a location.
    location: ?Location = null,

    /// Detailed explanation of what specifically went wrong during the operation.
    /// This should provide specific information about the error condition.
    /// Example: "Register R15 does not exist" or "Stack size exceeded 1MB limit"
    details: []const u8,

    /// Actionable suggestion on how to fix or avoid the error.
    /// This should provide clear, concrete steps that users can take.
    /// Example: "Use registers R0 through R14 only" or "Increase stack size in VM configuration"
    suggestion: []const u8,

    /// Represents a specific location in code where an error occurred.
    /// This helps users quickly find and fix issues in their code.
    pub const Location = struct {
        /// Line number in the source code or script (1-based)
        line: usize,
        /// Column number in the source code or script (1-based)
        column: usize,
        /// Optional source file name or identifier
        /// This might be null for REPL or dynamically generated code
        file: ?[]const u8 = null,
    };
};

/// Comprehensive set of all possible errors that can occur during VM operation.
/// Each error type is categorized and documented to help users understand
/// and handle specific error cases.
pub const VMError = error{
    // Memory-related errors
    /// Indicates that the VM could not allocate required memory
    /// This might occur during initialization or during operation
    OutOfMemory,

    /// Attempted to access memory outside of allowed bounds
    /// This often indicates a bug in user code or script
    MemoryAccessViolation,

    /// Stack space has been exhausted
    /// This might indicate infinite recursion or too deep call nesting
    StackOverflow,

    // Instruction-related errors
    /// Encountered an invalid or malformed instruction
    /// This might indicate corrupted bytecode or a compilation error
    InvalidInstruction,

    /// Attempted to use an operation not supported by the current VM configuration
    /// This might occur when using extended instructions that aren't enabled
    UnsupportedOperation,

    // Runtime-related errors
    /// Attempted to divide by zero
    /// This is a runtime arithmetic error that should be handled by user code
    DivisionByZero,

    /// Operand types don't match the operation requirements
    /// Example: Trying to add a string to a number
    TypeMismatch,

    // Resource-related errors
    /// A limited resource (other than memory) has been exhausted
    /// Example: Too many open files or network connections
    ResourceExhausted,

    // Configuration-related errors
    /// VM configuration contains invalid or incompatible settings
    /// This occurs during VM initialization with invalid configuration
    InvalidConfiguration,

    StackUnderflow,
    InvalidFunctionCall,
    InvalidMemoryAccess,
    InvalidAlignment,
    SecurityViolation,
};

pub const SecurityConfig = struct {
    /// Maximum allowed memory access
    max_memory: usize,
    /// Maximum allowed stack depth
    max_stack_depth: usize,
    /// Maximum instructions per execution
    max_instructions: usize,
    /// Allow self-modifying code
    allow_self_modify: bool,
};

/// Combines an error with its detailed context to provide comprehensive
/// error information and formatting capabilities.
pub const Error = struct {
    /// The specific error that occurred
    err: VMError,
    /// Detailed context about the error
    context: ErrorContext,

    /// Formats the error and its context into a human-readable message
    /// This method is called automatically when formatting the error with
    /// std.fmt.format() or printing it.
    ///
    /// Format options and fmt string are currently ignored as there is
    /// only one formatting style.
    pub fn format(
        self: Error,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        // Write error header with the error type
        try writer.print("\nError: {s}\n", .{@errorName(self.err)});

        // Write the operation that was being performed
        try writer.print("During: {s}\n", .{self.context.operation});

        // Write location information if available
        if (self.context.location) |loc| {
            if (loc.file) |file| {
                try writer.print("In file: {s}\n", .{file});
            }
            try writer.print("At line {d}, column {d}\n", .{ loc.line, loc.column });
        }

        // Write detailed error description
        try writer.print("\nDetails: {s}\n", .{self.context.details});

        // Write suggestion for fixing the error
        try writer.print("\nSuggestion: {s}\n", .{self.context.suggestion});
    }
};

/// Creates a new Error with full context.
/// This is the preferred way to create errors as it ensures all required
/// context information is provided.
///
/// Parameters:
///   - err: The specific VMError that occurred
///   - operation: Description of the operation being performed
///   - details: Detailed description of what went wrong
///   - suggestion: Actionable suggestion for fixing the error
///   - location: Optional location where the error occurred
///
/// Example:
/// ```zig
/// return createError(
///     .InvalidInstruction,
///     "executing ADD instruction",
///     "Register R15 does not exist",
///     "Use registers R0 through R14 only",
///     .{
///         .line = 42,
///         .column = 10,
///         .file = "script.zig",
///     },
/// );
/// ```
pub fn createError(
    comptime err: VMError,
    operation: []const u8,
    details: []const u8,
    suggestion: []const u8,
    location: ?ErrorContext.Location,
) VMError {
    // Print error information
    std.debug.print("\nError: {s}\n", .{@errorName(err)});
    std.debug.print("During: {s}\n", .{operation});

    // Print location if available
    if (location) |loc| {
        if (loc.file) |file| {
            std.debug.print("In file: {s}\n", .{file});
        }
        std.debug.print("At line {d}, column {d}\n", .{ loc.line, loc.column });
    }

    std.debug.print("Details: {s}\n", .{details});
    std.debug.print("Suggestion: {s}\n", .{suggestion});

    return err;
}

test "error formatting" {
    const err = createError(
        error.InvalidInstruction,
        "test operation",
        "test details",
        "test suggestion",
        .{
            .line = 1,
            .column = 1,
            .file = "test.zig",
        },
    );

    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try std.fmt.format(fbs.writer(), "{}", .{err});
}
