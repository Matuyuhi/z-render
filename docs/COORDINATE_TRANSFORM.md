# 座標変換パイプライン完全ガイド

## 🎯 なぜ座標変換が必要？

3Dオブジェクトを画面に表示するには、**複数の座標系を経由**する必要があります。

```
モデル作成時の座標
    ↓
ワールドに配置
    ↓
カメラから見た座標
    ↓
遠近法を適用
    ↓
画面のピクセル座標
```

---

## 📐 6つの座標系

### 1. Local Space (ローカル空間 / オブジェクト空間)

**概要**: モデル制作時の座標系

```
キューブの頂点:
(-1, -1, -1) ← 原点を中心とした座標
( 1, -1, -1)
( 1,  1, -1)
...
```

**特徴**:

- モデルの**原点**を中心とする
- モデリングツールで作成時の座標
- 回転・拡大・移動はまだ適用されていない

---

### 2. World Space (ワールド空間)

**概要**: シーン全体の座標系

**変換**: Model行列を適用

```
Model行列 = Scale × Rotation × Translation

world_pos = Model × local_pos
```

**例**:

```
ローカル座標: (1, 0, 0)
↓ Y軸で90度回転
ワールド座標: (0, 0, -1)
```

**Model行列の構成要素**:

1. **Scale (拡大縮小)**
   ```
   [sx  0   0   0]
   [0   sy  0   0]
   [0   0   sz  0]
   [0   0   0   1]
   ```

2. **Rotation (回転)**
   ```
   Y軸回転 (angle):
   [cos  0  -sin  0]
   [0    1   0    0]
   [sin  0   cos  0]
   [0    0   0    1]
   ```

3. **Translation (平行移動)**
   ```
   [1  0  0  tx]
   [0  1  0  ty]
   [0  0  1  tz]
   [0  0  0  1]
   ```

---

### 3. View Space (ビュー空間 / カメラ空間)

**概要**: カメラを原点とした座標系

**変換**: View行列を適用

```
view_pos = View × world_pos
```

**View行列の作り方 (lookAt関数)**:

```
カメラの設定:
- eye:    カメラの位置 (0, 0, 5)
- target: 注視点       (0, 0, 0)
- up:     上方向       (0, 1, 0)

計算手順:
1. forward = normalize(target - eye)
2. right   = normalize(cross(forward, up))
3. up_new  = cross(right, forward)

View行列:
[right.x    up_new.x   -forward.x   0]
[right.y    up_new.y   -forward.y   0]
[right.z    up_new.z   -forward.z   0]
[-dot(right,eye)  -dot(up_new,eye)  dot(forward,eye)  1]
```

**図解**:

```
World Space              View Space

  Y                        Y (up)
  |                        |
  |   eye                  |
  |   /                   eye (原点)
  |  /                     |
  | / forward              | -Z (forward)
  |/_______ X              |/_______ X (right)
 /|                       /
Z |                      /
```

---

### 4. Clip Space (クリップ空間 / 同次座標空間)

**概要**: 透視投影を適用した座標系（まだw≠1）

**変換**: Projection行列を適用

```
clip_pos = Projection × view_pos
```

**Projection行列 (透視投影)**:

```
パラメータ:
- fov:    視野角 (60度)
- aspect: アスペクト比 (width / height)
- near:   ニアクリップ平面 (0.1)
- far:    ファークリップ平面 (100.0)

計算:
f = 1 / tan(fov / 2)

[f/aspect  0   0              0         ]
[0         f   0              0         ]
[0         0   (far+near)/    -1        ]
                (near-far)
[0         0   2*far*near/    0         ]
                (near-far)
```

**同次座標の意味**:

```
clip = (x, y, z, w)

w成分が1でない！
→ まだピクセル座標ではない
→ 次のステップで透視除算
```

**視錐台 (View Frustum)**:

```
     far plane
    +---------+
   /|        /|
  / |   Z   / |
 /  |  ↗   /  |
+---+-----+   |  ← フラスタム（見える範囲）
|   |     |   |
|   +-----|---+
|  /      |  / near plane
| /       | /
|/        |/
+---------+
   eye
```

---

### 5. NDC (Normalized Device Coordinates / 正規化デバイス座標)

**概要**: [-1, 1]の立方体に正規化された座標系

**変換**: 透視除算 (Perspective Division)

```
ndc.x = clip.x / clip.w
ndc.y = clip.y / clip.w
ndc.z = clip.z / clip.w
```

**図解**:

```
Clip Space (視錐台)       NDC (立方体)

      /\                  +-------+
     /  \                 |       |
    /    \     透視除算    |       | [-1, 1]^3
   /      \     ───→      |       |
  /        \              +-------+
 +----------+
  視錐台               正規化された立方体
```

**透視除算の効果**:

```
遠くの点: w が大きい → 除算で小さくなる
近くの点: w が小さい → ほぼそのまま

→ 「遠くのものほど小さく見える」を実現
```

---

### 6. Screen Space (スクリーン空間)

**概要**: ピクセル座標 + 深度値

**変換**: ビューポート変換

```
screen.x = (ndc.x + 1) * 0.5 * width
screen.y = (1 - ndc.y) * 0.5 * height  // Y反転
screen.z = (ndc.z + 1) * 0.5           // [0, 1]に正規化
```

**なぜY反転？**

