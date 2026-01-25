//! Rasterizer (ラスタライザ)
//! ==========================
//!
//! 三角形を画面上のピクセルに変換する機能を提供します。
//! これは3Dグラフィックスパイプラインの中核となる処理です。
//!
//! ## 学習ポイント
//!
//! ### 1. ラスタライズとは
//! ベクトルデータ（頂点座標）をピクセルデータに変換する処理。
//! 「どのピクセルが三角形の内側にあるか」を判定し、色を塗る。
//!
//! ### 2. 重心座標 (Barycentric Coordinates)
//! 三角形内の任意の点を、3頂点の重み付き和として表現する手法。
//! 属性補間（色、テクスチャ座標、法線など）に必須。
//!
//! ### 3. エッジ関数 (Edge Function)
//! 点が辺のどちら側にあるかを判定する関数。
//! 3つの辺すべてで同じ側にあれば、点は三角形の内側。
//!
//! ## Phase 2 での実装範囲
//!
//! - ✅ バウンディングボックス計算
//! - ✅ エッジ関数による内外判定
//! - ✅ 重心座標計算
//! - ✅ 単色塗りつぶし
//! - ✅ 頂点カラー補間 (Gouraud Shading)
//!
//! ## TODO (Phase 3)
//!
//! - [ ] Zバッファによる深度テスト
//! - [ ] パースペクティブコレクト補間
//! - [ ] テクスチャマッピング

const std = @import("std");
const math = @import("../math/root.zig");
const Vec2 = math.Vec2;
const Vec4 = math.Vec4;
const vec2 = math.vec.vec2;
const vec4 = math.vec.vec4;
const framebuffer = @import("framebuffer.zig");

// =============================================================================
// 基本型定義
// =============================================================================

/// 2D頂点（座標 + 色）
/// Gouraud Shadingで使用
pub const Vertex2D = struct {
    pos: Vec2, // 画面座標 (x, y)
    color: Vec4, // 色 (r, g, b, a) ※各成分は 0.0 〜 1.0

    /// 頂点を生成
    pub fn init(x: f32, y: f32, r: f32, g: f32, b: f32, a: f32) Vertex2D {
        return .{
            .pos = vec2.init(x, y),
            .color = vec4.init(r, g, b, a),
        };
    }
};

/// バウンディングボックス（矩形領域）
pub const BoundingBox = struct {
    min_x: i32,
    min_y: i32,
    max_x: i32,
    max_y: i32,
};

// =============================================================================
// Step 1: バウンディングボックス計算
// =============================================================================

/// 3頂点からバウンディングボックスを計算
///
/// ## アルゴリズム
///
/// 1. 3頂点のx座標の最小値・最大値を求める
/// 2. 3頂点のy座標の最小値・最大値を求める
/// 3. 画面範囲内にクリッピング
///
/// ## 図解
///
/// ```
///       v1
///       /\
///      /  \
///     /____\
///    v0      v2
///
///   +----------------+  <- BoundingBox
///   |   v1           |
///   |   /\           |
///   |  /  \          |
///   | /____\         |
///   |v0      v2      |
///   +----------------+
/// ```
///
/// ## 学習ポイント
///
/// - すべてのピクセルをチェックするのは無駄
/// - 三角形を囲む最小矩形だけをスキャンすれば効率的
/// - クリッピングで画面外アクセスを防ぐ
///
/// ## TODO (Phase 5)
///
/// - タイルベースレンダリングでさらに最適化
pub fn computeBoundingBox(v0: Vec2, v1: Vec2, v2: Vec2) BoundingBox {
    const width = @as(i32, @intCast(framebuffer.getWidth()));
    const height = @as(i32, @intCast(framebuffer.getHeight()));

    // 各頂点の座標を整数に変換
    const x0 = @as(i32, @intFromFloat(v0[0]));
    const y0 = @as(i32, @intFromFloat(v0[1]));
    const x1 = @as(i32, @intFromFloat(v1[0]));
    const y1 = @as(i32, @intFromFloat(v1[1]));
    const x2 = @as(i32, @intFromFloat(v2[0]));
    const y2 = @as(i32, @intFromFloat(v2[1]));

    // 最小値・最大値を計算
    var min_x = @min(x0, @min(x1, x2));
    var min_y = @min(y0, @min(y1, y2));
    var max_x = @max(x0, @max(x1, x2));
    var max_y = @max(y0, @max(y1, y2));

    // 画面範囲内にクリッピング
    min_x = @max(0, min_x);
    min_y = @max(0, min_y);
    max_x = @min(width - 1, max_x);
    max_y = @min(height - 1, max_y);

    return BoundingBox{
        .min_x = min_x,
        .min_y = min_y,
        .max_x = max_x,
        .max_y = max_y,
    };
}

