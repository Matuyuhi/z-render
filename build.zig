const std = @import("std");

/// Z-Render Build Configuration
/// =============================
/// WebAssembly向けのソフトウェアレンダラーをビルドします。
///
/// ビルドコマンド:
///   zig build                    # デバッグビルド
///   zig build -Doptimize=ReleaseFast  # 最適化ビルド
///
/// 出力: zig-out/lib/z-render.wasm
pub fn build(b: *std.Build) void {
    // ターゲット: WebAssembly (wasm32-freestanding)
    // freestanding = OSなし、標準ライブラリの一部のみ使用可能
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    // 最適化レベル (コマンドラインから -Doptimize=XXX で指定可能)
    const optimize = b.standardOptimizeOption(.{});

    // メインのWasmライブラリをビルド
    const lib = b.addExecutable(.{
        .name = "z-render",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Wasm向けの設定
    // エントリーポイントを無効化 (JSから直接関数を呼び出すため)
    lib.entry = .disabled;

    // export された関数をJS側から呼び出せるようにする
    lib.rdynamic = true;

    // スタックサイズの設定 (必要に応じて調整)
    lib.stack_size = 64 * 1024; // 64KB

    // ビルド成果物をインストール
    b.installArtifact(lib);

    // ===================
    // テスト設定
    // ===================
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        // テストはネイティブターゲットで実行
        .target = b.host,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
