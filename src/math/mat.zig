//! Matrix Types (行列型)
//! ======================
//!
//! 4x4行列と変換操作を提供します。
//!
//! ## 学習ポイント
//!
//! ### 1. 同次座標系 (Homogeneous Coordinates)
//!
//! 3D座標を4次元で表現することで、平行移動を行列乗算で表現できます。
//!
//! ```
//! [x]   [m00 m01 m02 m03] [x']
//! [y] = [m10 m11 m12 m13] [y']
//! [z]   [m20 m21 m22 m23] [z']
//! [1]   [m30 m31 m32 m33] [w']
//! ```
//!
//! - 点 (point): w = 1.0 (平行移動の影響を受ける)
//! - 方向 (direction): w = 0.0 (平行移動の影響を受けない)
//!
//! ### 2. 行優先 vs 列優先 (Row-major vs Column-major)
//!
//! このプロジェクトでは **列優先 (Column-major)** を採用:
//! - OpenGL/WebGL と同じ慣習
//! - メモリ上では列が連続して並ぶ
//! - 行列の乗算は `M * v` (行列×ベクトル) の順
//!
//! ### 3. 座標変換パイプライン
//!
//! ```
//! Local → World → View → Clip → NDC → Screen
//!   |       |       |       |      |
//!   +-------+-------+-------+------+---→ それぞれ行列乗算
//! ```
//!
//! ## TODO (Phase 3 で実装)
//!
//! - [ ] Model 行列 (translate, rotate, scale)
//! - [ ] View 行列 (lookAt)
//! - [ ] Projection 行列 (perspective, orthographic)

const std = @import("std");
const vec = @import("vec.zig");

const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

