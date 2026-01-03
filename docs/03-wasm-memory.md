# WebAssembly Memory Model

## リニアメモリとは

WebAssemblyは「リニアメモリ」という連続したバイト配列を持ちます。

```
アドレス空間:
0x00000000 ────────────────────────────────────────── 0xFFFFFFFF
     │                                                     │
     │  [Static Data] [Stack] [Heap]                       │
     │       │                                             │
     │       └── framebuffer などの静的配列                 │
     │                                                     │
     └─────────────────────────────────────────────────────┘
                    Wasm Linear Memory
```

## JS側からのアクセス

```javascript
// Wasmインスタンスからメモリオブジェクトを取得
const memory = wasmInstance.exports.memory;

// ArrayBufferとして直接アクセス
const buffer = memory.buffer;

// 型付き配列としてビュー作成
const u8View = new Uint8Array(buffer);
const u32View = new Uint32Array(buffer);
const f32View = new Float32Array(buffer);
```

## ポインタの受け渡し

Zig側:
```zig
var buffer: [1000]u32 = undefined;

export fn getBufferPtr() [*]u32 {
    return &buffer;
}
```

JS側:
```javascript
// ポインタ（バイトオフセット）を取得
const ptr = wasm.getBufferPtr();

// そのオフセットからUint32Arrayを作成
const view = new Uint32Array(memory.buffer, ptr, 1000);

// 直接読み書き可能！
view[0] = 0xFF0000FF;  // 赤色をセット
```

## なぜこれが高速なのか？

### 従来の方法（コピーベース）

```
[Wasm Memory] ──copy──> [JS Array] ──copy──> [Canvas]
                  ↑                    ↑
              遅い！              遅い！
```

### 今回の方法（ゼロコピー）

```
[Wasm Memory] ──────────────────────> [Canvas ImageData]
                        ↑
                  同じメモリを参照！
                  （ビューを作るだけ）
```

## 注意点

### 1. メモリの成長

Wasmメモリは動的に成長できます。成長すると `buffer` が新しいオブジェクトになるため、ビューを再作成する必要があります。

```javascript
// 悪い例: 古いビューを使い続ける
const oldView = new Uint32Array(memory.buffer, ptr, size);
// ... メモリが成長 ...
oldView[0] = 123;  // 動作しないかもしれない！

// 良い例: 使う直前にビューを作成
function render() {
    const view = new Uint32Array(memory.buffer, ptr, size);
    // ...
}
```

### 2. エンディアン

Wasm はリトルエンディアンです。

```
u32 = 0xAABBGGRR (メモリ上)
         │ │ │ └── byte 0: RR
         │ │ └──── byte 1: GG
         │ └────── byte 2: BB
         └──────── byte 3: AA
```

Canvas の ImageData は RGBA の順序を期待するので、ちょうど合います！

### 3. アライメント

Wasmでは適切なアライメントが重要です。u32配列は4バイト境界にアライメントされている必要があります。

```zig
// Zigは自動的に適切なアライメントを保証
var buffer: [1000]u32 align(4) = undefined;
```

## 演習課題

1. `renderer.js` の `blitToCanvas()` を読んで、メモリ転送の流れを理解する
2. DevToolsでメモリビューを確認してみる（Memory タブ）
3. フレームバッファのサイズを変更して、解像度が変わることを確認

## 次のステップ

- `04-rasterization.md` - 三角形の塗りつぶし（Phase 2）
