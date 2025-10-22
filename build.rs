// ビルドスクリプト
// RustのFFI関数からCヘッダーファイルを自動生成する

use cbindgen;
use std::env;
use std::path::PathBuf;

fn main() {
    // プロジェクトのルートディレクトリを取得
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    
    // 出力先のヘッダーファイルパスを構築
    // mac-app/Bridging/window_restore.h に出力される
    let output_file = PathBuf::from(&crate_dir)
        .join("mac-app")
        .join("Bridging")
        .join("window_restore.h");

    // cbindgenを使用してCヘッダーファイルを生成
    // Rustの公開FFI関数がCから呼び出せる形式でエクスポートされる
    cbindgen::generate(crate_dir)
        .expect("Unable to generate bindings")
        .write_to_file(output_file);
}
