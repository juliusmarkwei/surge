/// System directories that must NEVER be deleted
/// This is a security-critical list - any modification must be carefully reviewed
#[cfg(target_os = "macos")]
pub static BLACKLISTED_PATHS: &[&str] = &[
    // Core system directories
    "/System",
    "/bin",
    "/sbin",
    "/usr/bin",
    "/usr/sbin",
    "/usr/lib",
    "/usr/libexec",
    "/usr/share",
    "/etc",
    "/dev",
    "/var",
    "/private/etc",
    "/private/var",

    // Apple frameworks and system apps
    "/Library/Apple",
    "/Library/Frameworks",
    "/Library/Extensions",
    "/System/Library",
    "/Applications/Utilities",

    // Critical user directories
    "/Users",
    "/Volumes",
    "/Network",
    "/cores",

    // Boot and recovery
    "/boot",
    "/.vol",
    "/Preboot",

    // Home directory critical paths
    "~/Library/Application Support",
    "~/Library/Preferences",
    "~/Library/Keychains",
    "~/Documents",
    "~/Desktop",
    "~/Pictures",
    "~/Music",
    "~/Movies",
];

#[cfg(target_os = "linux")]
pub static BLACKLISTED_PATHS: &[&str] = &[
    // Core system directories
    "/bin",
    "/sbin",
    "/usr/bin",
    "/usr/sbin",
    "/usr/lib",
    "/usr/lib64",
    "/usr/libexec",
    "/usr/share",
    "/lib",
    "/lib64",
    "/etc",
    "/dev",
    "/proc",
    "/sys",
    "/boot",
    "/root",

    // System administration
    "/var/lib",
    "/var/log/journal",

    // User directories
    "/home",
    "~/Documents",
    "~/Desktop",
    "~/Pictures",
    "~/Music",
    "~/Videos",
    "~/Downloads",
];

/// Whitelisted paths that are safe to clean (with additional validation)
#[cfg(target_os = "macos")]
pub static WHITELISTED_PATHS: &[&str] = &[
    "/Library/Caches",
    "/System/Library/Caches",
    "~/Library/Caches",
    "~/Library/Logs",
    "/Library/Logs",
    "~/Downloads",
    "~/.Trash",
    "/private/var/folders",
    "/private/var/log",
];

#[cfg(target_os = "linux")]
pub static WHITELISTED_PATHS: &[&str] = &[
    "/var/cache",
    "/var/tmp",
    "/tmp",
    "~/.cache",
    "~/.local/share/Trash",
    "~/Downloads",
    "/var/log",
];

/// Developer-specific cache directories (cross-platform)
pub static DEVELOPER_CACHE_PATHS: &[&str] = &[
    "~/.npm",
    "~/.yarn",
    "~/.cargo/registry",
    "~/.cargo/git",
    "~/.gradle/caches",
    "~/.m2/repository",
    "~/.pub-cache",
    "~/Library/Developer/Xcode/DerivedData",
    "~/Library/Developer/CoreSimulator/Caches",
    "~/.rustup/toolchains",
    "~/.cache/pip",
    "~/.cache/yarn",
    "~/.cache/go-build",
];
