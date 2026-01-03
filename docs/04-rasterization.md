# Rasterization - 三角形の塗りつぶし

> このドキュメントは Phase 2 の予習用です。

## ラスタライズとは

3D座標を2Dピクセルに変換するプロセスの一部で、三角形の内部を塗りつぶす処理です。

```
頂点データ         スクリーン座標      ピクセル
(x, y, z)    →    (x', y')      →    [■][■][■]
                                      [■][■][■]
                                      [■][■][■]
```

## 重心座標系 (Barycentric Coordinates)

三角形内の任意の点を、3つの頂点の重み付き平均で表現します。

```
        v0
        /\
       /  \
      / P  \
     /______\
   v1        v2

P = w0 * v0 + w1 * v1 + w2 * v2
where w0 + w1 + w2 = 1
```

### なぜ重心座標が便利なのか

1. **内外判定**: w0, w1, w2 がすべて >= 0 なら点は三角形の内側
2. **補間**: 色、テクスチャ座標、深度など、任意の属性を簡単に補間できる

```zig
// 重心座標を使った色補間
const color = w0 * color0 + w1 * color1 + w2 * color2;
```

## エッジ関数 (Edge Function)

2つの頂点を結ぶ辺と、点Pの位置関係を判定する関数。

```zig
fn edgeFunction(v0: Vec2, v1: Vec2, p: Vec2) f32 {
    return (p[0] - v0[0]) * (v1[1] - v0[1]) - (p[1] - v0[1]) * (v1[0] - v0[0]);
}
```

- 正の値: 点は辺の右側
- 負の値: 点は辺の左側
- 0: 点は辺の上

3つの辺すべてで同じ符号 → 点は三角形の内側

## 基本的なアルゴリズム

```zig
fn rasterizeTriangle(v0: Vec2, v1: Vec2, v2: Vec2, color: u32) void {
    // 1. バウンディングボックスを計算
    const minX = min(v0.x, v1.x, v2.x);
    const maxX = max(v0.x, v1.x, v2.x);
    const minY = min(v0.y, v1.y, v2.y);
    const maxY = max(v0.y, v1.y, v2.y);

    // 2. バウンディングボックス内の各ピクセルをチェック
    for (minY..maxY) |y| {
        for (minX..maxX) |x| {
            const p = Vec2{ x + 0.5, y + 0.5 };  // ピクセル中心

            // 3. 重心座標を計算
            const w0 = edgeFunction(v1, v2, p);
            const w1 = edgeFunction(v2, v0, p);
            const w2 = edgeFunction(v0, v1, p);

            // 4. 三角形の内側か判定
            if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                setPixel(x, y, color);
            }
        }
    }
}
```

## SIMD最適化のヒント (Phase 5)

4ピクセルを同時に処理:

```zig
// 4つのx座標を同時に処理
const x_coords: @Vector(4, f32) = .{ x, x+1, x+2, x+3 };

// 4つのエッジ関数を同時計算
const w0s = edgeFunctionSIMD(v1, v2, x_coords, y);
const w1s = edgeFunctionSIMD(v2, v0, x_coords, y);
const w2s = edgeFunctionSIMD(v0, v1, x_coords, y);

// 4つの判定を同時実行
const inside = (w0s >= 0) & (w1s >= 0) & (w2s >= 0);
```

## 演習課題 (Phase 2 で取り組む)

1. `edgeFunction` を実装
2. 単色の三角形を描画
3. 頂点ごとに色を指定して、グラデーション描画（Gouraud Shading）

## 参考資料

- [Scratchapixel - Rasterization](https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation)
- [Triangle Rasterization](https://fgiesen.wordpress.com/2013/02/06/the-barycentric-conspirac/)
