//! Unit tests for Window Restore

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_window_restore_creation() {
        let app = WindowRestore::new();
        assert!(app.is_ok());
    }

    #[test]
    fn test_config_default() {
        let config = config::Config::default();
        assert_eq!(config.auto_restore, false);
        assert_eq!(config.display_change_detection, true);
        assert!(config.exclude_apps.contains(&"com.apple.finder".to_string()));
    }

    #[test]
    fn test_layout_manager_creation() {
        let manager = layout_manager::LayoutManager::new();
        assert!(manager.is_ok());
    }

    #[test]
    fn test_permission_checker_creation() {
        let checker = permission_checker::PermissionChecker::new();
        assert!(checker.is_ok());
    }

    #[test]
    fn test_notification_manager_creation() {
        let manager = notification::NotificationManager::new();
        assert!(manager.is_ok());
    }

    #[test]
    fn test_app_launcher_creation() {
        let launcher = app_launcher::AppLauncher::new();
        assert!(launcher.is_ok());
    }

    #[test]
    fn test_display_manager_creation() {
        let manager = display_manager::DisplayManager::new();
        assert!(manager.is_ok());
    }
}