/// 4x4行列 (列優先)
/// 各列が Vec4 として格納される
pub const Mat4 = struct {
    /// 列データ [col0, col1, col2, col3]
    cols: [4]Vec4,

    const Self = @This();

    // =========================================================================
    // コンストラクタ
    // =========================================================================

    /// 単位行列
    pub const identity: Mat4 = .{
        .cols = .{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };

    /// ゼロ行列
    pub const zero: Mat4 = .{
        .cols = .{
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
        },
    };

    // =========================================================================
    // 基本操作
    // =========================================================================

    /// 要素アクセス (row, col)
    pub inline fn at(self: Self, row: usize, col: usize) f32 {
        return self.cols[col][row];
    }

    /// 要素設定 (row, col)
    pub inline fn set(self: *Self, row: usize, col: usize, value: f32) void {
        self.cols[col][row] = value;
    }

    // =========================================================================
    // 変換行列の作成 (Phase 3 で実装)
    // =========================================================================

    /// 平行移動行列
    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        return .{
            .cols = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ x, y, z, 1.0 },
            },
        };
    }

    /// スケール行列
    pub fn scaling(x: f32, y: f32, z: f32) Mat4 {
        return .{
            .cols = .{
                .{ x, 0.0, 0.0, 0.0 },
                .{ 0.0, y, 0.0, 0.0 },
                .{ 0.0, 0.0, z, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// X軸回転行列
    pub fn rotationX(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, c, s, 0.0 },
                .{ 0.0, -s, c, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// Y軸回転行列
    pub fn rotationY(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ c, 0.0, -s, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ s, 0.0, c, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    /// Z軸回転行列
    pub fn rotationZ(angle_rad: f32) Mat4 {
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        return .{
            .cols = .{
                .{ c, s, 0.0, 0.0 },
                .{ -s, c, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    // =========================================================================
    // 行列演算
    // =========================================================================

    /// 行列×行列
    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;

        // 各列を計算
        inline for (0..4) |col| {
            // result.col[i] = a.col[0] * b[0][col] + a.col[1] * b[1][col] + ...
            const b_col = b.cols[col];
            const factor0: Vec4 = @splat(b_col[0]);
            const factor1: Vec4 = @splat(b_col[1]);
            const factor2: Vec4 = @splat(b_col[2]);
            const factor3: Vec4 = @splat(b_col[3]);

            result.cols[col] = a.cols[0] * factor0 +
                a.cols[1] * factor1 +
                a.cols[2] * factor2 +
                a.cols[3] * factor3;
        }

        return result;
    }

    /// 行列×ベクトル
    pub fn mulVec4(m: Mat4, v: Vec4) Vec4 {
        const factor0: Vec4 = @splat(v[0]);
        const factor1: Vec4 = @splat(v[1]);
        const factor2: Vec4 = @splat(v[2]);
        const factor3: Vec4 = @splat(v[3]);

        return m.cols[0] * factor0 +
            m.cols[1] * factor1 +
            m.cols[2] * factor2 +
            m.cols[3] * factor3;
    }

    // =========================================================================
    // View / Projection 行列 (Phase 3 で実装)
    // =========================================================================

    /// LookAt行列 (View 行列)
    ///
    /// ## アルゴリズム
    ///
    /// カメラの位置（eye）と注視点（target）から、ワールド座標からビュー座標への
    /// 変換行列を生成します。
    ///
    /// 1. カメラの向き（forward）を計算: `forward = normalize(target - eye)`
    /// 2. カメラの右方向（right）を計算: `right = normalize(cross(forward, up))`
    /// 3. カメラの上方向（actualUp）を再計算: `actualUp = cross(right, forward)`
    /// 4. 回転部分と平行移動を組み合わせた行列を作成
    ///
    /// ## 図解
    ///
    /// ```
    ///       up (world)
    ///        |
    ///        |
    ///        +---→ right
    ///       /
    ///      / forward (camera direction)
    ///     eye
    ///      \
    ///       \
    ///        target
    /// ```
    ///
    /// ## 学習ポイント
    ///
    /// - OpenGLの右手座標系では、カメラは-Z方向を向く
    /// - このため、forward を反転させる（-forward）
    /// - View行列は「ワールドをカメラ基準に変換」する行列
    ///
    /// ## TODO (Phase 4)
    ///
    /// - カメラのロール（Z軸回転）にも対応
    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        // forward = normalize(target - eye)
        // 右手座標系なので、カメラは-Z方向を向く
        const forward_dir = target - eye;
        const forward_len = @sqrt(vec.vec3.dot(forward_dir, forward_dir));
        const forward_norm: Vec3 = if (forward_len > 0.0001) forward_dir / @as(Vec3, @splat(forward_len)) else .{ 0, 0, -1 };

        // right = normalize(cross(forward, up))
        const right_dir = vec.vec3.cross(forward_norm, up);
        const right_len = @sqrt(vec.vec3.dot(right_dir, right_dir));
        const right: Vec3 = if (right_len > 0.0001) right_dir / @as(Vec3, @splat(right_len)) else .{ 1, 0, 0 };

        // actualUp = cross(right, forward)
        const actual_up = vec.vec3.cross(right, forward_norm);

        // View行列を構築
        // カメラ座標系の軸ベクトルを行列の行として配置し、
        // 原点をカメラ位置に移動
        const tx = -vec.vec3.dot(right, eye);
        const ty = -vec.vec3.dot(actual_up, eye);
        const tz = vec.vec3.dot(forward_norm, eye); // 注意: +にする（-Z方向を向くため）

        return .{
            .cols = .{
                .{ right[0], actual_up[0], -forward_norm[0], 0.0 },
                .{ right[1], actual_up[1], -forward_norm[1], 0.0 },
                .{ right[2], actual_up[2], -forward_norm[2], 0.0 },
                .{ tx, ty, tz, 1.0 },
            },
        };
    }

    /// 透視投影行列 (Perspective Projection)
    ///
    /// ## アルゴリズム
    ///
    /// 3D空間の点を、遠近感を持つ2D平面に投影します。
    ///
    /// 1. 視野角（fov）からフラスタム（視錐台）のサイズを計算
    /// 2. near/farクリッピング平面を設定
    /// 3. 透視除算のための同次座標（w成分）を設定
    ///
    /// ## 図解
    ///
    /// ```
    ///        far plane
    ///       /        \
    ///      /          \
    ///     /            \  <- フラスタム（視錐台）
    ///    /      fov     \
    ///   +----------------+ near plane
    ///   |    (eye)
    /// ```
    ///
    /// ## 学習ポイント
    ///
    /// - 透視投影では、遠くのものほど小さく見える
    /// - w成分にz値を格納し、後で透視除算（x/w, y/w, z/w）を行う
    /// - NDC（正規化デバイス座標）は [-1, 1]^3 の立方体
    /// - OpenGLスタイル: Zは [-1, 1]（DirectXは [0, 1]）
    ///
    /// ## TODO (Phase 4)
    ///
    /// - リバースZ（深度精度向上）の実装
    ///
    /// @param fov_rad 視野角（ラジアン）※垂直方向
    /// @param aspect アスペクト比（width / height）
    /// @param near ニアクリップ平面
    /// @param far ファークリップ平面
    pub fn perspective(fov_rad: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fov = @tan(fov_rad / 2.0);

        // フラスタムのサイズを計算
        const f = 1.0 / tan_half_fov;
        const nf = 1.0 / (near - far);

        return .{
            .cols = .{
                .{ f / aspect, 0.0, 0.0, 0.0 },
                .{ 0.0, f, 0.0, 0.0 },
                .{ 0.0, 0.0, (far + near) * nf, -1.0 },
                .{ 0.0, 0.0, 2.0 * far * near * nf, 0.0 },
            },
        };
    }

    /// 正射影行列 (Orthographic Projection)
    ///
    /// ## アルゴリズム
    ///
    /// 遠近感のない平行投影を行います。
    /// 主にUIやデバッグ描画に使用。
    ///
    /// ## 学習ポイント
    ///
    /// - 透視投影と異なり、遠くのものも同じ大きさで表示
    /// - w成分は常に1.0のまま（透視除算なし）
    ///
    /// @param left 左端
    /// @param right 右端
    /// @param bottom 下端
    /// @param top 上端
    /// @param near ニアクリップ
    /// @param far ファークリップ
    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        const rl = 1.0 / (right - left);
        const tb = 1.0 / (top - bottom);
        const far_near = 1.0 / (far - near);

        return .{
            .cols = .{
                .{ 2.0 * rl, 0.0, 0.0, 0.0 },
                .{ 0.0, 2.0 * tb, 0.0, 0.0 },
                .{ 0.0, 0.0, -2.0 * far_near, 0.0 },
                .{ -(right + left) * rl, -(top + bottom) * tb, -(far + near) * far_near, 1.0 },
            },
        };
    }
};

// =============================================================================
// テスト
// =============================================================================

test "identity matrix" {
    const m = Mat4.identity;
    try std.testing.expectEqual(@as(f32, 1.0), m.at(0, 0));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(1, 1));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(2, 2));
    try std.testing.expectEqual(@as(f32, 1.0), m.at(3, 3));
    try std.testing.expectEqual(@as(f32, 0.0), m.at(0, 1));
}

test "translation matrix" {
    const t = Mat4.translation(1.0, 2.0, 3.0);
    const v = Vec4{ 0.0, 0.0, 0.0, 1.0 };
    const result = t.mulVec4(v);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), result[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), result[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result[2], 0.0001);
}

test "matrix multiplication" {
    const a = Mat4.scaling(2.0, 2.0, 2.0);
    const b = Mat4.translation(1.0, 0.0, 0.0);

    // scale then translate
    const m = Mat4.mul(b, a);
    const v = Vec4{ 1.0, 0.0, 0.0, 1.0 };
    const result = m.mulVec4(v);

    // 1 * 2 + 1 = 3
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), result[0], 0.0001);
}