// =============================================================================
// Step 2: エッジ関数
// =============================================================================

/// エッジ関数 - 点が辺のどちら側にあるかを判定
///
/// ## アルゴリズム
///
/// 2D外積（cross product）を使用:
/// ```
/// edge(a, b, p) = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
/// ```
///
/// 結果の符号が示すもの:
/// - 正: 点pは辺abの「左側」にある
/// - 負: 点pは辺abの「右側」にある
/// - 0: 点pは辺ab上にある
///
/// ## 図解
///
/// ```
///      a ----------> b
///      |
///      |  p (左側: edge > 0)
///      |
///
///      a ----------> b
///                    |
///          p (右側: edge < 0)
///                    |
/// ```
///
/// ## 学習ポイント
///
/// - 3つの辺すべてで同じ符号なら、点は三角形内部
/// - 頂点の巻き順（CCW/CW）が重要
/// - このプロジェクトでは反時計回り（CCW）を採用
///
/// ## TODO (Phase 3)
///
/// - バックフェイスカリング対応
pub fn edgeFunction(a: Vec2, b: Vec2, p: Vec2) f32 {
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]);
}

// =============================================================================
// Step 3: 重心座標計算
// =============================================================================

/// 重心座標を計算
///
/// ## アルゴリズム
///
/// 点pを3頂点の線形結合として表現:
/// ```
/// p = w0 * v0 + w1 * v1 + w2 * v2
/// ただし w0 + w1 + w2 = 1
/// ```
///
/// 各重みはエッジ関数を使って計算:
/// ```
/// area = edge(v0, v1, v2)  // 三角形全体の面積（×2）
/// w0 = edge(v1, v2, p) / area
/// w1 = edge(v2, v0, p) / area
/// w2 = edge(v0, v1, p) / area
/// ```
///
/// ## 図解
///
/// ```
///       v2
///       /\
///      /p \ <- この点の重心座標を求める
///     /____\
///    v0     v1
///
/// pがv0に近い → w0が大きい
/// pがv1に近い → w1が大きい
/// pがv2に近い → w2が大きい
/// ```
///
/// ## 学習ポイント
///
/// - 重心座標は属性補間に使う（色、UV、法線など）
/// - すべての重みが 0 〜 1 なら、点は三角形内部
/// - 重みの合計は常に1.0
///
/// ## TODO (Phase 3)
///
/// - パースペクティブコレクト補間（w座標を考慮）
pub fn barycentric(v0: Vec2, v1: Vec2, v2: Vec2, p: Vec2) Vec4 {
    const area = edgeFunction(v0, v1, v2);

    // 退化した三角形（面積0）の場合
    if (@abs(area) < 0.0001) {
        return vec4.init(0, 0, 0, 0);
    }

    const w0 = edgeFunction(v1, v2, p) / area;
    const w1 = edgeFunction(v2, v0, p) / area;
    const w2 = edgeFunction(v0, v1, p) / area;

    return vec4.init(w0, w1, w2, 0);
}

// =============================================================================
// Step 4: 三角形塗りつぶし（単色）
// =============================================================================

