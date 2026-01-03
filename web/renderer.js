/**
 * Z-Render: JavaScript / WebAssembly Bridge
 * ==========================================
 *
 * このファイルはWasmモジュールとCanvas APIを橋渡しします。
 *
 * ## 学習ポイント
 *
 * ### 1. WebAssembly のメモリモデル
 *
 * Wasm は「リニアメモリ」という連続したバイト配列を持ちます。
 * JS側から `WebAssembly.Memory` オブジェクトとしてアクセスできます。
 *
 * ```
 * [0x00000000] ─────────────────────────────────────── [0xFFFFFFFF]
 *     |                    Wasm Linear Memory                    |
 *     |  [Zig static data] [Stack] [Heap (unused)]               |
 *     |      └── framebuffer はここに配置される                    |
 * ```
 *
 * ### 2. JS ↔ Wasm データ転送
 *
 * 方法1: メモリ共有（高速）
 *   - Wasm側でバッファを確保し、ポインタをJSに渡す
 *   - JSはそのポインタを使って直接メモリにアクセス
 *   - コピー不要！
 *
 * 方法2: SharedArrayBuffer + Web Workers（最速、Phase 5）
 *   - 複数のWeb Workerが同じメモリを共有
 *   - タイルベースの並列レンダリングが可能
 *
 * ### 3. ImageData と Canvas
 *
 * Canvas 2D の `putImageData()` は、Uint8ClampedArray を受け取ります。
 * Wasmのu32配列をUint8ClampedArrayとして解釈することで、
 * メモリコピーなしでCanvasに描画できます。
 */

class ZRenderer {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.width = canvas.width;
        this.height = canvas.height;

        // Wasm関連
        this.wasm = null;
        this.memory = null;
        this.framebufferPtr = 0;

        // FPS計測用
        this.lastTime = performance.now();
        this.frameCount = 0;
        this.fps = 0;

        // ImageData (Canvas描画用)
        this.imageData = this.ctx.createImageData(this.width, this.height);
    }

    /**
     * Wasmモジュールを読み込んで初期化
     */
    async init() {
        try {
            // Wasmファイルを読み込み
            const response = await fetch('../zig-out/bin/z-render.wasm');
            const bytes = await response.arrayBuffer();

            // Wasmをインスタンス化
            const result = await WebAssembly.instantiate(bytes, {
                env: {
                    // Wasm側からJSの関数を呼び出す場合はここに定義
                    // 例: console_log: (ptr, len) => { ... }
                }
            });

            this.wasm = result.instance.exports;
            this.memory = this.wasm.memory;

            // フレームバッファを初期化
            const success = this.wasm.initFramebuffer(this.width, this.height);
            if (!success) {
                throw new Error('Failed to initialize framebuffer');
            }

            // フレームバッファのポインタを取得
            this.framebufferPtr = this.wasm.getFramebufferPtr();

            console.log('Z-Render initialized successfully!');
            console.log(`Resolution: ${this.width}x${this.height}`);
            console.log(`Framebuffer pointer: 0x${this.framebufferPtr.toString(16)}`);

            this.updateStats();
            return true;

        } catch (error) {
            console.error('Failed to initialize Z-Render:', error);
            this.showError(error.message);
            return false;
        }
    }

    /**
     * 1フレームを描画
     */
    render() {
        if (!this.wasm) return;

        // Wasm側でレンダリング
        this.wasm.renderFrame();

        // フレームバッファをCanvasに転送
        this.blitToCanvas();

        // FPS計測
        this.measureFps();
    }

    /**
     * フレームバッファをCanvasに転送
     *
     * 学習ポイント:
     * - Wasmのメモリを Uint8ClampedArray として解釈
     * - putImageData で Canvas に一括転送
     * - メモリコピーは発生するが、ピクセル単位の操作より高速
     */
    blitToCanvas() {
        const bufferSize = this.width * this.height * 4; // RGBA = 4 bytes/pixel
        const wasmBuffer = new Uint8ClampedArray(
            this.memory.buffer,
            this.framebufferPtr,
            bufferSize
        );

        // ImageData に直接セット
        this.imageData.data.set(wasmBuffer);

        // Canvas に描画
        this.ctx.putImageData(this.imageData, 0, 0);
    }

    /**
     * 画面を指定色でクリア
     * @param {number} color - ABGR形式の色 (0xAABBGGRR)
     */
    clear(color) {
        if (!this.wasm) return;
        this.wasm.clearFramebuffer(color);
    }

    /**
     * FPS計測
     */
    measureFps() {
        this.frameCount++;
        const now = performance.now();
        const delta = now - this.lastTime;

        if (delta >= 1000) {
            this.fps = Math.round((this.frameCount * 1000) / delta);
            this.frameCount = 0;
            this.lastTime = now;
            this.updateStats();
        }
    }

    /**
     * 統計情報を更新
     */
    updateStats() {
        const fpsEl = document.getElementById('fps');
        const resEl = document.getElementById('resolution');

        if (fpsEl) fpsEl.textContent = `FPS: ${this.fps}`;
        if (resEl) resEl.textContent = `Resolution: ${this.width}x${this.height}`;
    }

    /**
     * エラー表示
     */
    showError(message) {
        this.ctx.fillStyle = '#ff0000';
        this.ctx.font = '16px monospace';
        this.ctx.fillText(`Error: ${message}`, 20, 30);
        this.ctx.fillText('Make sure to build the Wasm first:', 20, 60);
        this.ctx.fillText('  zig build', 20, 90);
    }

    /**
     * アニメーションループ開始
     */
    startLoop() {
        const loop = () => {
            this.render();
            requestAnimationFrame(loop);
        };
        requestAnimationFrame(loop);
    }
}

// =============================================================================
// RGBA色の作成ヘルパー (ABGR形式、リトルエンディアン)
// =============================================================================

function rgba(r, g, b, a = 255) {
    return ((a << 24) | (b << 16) | (g << 8) | r) >>> 0;
}

// =============================================================================
// メイン
// =============================================================================

async function main() {
    const canvas = document.getElementById('canvas');
    const renderer = new ZRenderer(canvas);

    const success = await renderer.init();
    if (!success) return;

    // 初期状態: 黒でクリア
    renderer.clear(rgba(0, 0, 0, 255));
    renderer.blitToCanvas();

    // ボタンイベント
    document.getElementById('btn-clear-red').addEventListener('click', () => {
        renderer.clear(rgba(255, 50, 50, 255));
        renderer.blitToCanvas();
    });

    document.getElementById('btn-clear-green').addEventListener('click', () => {
        renderer.clear(rgba(50, 255, 50, 255));
        renderer.blitToCanvas();
    });

    document.getElementById('btn-clear-blue').addEventListener('click', () => {
        renderer.clear(rgba(50, 50, 255, 255));
        renderer.blitToCanvas();
    });

    // アニメーションループは必要に応じて有効化
    // renderer.startLoop();

    console.log('Z-Render is ready!');
    console.log('Try: renderer.clear(rgba(255, 0, 0, 255))');
}

// DOMContentLoaded を待ってから実行
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', main);
} else {
    main();
}
