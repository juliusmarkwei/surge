use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame,
};

use crate::app::App;
use crate::ui::common;

pub fn render(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner
            Constraint::Min(10),    // Content
            Constraint::Length(3),  // Status bar
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    if app.large_files_scanning {
        render_scanning(frame, app, chunks[1]);
    } else if app.large_files.is_empty() {
        render_empty(frame, app, chunks[1]);
    } else {
        render_large_files(frame, app, chunks[1]);
    }

    // Render status bar
    render_status_bar(frame, app, chunks[2]);
}

fn render_scanning(frame: &mut Frame, app: &App, area: Rect) {
    let spinner = app.get_spinner();
    let min_size_mb = app.large_files_min_size / (1024 * 1024);

    let text = format!(
        "{} Scanning for large files...\n\n\
        This may take a few minutes depending on the number of files.\n\n\
        Current filters:\n\
        • Minimum size: {} MB\n\
        • Minimum age: {} days",
        spinner, min_size_mb, app.large_files_min_age
    );

    let widget = Paragraph::new(text)
        .style(Style::default().fg(Color::Cyan))
        .alignment(Alignment::Center)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Large Files - Scanning"),
        )
        .wrap(Wrap { trim: true });

    frame.render_widget(widget, area);
}

fn render_empty(frame: &mut Frame, app: &App, area: Rect) {
    let min_size_mb = app.large_files_min_size / (1024 * 1024);
    let text = format!(
        "No large files found!\n\n\
        No files found matching the criteria:\n\
        • Size ≥ {} MB\n\
        • Age ≥ {} days\n\n\
        Press Esc to go back",
        min_size_mb, app.large_files_min_age
    );

    let widget = Paragraph::new(text)
        .style(
            Style::default()
                .fg(Color::Green)
                .add_modifier(Modifier::BOLD),
        )
        .alignment(Alignment::Center)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Large Files - Results"),
        );

    frame.render_widget(widget, area);
}

fn render_large_files(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(70), // File list
            Constraint::Percentage(30), // Details panel
        ])
        .split(area);

    render_file_list(frame, app, chunks[0]);
    render_details_panel(frame, app, chunks[1]);
}

fn render_file_list(frame: &mut Frame, app: &App, area: Rect) {
    let items: Vec<ListItem> = app
        .large_files
        .iter()
        .enumerate()
        .map(|(idx, file)| {
            let is_selected = idx == app.large_files_selected_index;
            let checkbox = if file.selected { "[×]" } else { "[ ]" };

            let size_str = humansize::format_size(file.size, humansize::BINARY);
            let age_str = format_age_days(file.age_days);
            let file_name = file
                .path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown");
            let path_str = file
                .path
                .parent()
                .and_then(|p| p.to_str())
                .unwrap_or("");

            let line_text = format!(
                "{} {:>8} │ {:>12} │ {} - {}",
                checkbox, size_str, age_str, file_name, path_str
            );

            let style = if is_selected {
                Style::default()
                    .fg(Color::White)
                    .bg(Color::DarkGray)
                    .add_modifier(Modifier::BOLD)
            } else if file.selected {
                Style::default().fg(Color::Red)
            } else {
                // Color code by age
                if file.age_days >= 365 {
                    Style::default().fg(Color::Magenta) // 1+ years old
                } else if file.age_days >= 180 {
                    Style::default().fg(Color::Yellow) // 6+ months old
                } else if file.age_days >= 90 {
                    Style::default().fg(Color::Cyan) // 3+ months old
                } else {
                    Style::default().fg(Color::Gray) // Recent
                }
            };

            ListItem::new(Line::from(Span::styled(line_text, style)))
        })
        .collect();

    // Calculate scroll offset to keep selected item visible
    let visible_height = area.height.saturating_sub(2) as usize; // Minus borders
    let scroll_offset = if app.large_files_selected_index >= visible_height {
        app.large_files_selected_index.saturating_sub(visible_height / 2)
    } else {
        0
    };

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Large Files (Space=Toggle, a=Select All, n=None, d=Delete)"),
        )
        .style(Style::default().fg(Color::White));

    // Render with scroll offset
    let mut list_state = ratatui::widgets::ListState::default();
    list_state.select(Some(scroll_offset));

    frame.render_stateful_widget(list, area, &mut list_state);
}

