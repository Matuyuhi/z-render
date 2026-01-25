# 重心座標 (Barycentric Coordinates) 完全ガイド

## 📚 重心座標とは？

三角形内の任意の点を、**3つの頂点の重み付き和**として表現する方法。

```
       v2
       /\
      /  \
     / p  \  ← この点pを表現したい
    /______\
  v0        v1

点p = w0 * v0 + w1 * v1 + w2 * v2

ただし: w0 + w1 + w2 = 1
```

## 🎯 何に使える？

### 1. 内外判定

点が三角形の**中**にあるかを判定できる。

```
すべての重み (w0, w1, w2) が 0〜1 の範囲
→ 点pは三角形の中

どれか1つでも負 or 1より大きい
→ 点pは三角形の外
```

### 2. 属性補間

頂点の「何か」を、点pの位置に応じて混ぜられる。

**例: 色の補間**

```
v0 = 赤 (1, 0, 0)
v1 = 緑 (0, 1, 0)
v2 = 青 (0, 0, 1)

三角形の中央付近の点p:
w0 = 0.33, w1 = 0.33, w2 = 0.33

色(p) = 0.33*(1,0,0) + 0.33*(0,1,0) + 0.33*(0,0,1)
      = (0.33, 0.33, 0.33)  ← 灰色！
```

**その他の用途:**

- UV座標の補間（テクスチャマッピング）
- 法線ベクトルの補間（ライティング）
- 深度値の補間（Z-Buffer）

---

## 🧮 計算方法

### エッジ関数を使う方法

**エッジ関数**は「点が辺のどちら側にあるか」を判定する関数。

```zig
// 2D外積（クロス積のZ成分）
fn edgeFunction(a: Vec2, b: Vec2, p: Vec2) f32 {
    return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
}
```

**重心座標の計算:**

```zig
// 三角形全体の面積（の2倍）
area = edgeFunction(v0, v1, v2)

// 各頂点に対する重み
w0 = edgeFunction(v1, v2, p) / area
w1 = edgeFunction(v2, v0, p) / area
w2 = edgeFunction(v0, v1, p) / area
```

### 図解

```
三角形を3つの小三角形に分割:

       v2
       /\
      /|\\
     / | \\
    /  p  \\
   /___|___\\
  v0   |    v1

Area0 = △(v1, v2, p)  ← v0の反対側
Area1 = △(v2, v0, p)  ← v1の反対側
Area2 = △(v0, v1, p)  ← v2の反対側

w0 = Area0 / TotalArea
w1 = Area1 / TotalArea
w2 = Area2 / TotalArea
```

**意味:**

- 点pがv0に近い → Area0が大きい → w0が大きい
- 点pがv1に近い → Area1が大きい → w1が大きい
- 点pがv2に近い → Area2が大きい → w2が大きい

---

## 💡 実装例

### 重心座標の計算

```zig
pub fn barycentric(v0: Vec2, v1: Vec2, v2: Vec2, p: Vec2) Vec3 {
    const area = edgeFunction(v0, v1, v2);

    // 退化した三角形（面積0）の場合
    if (@abs(area) < 0.0001) {
        return Vec3{ 0, 0, 0 };
    }

    const w0 = edgeFunction(v1, v2, p) / area;
    const w1 = edgeFunction(v2, v0, p) / area;
    const w2 = edgeFunction(v0, v1, p) / area;

    return Vec3{ w0, w1, w2 };
}
```

### 三角形の塗りつぶし

```zig
pub fn fillTriangle(v0: Vec2, v1: Vec2, v2: Vec2, c0: Color, c1: Color, c2: Color) void {
    const bbox = computeBoundingBox(v0, v1, v2);

    var y = bbox.min_y;
    while (y <= bbox.max_y) : (y += 1) {
        var x = bbox.min_x;
        while (x <= bbox.max_x) : (x += 1) {
            const p = Vec2{ x, y };
            const bc = barycentric(v0, v1, v2, p);

            // 内外判定
            if (bc.x >= 0 and bc.y >= 0 and bc.z >= 0) {
                // 色を補間
                const color = c0 * bc.x + c1 * bc.y + c2 * bc.z;

                // ピクセルを描画
                setPixel(x, y, color);
            }
        }
    }
}
```

