//! Integration tests for Window Restore
//! CoreGraphics等の環境依存APIを避け、LayoutManagerの往復動作のみを検証

use std::env;

#[test]
fn layout_roundtrip_flow_pure_io() {
    // 分離されたテスト用データディレクトリ
    let cwd = std::env::current_dir().unwrap();
    let data_dir = cwd.join("target").join("it_window_restore");
    std::fs::create_dir_all(&data_dir).unwrap();
    env::set_var("WINDOW_RESTORE_DATA_DIR", &data_dir);

    // ダミーウィンドウを1件作成（純粋データのみ）
    let dummy_window = window_restore::WindowInfo {
        app_name: "DummyApp".to_string(),
        bundle_id: "com.example.dummy".to_string(),
        title: "Dummy Window".to_string(),
        frame: window_restore::WindowFrame { x: 10.0, y: 20.0, width: 300.0, height: 200.0 },
        display_uuid: "display-0".to_string(),
        window_level: window_restore::WindowLevel::Normal,
        is_minimized: false,
        is_hidden: false,
    };

    let lm = window_restore::layout_manager::LayoutManager::new().expect("layout manager");

    // 保存
    lm.save_layout("it_test_layout", &[dummy_window.clone()]).expect("save layout");

    // 一覧
    let list = lm.list_layouts().expect("list layouts");
    assert!(list.iter().any(|n| n == "it_test_layout"));

    // 読み込み
    let layout = lm.load_layout("it_test_layout").expect("load layout");
    assert_eq!(layout.layout_name, "it_test_layout");
    assert_eq!(layout.windows.len(), 1);
    assert_eq!(layout.windows[0].title, "Dummy Window");

    // 削除
    lm.delete_layout("it_test_layout").expect("delete layout");

    // 削除後に一覧に含まれない
    let list_after = lm.list_layouts().expect("list layouts after delete");
    assert!(list_after.iter().all(|n| n != "it_test_layout"));
}


