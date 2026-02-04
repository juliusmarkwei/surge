use anyhow::Result;
use ratatui::Frame;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::thread;

use crate::models::{CleanableItem, SystemStats};
use crate::scanner::cleanup::CleanupScanner;
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

pub struct App {
    pub current_screen: Screen,
    pub previous_screen: Option<Screen>,
    pub preview_mode: bool,
    pub system_stats: SystemStats,

    // Home menu state
    pub menu_index: usize,

    // Storage cleanup state
    pub cleanable_items: Vec<CleanableItem>,
    pub selected_index: usize,
    pub scanning: bool,
    pub scan_progress: f64,
    pub spinner_state: usize,
    pub needs_scan: bool,
    scan_receiver: Option<Receiver<Vec<CleanableItem>>>,

    // UI state
    pub status_message: Option<String>,
    pub error_message: Option<String>,
}

impl App {
    pub fn new(preview_mode: bool) -> Self {
        Self {
            current_screen: Screen::Home,
            previous_screen: None,
            preview_mode,
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
            scan_progress: 0.0,
            spinner_state: 0,
            needs_scan: false,
            scan_receiver: None,
            status_message: None,
            error_message: None,
        }
    }

    pub fn update(&mut self) -> Result<()> {
        // Update system stats
        self.system_stats = get_system_stats()?;

        // Update spinner animation
        self.spinner_state = (self.spinner_state + 1) % 10;

        // Check for scan results
        if let Some(receiver) = &self.scan_receiver {
            if let Ok(items) = receiver.try_recv() {
                self.cleanable_items = items;
                self.selected_index = 0; // Reset selection to first item
                self.scanning = false;
                self.scan_receiver = None;
                self.status_message = Some(format!("Found {} items", self.cleanable_items.len()));
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
            3 => Screen::DuplicateFinder,
            4 => Screen::LargeFiles,
            5 => Screen::Performance,
            6 => Screen::SecurityScan,
            _ => return,
        };

        self.previous_screen = Some(self.current_screen);
        self.current_screen = new_screen;

        // Start async scanning for relevant screens
        match new_screen {
            Screen::StorageCleanup => {
                if self.cleanable_items.is_empty() && !self.scanning {
                    self.start_async_scan();
                }
            }
            _ => {}
        }
    }

    pub fn go_back(&mut self) {
        if let Some(prev) = self.previous_screen {
            self.current_screen = prev;
            self.previous_screen = None;
        } else {
            self.current_screen = Screen::Home;
        }
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
            _ => {}
        }
    }

    pub fn move_down(&mut self) {
        match self.current_screen {
            Screen::Home => {
                if self.menu_index < 5 {
                    // 6 menu items (0-5)
                    self.menu_index += 1;
                }
            }
            Screen::StorageCleanup => {
                if !self.cleanable_items.is_empty() && self.selected_index < self.cleanable_items.len() - 1 {
                    self.selected_index += 1;
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
        let selected_count = self.cleanable_items.iter().filter(|i| i.selected).count();

        if selected_count == 0 {
            self.error_message = Some("No items selected".to_string());
            return Ok(());
        }

        let total_size = self.get_selected_size();

        if self.preview_mode {
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
                    "Deleted {} items ({}) - {} failed",
                    deleted_count,
                    humansize::format_size(total_size, humansize::BINARY),
                    failed_count
                ));
            } else {
                self.status_message = Some(format!(
                    "Deleted {} items ({})",
                    deleted_count,
                    humansize::format_size(total_size, humansize::BINARY)
                ));
            }
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
}