---

## 🔬 数学的な背景

### なぜ面積比で計算できる？

三角形の重心座標は、**面積座標 (Areal Coordinates)** とも呼ばれます。

```
点pが三角形を3つに分割したとき:

       v2
       /\
      /|\\
     /A0\\     A0 = Area(v1, v2, p)
    /___p\\    A1 = Area(v2, v0, p)
   /A2 | A1\   A2 = Area(v0, v1, p)
  v0---|---v1

w0 = A0 / (A0 + A1 + A2)
w1 = A1 / (A0 + A1 + A2)
w2 = A2 / (A0 + A1 + A2)
```

**証明のポイント:**

点pを3頂点の線形結合として表現:

```
p = w0 * v0 + w1 * v1 + w2 * v2
```

この式を展開すると、各重みが面積比に等しいことが示せます。

---

## ⚡ パフォーマンス最適化

### 1. 増分計算 (Incremental Computation)

横方向にスキャンするとき、重心座標を毎回計算せず**差分更新**できる。

```zig
// 最初のピクセル
var bc = barycentric(v0, v1, v2, Vec2{ x, y });

// 1ピクセル右に移動
x += 1;
bc.x += dx0;  // 事前計算した差分を加算
bc.y += dx1;
bc.z += dx2;
```

これにより、ピクセルごとの除算が不要になる。

### 2. ハーフスペース最適化

エッジ関数の符号だけを見れば良い場合（内外判定のみ）、除算不要。

```zig
const e0 = edgeFunction(v0, v1, p);
const e1 = edgeFunction(v1, v2, p);
const e2 = edgeFunction(v2, v0, p);

// 3つとも同じ符号なら内部
if ((e0 >= 0 and e1 >= 0 and e2 >= 0) or
    (e0 <= 0 and e1 <= 0 and e2 <= 0)) {
    // 内部
}
```

---

## 🎨 視覚的な例

### 重みの変化

```
v0に近い点p:
w0 = 0.8, w1 = 0.1, w2 = 0.1
→ ほぼv0の色

v1とv2の中間の点p:
w0 = 0.0, w1 = 0.5, w2 = 0.5
→ v1とv2の色が半々

三角形の中心（重心）:
w0 = 0.33, w1 = 0.33, w2 = 0.33
→ 3色が均等に混ざる
```

### グラデーション三角形

```
v0 (赤)
  |\
  | \
  |  \    ← この辺に沿って赤→青
  |   \     (w0が1→0, w2が0→1)
  |____\
v1     v2 (青)
(緑)

中央: 3色が混ざって灰色
辺上: 2色が混ざる
頂点: 純色
```

---

## 🚨 注意点

### 1. 退化した三角形

3頂点が一直線上にある（面積0）場合、重心座標は定義できない。

```zig
if (@abs(area) < 0.0001) {
    // エラー処理
    return;
}
```

### 2. 浮動小数点誤差

厳密に `w0 + w1 + w2 = 1` にならない場合がある。

```zig
const sum = w0 + w1 + w2;
if (@abs(sum - 1.0) > 0.01) {
    // 警告
}
```

### 3. 巻き順（CCW vs CW）

頂点の順序で面積の符号が変わる。

```
反時計回り (CCW): area > 0
時計回り (CW):    area < 0
```

このプロジェクトでは**反時計回り (CCW)** を採用。

---

## 📖 参考資料

- [Scratchapixel: Rasterization: a Practical Implementation](https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation)
- [Wikipedia: Barycentric coordinate system](https://en.wikipedia.org/wiki/Barycentric_coordinate_system)
