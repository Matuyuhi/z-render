//! Rendering Pipeline (レンダリングパイプライン)
//! ===============================================
//!
//! 3Dオブジェクトを画面に描画するための座標変換パイプライン。
//!
//! ## 学習ポイント
//!
//! ### 座標変換の流れ
//!
//! ```
//! Local Space (ローカル空間)
//!   ↓ Model Matrix
//! World Space (ワールド空間)
//!   ↓ View Matrix
//! View Space (ビュー空間 / カメラ空間)
//!   ↓ Projection Matrix
//! Clip Space (クリップ空間 / 同次座標)
//!   ↓ Perspective Division (透視除算)
//! NDC (正規化デバイス座標)
//!   ↓ Viewport Transform
//! Screen Space (スクリーン空間 / ピクセル座標)
//! ```
//!
//! ### 各空間の意味
//!
//! 1. **Local Space**: モデルの原点を中心とした座標系
//! 2. **World Space**: ワールドの原点を中心とした座標系
//! 3. **View Space**: カメラを原点とした座標系
//! 4. **Clip Space**: 透視投影後の同次座標（w≠1）
//! 5. **NDC**: [-1, 1]^3 の正規化された立方体
//! 6. **Screen Space**: ピクセル座標 [0, width] × [0, height]
//!
//! ## TODO (Phase 4)
//!
//! - クリッピング（視錐台の外側をカット）
//! - フラグメントシェーダー相当の処理

