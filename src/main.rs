fn main() {
    println!("Window Restore Application Starting");
    // 権限チェックの実行（簡易確認用）
    let has_permission = window_restore::permission_checker::check_accessibility_permission();
    println!("Accessibility permission: {}", has_permission);
}
