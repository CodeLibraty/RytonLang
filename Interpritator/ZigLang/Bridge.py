from pathlib import Path
import subprocess
import hashlib
import os

class ZigBridge:
    def __init__(self):
        self.cache_dir = Path(".zig_cache")
        self.cache_dir.mkdir(exist_ok=True)

    def _run_binary(self, binary_path):
        result = subprocess.run(
            str(binary_path), 
            capture_output=True, 
            text=True
        )
        return result.stdout

    def compile_and_run(self, zig_code: str, mode="bin", cache=True):
        if cache:
            code_hash = hashlib.md5(zig_code.encode()).hexdigest()
            cache_path = self.cache_dir / f"{code_hash}.exe"
            if cache_path.exists():
                return self._run_binary(cache_path)
        
        return self._compile_and_execute(zig_code, mode)

    def _create_build_zig(self):
        build_content = """
    const std = @import("std");

    pub fn build(b: *std.build.Builder) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});
        
        const exe = b.addExecutable(.{
            .name = "temp",
            .root_source_file = .{ .path = "./zig/src/temp.zig" },
            .target = target,
            .optimize = optimize,
        });
        
        b.installArtifact(exe);
    }
    """
        Path("zig/build.zig").write_text(build_content)

    def _compile_and_execute(self, code, mode):
        self._create_build_zig()
        temp_file = Path("zig/src/temp.zig")
        temp_file.write_text(code)
        
        if mode == "run":
            result = subprocess.run(["./Interpritator/ZigLang/zig", "run", "zig/src/temp.zig"]) 
        elif mode == "obj":
            subprocess.run(["./Interpritator/ZigLang/zig", "build-obj", "temp.zig"])
            result = Path("temp.o")
        elif mode == "lib":
            subprocess.run(["./Interpritator/ZigLang/zig", "build-lib", "temp.zig"])
            result = Path("temp.lib")
            
        return result
