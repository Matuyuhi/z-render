# SIMD Basics - ベクトル演算の基礎

## SIMDとは

**SIMD** = **S**ingle **I**nstruction, **M**ultiple **D**ata

1つの命令で複数のデータを同時に処理する技術です。

```
通常の演算 (スカラー):
  a + b → c     (1回の加算)

SIMD演算 (ベクトル):
  [a0, a1, a2, a3] + [b0, b1, b2, b3] → [c0, c1, c2, c3]
  (4回の加算が1命令で完了!)
```

## ZigでのSIMD

### @Vector 型

```zig
// 4つのf32を並列処理できるベクトル型
const Vec4 = @Vector(4, f32);

const a: Vec4 = .{ 1.0, 2.0, 3.0, 4.0 };
const b: Vec4 = .{ 5.0, 6.0, 7.0, 8.0 };

// 4つの加算が1命令で実行される
const c = a + b;  // { 6.0, 8.0, 10.0, 12.0 }
```

### 対応している演算

```zig
const a: Vec4 = .{ 1.0, 2.0, 3.0, 4.0 };
const b: Vec4 = .{ 2.0, 2.0, 2.0, 2.0 };

a + b  // 加算
a - b  // 減算
a * b  // 乗算
a / b  // 除算
-a     // 符号反転
```

### @splat - スカラー値をベクトルに展開

```zig
// 同じ値で埋める
const scalar: f32 = 2.0;
const vec: Vec4 = @splat(scalar);  // { 2.0, 2.0, 2.0, 2.0 }

// スケーリングに便利
const position: Vec4 = .{ 1.0, 2.0, 3.0, 1.0 };
const scale: Vec4 = @splat(2.0);
const scaled = position * scale;  // { 2.0, 4.0, 6.0, 2.0 }
```

### @reduce - ベクトルをスカラーに畳み込む

```zig
const v: Vec4 = .{ 1.0, 2.0, 3.0, 4.0 };

// 合計
@reduce(.Add, v)  // 10.0

// 最大値
@reduce(.Max, v)  // 4.0

// 最小値
@reduce(.Min, v)  // 1.0
```

## 内積 (Dot Product) のSIMD実装

```zig
pub fn dot(a: Vec4, b: Vec4) f32 {
    // Step 1: 要素ごとの乗算
    const products = a * b;  // { a.x*b.x, a.y*b.y, a.z*b.z, a.w*b.w }

    // Step 2: 合計を取る
    return @reduce(.Add, products);  // a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w
}
```

## WebAssembly SIMDについて

Wasm SIMD は 128-bit のベクトルをサポート:

| 型 | 要素数 | 合計サイズ |
|---|---|---|
| f32x4 | 4 | 128 bits |
| f64x2 | 2 | 128 bits |
| i32x4 | 4 | 128 bits |
| i16x8 | 8 | 128 bits |
| i8x16 | 16 | 128 bits |

Zigの `@Vector(4, f32)` は自動的に Wasm SIMD にコンパイルされます。

## 演習課題

1. **vec.zig** の `lengthSquared` 関数を読んで、どのようにSIMDが使われているか確認
2. 2つのVec3の距離を計算する `distance(a, b)` 関数を実装してみる
3. ベクトルの線形補間 `lerp(a, b, t)` を実装してみる

## 参考リンク

- [Zig Language Reference - Vectors](https://ziglang.org/documentation/master/#Vectors)
- [WebAssembly SIMD Proposal](https://github.com/WebAssembly/simd)
