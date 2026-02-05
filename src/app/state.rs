use anyhow::Result;
use ratatui::Frame;
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver};
use std::thread;

use crate::models::{CleanableItem, DuplicateGroup, LargeFileItem, SystemStats, TreeMapItem};
use crate::scanner::cleanup::CleanupScanner;
use crate::scanner::duplicates::DuplicateScanner;
use crate::scanner::large_files::LargeFileScanner;
use crate::scanner::treemap::TreeMapScanner;
use crate::system::stats::get_system_stats;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Home,
    StorageCleanup,
    DiskTreeMap,
    DuplicateFinder,
    LargeFiles,
    Performance,
    SecurityScan,
    Help,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortOrder {
    None,           // Original scan order
    SizeAsc,        // Smallest first
    SizeDesc,       // Largest first
}

pub struct App {
    pub current_screen: Screen,
    pub previous_screen: Option<Screen>,
    pub preview_mode: bool,
    pub custom_scan_path: Option<PathBuf>,
    pub system_stats: SystemStats,

    // Home menu state
    pub menu_index: usize,

    // Storage cleanup state
    pub cleanable_items: Vec<CleanableItem>,
    pub selected_index: usize,
    pub scanning: bool,
    pub deleting: bool,
    pub scan_progress: f64,
    pub spinner_state: usize,
    pub needs_scan: bool,
    pub sort_order: SortOrder,
    scan_receiver: Option<Receiver<Vec<CleanableItem>>>,

    // TreeMap state
    pub treemap_root: Option<TreeMapItem>,
    pub treemap_scanning: bool,
    pub treemap_selected_index: usize,
    pub treemap_path_stack: Vec<PathBuf>,
    pub treemap_show_preview: bool,
    treemap_receiver: Option<Receiver<TreeMapItem>>,

    // Duplicate Finder state
    pub duplicate_groups: Vec<DuplicateGroup>,
    pub duplicate_scanning: bool,
    pub duplicate_selected_group: usize,
    pub duplicate_selected_file: usize,
    duplicate_receiver: Option<Receiver<Vec<DuplicateGroup>>>,

    // Large Files state
    pub large_files: Vec<LargeFileItem>,
    pub large_files_scanning: bool,
    pub large_files_selected_index: usize,
    pub large_files_min_size: u64,    // Minimum size filter (bytes)
    pub large_files_min_age: u64,     // Minimum age filter (days)
    large_files_receiver: Option<Receiver<Vec<LargeFileItem>>>,

    // UI state
    pub status_message: Option<String>,
    pub error_message: Option<String>,
    pub number_buffer: String,
}

impl App {
    pub fn new(preview_mode: bool, custom_scan_path: Option<String>) -> Self {
        // Convert custom scan path to PathBuf if provided
        let scan_path = custom_scan_path.map(|p| PathBuf::from(p));

        Self {
            current_screen: Screen::Home,
            previous_screen: None,
            preview_mode,
            custom_scan_path: scan_path,
            system_stats: SystemStats {
                cpu_usage: 0.0,
                memory_used: 0,
                memory_total: 0,
                disk_used: 0,
                disk_total: 0,
            },
            menu_index: 0,
            cleanable_items: Vec::new(),
            selected_index: 0,
            scanning: false,
            deleting: false,
            scan_progress: 0.0,
            spinner_state: 0,
            needs_scan: false,
            sort_order: SortOrder::None,
            scan_receiver: None,
            treemap_root: None,
            treemap_scanning: false,
            treemap_selected_index: 0,
            treemap_path_stack: Vec::new(),
            treemap_show_preview: true,
            treemap_receiver: None,
            duplicate_groups: Vec::new(),
            duplicate_scanning: false,
            duplicate_selected_group: 0,
            duplicate_selected_file: 0,
            duplicate_receiver: None,
            large_files: Vec::new(),
            large_files_scanning: false,
            large_files_selected_index: 0,
            large_files_min_size: 1024 * 1024 * 100, // 100 MB default
            large_files_min_age: 0, // No age filter by default
            large_files_receiver: None,
            status_message: None,
            error_message: None,
            number_buffer: String::new(),
        }
    }

