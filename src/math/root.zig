//! Math Module
//! ============
//!
//! SIMD最適化された3Dグラフィックス用数学ライブラリ。
//! ベクトル演算と行列演算を提供します。
//!
//! ## 設計方針
//!
//! 1. **SIMD First**: すべての演算を `@Vector` 型で実装
//! 2. **Zero Allocation**: ヒープ割り当てなし
//! 3. **Inline by Default**: 小さな関数は積極的にインライン化
//!
//! ## モジュール構成
//!
//! - `vec`: ベクトル型 (Vec2, Vec3, Vec4)
//! - `mat`: 行列型 (Mat4)

pub const vec = @import("vec.zig");
pub const mat = @import("mat.zig");

// 便利なエイリアス
pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;
pub const Mat4 = mat.Mat4;

test {
    _ = vec;
    _ = mat;
}
