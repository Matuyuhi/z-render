//! Depth Buffer (深度バッファ / Z-Buffer)
//! ========================================
//!
//! 3D描画における前後関係を正しく表現するための深度バッファ。
//!
//! ## 学習ポイント
//!
//! ### 1. Z-Bufferとは
//!
//! 各ピクセルに「奥行き（深度）」情報を保持し、
//! 描画時に「より手前にあるピクセル」だけを画面に表示します。
//!
//! ```
//! Frame 1: 赤い三角形を描画
//!   Color Buffer: [R, R, R, ...]
//!   Depth Buffer: [0.5, 0.5, 0.5, ...]
//!
//! Frame 2: 青い三角形を描画（より手前）
//!   新しいZ = 0.3 < 0.5 → 青を描画
//!   Color Buffer: [B, B, B, ...]
//!   Depth Buffer: [0.3, 0.3, 0.3, ...]
//!
//! Frame 3: 緑の三角形を描画（より奥）
//!   新しいZ = 0.7 > 0.3 → 描画しない（青が手前）
//!   Color Buffer: [B, B, B, ...] （変更なし）
//! ```
//!
//! ### 2. 深度値の範囲
//!
//! - NDC（正規化デバイス座標）では Z ∈ [-1, 1]
//! - 深度バッファでは通常 Z ∈ [0, 1] に正規化
//! - 0.0 = ニアクリップ平面（最も手前）
//! - 1.0 = ファークリップ平面（最も奥）
//!
//! ### 3. 深度精度問題
//!
//! 透視投影では、遠方ほど深度精度が低下します。
//! これを「Z-Fighting」と呼び、Phase 5でリバースZで改善します。
//!
//! ## TODO (Phase 5)
//!
//! - リバースZ（1.0 = near, 0.0 = far）で精度向上
//! - ハイアラーキカルZ-Buffer（階層的深度バッファ）

const std = @import("std");

/// 最大解像度（framebufferと同じ）
const MAX_WIDTH: u32 = 1920;
const MAX_HEIGHT: u32 = 1080;
const MAX_PIXELS: u32 = MAX_WIDTH * MAX_HEIGHT;

/// 深度バッファ（各ピクセルのZ値を保持）
var buffer: [MAX_PIXELS]f32 = undefined;

/// 現在の有効領域
var width: u32 = 0;
var height: u32 = 0;

// =============================================================================
// Public API
// =============================================================================

/// 深度バッファを初期化
/// @param w 幅
/// @param h 高さ
/// @return 成功ならtrue、サイズオーバーならfalse
pub fn init(w: u32, h: u32) bool {
    if (w > MAX_WIDTH or h > MAX_HEIGHT) {
        return false;
    }
    if (w == 0 or h == 0) {
        return false;
    }

    width = w;
    height = h;

    // 初期化時に最大深度（無限遠）でクリア
    clear();

    return true;
}

/// 深度バッファをクリア（すべてのピクセルを最大深度に設定）
///
/// ## 学習ポイント
///
/// - 最大深度 = 1.0（最も遠い）に設定
/// - これにより、すべての新しいピクセルが「より手前」として描画される
pub fn clear() void {
    const size = width * height;
    // すべてのピクセルを無限遠（1.0）に設定
    for (buffer[0..size]) |*depth| {
        depth.* = 1.0;
    }
}

/// 深度テスト＆書き込み
///
/// ## アルゴリズム
///
/// 1. 現在の深度値を読み取る
/// 2. 新しい深度値と比較
/// 3. 新しい値が手前なら、深度バッファを更新してtrueを返す
/// 4. そうでなければfalseを返す（描画しない）
///
/// ## 学習ポイント
///
/// - この関数が返すboolで「描画するか否か」を判断
/// - ラスタライザのホットパス（最も頻繁に呼ばれる）
/// - Phase 5でSIMD化予定
///
/// @param x X座標
/// @param y Y座標
/// @param depth 新しい深度値（0.0 = 手前、1.0 = 奥）
/// @return 描画すべきならtrue
pub fn testAndSet(x: u32, y: u32, depth: f32) bool {
    if (x >= width or y >= height) return false;

    const index = y * width + x;
    const current_depth = buffer[index];

    // 新しい深度が手前にある場合のみ描画
    if (depth < current_depth) {
        buffer[index] = depth;
        return true;
    }

    return false;
}

/// 深度値を取得（デバッグ用）
pub fn getDepth(x: u32, y: u32) ?f32 {
    if (x >= width or y >= height) return null;
    return buffer[y * width + x];
}

/// 幅を取得
pub fn getWidth() u32 {
    return width;
}

/// 高さを取得
pub fn getHeight() u32 {
    return height;
}

// =============================================================================
// テスト
// =============================================================================

test "init and clear" {
    const result = init(100, 100);
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(u32, 100), getWidth());
    try std.testing.expectEqual(@as(u32, 100), getHeight());

    // クリア後はすべて1.0
    try std.testing.expectEqual(@as(?f32, 1.0), getDepth(0, 0));
    try std.testing.expectEqual(@as(?f32, 1.0), getDepth(50, 50));
}

test "testAndSet basic" {
    _ = init(10, 10);

    // 最初は1.0なので、0.5は手前 → true
    try std.testing.expect(testAndSet(5, 5, 0.5));

    // 現在0.5なので、0.7は奥 → false
    try std.testing.expect(!testAndSet(5, 5, 0.7));

    // 現在0.5なので、0.3は手前 → true
    try std.testing.expect(testAndSet(5, 5, 0.3));

    // 最終的な深度は0.3
    try std.testing.expectEqual(@as(?f32, 0.3), getDepth(5, 5));
}

test "boundary check" {
    _ = init(10, 10);

    // 範囲外はfalse
    try std.testing.expect(!testAndSet(100, 100, 0.5));
}