fn render_details_panel(frame: &mut Frame, app: &App, area: Rect) {
    let mut text = String::new();

    // Overall stats
    let total_count = app.large_files.len();
    let total_size = app.large_files.iter().map(|f| f.size).sum::<u64>();
    let selected_count = app.get_large_files_selected_count();
    let selected_size = app.get_large_files_selected_size();

    text.push_str("═══ SUMMARY ═══\n\n");
    text.push_str(&format!("Total files:   {}\n", total_count));
    text.push_str(&format!(
        "Total size:    {}\n\n",
        humansize::format_size(total_size, humansize::BINARY)
    ));

    text.push_str("═══ FILTERS ═══\n\n");
    let min_size_mb = app.large_files_min_size / (1024 * 1024);
    text.push_str(&format!("Min size:      {} MB\n", min_size_mb));
    text.push_str(&format!("Min age:       {} days\n\n", app.large_files_min_age));

    text.push_str("═══ SELECTED ═══\n\n");
    text.push_str(&format!("Files:         {}\n", selected_count));
    text.push_str(&format!(
        "Size:          {}\n\n",
        humansize::format_size(selected_size, humansize::BINARY)
    ));

    // Current file details
    if let Some(file) = app.large_files.get(app.large_files_selected_index) {
        text.push_str("═══ CURRENT FILE ═══\n\n");
        text.push_str(&format!(
            "Size:     {}\n",
            humansize::format_size(file.size, humansize::BINARY)
        ));
        text.push_str(&format!("Age:      {} days\n", file.age_days));
        text.push_str(&format!(
            "Modified: {}\n",
            file.modified.format("%Y-%m-%d %H:%M")
        ));
        text.push_str(&format!(
            "Accessed: {}\n\n",
            file.accessed.format("%Y-%m-%d %H:%M")
        ));
        text.push_str(&format!("Path:\n{}", file.path.to_string_lossy()));
    }

    // Age legend
    text.push_str("\n\n═══ AGE LEGEND ═══\n\n");
    text.push_str("Gray     < 3 months\n");
    text.push_str("Cyan     3-6 months\n");
    text.push_str("Yellow   6-12 months\n");
    text.push_str("Magenta  1+ years");

    let widget = Paragraph::new(text)
        .style(Style::default().fg(Color::White))
        .block(Block::default().borders(Borders::ALL).title("Details"))
        .wrap(Wrap { trim: true });

    frame.render_widget(widget, area);
}

fn render_status_bar(frame: &mut Frame, app: &App, area: Rect) {
    let help_text = if app.preview_mode {
        "PREVIEW MODE - No files will be deleted | ↑↓=Navigate | Space=Toggle | a=Select | d=Delete | Esc=Back"
    } else {
        "↑↓=Navigate | Space=Toggle | a=Select All | n=None | d=Delete | Esc=Back"
    };

    let status_text = if let Some(msg) = &app.status_message {
        msg.clone()
    } else if let Some(err) = &app.error_message {
        format!("Error: {}", err)
    } else {
        help_text.to_string()
    };

    let widget = Paragraph::new(status_text)
        .style(Style::default().fg(Color::Cyan))
        .block(Block::default().borders(Borders::ALL));

    frame.render_widget(widget, area);
}

fn format_age_days(days: u64) -> String {
    if days >= 365 {
        format!("{} years", days / 365)
    } else if days >= 30 {
        format!("{} months", days / 30)
    } else if days > 0 {
        format!("{} days", days)
    } else {
        "today".to_string()
    }
}
