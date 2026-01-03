# Getting Started - プロジェクトの始め方

## 必要なツール

1. **Zig** (0.11.0 以上推奨)
   - https://ziglang.org/download/
   - macOS: `brew install zig`
   - Windows: Scoop/Chocolatey または公式バイナリ

2. **Web ブラウザ** (SIMD対応)
   - Chrome 91+, Firefox 89+, Safari 16.4+

3. **ローカルサーバー** (CORS対策)
   - Python: `python3 -m http.server 8000`
   - Node.js: `npx serve .`

## ビルド方法

```bash
# デバッグビルド
zig build

# 最適化ビルド (本番用)
zig build -Doptimize=ReleaseFast

# テスト実行
zig build test
```

ビルド成果物は `zig-out/bin/z-render.wasm` に出力されます。

## 実行方法

```bash
# プロジェクトルートでサーバー起動
python3 -m http.server 8000

# ブラウザでアクセス
# http://localhost:8000/web/
```

## ディレクトリ構成

```
z-render/
├── build.zig          # ビルド設定
├── src/
│   ├── main.zig       # エントリーポイント (Wasm exports)
│   ├── math/          # 数学ライブラリ
│   │   ├── root.zig
│   │   ├── vec.zig    # ベクトル型
│   │   └── mat.zig    # 行列型
│   └── render/        # レンダリング
│       ├── root.zig
│       └── framebuffer.zig
├── web/
│   ├── index.html     # デモページ
│   └── renderer.js    # Wasm ↔ JS ブリッジ
└── docs/              # 学習用ドキュメント
```

## 次のステップ

1. `02-simd-basics.md` - ZigのSIMDについて学ぶ
2. `03-wasm-memory.md` - WebAssemblyのメモリモデル
3. `04-rasterization.md` - ラスタライズの基礎
