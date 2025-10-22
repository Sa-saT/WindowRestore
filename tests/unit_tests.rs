//! Unit tests for Window Restore
//! Window Restoreのユニットテスト
//! 各モジュールの基本的な機能をテストする

#[cfg(test)]
mod tests {
    // window_restoreクレートからすべてのモジュールをインポート
    use window_restore::*;

    /// WindowRestoreインスタンスの作成をテスト
    /// メインのWindowRestore構造体が正常に初期化できることを確認
    #[test]
    fn test_window_restore_creation() {
        let app = WindowRestore::new();
        assert!(app.is_ok());
    }

    /// デフォルト設定の値をテスト
    /// Config::default()が期待される初期値を持つことを確認
    #[test]
    fn test_config_default() {
        let config = config::Config::default();
        // 自動復元はデフォルトでfalse
        assert_eq!(config.auto_restore, false);
        // ディスプレイ変更検知はデフォルトでtrue
        assert_eq!(config.display_change_detection, true);
        // Finderはデフォルトで除外リストに含まれる
        assert!(config.exclude_apps.contains(&"com.apple.finder".to_string()));
    }

    /// LayoutManagerの作成をテスト
    /// レイアウトマネージャーが正常に初期化できることを確認
    /// 注: ディレクトリ作成権限がない場合は失敗する可能性がある
    #[test]
    fn test_layout_manager_creation() {
        let manager = layout_manager::LayoutManager::new();
        assert!(manager.is_ok());
    }

    /// PermissionCheckerの作成をテスト
    /// 権限チェッカーが正常に初期化できることを確認
    #[test]
    fn test_permission_checker_creation() {
        let checker = permission_checker::PermissionChecker::new();
        assert!(checker.is_ok());
    }

    /// NotificationManagerの作成をテスト
    /// 通知マネージャーが正常に初期化できることを確認
    #[test]
    fn test_notification_manager_creation() {
        let manager = notification::NotificationManager::new();
        assert!(manager.is_ok());
    }

    /// AppLauncherの作成をテスト
    /// アプリランチャーが正常に初期化できることを確認
    #[test]
    fn test_app_launcher_creation() {
        let launcher = app_launcher::AppLauncher::new();
        assert!(launcher.is_ok());
    }

    /// DisplayManagerの作成をテスト
    /// ディスプレイマネージャーが正常に初期化できることを確認
    #[test]
    fn test_display_manager_creation() {
        let manager = display_manager::DisplayManager::new();
        assert!(manager.is_ok());
    }
}