```
NDC座標系:           スクリーン座標系:
  Y                    0 ────→ X
  ↑                    │
  │                    │
  └───→ X              ↓
                       Y

上が+1               上が0
下が-1               下がheight
```

**深度値 (Z成分)**:

```
NDCのZ: [-1, 1]
↓ 正規化
スクリーンのZ: [0, 1]

0.0 = 最も手前 (near)
1.0 = 最も奥   (far)
```

---

## 🔄 全体の流れ（実例）

### キューブの1頂点を追跡

```zig
// 1. Local Space
local = (-1, -1, -1)

// 2. World Space (Y軸45度回転)
model = rotationY(45度)
world = model × (local, 1)
      = (-0.707, -1, -0.707, 1)

// 3. View Space (カメラは(0,0,5)から原点を見る)
view = lookAt(eye=(0,0,5), target=(0,0,0), up=(0,1,0))
view_pos = view × world
         = (-0.707, -1, -5.707, 1)

// 4. Clip Space (透視投影)
proj = perspective(fov=60°, aspect=800/600, near=0.1, far=100)
clip = proj × view_pos
     = (-0.4, -0.6, 3.8, 5.7)

// 5. NDC (透視除算)
ndc.x = -0.4 / 5.7 = -0.07
ndc.y = -0.6 / 5.7 = -0.105
ndc.z =  3.8 / 5.7 =  0.67

// 6. Screen Space (800x600)
screen.x = (-0.07 + 1) * 0.5 * 800 = 372
screen.y = (1 - (-0.105)) * 0.5 * 600 = 331.5
screen.z = (0.67 + 1) * 0.5 = 0.835
```

**結果**: ピクセル (372, 331) に深度 0.835 で描画

---

## 💡 実装のポイント

### 1. MVP行列の事前計算

```zig
// 毎フレーム1回だけ計算
const model = rotationY(time);
const view = lookAt(eye, target, up);
const proj = perspective(fov, aspect, near, far);

const mvp = proj.mul(view).mul(model);

// 各頂点で使い回す
for (vertices) |v| {
    const clip = mvp.mulVec4(toVec4(v.pos, 1.0));
    // ...
}
```

### 2. 同次座標の扱い

```zig
// Vec3 → Vec4 (w=1)
const homo = Vec4{ v.x, v.y, v.z, 1.0 };

// 行列変換
const result = matrix.mulVec4(homo);

// Vec4 → Vec3
const xyz = Vec3{ result.x, result.y, result.z };
```

### 3. クリッピング（簡易版）

```zig
// wが0に近い点はスキップ
if (@abs(clip.w) < 0.0001) {
    continue; // 描画しない
}
```

完全版は視錐台の6平面でクリッピングが必要（Phase 4で実装予定）。

---

## 🎨 視覚的な理解

### 座標系の遷移図

```
       Local              World
        ___                ___
       /  /|              /  /|
      /__/ |  Model矩陣  /__/ |
      |  | | ────────→   |  | |
      |  |/              |  |/
      |__|               |__|

       View               Clip
        |                  /\
        |   View矩陣      /  \
      --+--  ────────→   /    \
       /|\              /______\
        |

       NDC               Screen
      +---+              0─────→
      |   | 透視除算      │#####│
      +---+ ────────→    │#####│
    [-1,1]              └─────┘
                        ピクセル
```

---

## ⚡ パフォーマンス最適化

### 1. SIMD行列演算

```zig
// Vec4のSIMD演算
const col0: Vec4 = @splat(v.x);
const col1: Vec4 = @splat(v.y);
const col2: Vec4 = @splat(v.z);
const col3: Vec4 = @splat(v.w);

result = m.cols[0] * col0 +
         m.cols[1] * col1 +
         m.cols[2] * col2 +
         m.cols[3] * col3;
```

4回の乗算と3回の加算が**並列実行**される！

### 2. 行列の合成順序

```zig
// 悪い例: 各頂点で3回の行列乗算
for (vertices) |v| {
    const world = model.mulVec4(v);
    const view_pos = view.mulVec4(world);
    const clip = proj.mulVec4(view_pos);
}

// 良い例: 事前に1つの行列に合成
const mvp = proj.mul(view).mul(model);
for (vertices) |v| {
    const clip = mvp.mulVec4(v);  // 1回だけ
}
```

---

## 🚨 よくある間違い

### 1. 行列の乗算順序

```zig
// 正しい
mvp = Projection × View × Model

// 間違い
mvp = Model × View × Projection  // 逆！
```

### 2. Y軸の反転を忘れる

```zig
// NDC: 上が+1
// Screen: 上が0

// 正しい
screen_y = (1 - ndc_y) * 0.5 * height

// 間違い
screen_y = (ndc_y + 1) * 0.5 * height  // 上下逆！
```

### 3. 透視除算のタイミング

```zig
// 正しい順序
clip = proj × view × model × vertex
ndc = clip / clip.w  // ← ここで除算

// 間違い
// 除算してから他の変換をしてはいけない
```

---

## 📖 参考資料

- [Learn OpenGL: Coordinate Systems](https://learnopengl.com/Getting-started/Coordinate-Systems)
- [Scratchapixel: The Perspective and Orthographic Projection Matrix](https://www.scratchapixel.com/lessons/3d-basic-rendering/perspective-and-orthographic-projection-matrix)