const std = @import("std");
const math = @import("../math/root.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;
const vec2 = math.vec.vec2;
const vec3 = math.vec.vec3;
const vec4 = math.vec.vec4;

// =============================================================================
// 座標変換関数
// =============================================================================

/// ローカル座標からワールド座標に変換
///
/// ## アルゴリズム
///
/// Model行列を適用してローカル座標をワールド座標に変換します。
///
/// ```
/// world_pos = Model * local_pos
/// ```
///
/// ## 学習ポイント
///
/// - Model行列 = Scale × Rotation × Translation の順で合成
/// - 頂点は同次座標（w=1.0）として扱う
///
/// @param local_pos ローカル座標（Vec3）
/// @param model Model行列
/// @return ワールド座標（Vec3）
pub fn transformToWorld(local_pos: Vec3, model: Mat4) Vec3 {
    const local_homo = vec4.fromVec3(local_pos, 1.0);
    const world_homo = model.mulVec4(local_homo);
    return vec4.xyz(world_homo);
}

/// ワールド座標からクリップ座標に変換
///
/// ## アルゴリズム
///
/// View行列とProjection行列を適用してクリップ座標に変換します。
///
/// ```
/// clip_pos = Projection * View * world_pos
///          = MVP * local_pos
/// ```
///
/// ## 学習ポイント
///
/// - MVP行列は事前に合成しておくのが一般的
/// - クリップ座標はw≠1の同次座標
/// - w成分は透視除算で使用
///
/// @param world_pos ワールド座標（Vec3）
/// @param view_projection View行列×Projection行列
/// @return クリップ座標（Vec4、同次座標）
pub fn transformToClip(world_pos: Vec3, view_projection: Mat4) Vec4 {
    const world_homo = vec4.fromVec3(world_pos, 1.0);
    return view_projection.mulVec4(world_homo);
}

/// クリップ座標からNDCに変換（透視除算）
///
/// ## アルゴリズム
///
/// 同次座標のw成分で割ることで、透視投影を完成させます。
///
/// ```
/// ndc.x = clip.x / clip.w
/// ndc.y = clip.y / clip.w
/// ndc.z = clip.z / clip.w
/// ```
///
/// ## 図解
///
/// ```
/// Clip Space (視錐台)       NDC (立方体)
///       /\                     +-------+
///      /  \                    |       |
///     /    \       ÷w         |       |
///    /      \      -->         |       |
///   +--------+                 +-------+
/// ```
///
/// ## 学習ポイント
///
/// - 透視除算により「遠くのものほど小さく」なる
/// - NDCは [-1, 1]^3 の立方体
/// - wが0に近いとき、除算に注意（クリッピングで対処）
///
/// @param clip クリップ座標（Vec4）
/// @return NDC（Vec3）
pub fn clipToNDC(clip: Vec4) Vec3 {
    const w = clip[3];
    if (@abs(w) < 0.0001) {
        // wが0に近い場合はクリッピングされるべき
        return vec3.init(0, 0, 0);
    }

    return vec3.init(
        clip[0] / w,
        clip[1] / w,
        clip[2] / w,
    );
}

/// NDCからスクリーン座標に変換
///
/// ## アルゴリズム
///
/// NDCの[-1, 1]範囲を、スクリーンの[0, width]×[0, height]に変換します。
///
/// ```
/// screen.x = (ndc.x + 1) * 0.5 * width
/// screen.y = (1 - ndc.y) * 0.5 * height  // Yは反転
/// screen.z = (ndc.z + 1) * 0.5           // 深度バッファ用 [0, 1]
/// ```
///
/// ## 学習ポイント
///
/// - NDCのYは上が+1、下が-1
/// - スクリーンのYは上が0、下がheight
/// - したがってYを反転させる必要がある
/// - Zは深度バッファ用に[0, 1]に正規化
///
/// @param ndc NDC座標（Vec3）
/// @param width 画面幅
/// @param height 画面高さ
/// @return スクリーン座標（Vec3、z成分は深度値）
pub fn ndcToScreen(ndc: Vec3, width: f32, height: f32) Vec3 {
    return vec3.init(
        (ndc[0] + 1.0) * 0.5 * width,
        (1.0 - ndc[1]) * 0.5 * height, // Y反転
        (ndc[2] + 1.0) * 0.5, // [0, 1]に正規化
    );
}

/// 一括変換: ワールド座標からスクリーン座標へ
///
/// ## 学習ポイント
///
/// - パイプライン全体を1つの関数にまとめた便利版
/// - ホットパスではインライン化されることを期待
///
/// @param world_pos ワールド座標（Vec3）
/// @param view_projection View×Projection行列
/// @param width 画面幅
/// @param height 画面高さ
/// @return スクリーン座標（Vec3）
pub fn worldToScreen(world_pos: Vec3, view_projection: Mat4, width: f32, height: f32) Vec3 {
    const clip = transformToClip(world_pos, view_projection);
    const ndc = clipToNDC(clip);
    return ndcToScreen(ndc, width, height);
}

// =============================================================================
// バックフェイスカリング
// =============================================================================

/// 三角形の法線ベクトルを計算
///
/// ## アルゴリズム
///
/// 2つのエッジベクトルの外積を計算します。
///
/// ```
/// edge1 = v1 - v0
/// edge2 = v2 - v0
/// normal = cross(edge1, edge2)
/// ```
///
/// ## 図解
///
/// ```
///        v2
///       /|
///  e2  / |
///     /  | e1
///    v0--v1
///
///  normal = e1 × e2 (右手の法則)
/// ```
///
/// ## 学習ポイント
///
/// - 頂点の巻き順が反時計回り（CCW）なら、法線は表面の外側を向く
/// - 正規化しないバージョン（面積も含む）
///
/// @param v0, v1, v2 三角形の3頂点（スクリーン座標）
/// @return 法線ベクトル（正規化されていない）
pub fn computeNormal(v0: Vec3, v1: Vec3, v2: Vec3) Vec3 {
    const edge1 = v1 - v0;
    const edge2 = v2 - v0;
    return vec3.cross(edge1, edge2);
}

/// 三角形が表面を向いているか判定（バックフェイスカリング）
///
/// ## アルゴリズム
///
/// 法線ベクトルと視線ベクトルの内積で判定します。
///
/// ```
/// dot(normal, viewDir) > 0 なら表面
/// ```
///
/// ## 学習ポイント
///
/// - スクリーン座標での2D判定でもOK
/// - Z成分の符号だけを見れば良い（より高速）
/// - 正の値 = 表面、負の値 = 裏面
///
/// @param v0, v1, v2 三角形の3頂点（スクリーン座標）
/// @return 表面ならtrue
pub fn isFrontFacing(v0: Vec2, v1: Vec2, v2: Vec2) bool {
    // 2Dでのエッジ関数（外積のZ成分）
    const edge1_x = v1[0] - v0[0];
    const edge1_y = v1[1] - v0[1];
    const edge2_x = v2[0] - v0[0];
    const edge2_y = v2[1] - v0[1];

    // 外積のZ成分
    const cross_z = edge1_x * edge2_y - edge1_y * edge2_x;

    // 反時計回りなら正
    return cross_z > 0.0;
}

// =============================================================================
// テスト
// =============================================================================

test "transformToWorld" {
    const local = vec3.init(1.0, 0.0, 0.0);
    const model = Mat4.translation(2.0, 3.0, 4.0);
    const world = transformToWorld(local, model);

    try std.testing.expectApproxEqAbs(@as(f32, 3.0), world[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), world[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), world[2], 0.0001);
}

test "clipToNDC" {
    const clip = vec4.init(2.0, 4.0, 6.0, 2.0); // w=2で割る
    const ndc = clipToNDC(clip);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ndc[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), ndc[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), ndc[2], 0.0001);
}

test "ndcToScreen" {
    const ndc = vec3.init(0.0, 0.0, 0.0); // 中心
    const screen = ndcToScreen(ndc, 800.0, 600.0);

    // 画面中央
    try std.testing.expectApproxEqAbs(@as(f32, 400.0), screen[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 300.0), screen[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), screen[2], 0.0001);
}

test "isFrontFacing" {
    // 反時計回り（CCW）
    const v0 = vec2.init(0.0, 0.0);
    const v1 = vec2.init(1.0, 0.0);
    const v2 = vec2.init(0.0, 1.0);

    try std.testing.expect(isFrontFacing(v0, v1, v2));

    // 時計回り（CW） - 裏面
    try std.testing.expect(!isFrontFacing(v0, v2, v1));
}
