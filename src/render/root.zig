//! Render Module
//! ==============
//!
//! レンダリングパイプラインの中核モジュール。
//! フレームバッファ管理、ラスタライズ、シェーディングを担当します。
//!
//! ## モジュール構成
//!
//! - `framebuffer`: ピクセルバッファの管理
//! - `rasterizer`: 三角形の塗りつぶし
//! - `depth_buffer`: 深度バッファ (Z-Buffer)
//! - `mesh`: 3Dメッシュデータ
//! - `pipeline`: レンダリングパイプライン全体の制御

pub const framebuffer = @import("framebuffer.zig");
pub const rasterizer = @import("rasterizer.zig");
pub const depth_buffer = @import("depth_buffer.zig");
pub const mesh = @import("mesh.zig");
pub const pipeline = @import("pipeline.zig");

// =============================================================================
// Phase 3 で追加するモジュール
// =============================================================================
// pub const depth_buffer = @import("depth_buffer.zig");
// pub const pipeline = @import("pipeline.zig");

test {
    _ = framebuffer;
    _ = rasterizer;
    _ = depth_buffer;
    _ = mesh;
    _ = pipeline;
}
