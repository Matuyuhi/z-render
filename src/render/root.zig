//! Render Module
//! ==============
//!
//! レンダリングパイプラインの中核モジュール。
//! フレームバッファ管理、ラスタライズ、シェーディングを担当します。
//!
//! ## モジュール構成
//!
//! - `framebuffer`: ピクセルバッファの管理
//! - (TODO) `rasterizer`: 三角形の塗りつぶし
//! - (TODO) `pipeline`: レンダリングパイプライン全体の制御

pub const framebuffer = @import("framebuffer.zig");

// =============================================================================
// Phase 2 で追加するモジュール
// =============================================================================
// pub const rasterizer = @import("rasterizer.zig");
// pub const triangle = @import("triangle.zig");

// =============================================================================
// Phase 3 で追加するモジュール
// =============================================================================
// pub const depth_buffer = @import("depth_buffer.zig");
// pub const pipeline = @import("pipeline.zig");

test {
    _ = framebuffer;
}
