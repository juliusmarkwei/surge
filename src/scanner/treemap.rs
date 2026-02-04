use anyhow::Result;
use std::path::{Path, PathBuf};
use std::fs;

use crate::models::TreeMapItem;

pub struct TreeMapScanner;

impl TreeMapScanner {
    pub fn new() -> Self {
        Self
    }

    /// Scan a directory and build a tree map
    pub fn scan(&self, root_path: &Path) -> Result<TreeMapItem> {
        self.scan_directory(root_path, 0, 3) // Max depth of 3 levels
    }

    fn scan_directory(&self, path: &Path, current_depth: usize, max_depth: usize) -> Result<TreeMapItem> {
        let metadata = fs::metadata(path)?;

        if metadata.is_file() {
            return Ok(TreeMapItem::new(
                path.to_path_buf(),
                metadata.len(),
                true,
            ));
        }

        let mut item = TreeMapItem::new(path.to_path_buf(), 0, false);
        let mut total_size = 0u64;

        // Read directory entries
        if let Ok(entries) = fs::read_dir(path) {
            for entry in entries.flatten() {
                if let Ok(child_metadata) = entry.metadata() {
                    let child_path = entry.path();

                    // Skip hidden files and system files
                    if let Some(name) = child_path.file_name() {
                        if name.to_string_lossy().starts_with('.') {
                            continue;
                        }
                    }

                    let child = if child_metadata.is_dir() {
                        if current_depth < max_depth {
                            // Recursively scan subdirectory
                            match self.scan_directory(&child_path, current_depth + 1, max_depth) {
                                Ok(child_item) => child_item,
                                Err(_) => continue, // Skip directories we can't read
                            }
                        } else {
                            // At max depth, just create a leaf node with the directory size
                            let dir_size = self.quick_dir_size(&child_path);
                            TreeMapItem::new(child_path, dir_size, false)
                        }
                    } else {
                        TreeMapItem::new(
                            child_path,
                            child_metadata.len(),
                            true,
                        )
                    };

                    total_size += child.size;
                    item.children.push(child);
                }
            }
        }

        // Sort children by size (largest first)
        item.children.sort_by(|a, b| b.size.cmp(&a.size));
        item.size = total_size;

        Ok(item)
    }

    /// Quickly calculate directory size without deep recursion
    fn quick_dir_size(&self, path: &Path) -> u64 {
        let mut total = 0u64;
        if let Ok(entries) = fs::read_dir(path) {
            for entry in entries.flatten() {
                if let Ok(metadata) = entry.metadata() {
                    total += metadata.len();
                }
            }
        }
        total
    }

    /// Get the home directory for scanning
    pub fn get_default_scan_path() -> PathBuf {
        dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"))
    }
}