/// 三角形を単色で塗りつぶす
///
/// ## アルゴリズム
///
/// 1. バウンディングボックスを計算
/// 2. その範囲内のすべてのピクセルをループ
/// 3. 各ピクセルが三角形内部かを重心座標で判定
/// 4. 内部なら色を書き込む
///
/// ## 図解
///
/// ```
/// +---+---+---+---+
/// | x | x | x | x |  <- バウンディングボックスをスキャン
/// +---+---+---+---+
/// | x | ■ | ■ | x |  ■ = 三角形内部（描画）
/// +---+---+---+---+  x = 三角形外部（スキップ）
/// | x | x | x | x |
/// +---+---+---+---+
/// ```
///
/// ## 学習ポイント
///
/// - **ポインタ演算でフレームバッファに直接書き込む**
/// - setPixel()を使うと境界チェックで遅くなる
/// - ホットパスでは安全性より速度を優先
///
/// ## TODO (Phase 5)
///
/// - SIMD並列化（複数ピクセルを同時処理）
/// - ハーフスペース最適化
pub fn fillTriangle(v0: Vec2, v1: Vec2, v2: Vec2, color: u32) void {
    const bbox = computeBoundingBox(v0, v1, v2);
    const fb_ptr = framebuffer.getPtr();
    const width = framebuffer.getWidth();

    // バウンディングボックス内の各ピクセルをチェック
    var y: i32 = bbox.min_y;
    while (y <= bbox.max_y) : (y += 1) {
        var x: i32 = bbox.min_x;
        while (x <= bbox.max_x) : (x += 1) {
            const p = vec2.init(@floatFromInt(x), @floatFromInt(y));
            const bc = barycentric(v0, v1, v2, p);

            // 重心座標がすべて非負なら内部
            if (bc[0] >= 0 and bc[1] >= 0 and bc[2] >= 0) {
                // ポインタ演算で直接書き込み（高速化）
                const index = @as(u32, @intCast(y)) * width + @as(u32, @intCast(x));
                fb_ptr[index] = color;
            }
        }
    }
}

// =============================================================================
// Step 5: Gouraud Shading（頂点カラー補間）
// =============================================================================

/// Vec4の色をu32に変換
///
/// ## アルゴリズム
///
/// Vec4 (r, g, b, a) の各成分を 0.0〜1.0 から 0〜255 に変換し、
/// ABGR形式のu32にパックする。
///
/// ## 学習ポイント
///
/// - `@max(0, @min(1, value))` でクランプ（0〜1の範囲に制限）
/// - リトルエンディアンなので ABGR 順にシフト
pub fn vec4ToColor(v: Vec4) u32 {
    // 0.0 〜 1.0 にクランプ
    const r = @max(0.0, @min(1.0, v[0]));
    const g = @max(0.0, @min(1.0, v[1]));
    const b = @max(0.0, @min(1.0, v[2]));
    const a = @max(0.0, @min(1.0, v[3]));

    // 0 〜 255 に変換
    const r8: u32 = @intFromFloat(r * 255.0);
    const g8: u32 = @intFromFloat(g * 255.0);
    const b8: u32 = @intFromFloat(b * 255.0);
    const a8: u32 = @intFromFloat(a * 255.0);

    // ABGR形式にパック
    return (a8 << 24) | (b8 << 16) | (g8 << 8) | r8;
}

