# Z-Render: The High-Performance Software GPU

Z-Render is a zero-dependency, SIMD-accelerated 3D graphics pipeline written in Zig.
It rejects modern graphics APIs (WebGL, WebGPU, Vulkan) to implement the entire rendering pipeline purely on the CPU, targeting WebAssembly for high-performance browser execution.
> Motto: "No GPU? No Problem. We are the GPU."

**🎮 [Live Demo on GitHub Pages](https://matuyuhi.github.io/z-render/)** *(自動デプロイ)*


🚀 Project Concept  

現代のGPUがハードウェアレベルで行っている処理（頂点変換、ラスタライズ、シェーディング）を、Zig のメモリ制御能力と SIMD 命令を駆使してソフトウェアレベルで再実装します。  
目的は、グラフィックスAPIのブラックボックスを開け、計算機科学的な最適化（キャッシュ局所性、並列処理、ベクトル演算）の極致を学ぶことです。  
🛠 Tech Stack
- Language: Zig (Release Safe/Fast)
- Target: WebAssembly (wasm32-freestanding)
- Key Tech:
  - SIMD: @Vector(4, f32) for massive parallel math.
  - Linear Memory: Direct pixel buffer manipulation.
  - No Allocations: Zero-allocation rendering loop.

🏗 Architecture (Pipeline)  
```mermaid
graph LR
    A[Input: Vertices] -->|Vertex Shader| B(Vertex Processing)
    B -->|Screen Coords| C{Rasterizer}
    C -->|Barycentric Coords| D[Fragment Shader]
    D -->|Color| E[Framebuffer]
    
    style A fill:#333,stroke:#fff,color:#fff
    style B fill:#444,stroke:#0f0,color:#fff
    style C fill:#444,stroke:#0f0,color:#fff
    style D fill:#444,stroke:#0f0,color:#fff
    style E fill:#333,stroke:#fff,color:#fff
```

- Vertex Processing: World/View/Projection 行列演算 (SIMD化)
- Rasterization: 重心座標系 (Barycentric Coordinates) を用いた三角形の塗りつぶし
- Fragment Processing: テクスチャマッピング、ライティング計算
- Output: u32 配列への書き込み -> Canvas (SharedArrayBuffer)
🔥 Technical Challenges (The "Hard" Parts)

1. SIMD-First Rasterization
ピクセルを1つずつ処理するのではなく、4ピクセル（またはそれ以上）をまとめて処理します。
- Goal: エッジ関数（三角形の内外判定）をベクトル命令で一括計算する。

2. Cache-Friendly Texture Mapping
テクスチャデータを単純な配列として保持すると、縦方向のアクセスでキャッシュミスが多発します。
- Solution: Z-Order Curve (Morton Code) を実装し、テクスチャをタイル状にメモリ配置してキャッシュヒット率を最大化します。

3. Tile-Based Multi-Threading
画面をタイル（例: 64x64px）に分割し、複数のWeb Workerで並列描画します。
- Challenge: ロックフリーなタスクキューの実装と、スレッド間の同期コストの最小化。
✅ Todo List & Roadmap

Phase 1: Foundation & Math
- [x] プロジェクトセットアップ (Zig + Wasmビルド環境)
- [x] フレームバッファ ([]u32) の作成とJS側への転送
- [x] SIMD算術ライブラリの実装 (Vec3, Vec4, Mat4)
  - [x] Dot Product, Cross Product のSIMD化

Phase 2: The Rasterizer (2D)
- [x] 頂点3つを受け取り、バウンディングボックスを計算する
- [x] Barycentric Coordinates (重心座標) の実装
- [x] 三角形の塗りつぶし (単色)
- [x] 重心座標を使った色の補間 (Gouraud Shadingの基礎)

Phase 3: The 3D Pipeline
- [x] Model, View, Projection 行列の実装
- [x] 座標変換パイプラインの構築 (Local -> World -> Clip -> Screen)
- [x] 深度バッファ (Z-Buffer) の実装
- [x] Back-face Culling (裏面の描画スキップ)

Phase 4: Shading & Textures
- [ ] UV座標の補間 (Perspective Correct Interpolation)
- [ ] テクスチャ読み込みとサンプリング (Nearest / Bilinear)
- [ ] 基本的なライティング (Lambert / Phong)

Phase 5: Optimization (The Beast Mode)
- [ ] SIMDラスタライザへの書き換え (4ピクセル同時処理)
- [ ] マルチスレッド化 (Web Workers)
- [ ] プロファイリングとボトルネック潰し

## 🚩 マイルストーン

### ✅ Phase 2 Milestone: "The Hello World Triangle"
2Dの三角形を、爆速で画面に出す。
- ✅ WasmからJSのCanvasへピクセルデータを転送
- ✅ Gouraud Shading（頂点カラー補間）
- ✅ ポインタ演算でバッファを直接書き換え

### ✅ Phase 3 Milestone: "The Rotating Cube"
3Dパイプラインを実装し、回転するキューブを描画。
- ✅ Model/View/Projection 行列による座標変換
- ✅ 深度バッファ (Z-Buffer) による正しい前後関係
- ✅ バックフェイスカリングで裏面をスキップ
- ✅ 60FPSで滑らかに回転する3Dキューブ

## 🚀 Quick Start

### ローカル環境で実行

1. **リポジトリをクローン**
```bash
git clone https://github.com/Matuyuhi/z-render.git
cd z-render
```

2. **Wasmモジュールをビルド**
```bash
zig build -Doptimize=ReleaseFast
```

3. **ローカルサーバーを起動**
```bash
python3 -m http.server 8000
```

4. **ブラウザで開く**
```
http://localhost:8000/web/
```

### GitHub Pagesでの自動デプロイ

mainブランチへのpush時に自動的にGitHub Pagesにデプロイされます。

**デプロイURL**: https://matuyuhi.github.io/z-render/

### 必要な環境

- Zig 0.15.2
- モダンなWebブラウザ（WebAssembly対応）

