use anyhow::Result;
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

use crate::models::{DuplicateFile, DuplicateGroup};

pub struct DuplicateScanner {
    min_size: u64,
    max_depth: Option<usize>,
}

impl DuplicateScanner {
    pub fn new() -> Self {
        Self {
            min_size: 1024 * 100, // 100 KB minimum
            max_depth: None,
        }
    }

    pub fn with_min_size(mut self, min_size: u64) -> Self {
        self.min_size = min_size;
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

    /// Scan for duplicate files in the given path
    pub fn scan(&self, path: &Path) -> Result<Vec<DuplicateGroup>> {
        // Step 1: Group files by size (fast pre-filter)
        let size_groups = self.group_by_size(path)?;

        // Step 2: For files with same size, calculate SHA-256 hash
        let mut hash_groups: HashMap<String, Vec<DuplicateFile>> = HashMap::new();

        for (size, files) in size_groups {
            // Only hash if there are at least 2 files with same size
            if files.len() < 2 {
                continue;
            }

            for file_path in files {
                if let Ok(hash) = self.hash_file(&file_path) {
                    let metadata = fs::metadata(&file_path).ok();
                    let modified = metadata
                        .and_then(|m| m.modified().ok())
                        .map(|t| chrono::DateTime::from(t))
                        .unwrap_or_else(|| chrono::Local::now());

                    let duplicate_file = DuplicateFile {
                        path: file_path,
                        size,
                        modified,
                        selected: false,
                    };

                    hash_groups.entry(hash).or_default().push(duplicate_file);
                }
            }
        }

        // Step 3: Convert to DuplicateGroup, keeping only groups with 2+ files
        let mut duplicate_groups: Vec<DuplicateGroup> = hash_groups
            .into_iter()
            .filter(|(_, files)| files.len() >= 2)
            .map(|(hash, mut files)| {
                // Sort by modification time (oldest first)
                files.sort_by(|a, b| a.modified.cmp(&b.modified));

                let total_size = files.iter().map(|f| f.size).sum::<u64>();
                let duplicate_size = if !files.is_empty() {
                    total_size - files[0].size // All but one copy is wasted
                } else {
                    0
                };

                DuplicateGroup {
                    hash,
                    files,
                    total_size,
                    duplicate_size,
                }
            })
            .collect();

        // Sort groups by wasted size (largest waste first)
        duplicate_groups.sort_by(|a, b| b.duplicate_size.cmp(&a.duplicate_size));

        Ok(duplicate_groups)
    }

    /// Group files by size
    fn group_by_size(&self, path: &Path) -> Result<HashMap<u64, Vec<PathBuf>>> {
        let mut size_map: HashMap<u64, Vec<PathBuf>> = HashMap::new();

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

            // Skip files smaller than minimum size
            if let Ok(metadata) = entry.metadata() {
                let size = metadata.len();
                if size < self.min_size {
                    continue;
                }

                size_map.entry(size).or_default().push(entry.path().to_path_buf());
            }
        }

        Ok(size_map)
    }

    /// Calculate SHA-256 hash of a file
    fn hash_file(&self, path: &Path) -> Result<String> {
        let file = File::open(path)?;
        let mut reader = BufReader::new(file);
        let mut hasher = Sha256::new();
        let mut buffer = [0; 8192]; // 8KB buffer

        loop {
            let bytes_read = reader.read(&mut buffer)?;
            if bytes_read == 0 {
                break;
            }
            hasher.update(&buffer[..bytes_read]);
        }

        let hash = hasher.finalize();
        Ok(format!("{:x}", hash))
    }

    /// Calculate total duplicate space across all duplicate groups
    pub fn calculate_total_duplicates(groups: &[DuplicateGroup]) -> u64 {
        groups.iter().map(|g| g.duplicate_size).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::TempDir;

    #[test]
    fn test_finds_duplicates() {
        let temp_dir = TempDir::new().unwrap();
        let temp_path = temp_dir.path();

        // Create identical files
        let content = b"test content for duplicate detection";
        let file1 = temp_path.join("file1.txt");
        let file2 = temp_path.join("file2.txt");

        fs::write(&file1, content).unwrap();
        fs::write(&file2, content).unwrap();

        let scanner = DuplicateScanner::new().with_min_size(1); // Very small min size for test
        let groups = scanner.scan(temp_path).unwrap();

        assert_eq!(groups.len(), 1, "Should find exactly one duplicate group");
        assert_eq!(groups[0].files.len(), 2, "Group should contain 2 files");
    }

    #[test]
    fn test_hash_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");

        let content = b"hello world";
        fs::write(&file_path, content).unwrap();

        let scanner = DuplicateScanner::new();
        let hash1 = scanner.hash_file(&file_path).unwrap();
        let hash2 = scanner.hash_file(&file_path).unwrap();

        assert_eq!(hash1, hash2, "Same file should produce same hash");
    }
}
