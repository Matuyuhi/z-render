//! Vector Types (ベクトル型)
//! ==========================
//!
//! SIMD最適化されたベクトル型を提供します。
//!
//! ## 学習ポイント
//!
//! ### 1. Zig の @Vector 型
//!
//! `@Vector(N, T)` はコンパイラに対して「この配列は並列演算可能」と伝えます。
//! ターゲットアーキテクチャに応じて、自動的にSIMD命令に変換されます。
//!
//! ```zig
//! const a: @Vector(4, f32) = .{ 1.0, 2.0, 3.0, 4.0 };
//! const b: @Vector(4, f32) = .{ 5.0, 6.0, 7.0, 8.0 };
//! const c = a + b;  // SIMD加算！ 4つの演算が1命令で完了
//! ```
//!
//! ### 2. WebAssembly SIMD
//!
//! Wasm SIMD は 128-bit レジスタを持ち、以下の並列演算が可能:
//! - 4 x f32 (32-bit float × 4)
//! - 2 x f64 (64-bit float × 2)
//! - 4 x i32, 8 x i16, 16 x i8 など
//!
//! Vec4 (4 x f32) は Wasm SIMD レジスタにちょうど収まる！
//!
//! ### 3. メモリレイアウト
//!
//! ```
//! Vec4: [x, y, z, w] = 16 bytes (128 bits)
//!       |<--- SIMD レジスタ 1つ分 --->|
//! ```
//!
//! ## TODO (Phase 1 で実装)
//!
//! - [ ] dot product (内積)
//! - [ ] cross product (外積、Vec3のみ)
//! - [ ] normalize (正規化)
//! - [ ] length / length_squared

const std = @import("std");

/// 2次元ベクトル (スクリーン座標など)
pub const Vec2 = @Vector(2, f32);

/// 3次元ベクトル (ワールド座標、法線など)
pub const Vec3 = @Vector(3, f32);

/// 4次元ベクトル (同次座標、RGBA色など)
/// Wasm SIMD の 128-bit レジスタにぴったり収まる
pub const Vec4 = @Vector(4, f32);

// =============================================================================
// Vec2 Operations
// =============================================================================

pub const vec2 = struct {
    /// ゼロベクトル
    pub const zero: Vec2 = .{ 0.0, 0.0 };

    /// 新規作成
    pub inline fn init(x: f32, y: f32) Vec2 {
        return .{ x, y };
    }

    /// 内積 (dot product)
    /// 計算: a.x * b.x + a.y * b.y
    pub inline fn dot(a: Vec2, b: Vec2) f32 {
        // TODO: SIMD最適化
        // 現在は @reduce を使用（コンパイラが最適化する）
        return @reduce(.Add, a * b);
    }

    /// ベクトルの長さの2乗
    pub inline fn lengthSquared(v: Vec2) f32 {
        return dot(v, v);
    }

    /// ベクトルの長さ
    pub inline fn length(v: Vec2) f32 {
        return @sqrt(lengthSquared(v));
    }
};

// =============================================================================
// Vec3 Operations
// =============================================================================

pub const vec3 = struct {
    /// ゼロベクトル
    pub const zero: Vec3 = .{ 0.0, 0.0, 0.0 };

    /// 新規作成
    pub inline fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ x, y, z };
    }

    /// 内積 (dot product)
    pub inline fn dot(a: Vec3, b: Vec3) f32 {
        return @reduce(.Add, a * b);
    }

    /// 外積 (cross product)
    /// 計算: (a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x)
    pub inline fn cross(a: Vec3, b: Vec3) Vec3 {
        // TODO: より効率的なSIMD実装を検討
        const a_yzx: Vec3 = .{ a[1], a[2], a[0] };
        const a_zxy: Vec3 = .{ a[2], a[0], a[1] };
        const b_yzx: Vec3 = .{ b[1], b[2], b[0] };
        const b_zxy: Vec3 = .{ b[2], b[0], b[1] };

        return a_yzx * b_zxy - a_zxy * b_yzx;
    }

    /// ベクトルの長さの2乗
    pub inline fn lengthSquared(v: Vec3) f32 {
        return dot(v, v);
    }

    /// ベクトルの長さ
    pub inline fn length(v: Vec3) f32 {
        return @sqrt(lengthSquared(v));
    }

    /// 正規化 (長さを1にする)
    pub inline fn normalize(v: Vec3) Vec3 {
        const len = length(v);
        if (len == 0.0) return zero;
        const inv_len: Vec3 = @splat(1.0 / len);
        return v * inv_len;
    }
};

// =============================================================================
// Vec4 Operations
// =============================================================================

pub const vec4 = struct {
    /// ゼロベクトル
    pub const zero: Vec4 = .{ 0.0, 0.0, 0.0, 0.0 };

    /// 新規作成
    pub inline fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ x, y, z, w };
    }

    /// Vec3 + w から作成
    pub inline fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ v[0], v[1], v[2], w };
    }

    /// 内積 (dot product)
    pub inline fn dot(a: Vec4, b: Vec4) f32 {
        return @reduce(.Add, a * b);
    }

    /// ベクトルの長さの2乗
    pub inline fn lengthSquared(v: Vec4) f32 {
        return dot(v, v);
    }

    /// ベクトルの長さ
    pub inline fn length(v: Vec4) f32 {
        return @sqrt(lengthSquared(v));
    }

    /// 正規化
    pub inline fn normalize(v: Vec4) Vec4 {
        const len = length(v);
        if (len == 0.0) return zero;
        const inv_len: Vec4 = @splat(1.0 / len);
        return v * inv_len;
    }

    /// xyz成分だけを取り出す
    pub inline fn xyz(v: Vec4) Vec3 {
        return .{ v[0], v[1], v[2] };
    }
};

// =============================================================================
// テスト
// =============================================================================

test "vec2 dot product" {
    const a = vec2.init(1.0, 2.0);
    const b = vec2.init(3.0, 4.0);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), vec2.dot(a, b), 0.0001);
}

test "vec3 cross product" {
    // x × y = z
    const x = vec3.init(1.0, 0.0, 0.0);
    const y = vec3.init(0.0, 1.0, 0.0);
    const z = vec3.cross(x, y);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), z[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), z[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), z[2], 0.0001);
}

test "vec3 normalize" {
    const v = vec3.init(3.0, 0.0, 4.0);
    const n = vec3.normalize(v);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), vec3.length(n), 0.0001);
}

test "vec4 from vec3" {
    const v3 = vec3.init(1.0, 2.0, 3.0);
    const v4 = vec4.fromVec3(v3, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), v4[0]);
    try std.testing.expectEqual(@as(f32, 2.0), v4[1]);
    try std.testing.expectEqual(@as(f32, 3.0), v4[2]);
    try std.testing.expectEqual(@as(f32, 1.0), v4[3]);
}
