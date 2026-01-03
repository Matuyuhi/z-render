//! Z-Render: Software GPU for WebAssembly
//! ========================================
//!
//! このファイルはWasmモジュールのエントリーポイントです。
//! JS側から呼び出される関数をexportし、各モジュールを統合します。
//!
//! ## アーキテクチャ概要
//!
//! ```
//! [JavaScript] <---> [main.zig (exports)] <---> [render/] <---> [math/]
//!      |                     |
//!      v                     v
//!   Canvas              Framebuffer
//! ```
//!
//! ## 学習ポイント
//!
//! 1. `export` キーワード: JS側から関数を呼び出し可能にする
//! 2. ポインタ演算: Wasmのリニアメモリを直接操作
//! 3. SIMD: `@Vector` 型で並列演算を実現

const std = @import("std");

// モジュールのインポート
pub const math = @import("math/root.zig");
pub const render = @import("render/root.zig");

// =============================================================================
// Wasm Export Functions (JS側から呼び出される関数)
// =============================================================================

/// フレームバッファのポインタを取得
/// JS側でこのポインタを使って直接メモリにアクセスできる
export fn getFramebufferPtr() [*]u32 {
    return render.framebuffer.getPtr();
}

/// フレームバッファのサイズ（ピクセル数）を取得
export fn getFramebufferSize() u32 {
    return render.framebuffer.getSize();
}

/// フレームバッファの幅を取得
export fn getFramebufferWidth() u32 {
    return render.framebuffer.getWidth();
}

/// フレームバッファの高さを取得
export fn getFramebufferHeight() u32 {
    return render.framebuffer.getHeight();
}

/// フレームバッファを初期化
/// @param width 幅（ピクセル）
/// @param height 高さ（ピクセル）
/// @return 成功なら true
export fn initFramebuffer(width: u32, height: u32) bool {
    return render.framebuffer.init(width, height);
}

/// フレームバッファを指定色でクリア
/// @param color RGBA形式の色（0xRRGGBBAA）
export fn clearFramebuffer(color: u32) void {
    render.framebuffer.clear(color);
}

/// 1フレームをレンダリング
/// TODO: ここに描画ロジックを追加していく
export fn renderFrame() void {
    // Phase 2 で実装: 三角形の描画など
    _ = 0;
}

// =============================================================================
// テスト
// =============================================================================

test "math module" {
    _ = math;
}

test "render module" {
    _ = render;
}
