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
    const fb_ok = render.framebuffer.init(width, height);
    const db_ok = render.depth_buffer.init(width, height);
    return fb_ok and db_ok;
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

// =============================================================================
// Phase 3: 3D Cube Demo
// =============================================================================

// グローバル変数: 時間カウンター（フレーム数）
var frame_counter: u32 = 0;

/// 1フレームをレンダリング
/// Phase 3 デモ: 回転する3Dキューブを描画
export fn renderFrame() void {
    // バッファをクリア
    render.framebuffer.clear(0xFF000000); // 黒
    render.depth_buffer.clear();

    // 画面サイズを取得
    const width = @as(f32, @floatFromInt(render.framebuffer.getWidth()));
    const height = @as(f32, @floatFromInt(render.framebuffer.getHeight()));

    // 時間を進める（フレームカウンター）
    frame_counter +%= 1;
    const time = @as(f32, @floatFromInt(frame_counter)) * 0.016; // 約60FPS想定

    // カメラの設定
    const eye = math.vec.vec3.init(0.0, 0.0, 5.0); // カメラ位置
    const target = math.vec.vec3.init(0.0, 0.0, 0.0); // 注視点
    const up = math.vec.vec3.init(0.0, 1.0, 0.0); // 上方向

    const view = math.Mat4.lookAt(eye, target, up);
    const proj = math.Mat4.perspective(
        std.math.degreesToRadians(60.0), // 視野角60度
        width / height, // アスペクト比
        0.1, // ニアクリップ
        100.0, // ファークリップ
    );

    // Model行列: Y軸とX軸で回転
    const rot_y = math.Mat4.rotationY(time * 0.5);
    const rot_x = math.Mat4.rotationX(time * 0.3);
    const model = rot_y.mul(rot_x);

    // MVP行列を事前計算
    const mvp = proj.mul(view).mul(model);

    // キューブメッシュを取得
    const cube = render.mesh.getCubeMesh();

    // 各三角形を描画
    for (cube.indices) |tri| {
        const v0 = cube.vertices[tri.v0];
        const v1 = cube.vertices[tri.v1];
        const v2 = cube.vertices[tri.v2];

        // ローカル座標をクリップ座標に変換
        const clip0 = mvp.mulVec4(math.vec.vec4.fromVec3(v0.pos, 1.0));
        const clip1 = mvp.mulVec4(math.vec.vec4.fromVec3(v1.pos, 1.0));
        const clip2 = mvp.mulVec4(math.vec.vec4.fromVec3(v2.pos, 1.0));

        // 透視除算 → スクリーン座標変換
        const ndc0 = render.pipeline.clipToNDC(clip0);
        const ndc1 = render.pipeline.clipToNDC(clip1);
        const ndc2 = render.pipeline.clipToNDC(clip2);

        const screen0 = render.pipeline.ndcToScreen(ndc0, width, height);
        const screen1 = render.pipeline.ndcToScreen(ndc1, width, height);
        const screen2 = render.pipeline.ndcToScreen(ndc2, width, height);

        // バックフェイスカリング（2D判定）
        const p0 = math.vec.vec2.init(screen0[0], screen0[1]);
        const p1 = math.vec.vec2.init(screen1[0], screen1[1]);
        const p2 = math.vec.vec2.init(screen2[0], screen2[1]);

        if (!render.pipeline.isFrontFacing(p0, p1, p2)) {
            continue; // 裏面なのでスキップ
        }

        // 3D頂点を構築
        const sv0 = render.rasterizer.Vertex3DScreen{
            .screen_pos = screen0,
            .color = v0.color,
        };
        const sv1 = render.rasterizer.Vertex3DScreen{
            .screen_pos = screen1,
            .color = v1.color,
        };
        const sv2 = render.rasterizer.Vertex3DScreen{
            .screen_pos = screen2,
            .color = v2.color,
        };

        // 深度バッファ対応で描画
        render.rasterizer.fillTriangle3D(sv0, sv1, sv2);
    }
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