    pub fn update(&mut self) -> Result<()> {
        // Update system stats
        self.system_stats = get_system_stats()?;

        // Update spinner animation
        self.spinner_state = (self.spinner_state + 1) % 10;

        // Check for cleanup scan results
        if let Some(receiver) = &self.scan_receiver {
            if let Ok(items) = receiver.try_recv() {
                self.cleanable_items = items;
                self.selected_index = 0; // Reset selection to first item
                self.scanning = false;
                self.scan_receiver = None;
                self.status_message = Some(format!("Found {} items", self.cleanable_items.len()));
            }
        }

        // Check for treemap scan results
        if let Some(receiver) = &self.treemap_receiver {
            if let Ok(root) = receiver.try_recv() {
                self.treemap_root = Some(root);
                self.treemap_scanning = false;
                self.treemap_receiver = None;
                self.status_message = Some("Scan complete".to_string());
            }
        }

        // Check for duplicate scan results
        if let Some(receiver) = &self.duplicate_receiver {
            if let Ok(groups) = receiver.try_recv() {
                let total_duplicate = DuplicateScanner::calculate_total_duplicates(&groups);
                self.duplicate_groups = groups;
                self.duplicate_scanning = false;
                self.duplicate_receiver = None;
                self.duplicate_selected_group = 0;
                self.duplicate_selected_file = 0;
                self.status_message = Some(format!(
                    "Found {} duplicate groups - {} duplicate",
                    self.duplicate_groups.len(),
                    humansize::format_size(total_duplicate, humansize::BINARY)
                ));
            }
        }

        // Check for large files scan results
        if let Some(receiver) = &self.large_files_receiver {
            if let Ok(files) = receiver.try_recv() {
                let total_size = LargeFileScanner::calculate_total_size(&files);
                self.large_files = files;
                self.large_files_scanning = false;
                self.large_files_receiver = None;
                self.large_files_selected_index = 0;
                self.status_message = Some(format!(
                    "Found {} large files - {} total",
                    self.large_files.len(),
                    humansize::format_size(total_size, humansize::BINARY)
                ));
            }
        }

        Ok(())
    }

    fn start_async_scan(&mut self) {
        self.scanning = true;
        self.status_message = Some("Scanning...".to_string());

        let (tx, rx) = channel();
        self.scan_receiver = Some(rx);

        thread::spawn(move || {
            let scanner = CleanupScanner::new();
            if let Ok(items) = scanner.scan_all() {
                let _ = tx.send(items);
            }
        });
    }


