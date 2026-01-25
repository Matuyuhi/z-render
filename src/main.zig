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

// =============================================================================
// Phase 2: 三角形描画
// =============================================================================

/// 単色の三角形を描画
/// @param x0, y0, x1, y1, x2, y2: 3頂点の座標
/// @param color: ABGR形式の色 (0xAABBGGRR)
export fn drawTriangle(
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    color: u32,
) void {
    const v0 = math.vec.vec2.init(x0, y0);
    const v1 = math.vec.vec2.init(x1, y1);
    const v2 = math.vec.vec2.init(x2, y2);
    render.rasterizer.fillTriangle(v0, v1, v2, color);
}

/// 頂点カラー補間の三角形を描画 (Gouraud Shading)
/// @param x0, y0, r0, g0, b0, a0: 頂点0の座標と色
/// @param x1, y1, r1, g1, b1, a1: 頂点1の座標と色
/// @param x2, y2, r2, g2, b2, a2: 頂点2の座標と色
/// @note: 色の各成分は 0.0 〜 1.0 の範囲
export fn drawTriangleGouraud(
    x0: f32,
    y0: f32,
    r0: f32,
    g0: f32,
    b0: f32,
    a0: f32,
    x1: f32,
    y1: f32,
    r1: f32,
    g1: f32,
    b1: f32,
    a1: f32,
    x2: f32,
    y2: f32,
    r2: f32,
    g2: f32,
    b2: f32,
    a2: f32,
) void {
    const v0 = render.rasterizer.Vertex2D.init(x0, y0, r0, g0, b0, a0);
    const v1 = render.rasterizer.Vertex2D.init(x1, y1, r1, g1, b1, a1);
    const v2 = render.rasterizer.Vertex2D.init(x2, y2, r2, g2, b2, a2);
    render.rasterizer.fillTriangleInterpolated(v0, v1, v2);
}

/// 1フレームをレンダリング
/// Phase 2 デモ: Hello World Triangle を描画
export fn renderFrame() void {
    // 黒でクリア
    render.framebuffer.clear(0xFF000000);

    // 画面サイズを取得
    const width = @as(f32, @floatFromInt(render.framebuffer.getWidth()));
    const height = @as(f32, @floatFromInt(render.framebuffer.getHeight()));

    // 画面中央に三角形を描画（Gouraud Shading）
    const cx = width / 2.0;
    const cy = height / 2.0;
    const size: f32 = 200.0;

    // 頂点座標（画面中央を基準に、上・左下・右下の正三角形風）
    const x0 = cx;
    const y0 = cy - size;
    const x1 = cx - size * 0.866; // cos(30度) ≈ 0.866
    const y1 = cy + size * 0.5;
    const x2 = cx + size * 0.866;
    const y2 = cy + size * 0.5;

    // 頂点カラー（赤・緑・青）
    drawTriangleGouraud(
        x0, y0, 1.0, 0.0, 0.0, 1.0, // 頂点0: 赤
        x1, y1, 0.0, 1.0, 0.0, 1.0, // 頂点1: 緑
        x2, y2, 0.0, 0.0, 1.0, 1.0, // 頂点2: 青
    );
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
