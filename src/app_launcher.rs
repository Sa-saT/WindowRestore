//! Application launcher functionality

use anyhow::Result;
use std::process::Command;

/// Application launcher for macOS
pub struct AppLauncher {
    // Internal state for app launching
}

impl AppLauncher {
    /// Create a new AppLauncher instance
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }

    /// Launch an application by bundle ID
    pub fn launch_app(&self, bundle_id: &str) -> Result<()> {
        log::info!("Launching application: {}", bundle_id);
        
        let output = Command::new("open")
            .arg("-b")
            .arg(bundle_id)
            .output()?;
        
        if !output.status.success() {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("Failed to launch app {}: {}", bundle_id, error_msg));
        }
        
        log::info!("Successfully launched application: {}", bundle_id);
        Ok(())
    }

    /// Check if an application is running
    pub fn is_app_running(&self, bundle_id: &str) -> bool {
        let output = Command::new("pgrep")
            .arg("-f")
            .arg(bundle_id)
            .output();
        
        match output {
            Ok(result) => result.status.success(),
            Err(_) => false,
        }
    }

    /// Get running applications
    pub fn get_running_apps(&self) -> Result<Vec<String>> {
        let output = Command::new("ps")
            .arg("-ax")
            .arg("-o")
            .arg("comm")
            .output()?;
        
        let stdout = String::from_utf8(output.stdout)?;
        let apps: Vec<String> = stdout
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect();
        
        Ok(apps)
    }

    /// Wait for application to start
    pub fn wait_for_app(&self, bundle_id: &str, timeout_ms: u64) -> Result<()> {
        let start_time = std::time::Instant::now();
        let timeout = std::time::Duration::from_millis(timeout_ms);
        
        while start_time.elapsed() < timeout {
            if self.is_app_running(bundle_id) {
                return Ok(());
            }
            
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        
        Err(anyhow::anyhow!("Timeout waiting for app to start: {}", bundle_id))
    }
}
