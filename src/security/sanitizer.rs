use anyhow::{anyhow, Result};
use std::path::{Path, PathBuf};
use std::time::SystemTime;

use super::blacklist::BLACKLISTED_PATHS;

#[derive(Debug, Clone)]
pub enum ValidationError {
    PathTraversal(String),
    Blacklisted(String),
    DoesNotExist(String),
    TooRecent(String, u64),
    NotSafeToDelete(String),
}

impl std::fmt::Display for ValidationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ValidationError::PathTraversal(p) => write!(f, "Path traversal detected: {}", p),
            ValidationError::Blacklisted(p) => write!(f, "Path is blacklisted: {}", p),
            ValidationError::DoesNotExist(p) => write!(f, "Path does not exist: {}", p),
            ValidationError::TooRecent(p, days) => {
                write!(f, "File too recent ({} days old): {}", days, p)
            }
            ValidationError::NotSafeToDelete(p) => write!(f, "Not safe to delete: {}", p),
        }
    }
}

impl std::error::Error for ValidationError {}

pub struct PathSanitizer {
    /// Minimum age in days before a file can be deleted (default: 7 days)
    min_age_days: u64,
    /// Whether to enforce age protection
    enforce_age_protection: bool,
}

impl Default for PathSanitizer {
    fn default() -> Self {
        Self {
            min_age_days: 7,
            enforce_age_protection: true,
        }
    }
}

impl PathSanitizer {
    pub fn new(min_age_days: u64, enforce_age_protection: bool) -> Self {
        Self {
            min_age_days,
            enforce_age_protection,
        }
    }

    /// Main sanitization method - validates and canonicalizes a path
    pub fn sanitize_path(&self, path: &Path) -> Result<PathBuf> {
        // 1. Expand home directory
        let expanded = self.expand_home(path)?;

        // 2. Canonicalize (resolve symlinks, relative paths)
        let canonical = match expanded.canonicalize() {
            Ok(p) => p,
            Err(_) => {
                // If path doesn't exist, try parent directory
                if let Some(parent) = expanded.parent() {
                    if parent.exists() {
                        expanded
                    } else {
                        return Err(anyhow!(ValidationError::DoesNotExist(
                            path.display().to_string()
                        )));
                    }
                } else {
                    return Err(anyhow!(ValidationError::DoesNotExist(
                        path.display().to_string()
                    )));
                }
            }
        };

        // 3. Check for path traversal attacks
        self.check_path_traversal(&canonical)?;

        // 4. Check blacklist
        self.check_blacklist(&canonical)?;

        // 5. Check age protection (if enabled)
        if self.enforce_age_protection {
            self.check_age_protection(&canonical)?;
        }

        Ok(canonical)
    }

    /// Validate multiple paths at once
    pub fn sanitize_paths(&self, paths: &[PathBuf]) -> Result<Vec<PathBuf>> {
        paths
            .iter()
            .map(|p| self.sanitize_path(p))
            .collect::<Result<Vec<_>>>()
    }

    /// Expand ~ to home directory
    fn expand_home(&self, path: &Path) -> Result<PathBuf> {
        let path_str = path.to_str().ok_or_else(|| anyhow!("Invalid UTF-8 in path"))?;

        if path_str.starts_with("~/") {
            if let Some(home) = dirs::home_dir() {
                Ok(home.join(&path_str[2..]))
            } else {
                Err(anyhow!("Could not determine home directory"))
            }
        } else if path_str == "~" {
            dirs::home_dir().ok_or_else(|| anyhow!("Could not determine home directory"))
        } else {
            Ok(path.to_path_buf())
        }
    }

    /// Check for path traversal attempts (../, symlinks to system dirs, etc.)
    fn check_path_traversal(&self, path: &Path) -> Result<()> {
        let path_str = path.to_str().ok_or_else(|| anyhow!("Invalid UTF-8 in path"))?;

        // Check for .. components in the canonicalized path (suspicious)
        if path_str.contains("/../") || path_str.ends_with("/..") {
            return Err(anyhow!(ValidationError::PathTraversal(
                path_str.to_string()
            )));
        }

        Ok(())
    }

    /// Check if path is in the blacklist
    fn check_blacklist(&self, path: &Path) -> Result<()> {
        let canonical_str = path.to_str().ok_or_else(|| anyhow!("Invalid UTF-8 in path"))?;

        for blacklisted in BLACKLISTED_PATHS.iter() {
            let blacklisted_expanded = self.expand_home(Path::new(blacklisted))?;
            let blacklisted_str = blacklisted_expanded
                .to_str()
                .ok_or_else(|| anyhow!("Invalid UTF-8 in blacklisted path"))?;

            // Check if path starts with blacklisted directory
            if canonical_str == blacklisted_str || canonical_str.starts_with(&format!("{}/", blacklisted_str)) {
                return Err(anyhow!(ValidationError::Blacklisted(
                    canonical_str.to_string()
                )));
            }
        }

        Ok(())
    }

    /// Check if file was modified recently (age protection)
    fn check_age_protection(&self, path: &Path) -> Result<()> {
        if !path.exists() {
            return Ok(()); // Don't check age for non-existent paths
        }

        let metadata = path.metadata()?;
        let modified = metadata.modified()?;
        let age = SystemTime::now()
            .duration_since(modified)
            .unwrap_or_default();

        let age_days = age.as_secs() / 86400;

        if age_days < self.min_age_days {
            return Err(anyhow!(ValidationError::TooRecent(
                path.display().to_string(),
                age_days
            )));
        }

        Ok(())
    }

    /// Check if a path is safe to delete (quick check without full sanitization)
    pub fn is_safe_to_delete(&self, path: &Path) -> bool {
        self.sanitize_path(path).is_ok()
    }

    /// Disable age protection (for testing or user override)
    pub fn without_age_protection(mut self) -> Self {
        self.enforce_age_protection = false;
        self
    }

    /// Set minimum age in days
    pub fn with_min_age(mut self, days: u64) -> Self {
        self.min_age_days = days;
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_blacklisted_paths() {
        let sanitizer = PathSanitizer::default();

        // System directories should be rejected
        assert!(sanitizer.sanitize_path(Path::new("/System")).is_err());
        assert!(sanitizer.sanitize_path(Path::new("/bin")).is_err());
        assert!(sanitizer.sanitize_path(Path::new("/usr/bin")).is_err());
    }

    #[test]
    fn test_age_protection() {
        let temp_dir = TempDir::new().unwrap();
        let temp_file = temp_dir.path().join("recent.txt");
        fs::write(&temp_file, "test").unwrap();

        let sanitizer = PathSanitizer::default();

        // Recently created file should be rejected
        assert!(sanitizer.sanitize_path(&temp_file).is_err());

        // Should pass without age protection
        let sanitizer_no_age = PathSanitizer::default().without_age_protection();
        assert!(sanitizer_no_age.sanitize_path(&temp_file).is_ok());
    }

    #[test]
    fn test_home_expansion() {
        let sanitizer = PathSanitizer::default().without_age_protection();
        let home_path = Path::new("~/test");

        if let Ok(expanded) = sanitizer.expand_home(home_path) {
            assert!(!expanded.to_str().unwrap().contains('~'));
        }
    }
}