/// 頂点カラーを補間して三角形を塗りつぶす（Gouraud Shading）
///
/// ## アルゴリズム
///
/// 1. バウンディングボックス内の各ピクセルをスキャン
/// 2. 重心座標を計算
/// 3. 重心座標を使って3頂点の色を補間
///    ```
///    color = w0 * v0.color + w1 * v1.color + w2 * v2.color
///    ```
/// 4. 補間した色を描画
///
/// ## 図解
///
/// ```
///        赤 (v2)
///        /\
///       /  \
///      / グ \  <- 重心座標で色を補間
///     / ラデ \
///    /________\
///  青(v0)    緑(v1)
/// ```
///
/// ## 学習ポイント
///
/// - これが「スムーズシェーディング」の基礎
/// - 各ピクセルで色を補間するため滑らかなグラデーションになる
/// - Phase 3では法線も同様に補間（フォンシェーディング）
///
/// ## TODO (Phase 3)
///
/// - パースペクティブコレクト補間
/// - フォンシェーディング（ピクセルごとにライティング）
pub fn fillTriangleInterpolated(v0: Vertex2D, v1: Vertex2D, v2: Vertex2D) void {
    const bbox = computeBoundingBox(v0.pos, v1.pos, v2.pos);
    const fb_ptr = framebuffer.getPtr();
    const width = framebuffer.getWidth();

    var y: i32 = bbox.min_y;
    while (y <= bbox.max_y) : (y += 1) {
        var x: i32 = bbox.min_x;
        while (x <= bbox.max_x) : (x += 1) {
            const p = vec2.init(@floatFromInt(x), @floatFromInt(y));
            const bc = barycentric(v0.pos, v1.pos, v2.pos, p);

            // 重心座標がすべて非負なら内部
            if (bc[0] >= 0 and bc[1] >= 0 and bc[2] >= 0) {
                // 頂点カラーを補間（SIMD演算を使用）
                const w0: Vec4 = @splat(bc[0]);
                const w1: Vec4 = @splat(bc[1]);
                const w2: Vec4 = @splat(bc[2]);
                const c0 = v0.color * w0;
                const c1 = v1.color * w1;
                const c2 = v2.color * w2;
                const interpolated = c0 + c1 + c2;

                // u32に変換して描画
                const color = vec4ToColor(interpolated);
                const index = @as(u32, @intCast(y)) * width + @as(u32, @intCast(x));
                fb_ptr[index] = color;
            }
        }
    }
}

// =============================================================================
// テスト
// =============================================================================

test "computeBoundingBox" {
    _ = framebuffer.init(100, 100);

    const v0 = vec2.init(10, 10);
    const v1 = vec2.init(50, 20);
    const v2 = vec2.init(30, 60);

    const bbox = computeBoundingBox(v0, v1, v2);

    try std.testing.expectEqual(@as(i32, 10), bbox.min_x);
    try std.testing.expectEqual(@as(i32, 10), bbox.min_y);
    try std.testing.expectEqual(@as(i32, 50), bbox.max_x);
    try std.testing.expectEqual(@as(i32, 60), bbox.max_y);
}

test "edgeFunction" {
    const a = vec2.init(0, 0);
    const b = vec2.init(10, 0);
    const p_left = vec2.init(5, 5); // 左側
    const p_right = vec2.init(5, -5); // 右側

    const edge_left = edgeFunction(a, b, p_left);
    const edge_right = edgeFunction(a, b, p_right);

    try std.testing.expect(edge_left > 0);
    try std.testing.expect(edge_right < 0);
}

test "barycentric inside" {
    const v0 = vec2.init(0, 0);
    const v1 = vec2.init(10, 0);
    const v2 = vec2.init(5, 10);
    const p = vec2.init(5, 5); // 三角形の中心付近

    const bc = barycentric(v0, v1, v2, p);

    // すべての重みが非負
    try std.testing.expect(bc[0] >= 0);
    try std.testing.expect(bc[1] >= 0);
    try std.testing.expect(bc[2] >= 0);

    // 重みの合計は約1.0
    const sum = bc[0] + bc[1] + bc[2];
    try std.testing.expect(@abs(sum - 1.0) < 0.01);
}

test "barycentric outside" {
    const v0 = vec2.init(0, 0);
    const v1 = vec2.init(10, 0);
    const v2 = vec2.init(5, 10);
    const p = vec2.init(100, 100); // 明らかに外側

    const bc = barycentric(v0, v1, v2, p);

    // 少なくとも1つの重みが負
    const is_outside = bc[0] < 0 or bc[1] < 0 or bc[2] < 0;
    try std.testing.expect(is_outside);
}

test "vec4ToColor" {
    const red = vec4.init(1.0, 0.0, 0.0, 1.0);
    const color = vec4ToColor(red);

    // ABGR形式: 0xAA_BB_GG_RR
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), color);
}
