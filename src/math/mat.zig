//! Matrix Types (行列型)
//! ======================
//!
//! 4x4行列と変換操作を提供します。
//!
//! ## 学習ポイント
//!
//! ### 1. 同次座標系 (Homogeneous Coordinates)
//!
//! 3D座標を4次元で表現することで、平行移動を行列乗算で表現できます。
//!
//! ```
//! [x]   [m00 m01 m02 m03] [x']
//! [y] = [m10 m11 m12 m13] [y']
//! [z]   [m20 m21 m22 m23] [z']
//! [1]   [m30 m31 m32 m33] [w']
//! ```
//!
//! - 点 (point): w = 1.0 (平行移動の影響を受ける)
//! - 方向 (direction): w = 0.0 (平行移動の影響を受けない)
//!
//! ### 2. 行優先 vs 列優先 (Row-major vs Column-major)
//!
//! このプロジェクトでは **列優先 (Column-major)** を採用:
//! - OpenGL/WebGL と同じ慣習
//! - メモリ上では列が連続して並ぶ
//! - 行列の乗算は `M * v` (行列×ベクトル) の順
//!
//! ### 3. 座標変換パイプライン
//!
//! ```
//! Local → World → View → Clip → NDC → Screen
//!   |       |       |       |      |
//!   +-------+-------+-------+------+---→ それぞれ行列乗算
//! ```
//!
//! ## TODO (Phase 3 で実装)
//!
//! - [ ] Model 行列 (translate, rotate, scale)
//! - [ ] View 行列 (lookAt)
//! - [ ] Projection 行列 (perspective, orthographic)

const std = @import("std");
const vec = @import("vec.zig");

const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

/// 4x4行列 (列優先)
/// 各列が Vec4 として格納される
pub const Mat4 = struct {
    /// 列データ [col0, col1, col2, col3]
    cols: [4]Vec4,

    const Self = @This();

    // =========================================================================
    // コンストラクタ
    // =========================================================================

    /// 単位行列
    pub const identity: Mat4 = .{
        .cols = .{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };

    /// ゼロ行列
    pub const zero: Mat4 = .{
        .cols = .{
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
        },
    };

    // =========================================================================
    // 基本操作
    // =========================================================================

    /// 要素アクセス (row, col)
    pub inline fn at(self: Self, row: usize, col: usize) f32 {
        return self.cols[col][row];
    }

    /// 要素設定 (row, col)
    pub inline fn set(self: *Self, row: usize, col: usize, value: f32) void {
        self.cols[col][row] = value;
    }

    // =========================================================================
    // 変換行列の作成 (Phase 3 で実装)
    // =========================================================================

    /// 平行移動行列
    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        return .{
            .cols = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ x, y, z, 1.0 },
            },
        };
    }

    /// スケール行列
    pub fn scaling(x: f32, y: f32, z: f32) Mat4 {
        return .{
            .cols = .{
                .{ x, 0.0, 0.0, 0.0 },
                .{ 0.0, y, 0.0, 0.0 },
                .{ 0.0, 0.0, z, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// X軸回転行列
    pub fn rotationX(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, c, s, 0.0 },
                .{ 0.0, -s, c, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// Y軸回転行列
    pub fn rotationY(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ c, 0.0, -s, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ s, 0.0, c, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// Z軸回転行列
    pub fn rotationZ(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ c, s, 0.0, 0.0 },
                .{ -s, c, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    // =========================================================================
    // 行列演算
    // =========================================================================

    /// 行列×行列
    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;

        // 各列を計算
        inline for (0..4) |col| {
            // result.col[i] = a.col[0] * b[0][col] + a.col[1] * b[1][col] + ...
            const b_col = b.cols[col];
            const factor0: Vec4 = @splat(b_col[0]);
            const factor1: Vec4 = @splat(b_col[1]);
            const factor2: Vec4 = @splat(b_col[2]);
            const factor3: Vec4 = @splat(b_col[3]);

            result.cols[col] = a.cols[0] * factor0 +
                a.cols[1] * factor1 +
                a.cols[2] * factor2 +
                a.cols[3] * factor3;
        }

        return result;
    }

    /// 行列×ベクトル
    pub fn mulVec4(m: Mat4, v: Vec4) Vec4 {
        const factor0: Vec4 = @splat(v[0]);
        const factor1: Vec4 = @splat(v[1]);
        const factor2: Vec4 = @splat(v[2]);
        const factor3: Vec4 = @splat(v[3]);

        return m.cols[0] * factor0 +
            m.cols[1] * factor1 +
            m.cols[2] * factor2 +
            m.cols[3] * factor3;
    }

    // =========================================================================
    // View / Projection 行列 (Phase 3 で実装)
    // =========================================================================

    /// LookAt行列 (カメラ行列)
    /// TODO: 実装する
    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        _ = eye;
        _ = target;
        _ = up;
        // Phase 3 で実装
        return identity;
    }

    /// 透視投影行列
    /// TODO: 実装する
    pub fn perspective(fov_rad: f32, aspect: f32, near: f32, far: f32) Mat4 {
        _ = fov_rad;
        _ = aspect;
        _ = near;
        _ = far;
        // Phase 3 で実装
        return identity;
    }
};

// =============================================================================
// テスト
// =============================================================================

test "identity matrix" {
    const m = Mat4.identity;
    try std.testing.expectEqual(@as(f32, 1.0), m.at(0, 0));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(1, 1));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(2, 2));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(3, 3));
    try std.testing.expectEqual(@as(f32, 0.0), m.at(0, 1));
}

test "translation matrix" {
    const t = Mat4.translation(1.0, 2.0, 3.0);
    const v = Vec4{ 0.0, 0.0, 0.0, 1.0 };
    const result = t.mulVec4(v);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), result[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result[2], 0.0001);
}

test "matrix multiplication" {
    const a = Mat4.scaling(2.0, 2.0, 2.0);
    const b = Mat4.translation(1.0, 0.0, 0.0);

    // scale then translate
    const m = Mat4.mul(b, a);
    const v = Vec4{ 1.0, 0.0, 0.0, 1.0 };
    const result = m.mulVec4(v);

    // 1 * 2 + 1 = 3
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result[0], 0.0001);
}
