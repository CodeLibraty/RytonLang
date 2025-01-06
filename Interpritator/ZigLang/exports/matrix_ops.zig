
const std = @import("std");

export fn matrixMultiply(a: [*]f64, b: [*]f64) void {
    var i: usize = 0;
    while (i < size) : (i += 1) {
        var j: usize = 0;
        while (j < size) : (j += 1) {
            var sum: f64 = 0;
            var k: usize = 0;
            while (k < size) : (k += 1) {
                sum += a[i * size + k] * b[k * size + j];
            }
            result[i * size + j] = sum;
        }
    }
}

