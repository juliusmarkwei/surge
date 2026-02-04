use anyhow::Result;
use chrono::Local;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::models::{CleanableItem, CleanupCategory};

pub struct CleanupScanner;

impl CleanupScanner {
    pub fn new() -> Self {
        Self
    }

    /// Get paths to scan for a given category
    #[cfg(target_os = "macos")]
    fn get_category_paths(category: &CleanupCategory) -> Vec<PathBuf> {
        match category {
            CleanupCategory::SystemCaches => vec![
                PathBuf::from("/Library/Caches"),
                PathBuf::from("/System/Library/Caches"),
            ],
            CleanupCategory::UserCaches => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join("Library/Caches")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::Logs => {
                let mut paths = vec![
                    PathBuf::from("/Library/Logs"),
                    PathBuf::from("/private/var/log"),
                ];
                if let Some(home) = dirs::home_dir() {
                    paths.push(home.join("Library/Logs"));
                }
                paths
            }
            CleanupCategory::Trash => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join(".Trash")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::Downloads => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join("Downloads")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::DeveloperCaches => {
                if let Some(home) = dirs::home_dir() {
                    vec![
                        home.join(".npm"),
                        home.join(".yarn"),
                        home.join(".cargo/registry"),
                        home.join(".gradle/caches"),
                        home.join("Library/Developer/Xcode/DerivedData"),
                        home.join("Library/Developer/CoreSimulator/Caches"),
                    ]
                } else {
                    vec![]
                }
            }
            CleanupCategory::BrowserData => {
                if let Some(home) = dirs::home_dir() {
                    vec![
                        home.join("Library/Caches/Google/Chrome"),
                        home.join("Library/Caches/Firefox"),
                        home.join("Library/Safari"),
                    ]
                } else {
                    vec![]
                }
            }
            CleanupCategory::ApplicationSupport => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join("Library/Application Support")]
                } else {
                    vec![]
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    fn get_category_paths(category: &CleanupCategory) -> Vec<PathBuf> {
        match category {
            CleanupCategory::SystemCaches => vec![PathBuf::from("/var/cache")],
            CleanupCategory::UserCaches => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join(".cache")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::Logs => vec![PathBuf::from("/var/log")],
            CleanupCategory::Trash => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join(".local/share/Trash")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::Downloads => {
                if let Some(home) = dirs::home_dir() {
                    vec![home.join("Downloads")]
                } else {
                    vec![]
                }
            }
            CleanupCategory::DeveloperCaches => {
                if let Some(home) = dirs::home_dir() {
                    vec![
                        home.join(".npm"),
                        home.join(".yarn"),
                        home.join(".cargo/registry"),
                        home.join(".gradle/caches"),
                        home.join(".cache/pip"),
                    ]
                } else {
                    vec![]
                }
            }
            CleanupCategory::BrowserData => {
                if let Some(home) = dirs::home_dir() {
                    vec![
                        home.join(".cache/google-chrome"),
                        home.join(".mozilla/firefox"),
                        home.join(".cache/chromium"),
                    ]
                } else {
                    vec![]
                }
            }
            CleanupCategory::ApplicationSupport => vec![],
        }
    }

    /// Scan a category for cleanable items
    pub fn scan_category(&self, category: CleanupCategory) -> Result<Vec<CleanableItem>> {
        let paths = Self::get_category_paths(&category);
        let mut items = Vec::new();

        for path in paths {
            if !path.exists() {
                continue;
            }

            items.extend(self.scan_path(&path, &category)?);
        }

        Ok(items)
    }

    /// Scan a specific path recursively
    fn scan_path(&self, path: &Path, category: &CleanupCategory) -> Result<Vec<CleanableItem>> {
        let mut items = Vec::new();
        let mut dir_sizes: std::collections::HashMap<PathBuf, u64> = std::collections::HashMap::new();

        // Walk through all files and accumulate directory sizes
        for entry in WalkDir::new(path)
            .max_depth(5) // Scan deeper
            .follow_links(false)
        {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };

            if entry.file_type().is_file() {
                if let Ok(metadata) = entry.metadata() {
                    let size = metadata.len();

                    // Add to parent directory size
                    if let Some(parent) = entry.path().parent() {
                        *dir_sizes.entry(parent.to_path_buf()).or_insert(0) += size;
                    }
                }
            }
        }

        // Convert directory sizes to CleanableItems
        for (dir_path, total_size) in dir_sizes.iter() {
            if *total_size > 100 * 1024 { // Only show dirs > 100KB
                if let Ok(metadata) = std::fs::metadata(dir_path) {
                    let modified = metadata
                        .modified()
                        .ok()
                        .map(|t| chrono::DateTime::<Local>::from(t))
                        .unwrap_or_else(Local::now);

                    items.push(CleanableItem {
                        path: dir_path.clone(),
                        size: *total_size,
                        category: *category,
                        modified,
                        selected: false,
                    });
                }
            }
        }

        Ok(items)
    }

    /// Scan all categories
    pub fn scan_all(&self) -> Result<Vec<CleanableItem>> {
        let mut all_items = Vec::new();

        // Scan all predefined categories
        for category in CleanupCategory::all() {
            all_items.extend(self.scan_category(category)?);
        }

        // If we found nothing, do a broader scan of the home directory
        if all_items.is_empty() {
            if let Some(home) = dirs::home_dir() {
                // Scan common user directories
                let common_dirs = vec![
                    home.join("Downloads"),
                    home.join("Documents"),
                    home.join("Desktop"),
                    home.join("Library"),
                ];

                for dir in common_dirs {
                    if dir.exists() {
                        all_items.extend(self.scan_path(&dir, &CleanupCategory::UserCaches)?);
                    }
                }
            }
        }

        Ok(all_items)
    }
}
