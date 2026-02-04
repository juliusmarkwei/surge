use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CleanableItem {
    pub path: PathBuf,
    pub size: u64,
    pub category: CleanupCategory,
    pub modified: DateTime<Local>,
    pub selected: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CleanupCategory {
    SystemCaches,
    UserCaches,
    Logs,
    Trash,
    Downloads,
    DeveloperCaches,
    BrowserData,
    ApplicationSupport,
}

impl CleanupCategory {
    pub fn all() -> Vec<Self> {
        vec![
            Self::SystemCaches,
            Self::UserCaches,
            Self::Logs,
            Self::Trash,
            Self::Downloads,
            Self::DeveloperCaches,
            Self::BrowserData,
            Self::ApplicationSupport,
        ]
    }

    pub fn name(&self) -> &'static str {
        match self {
            Self::SystemCaches => "System Caches",
            Self::UserCaches => "User Caches",
            Self::Logs => "Log Files",
            Self::Trash => "Trash",
            Self::Downloads => "Downloads",
            Self::DeveloperCaches => "Developer Caches",
            Self::BrowserData => "Browser Data",
            Self::ApplicationSupport => "Application Support",
        }
    }

    pub fn description(&self) -> &'static str {
        match self {
            Self::SystemCaches => "System-wide cache files",
            Self::UserCaches => "User application caches",
            Self::Logs => "Application and system logs",
            Self::Trash => "Deleted files in trash",
            Self::Downloads => "Downloaded files",
            Self::DeveloperCaches => "npm, cargo, gradle, pip caches",
            Self::BrowserData => "Browser caches and data",
            Self::ApplicationSupport => "Application support files",
        }
    }
}

#[derive(Debug, Clone)]
pub struct TreeMapItem {
    pub path: PathBuf,
    pub name: String,
    pub size: u64,
    pub children: Vec<TreeMapItem>,
    pub is_file: bool,
}

impl TreeMapItem {
    pub fn new(path: PathBuf, size: u64, is_file: bool) -> Self {
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Unknown")
            .to_string();

        Self {
            path,
            name,
            size,
            children: Vec::new(),
            is_file,
        }
    }

    pub fn percentage_of(&self, total: u64) -> f64 {
        if total == 0 {
            0.0
        } else {
            (self.size as f64 / total as f64) * 100.0
        }
    }
}

#[derive(Debug, Clone)]
pub struct DuplicateGroup {
    pub hash: String,
    pub files: Vec<DuplicateFile>,
    pub total_size: u64,
    pub wasted_size: u64, // size - size of one file
}

#[derive(Debug, Clone)]
pub struct DuplicateFile {
    pub path: PathBuf,
    pub size: u64,
    pub modified: DateTime<Local>,
    pub selected: bool,
}

#[derive(Debug, Clone)]
pub struct LargeFileItem {
    pub path: PathBuf,
    pub size: u64,
    pub modified: DateTime<Local>,
    pub accessed: DateTime<Local>,
    pub age_days: u64,
    pub selected: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityThreat {
    pub path: PathBuf,
    pub threat_type: ThreatType,
    pub severity: ThreatSeverity,
    pub description: String,
    pub detected_at: DateTime<Local>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ThreatType {
    SuspiciousFile,
    LaunchAgent,
    LaunchDaemon,
    LoginItem,
    KernelExtension,
    BrowserExtension,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ThreatSeverity {
    Low,
    Medium,
    High,
    Critical,
}

#[derive(Debug, Clone)]
pub struct SystemStats {
    pub cpu_usage: f32,
    pub memory_used: u64,
    pub memory_total: u64,
    pub disk_used: u64,
    pub disk_total: u64,
}

impl SystemStats {
    pub fn memory_percentage(&self) -> f64 {
        if self.memory_total == 0 {
            0.0
        } else {
            (self.memory_used as f64 / self.memory_total as f64) * 100.0
        }
    }

    pub fn disk_percentage(&self) -> f64 {
        if self.disk_total == 0 {
            0.0
        } else {
            (self.disk_used as f64 / self.disk_total as f64) * 100.0
        }
    }
}

#[derive(Debug, Clone)]
pub struct QuarantineItem {
    pub original_path: PathBuf,
    pub quarantine_path: PathBuf,
    pub quarantined_at: DateTime<Local>,
    pub size: u64,
}
