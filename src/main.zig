const std = @import("std");
const mem = std.mem;
const process = std.process;
const fs = std.fs;
const path = fs.path;

pub fn main() anyerror!void {
    var context = std.StringHashMap([]u8).init(std.heap.c_allocator);
    var arg_it = process.args();

    _ = arg_it.skip();

    const name = try (arg_it.next(std.heap.c_allocator) orelse {
        std.debug.warn("First argument should be the name\n", .{});
        return error.InvalidArgs;
    });
    const package = try (arg_it.next(std.heap.c_allocator) orelse {
        std.debug.warn("Second argument should be the package\n", .{});
        return error.InvalidArgs;
    });
    const java_version = try (arg_it.next(std.heap.c_allocator) orelse {
        std.debug.warn("Third argument should be the java version\n", .{});
        return error.InvalidArgs;
    });

    var joined = try path.join(std.heap.c_allocator, &[_][]const u8{
        name,
        "src",
        "main",
        "java",
        try replaceAscii(package, '.', path.sep),
        try toLowerCaseAscii(name),
    });

    std.debug.warn("{}\n", .{joined});

    _ = try context.put("name", name);
    _ = try context.put("lowerName", try toLowerCaseAscii(name));
    _ = try context.put("package", package);
    _ = try context.put("java_version", java_version);

    var pomTemplate = try loadTemplate("../pom.xml.template");
    var javaTemplate = try loadTemplate("../Main.java.template");

    var current = fs.cwd();
    try current.makePath(joined);
    var javaFile = try (try current.openDirList(joined)).createFile("Main.java", .{});
    var pomFile = try (try current.openDirList(name)).createFile("pom.xml", .{});
    try javaFile.writeAll(try writeTemplate(javaTemplate, context));
    try pomFile.writeAll(try writeTemplate(pomTemplate, context));
}

pub fn toLowerCaseAscii(string: []u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(std.heap.c_allocator);

    for (string) |c| {
        if (c >= 65 and c <= 90) {
            try buffer.append(c + 32);
        } else {
            try buffer.append(c);
        }
    }

    return buffer.span();
}

pub fn replaceAscii(string: []u8, from: u8, to: u8) ![]u8 {
    var buffer = std.ArrayList(u8).init(std.heap.c_allocator);

    for (string) |c| {
        if (c == from) {
            try buffer.append(to);
        } else {
            try buffer.append(c);
        }
    }

    return buffer.span();
}

pub fn writeTemplate(templateParts: []TemplatePart, context: std.StringHashMap([]u8)) ![]u8 {
    var buffer = std.ArrayList(u8).init(std.heap.c_allocator);

    for (templateParts) |part| {
        switch (part) {
            TemplatePartTag.Text => |value| {
                for (value) |char| {
                    try buffer.append(char);
                }
            },
            TemplatePartTag.TemplateName => |value| {
                if (context.get(value)) |templateValue| {
                    for (templateValue.value) |char| {
                        try buffer.append(char);
                    }
                }
            },
        }
    }

    return buffer.span();
}

const TemplatePartTag = enum {
    Text,
    TemplateName,
};

const TemplatePart = union(TemplatePartTag) {
    Text: []u8,
    TemplateName: []u8,
};

pub fn loadTemplate(comptime file_name: []const u8) ![]TemplatePart {
    var result = std.ArrayList(TemplatePart).init(std.heap.c_allocator);

    const content = @embedFile(file_name);
    var buffer = std.ArrayList(u8).init(std.heap.c_allocator);
    var in_template = false;
    var last_char: ?u8 = null;
    var just_entered = false;
    var just_left = false;
    for (content) |value| {
        if (last_char) |lc| {
            if (value == '{' and lc == '{') {
                in_template = true;
                just_entered = true;
                try result.append(TemplatePart{ .Text = buffer.span() });
                buffer = std.ArrayList(u8).init(std.heap.c_allocator);
            } else if (value == '}' and lc == '}') {
                in_template = false;
                just_left = true;
                try result.append(TemplatePart{ .TemplateName = buffer.span() });
                buffer = std.ArrayList(u8).init(std.heap.c_allocator);
            } else {
                if (in_template) {
                    if (!just_entered) {
                        try buffer.append(lc);
                    } else {
                        just_entered = false;
                    }
                } else {
                    if (!just_left) {
                        try buffer.append(lc);
                    } else {
                        just_left = false;
                    }
                }
            }
        }

        last_char = value;
    }

    if (last_char) |lc| {
        try buffer.append(lc);
    }

    try result.append(TemplatePart{ .Text = buffer.span() });
    return result.span();
}
