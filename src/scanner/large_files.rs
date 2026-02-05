use anyhow::Result;
use chrono::{DateTime, Local};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};
use walkdir::WalkDir;

use crate::models::LargeFileItem;

pub struct LargeFileScanner {
    min_size: u64,
    min_age_days: u64,
    max_depth: Option<usize>,
}

impl LargeFileScanner {
    pub fn new() -> Self {
        Self {
            min_size: 1024 * 1024 * 100, // 100 MB default
            min_age_days: 0,              // No age requirement by default
            max_depth: None,
        }
    }

    pub fn with_min_size(mut self, min_size: u64) -> Self {
        self.min_size = min_size;
        self
    }

    pub fn with_min_age_days(mut self, days: u64) -> Self {
        self.min_age_days = days;
        self
    }

    pub fn with_max_depth(mut self, max_depth: usize) -> Self {
        self.max_depth = Some(max_depth);
        self
    }

    /// Get default scan path (user's home directory)
    pub fn get_default_scan_path() -> PathBuf {
        dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"))
    }

    /// Scan for large and/or old files
    pub fn scan(&self, path: &Path) -> Result<Vec<LargeFileItem>> {
        let mut items = Vec::new();
        let now = SystemTime::now();
        let age_cutoff = if self.min_age_days > 0 {
            Some(now - Duration::from_secs(self.min_age_days * 86400))
        } else {
            None
        };

        let walker = if let Some(depth) = self.max_depth {
            WalkDir::new(path).max_depth(depth)
        } else {
            WalkDir::new(path)
        };

        for entry in walker.follow_links(false).into_iter().filter_map(|e| e.ok()) {
            // Only process files
            if !entry.file_type().is_file() {
                continue;
            }

            if let Ok(metadata) = entry.metadata() {
                let size = metadata.len();

                // Check size requirement
                if size < self.min_size {
                    continue;
                }

                // Get file times
                let modified = metadata
                    .modified()
                    .ok()
                    .map(|t| DateTime::from(t))
                    .unwrap_or_else(|| Local::now());

                let accessed = metadata
                    .accessed()
                    .ok()
                    .map(|t| DateTime::from(t))
                    .unwrap_or_else(|| Local::now());

                // Check age requirement (if specified)
                if let Some(cutoff) = age_cutoff {
                    if let Ok(mod_time) = metadata.modified() {
                        if mod_time >= cutoff {
                            continue; // File is too new
                        }
                    }
                }

                // Calculate age in days
                let age_days = if let Ok(mod_time) = metadata.modified() {
                    if let Ok(duration) = now.duration_since(mod_time) {
                        duration.as_secs() / 86400
                    } else {
                        0
                    }
                } else {
                    0
                };

                items.push(LargeFileItem {
                    path: entry.path().to_path_buf(),
                    size,
                    modified,
                    accessed,
                    age_days,
                    selected: false,
                });
            }
        }

        // Sort by size (largest first)
        items.sort_by(|a, b| b.size.cmp(&a.size));

        Ok(items)
    }

    /// Calculate total size of items
    pub fn calculate_total_size(items: &[LargeFileItem]) -> u64 {
        items.iter().map(|i| i.size).sum()
    }

    /// Group items by size category
    pub fn group_by_size_category(items: &[LargeFileItem]) -> SizeCategories {
        let mut huge = Vec::new(); // > 1 GB
        let mut very_large = Vec::new(); // 500 MB - 1 GB
        let mut large = Vec::new(); // 100 MB - 500 MB
        let mut medium = Vec::new(); // < 100 MB

        for item in items {
            let size_gb = item.size as f64 / (1024.0 * 1024.0 * 1024.0);
            let size_mb = item.size as f64 / (1024.0 * 1024.0);

            if size_gb >= 1.0 {
                huge.push(item.clone());
            } else if size_mb >= 500.0 {
                very_large.push(item.clone());
            } else if size_mb >= 100.0 {
                large.push(item.clone());
            } else {
                medium.push(item.clone());
            }
        }

        SizeCategories {
            huge,
            very_large,
            large,
            medium,
        }
    }
}

#[derive(Debug, Clone)]
pub struct SizeCategories {
    pub huge: Vec<LargeFileItem>,        // > 1 GB
    pub very_large: Vec<LargeFileItem>,  // 500 MB - 1 GB
    pub large: Vec<LargeFileItem>,       // 100 MB - 500 MB
    pub medium: Vec<LargeFileItem>,      // < 100 MB
}

impl SizeCategories {
    pub fn total_count(&self) -> usize {
        self.huge.len() + self.very_large.len() + self.large.len() + self.medium.len()
    }

    pub fn total_size(&self) -> u64 {
        LargeFileScanner::calculate_total_size(&self.huge)
            + LargeFileScanner::calculate_total_size(&self.very_large)
            + LargeFileScanner::calculate_total_size(&self.large)
            + LargeFileScanner::calculate_total_size(&self.medium)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::TempDir;

    #[test]
    fn test_finds_large_files() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        // Create a large file (1 MB)
        let large_file = temp_path.join("large.bin");
        let mut file = fs::File::create(&large_file).unwrap();
        let data = vec![0u8; 1024 * 1024]; // 1 MB
        file.write_all(&data).unwrap();

        // Create a small file
        let small_file = temp_path.join("small.txt");
        fs::write(&small_file, b"small").unwrap();

        let scanner = LargeFileScanner::new().with_min_size(1024 * 500); // 500 KB
        let items = scanner.scan(temp_path).unwrap();

        assert_eq!(items.len(), 1, "Should find exactly one large file");
        assert!(items[0].size >= 1024 * 1024);
    }

    #[test]
    fn test_age_filter() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        // Create a file
        let file_path = temp_path.join("test.bin");
        let data = vec![0u8; 1024 * 1024]; // 1 MB
        fs::write(&file_path, data).unwrap();

        // Scan for files older than 1 day (should find nothing since file is new)
        let scanner = LargeFileScanner::new()
            .with_min_size(1024 * 500)
            .with_min_age_days(1);
        let items = scanner.scan(temp_path).unwrap();

        assert_eq!(items.len(), 0, "Should not find newly created file");
    }

    #[test]
    fn test_sorting_by_size() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        // Create files of different sizes
        fs::write(temp_path.join("small.bin"), vec![0u8; 1024 * 1024]).unwrap(); // 1 MB
        fs::write(temp_path.join("large.bin"), vec![0u8; 5 * 1024 * 1024]).unwrap(); // 5 MB
        fs::write(temp_path.join("medium.bin"), vec![0u8; 3 * 1024 * 1024]).unwrap(); // 3 MB

        let scanner = LargeFileScanner::new().with_min_size(1024 * 500);
        let items = scanner.scan(temp_path).unwrap();

        assert_eq!(items.len(), 3);
        // Should be sorted by size descending
        assert!(items[0].size >= items[1].size);
        assert!(items[1].size >= items[2].size);
    }
}