    pub fn get_spinner(&self) -> &str {
        const SPINNER_FRAMES: &[&str] = &["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
        SPINNER_FRAMES[self.spinner_state % SPINNER_FRAMES.len()]
    }

    pub fn render(&mut self, frame: &mut Frame) {
        use crate::ui::screens;

        let area = frame.size();

        match self.current_screen {
            Screen::Home => screens::home::render(frame, self, area),
            Screen::StorageCleanup => screens::cleanup::render(frame, self, area),
            Screen::DiskTreeMap => screens::treemap::render(frame, self, area),
            Screen::DuplicateFinder => screens::duplicates::render(frame, self, area),
            Screen::LargeFiles => screens::large_files::render(frame, self, area),
            Screen::Performance => screens::performance::render(frame, self, area),
            Screen::SecurityScan => screens::security::render(frame, self, area),
            Screen::Help => screens::help::render(frame, self, area),
        }
    }

    // Navigation
    pub fn navigate_to_screen(&mut self, number: usize) {
        let new_screen = match number {
            1 => Screen::StorageCleanup,
            2 => Screen::DiskTreeMap,
            // Commented out - not yet available
            // 3 => Screen::DuplicateFinder,
            // 4 => Screen::LargeFiles,
            // 5 => Screen::Performance,
            // 6 => Screen::SecurityScan,
            _ => return,
        };

        self.previous_screen = Some(self.current_screen);
        self.current_screen = new_screen;
        self.number_buffer.clear();

        // Start async scanning for relevant screens
        match new_screen {
            Screen::StorageCleanup => {
                if self.cleanable_items.is_empty() && !self.scanning {
                    self.start_async_scan();
                }
            }
            Screen::DiskTreeMap => {
                if self.treemap_root.is_none() && !self.treemap_scanning {
                    self.start_treemap_scan();
                }
            }
            // Commented out - not yet available
            // Screen::DuplicateFinder => {
            //     if self.duplicate_groups.is_empty() && !self.duplicate_scanning {
            //         self.start_duplicate_scan();
            //     }
            // }
            // Screen::LargeFiles => {
            //     if self.large_files.is_empty() && !self.large_files_scanning {
            //         self.start_large_files_scan();
            //     }
            // }
            _ => {}
        }
    }

    pub fn go_back(&mut self) {
        self.number_buffer.clear();
        if let Some(prev) = self.previous_screen {
            self.current_screen = prev;
            self.previous_screen = None;
        } else {
            self.current_screen = Screen::Home;
        }
    }

    pub fn go_home(&mut self) {
        self.number_buffer.clear();
        self.current_screen = Screen::Home;
        self.previous_screen = None;
        // Clear treemap navigation stack when going home
        self.treemap_path_stack.clear();
    }

    pub fn show_help(&mut self) {
        self.previous_screen = Some(self.current_screen);
        self.current_screen = Screen::Help;
    }

    // List navigation
    pub fn move_up(&mut self) {
        match self.current_screen {
            Screen::Home => {
                if self.menu_index > 0 {
                    self.menu_index -= 1;
                }
            }
            Screen::StorageCleanup => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            Screen::LargeFiles => {
                if self.large_files_selected_index > 0 {
                    self.large_files_selected_index -= 1;
                }
            }
            _ => {}
        }
    }

    pub fn jump_to_item(&mut self, number: usize) {
        match self.current_screen {
            Screen::StorageCleanup => {
                if number > 0 && number <= self.cleanable_items.len() {
                    self.selected_index = number - 1; // Convert to 0-based index
                }
            }
            _ => {}
        }
    }

    pub fn add_digit_to_buffer(&mut self, digit: char) {
        if self.number_buffer.len() < 5 { // Limit to 5 digits (99999 items max)
            self.number_buffer.push(digit);
        }
    }

    pub fn execute_number_buffer(&mut self) {
        if !self.number_buffer.is_empty() {
            if let Ok(number) = self.number_buffer.parse::<usize>() {
                self.jump_to_item(number);
            }
            self.number_buffer.clear();
        }
    }

    pub fn clear_number_buffer(&mut self) {
        self.number_buffer.clear();
    }

    pub fn toggle_sort(&mut self) {
        match self.current_screen {
            Screen::StorageCleanup => {
                // Cycle through sort orders: None -> SizeDesc -> SizeAsc -> None
                self.sort_order = match self.sort_order {
                    SortOrder::None => SortOrder::SizeDesc,
                    SortOrder::SizeDesc => SortOrder::SizeAsc,
                    SortOrder::SizeAsc => SortOrder::None,
                };
                self.apply_sort();

                // Update status message
                let sort_msg = match self.sort_order {
                    SortOrder::None => "Sort: Default order",
                    SortOrder::SizeDesc => "Sort: Largest first",
                    SortOrder::SizeAsc => "Sort: Smallest first",
                };
                self.status_message = Some(sort_msg.to_string());
            }
            _ => {}
        }
    }

    fn apply_sort(&mut self) {
        match self.sort_order {
            SortOrder::None => {
                // Don't sort, keep original order
                // In practice, we'd need to keep the original order somewhere
                // For now, we'll just not sort
            }
            SortOrder::SizeDesc => {
                self.cleanable_items.sort_by(|a, b| b.size.cmp(&a.size));
            }
            SortOrder::SizeAsc => {
                self.cleanable_items.sort_by(|a, b| a.size.cmp(&b.size));
            }
        }

        // Reset selection to first item after sorting
        if !self.cleanable_items.is_empty() {
            self.selected_index = 0;
        }
    }

    pub fn move_down(&mut self) {
        match self.current_screen {
            Screen::Home => {
                if self.menu_index < 1 {
                    // 2 menu items (0-1)
                    self.menu_index += 1;
                }
            }
            Screen::StorageCleanup => {
                if !self.cleanable_items.is_empty() && self.selected_index < self.cleanable_items.len() - 1 {
                    self.selected_index += 1;
                }
            }
            Screen::LargeFiles => {
                if !self.large_files.is_empty() && self.large_files_selected_index < self.large_files.len() - 1 {
                    self.large_files_selected_index += 1;
                }
            }
            _ => {}
        }
    }

    // Fast navigation - jump by 10 items
    pub fn page_up(&mut self) {
        match self.current_screen {
            Screen::Home => {
                self.menu_index = 0;
            }
            Screen::StorageCleanup => {
                if self.selected_index >= 10 {
                    self.selected_index -= 10;
                } else {
                    self.selected_index = 0;
                }
            }
            Screen::DiskTreeMap => {
                if self.treemap_selected_index >= 10 {
                    self.treemap_selected_index -= 10;
                } else {
                    self.treemap_selected_index = 0;
                }
            }
            Screen::LargeFiles => {
                if self.large_files_selected_index >= 10 {
                    self.large_files_selected_index -= 10;
                } else {
                    self.large_files_selected_index = 0;
                }
            }
            _ => {}
        }
    }

    pub fn page_down(&mut self) {
        match self.current_screen {
            Screen::Home => {
                self.menu_index = 5;
            }
            Screen::StorageCleanup => {
                if !self.cleanable_items.is_empty() {
                    let new_index = self.selected_index + 10;
                    self.selected_index = new_index.min(self.cleanable_items.len() - 1);
                }
            }
            Screen::DiskTreeMap => {
                let items = self.get_current_treemap_items();
                if !items.is_empty() {
                    let new_index = self.treemap_selected_index + 10;
                    self.treemap_selected_index = new_index.min(items.len() - 1);
                }
            }
            Screen::LargeFiles => {
                if !self.large_files.is_empty() {
                    let new_index = self.large_files_selected_index + 10;
                    self.large_files_selected_index = new_index.min(self.large_files.len() - 1);
                }
            }
            _ => {}
        }
    }

    // Medium navigation - jump by 5 items (vim-style Ctrl+U/Ctrl+D)
    pub fn jump_up(&mut self) {
        match self.current_screen {
            Screen::Home => {
                self.menu_index = 0;
            }
            Screen::StorageCleanup => {
                if self.selected_index >= 5 {
                    self.selected_index -= 5;
                } else {
                    self.selected_index = 0;
                }
            }
            Screen::DiskTreeMap => {
                if self.treemap_selected_index >= 5 {
                    self.treemap_selected_index -= 5;
                } else {
                    self.treemap_selected_index = 0;
                }
            }
            Screen::LargeFiles => {
                if self.large_files_selected_index >= 5 {
                    self.large_files_selected_index -= 5;
                } else {
                    self.large_files_selected_index = 0;
                }
            }
            _ => {}
        }
    }

    pub fn jump_down(&mut self) {
        match self.current_screen {
            Screen::Home => {
                self.menu_index = 5;
            }
            Screen::StorageCleanup => {
                if !self.cleanable_items.is_empty() {
                    let new_index = self.selected_index + 5;
                    self.selected_index = new_index.min(self.cleanable_items.len() - 1);
                }
            }
            Screen::DiskTreeMap => {
                let items = self.get_current_treemap_items();
                if !items.is_empty() {
                    let new_index = self.treemap_selected_index + 5;
                    self.treemap_selected_index = new_index.min(items.len() - 1);
                }
            }
            Screen::LargeFiles => {
                if !self.large_files.is_empty() {
                    let new_index = self.large_files_selected_index + 5;
                    self.large_files_selected_index = new_index.min(self.large_files.len() - 1);
                }
            }
            _ => {}
        }
    }

    pub fn move_left(&mut self) {
        // Future use for tab navigation
    }

    pub fn move_right(&mut self) {
        // Future use for tab navigation
    }

    // Selection
    pub fn toggle_selection(&mut self) {
        match self.current_screen {
            Screen::StorageCleanup => {
                if let Some(item) = self.cleanable_items.get_mut(self.selected_index) {
                    item.selected = !item.selected;
                }
            }
            Screen::DuplicateFinder => {
                self.duplicate_toggle_selection();
            }
            Screen::LargeFiles => {
                if let Some(item) = self.large_files.get_mut(self.large_files_selected_index) {
                    item.selected = !item.selected;
                }
            }
            _ => {}
        }
    }

    pub fn select_all(&mut self) {
        match self.current_screen {
            Screen::StorageCleanup => {
                for item in &mut self.cleanable_items {
                    item.selected = true;
                }
            }
            Screen::DuplicateFinder => {
                self.duplicate_select_all_but_newest();
            }
            Screen::LargeFiles => {
                for item in &mut self.large_files {
                    item.selected = true;
                }
            }
            _ => {}
        }
    }

    pub fn select_none(&mut self) {
        match self.current_screen {
            Screen::StorageCleanup => {
                for item in &mut self.cleanable_items {
                    item.selected = false;
                }
            }
            Screen::DuplicateFinder => {
                self.duplicate_select_none();
            }
            Screen::LargeFiles => {
                for item in &mut self.large_files {
                    item.selected = false;
                }
            }
            _ => {}
        }
    }

    // Actions
    pub fn confirm_action(&mut self) -> Result<()> {
        match self.current_screen {
            Screen::Home => {
                // Navigate to selected menu item (menu_index is 0-5 for items 1-6)
                self.navigate_to_screen(self.menu_index + 1);
            }
            Screen::StorageCleanup => {
                if !self.cleanable_items.is_empty() {
                    // Clean selected items
                    self.delete_selected()?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    pub fn start_scan(&mut self) -> Result<()> {
        self.scanning = true;
        self.status_message = Some("Scanning...".to_string());

        // Add a small delay to test spinner animation
        std::thread::sleep(std::time::Duration::from_secs(3));

        let scanner = CleanupScanner::new();

        // Scan all categories
        match scanner.scan_all() {
            Ok(items) => {
                self.cleanable_items = items;
                self.scanning = false;
                self.status_message = Some(format!("Found {} items", self.cleanable_items.len()));
            }
            Err(e) => {
                self.scanning = false;
                self.error_message = Some(format!("Scan error: {}", e));
            }
        }

        Ok(())
    }

    pub fn delete_selected(&mut self) -> Result<()> {
        // Dispatch to appropriate delete handler based on current screen
        match self.current_screen {
            Screen::DuplicateFinder => {
                return self.duplicate_delete_selected();
            }
            Screen::LargeFiles => {
                return self.large_files_delete_selected();
            }
            Screen::StorageCleanup => {
                // Continue with cleanup deletion logic below
            }
            _ => return Ok(()),
        }

        let selected_count = self.cleanable_items.iter().filter(|i| i.selected).count();

        if selected_count == 0 {
            self.error_message = Some("No items selected".to_string());
            return Ok(());
        }

        let total_size = self.get_selected_size();

        // Set deleting flag to show loading UI
        self.deleting = true;
        self.status_message = Some(format!("Deleting {} items...", selected_count));
        self.error_message = None;

        if self.preview_mode {
            self.deleting = false;
            self.status_message = Some(format!(
                "Preview mode: Would delete {} items ({})",
                selected_count,
                humansize::format_size(total_size, humansize::BINARY)
            ));
        } else {
            // Actually delete files from disk
            let mut deleted_count = 0;
            let mut failed_count = 0;

            for item in self.cleanable_items.iter().filter(|i| i.selected) {
                let result = if item.path.is_dir() {
                    std::fs::remove_dir_all(&item.path)
                } else {
                    std::fs::remove_file(&item.path)
                };

                match result {
                    Ok(_) => deleted_count += 1,
                    Err(_) => failed_count += 1,
                }
            }

            // Remove deleted items from the list
            self.cleanable_items.retain(|item| !item.selected);

            // Reset selection index if needed
            if self.selected_index >= self.cleanable_items.len() && !self.cleanable_items.is_empty() {
                self.selected_index = self.cleanable_items.len() - 1;
            }

            if failed_count > 0 {
                self.status_message = Some(format!(
                    "✓ Deleted {} items ({}) - {} failed",
                    deleted_count,
                    humansize::format_size(total_size, humansize::BINARY),
                    failed_count
                ));
            } else {
                self.status_message = Some(format!(
                    "✓ Deleted {} items ({})",
                    deleted_count,
                    humansize::format_size(total_size, humansize::BINARY)
                ));
            }

            // Clear deleting flag
            self.deleting = false;
        }

        Ok(())
    }

    pub fn get_selected_size(&self) -> u64 {
        self.cleanable_items
            .iter()
            .filter(|i| i.selected)
            .map(|i| i.size)
            .sum()
    }

    // TreeMap methods
    pub fn start_treemap_scan(&mut self) {
        self.treemap_scanning = true;
        self.status_message = Some("Scanning directory tree...".to_string());

        // Use custom scan path if provided, otherwise use default
        let scan_path = self.custom_scan_path.clone()
            .unwrap_or_else(|| TreeMapScanner::get_default_scan_path());

        let (tx, rx) = channel();
        self.treemap_receiver = Some(rx);

        thread::spawn(move || {
            let scanner = TreeMapScanner::new();
            if let Ok(root) = scanner.scan(&scan_path) {
                let _ = tx.send(root);
            }
        });
    }

    pub fn get_current_treemap_items(&self) -> Vec<&TreeMapItem> {
        if let Some(root) = &self.treemap_root {
            // Navigate to current directory based on path stack
            let mut current = root;
            for path in &self.treemap_path_stack {
                if let Some(child) = current.children.iter().find(|c| &c.path == path) {
                    current = child;
                } else {
                    return Vec::new();
                }
            }
            current.children.iter().collect()
        } else {
            Vec::new()
        }
    }

    pub fn treemap_enter_directory(&mut self) {
        let items = self.get_current_treemap_items();
        if self.treemap_selected_index < items.len() {
            let selected = items[self.treemap_selected_index];
            if !selected.is_file {
                self.treemap_path_stack.push(selected.path.clone());
                self.treemap_selected_index = 0;
            }
        }
    }

    pub fn treemap_go_back(&mut self) {
        if !self.treemap_path_stack.is_empty() {
            self.treemap_path_stack.pop();
            self.treemap_selected_index = 0;
        }
    }

    pub fn treemap_move_up(&mut self) {
        if self.treemap_selected_index > 0 {
            self.treemap_selected_index -= 1;
        }
    }

    pub fn treemap_move_down(&mut self) {
        let items = self.get_current_treemap_items();
        if !items.is_empty() && self.treemap_selected_index < items.len() - 1 {
            self.treemap_selected_index += 1;
        }
    }

    pub fn treemap_toggle_preview(&mut self) {
        self.treemap_show_preview = !self.treemap_show_preview;
    }

    pub fn get_selected_treemap_item(&self) -> Option<&TreeMapItem> {
        let items = self.get_current_treemap_items();
        items.get(self.treemap_selected_index).copied()
    }

    pub fn treemap_open_file(&mut self) {
        if let Some(item) = self.get_selected_treemap_item() {
            if item.is_file {
                let path = &item.path;
                // Open file with system's default application
                #[cfg(target_os = "macos")]
                {
                    let _ = std::process::Command::new("open")
                        .arg(path)
                        .spawn();
                }
                #[cfg(target_os = "linux")]
                {
                    let _ = std::process::Command::new("xdg-open")
                        .arg(path)
                        .spawn();
                }
                self.status_message = Some(format!("Opening: {}", item.name));
            }
        }
    }

    // Duplicate Finder methods
    pub fn start_duplicate_scan(&mut self) {
        self.duplicate_scanning = true;
        self.status_message = Some("Scanning for duplicates...".to_string());

        // Use custom scan path if provided, otherwise use default
        let scan_path = self.custom_scan_path.clone()
            .unwrap_or_else(|| DuplicateScanner::get_default_scan_path());

        let (tx, rx) = channel();
        self.duplicate_receiver = Some(rx);

        thread::spawn(move || {
            let scanner = DuplicateScanner::new()
                .with_min_size(1024 * 100) // 100 KB minimum
                .with_max_depth(10); // Limit depth for performance

            if let Ok(groups) = scanner.scan(&scan_path) {
                let _ = tx.send(groups);
            }
        });
    }

    pub fn duplicate_move_up(&mut self) {
        if self.duplicate_selected_file > 0 {
            self.duplicate_selected_file -= 1;
        } else if self.duplicate_selected_group > 0 {
            // Move to previous group's last file
            self.duplicate_selected_group -= 1;
            if let Some(group) = self.duplicate_groups.get(self.duplicate_selected_group) {
                self.duplicate_selected_file = group.files.len().saturating_sub(1);
            }
        }
    }

    pub fn duplicate_move_down(&mut self) {
        if let Some(group) = self.duplicate_groups.get(self.duplicate_selected_group) {
            if self.duplicate_selected_file < group.files.len() - 1 {
                self.duplicate_selected_file += 1;
            } else if self.duplicate_selected_group < self.duplicate_groups.len() - 1 {
                // Move to next group's first file
                self.duplicate_selected_group += 1;
                self.duplicate_selected_file = 0;
            }
        }
    }

    pub fn duplicate_toggle_selection(&mut self) {
        if let Some(group) = self.duplicate_groups.get_mut(self.duplicate_selected_group) {
            if let Some(file) = group.files.get_mut(self.duplicate_selected_file) {
                file.selected = !file.selected;
            }
        }
    }

    pub fn duplicate_select_all_but_newest(&mut self) {
        for group in &mut self.duplicate_groups {
            if !group.files.is_empty() {
                // Keep the newest file (last in list after sorting by modified time)
                let newest_idx = group.files.len() - 1;
                for (idx, file) in group.files.iter_mut().enumerate() {
                    file.selected = idx != newest_idx;
                }
            }
        }
        self.status_message = Some("Selected all duplicates except newest".to_string());
    }

    pub fn duplicate_select_all_but_oldest(&mut self) {
        for group in &mut self.duplicate_groups {
            if !group.files.is_empty() {
                // Keep the oldest file (first in list after sorting by modified time)
                for (idx, file) in group.files.iter_mut().enumerate() {
                    file.selected = idx != 0;
                }
            }
        }
        self.status_message = Some("Selected all duplicates except oldest".to_string());
    }

    pub fn duplicate_select_none(&mut self) {
        for group in &mut self.duplicate_groups {
            for file in &mut group.files {
                file.selected = false;
            }
        }
    }

    pub fn duplicate_delete_selected(&mut self) -> Result<()> {
        let mut total_deleted = 0;
        let mut total_size = 0u64;
        let mut failed_count = 0;

        for group in &mut self.duplicate_groups {
            for file in &group.files {
                if file.selected {
                    total_size += file.size;
                    let result = if file.path.is_dir() {
                        std::fs::remove_dir_all(&file.path)
                    } else {
                        std::fs::remove_file(&file.path)
                    };

                    match result {
                        Ok(_) => total_deleted += 1,
                        Err(_) => failed_count += 1,
                    }
                }
            }
        }

        // Remove deleted files from groups
        for group in &mut self.duplicate_groups {
            group.files.retain(|f| !f.selected);
        }

        // Remove empty groups
        self.duplicate_groups.retain(|g| g.files.len() >= 2);

        // Reset selection if needed
        if self.duplicate_selected_group >= self.duplicate_groups.len() {
            self.duplicate_selected_group = self.duplicate_groups.len().saturating_sub(1);
        }
        if let Some(group) = self.duplicate_groups.get(self.duplicate_selected_group) {
            if self.duplicate_selected_file >= group.files.len() {
                self.duplicate_selected_file = group.files.len().saturating_sub(1);
            }
        }

        if failed_count > 0 {
            self.status_message = Some(format!(
                "Deleted {} files ({}) - {} failed",
                total_deleted,
                humansize::format_size(total_size, humansize::BINARY),
                failed_count
            ));
        } else {
            self.status_message = Some(format!(
                "Deleted {} duplicate files ({})",
                total_deleted,
                humansize::format_size(total_size, humansize::BINARY)
            ));
        }

        Ok(())
    }

    pub fn get_duplicate_selected_count(&self) -> usize {
        self.duplicate_groups
            .iter()
            .flat_map(|g| &g.files)
            .filter(|f| f.selected)
            .count()
    }

    pub fn get_duplicate_selected_size(&self) -> u64 {
        self.duplicate_groups
            .iter()
            .flat_map(|g| &g.files)
            .filter(|f| f.selected)
            .map(|f| f.size)
            .sum()
    }

    // Large Files methods
    pub fn start_large_files_scan(&mut self) {
        self.large_files_scanning = true;
        self.status_message = Some("Scanning for large files...".to_string());

        // Use custom scan path if provided, otherwise use default
        let scan_path = self.custom_scan_path.clone()
            .unwrap_or_else(|| LargeFileScanner::get_default_scan_path());

        let min_size = self.large_files_min_size;
        let min_age = self.large_files_min_age;

        let (tx, rx) = channel();
        self.large_files_receiver = Some(rx);

        thread::spawn(move || {
            let scanner = LargeFileScanner::new()
                .with_min_size(min_size)
                .with_min_age_days(min_age)
                .with_max_depth(10); // Limit depth for performance

            if let Ok(files) = scanner.scan(&scan_path) {
                let _ = tx.send(files);
            }
        });
    }

    pub fn large_files_delete_selected(&mut self) -> Result<()> {
        let mut total_deleted = 0;
        let mut total_size = 0u64;
        let mut failed_count = 0;

        for file in &self.large_files {
            if file.selected {
                total_size += file.size;
                let result = if file.path.is_dir() {
                    std::fs::remove_dir_all(&file.path)
                } else {
                    std::fs::remove_file(&file.path)
                };

                match result {
                    Ok(_) => total_deleted += 1,
                    Err(_) => failed_count += 1,
                }
            }
        }

        // Remove deleted files from list
        self.large_files.retain(|f| !f.selected);

        // Reset selection if needed
        if self.large_files_selected_index >= self.large_files.len() && !self.large_files.is_empty() {
            self.large_files_selected_index = self.large_files.len() - 1;
        }

        if failed_count > 0 {
            self.status_message = Some(format!(
                "Deleted {} files ({}) - {} failed",
                total_deleted,
                humansize::format_size(total_size, humansize::BINARY),
                failed_count
            ));
        } else {
            self.status_message = Some(format!(
                "Deleted {} large files ({})",
                total_deleted,
                humansize::format_size(total_size, humansize::BINARY)
            ));
        }

        Ok(())
    }

    pub fn large_files_set_min_size(&mut self, size_mb: u64) {
        self.large_files_min_size = size_mb * 1024 * 1024;
        // Trigger rescan
        self.large_files.clear();
        self.start_large_files_scan();
    }

    pub fn large_files_set_min_age(&mut self, days: u64) {
        self.large_files_min_age = days;
        // Trigger rescan
        self.large_files.clear();
        self.start_large_files_scan();
    }

    pub fn get_large_files_selected_count(&self) -> usize {
        self.large_files.iter().filter(|f| f.selected).count()
    }

    pub fn get_large_files_selected_size(&self) -> u64 {
        self.large_files
            .iter()
            .filter(|f| f.selected)
            .map(|f| f.size)
            .sum()
    }
}
