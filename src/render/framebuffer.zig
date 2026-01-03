//! Framebuffer (フレームバッファ)
//! ===============================
//!
//! ピクセルデータを格納するバッファを管理します。
//! WebAssemblyのリニアメモリ上に静的に確保されます。
//!
//! ## 学習ポイント
//!
//! ### 1. リニアメモリとは
//! Wasmは「リニアメモリ」という連続したバイト配列を持ちます。
//! このメモリはJS側から `WebAssembly.Memory` としてアクセス可能です。
//!
//! ### 2. 静的メモリ確保
//! Zigの `var buffer: [SIZE]T` は、コンパイル時にサイズが決まる静的配列です。
//! これはWasmのリニアメモリ内に配置され、ヒープ割り当てが不要です。
//!
//! ### 3. ポインタとスライス
//! - `[*]T`: 長さ不明のポインタ（C言語のポインタに近い）
//! - `[]T`: 長さ情報付きのスライス（安全だが、Wasmエクスポートには不向き）
//!
//! ### 4. 色のフォーマット
//! このプロジェクトでは ABGR (リトルエンディアン) 形式を使用:
//! ```
//! 0xAABBGGRR
//!   |  |  |  |
//!   |  |  |  +-- Red   (0-255)
//!   |  |  +----- Green (0-255)
//!   |  +-------- Blue  (0-255)
//!   +----------- Alpha (0-255)
//! ```
//! Canvas の ImageData は RGBA の順だが、u32として読み書きする場合は
//! リトルエンディアンのため逆順になる。

const std = @import("std");

/// 最大解像度 (1920x1080)
/// TODO: 動的リサイズ対応時に見直す
const MAX_WIDTH: u32 = 1920;
const MAX_HEIGHT: u32 = 1080;
const MAX_PIXELS: u32 = MAX_WIDTH * MAX_HEIGHT;

/// 静的フレームバッファ
/// Wasmのリニアメモリに配置される
var buffer: [MAX_PIXELS]u32 = undefined;

/// 現在の有効領域
var width: u32 = 0;
var height: u32 = 0;

// =============================================================================
// Public API
// =============================================================================

/// フレームバッファを初期化
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

    // 初期化時に黒でクリア
    clear(0xFF000000); // 不透明な黒

    return true;
}

/// バッファへのポインタを取得（JS側でメモリにアクセスするため）
pub fn getPtr() [*]u32 {
    return &buffer;
}

/// バッファサイズ（ピクセル数）を取得
pub fn getSize() u32 {
    return width * height;
}

/// 幅を取得
pub fn getWidth() u32 {
    return width;
}

/// 高さを取得
pub fn getHeight() u32 {
    return height;
}

/// 指定色でバッファをクリア
pub fn clear(color: u32) void {
    const size = width * height;
    // TODO: Phase 5 で SIMD 最適化
    for (buffer[0..size]) |*pixel| {
        pixel.* = color;
    }
}

/// 単一ピクセルを設定
/// 注意: 境界チェックあり。ホットパスでは直接バッファを操作すること
pub fn setPixel(x: u32, y: u32, color: u32) void {
    if (x >= width or y >= height) return;
    buffer[y * width + x] = color;
}

/// 単一ピクセルを取得
pub fn getPixel(x: u32, y: u32) ?u32 {
    if (x >= width or y >= height) return null;
    return buffer[y * width + x];
}

// =============================================================================
// ヘルパー関数
// =============================================================================

/// RGBA値からu32の色値を作成
/// Canvas の ImageData は RGBA 順だが、u32 として扱う場合は
/// リトルエンディアンのため ABGR 順に格納される
pub fn rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return @as(u32, a) << 24 |
        @as(u32, b) << 16 |
        @as(u32, g) << 8 |
        @as(u32, r);
}

// =============================================================================
// テスト
// =============================================================================

test "init and clear" {
    const result = init(100, 100);
    try std.testing.expect(result);
    try std.testing.expectEqual(@as(u32, 100), getWidth());
    try std.testing.expectEqual(@as(u32, 100), getHeight());
}

test "setPixel and getPixel" {
    _ = init(10, 10);
    setPixel(5, 5, 0xFFFF0000);
    try std.testing.expectEqual(@as(?u32, 0xFFFF0000), getPixel(5, 5));
}

test "boundary check" {
    _ = init(10, 10);
    setPixel(100, 100, 0xFFFFFFFF); // 範囲外は無視される
    try std.testing.expectEqual(@as(?u32, null), getPixel(100, 100));
}

test "rgba helper" {
    // 赤色 (R=255, G=0, B=0, A=255)
    const red = rgba(255, 0, 0, 255);
    // リトルエンディアンなので 0xFF0000FF ではなく 0xFF0000FF
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), red);
}
