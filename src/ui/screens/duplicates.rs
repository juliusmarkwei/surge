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

    if app.duplicate_scanning {
        render_scanning(frame, app, chunks[1]);
    } else if app.duplicate_groups.is_empty() {
        render_empty(frame, chunks[1]);
    } else {
        render_duplicates(frame, app, chunks[1]);
    }

    // Render status bar
    render_status_bar(frame, app, chunks[2]);
}

fn render_scanning(frame: &mut Frame, app: &App, area: Rect) {
    let spinner = app.get_spinner();
    let text = format!(
        "{} Scanning for duplicate files...\n\n\
        This may take a few minutes.\n\n\
        Files are grouped by:\n\
        1. Size (fast pre-filter)\n\
        2. SHA-256 hash (accurate detection)",
        spinner
    );

    let widget = Paragraph::new(text)
        .style(Style::default().fg(Color::Cyan))
        .alignment(Alignment::Center)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Duplicate Finder - Scanning"),
        )
        .wrap(Wrap { trim: true });

    frame.render_widget(widget, area);
}

fn render_empty(frame: &mut Frame, area: Rect) {
    let text = "No duplicate files found!\n\n\
        All files in the scanned directory are unique.\n\n\
        Press Esc to go back";

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
                .title("Duplicate Finder - Results"),
        );

    frame.render_widget(widget, area);
}

fn render_duplicates(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(65), // File list
            Constraint::Percentage(35), // Details panel
        ])
        .split(area);

    render_file_list(frame, app, chunks[0]);
    render_details_panel(frame, app, chunks[1]);
}

fn render_file_list(frame: &mut Frame, app: &App, area: Rect) {
    let mut items = Vec::new();
    let mut flat_index = 0;
    let mut selected_flat_index = 0;

    // Build flat list of all files across all groups
    for (group_idx, group) in app.duplicate_groups.iter().enumerate() {
        // Group header - cleaner design
        let group_header = format!(
            "━━ {} copies • {} each • {} total ━━",
            group.files.len(),
            humansize::format_size(
                if !group.files.is_empty() {
                    group.files[0].size
                } else {
                    0
                },
                humansize::BINARY
            ),
            humansize::format_size(group.duplicate_size, humansize::BINARY)
        );

        items.push(ListItem::new(Line::from(Span::styled(
            group_header,
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ))));
        flat_index += 1;

        // Files in this group - one per line, cleaner
        for (file_idx, file) in group.files.iter().enumerate() {
            let is_current = group_idx == app.duplicate_selected_group
                && file_idx == app.duplicate_selected_file;

            if is_current {
                selected_flat_index = flat_index;
            }

            let checkbox = if file.selected { "[×]" } else { "[ ]" };

            // File name (bold)
            let file_name = file
                .path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown")
                .to_string();

            // Directory path (gray)
            let dir_path = file
                .path
                .parent()
                .and_then(|p| p.to_str())
                .unwrap_or("");

            let age = format_age(&file.modified);

            // Create two-line display for each file
            let line1 = format!("  {} {}", checkbox, file_name);
            let line2 = format!("     {} • {}", dir_path, age);

            let style1 = if is_current {
                Style::default()
                    .fg(Color::White)
                    .bg(Color::DarkGray)
                    .add_modifier(Modifier::BOLD)
            } else if file.selected {
                Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::White)
            };

            let style2 = if is_current {
                Style::default().fg(Color::Gray).bg(Color::DarkGray)
            } else {
                Style::default().fg(Color::DarkGray)
            };

            items.push(ListItem::new(Line::from(Span::styled(line1, style1))));
            flat_index += 1;
            items.push(ListItem::new(Line::from(Span::styled(line2, style2))));
            flat_index += 1;
        }

        // Add spacing between groups
        items.push(ListItem::new(Line::from(Span::raw(""))));
        flat_index += 1;
    }

    // Calculate scroll offset to keep selected item visible
    let visible_height = area.height.saturating_sub(2) as usize;
    let scroll_offset = if selected_flat_index >= visible_height / 2 {
        (selected_flat_index.saturating_sub(visible_height / 2)).min(items.len().saturating_sub(visible_height))
    } else {
        0
    };

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Duplicate Files"),
        )
        .style(Style::default());

    // Render with scroll offset
    let mut list_state = ratatui::widgets::ListState::default();
    list_state.select(Some(scroll_offset));

    frame.render_stateful_widget(list, area, &mut list_state);
}

fn render_details_panel(frame: &mut Frame, app: &App, area: Rect) {
    let mut text = String::new();

    // Overall stats
    let total_groups = app.duplicate_groups.len();
    let total_files: usize = app.duplicate_groups.iter().map(|g| g.files.len()).sum();
    let total_duplicate: u64 = app.duplicate_groups.iter().map(|g| g.duplicate_size).sum();
    let selected_count = app.get_duplicate_selected_count();
    let selected_size = app.get_duplicate_selected_size();

    text.push_str("┌─ SUMMARY ─────────┐\n\n");
    text.push_str(&format!(" {} groups\n", total_groups));
    text.push_str(&format!(" {} files\n", total_files));
    text.push_str(&format!(
        " {} duplicates\n\n",
        humansize::format_size(total_duplicate, humansize::BINARY)
    ));

    text.push_str("└───────────────────┘\n\n");

    if selected_count > 0 {
        text.push_str("┌─ SELECTED ────────┐\n\n");
        text.push_str(&format!(" {} files\n", selected_count));
        text.push_str(&format!(
            " {}\n\n",
            humansize::format_size(selected_size, humansize::BINARY)
        ));
        text.push_str("└───────────────────┘\n\n");
    }

    // Current file details
    if let Some(group) = app.duplicate_groups.get(app.duplicate_selected_group) {
        if let Some(file) = group.files.get(app.duplicate_selected_file) {
            text.push_str("┌─ CURRENT FILE ────┐\n\n");
            text.push_str(&format!(
                " {}\n\n",
                humansize::format_size(file.size, humansize::BINARY)
            ));
            text.push_str(&format!(" {}\n\n", format_age(&file.modified)));

            let file_name = file
                .path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("Unknown");
            text.push_str(&format!(" {}\n\n", file_name));

            let dir = file
                .path
                .parent()
                .and_then(|p| p.to_str())
                .unwrap_or("");
            text.push_str(&format!(" {}\n\n", dir));
            text.push_str("└───────────────────┘\n\n");
        }
    }

    // Help
    text.push_str("┌─ CONTROLS ────────┐\n\n");
    text.push_str(" Space   Toggle\n");
    text.push_str(" a       Select all\n");
    text.push_str(" n       Select none\n");
    text.push_str(" d       Delete\n");
    text.push_str(" Esc     Go back\n\n");
    text.push_str("└───────────────────┘");

    let widget = Paragraph::new(text)
        .style(Style::default().fg(Color::White))
        .block(Block::default().borders(Borders::ALL).title("Info"))
        .wrap(Wrap { trim: false });

    frame.render_widget(widget, area);
}

fn render_status_bar(frame: &mut Frame, app: &App, area: Rect) {
    let status_text = if let Some(msg) = &app.status_message {
        msg.clone()
    } else if let Some(err) = &app.error_message {
        format!("Error: {}", err)
    } else if app.preview_mode {
        "PREVIEW MODE - No files will be deleted".to_string()
    } else {
        "Select duplicates to delete • 'a' keeps newest • 'n' clears selection".to_string()
    };

    let widget = Paragraph::new(status_text)
        .style(Style::default().fg(Color::Cyan))
        .block(Block::default().borders(Borders::ALL));

    frame.render_widget(widget, area);
}

fn format_age(datetime: &chrono::DateTime<chrono::Local>) -> String {
    let now = chrono::Local::now();
    let duration = now.signed_duration_since(*datetime);

    if duration.num_days() > 365 {
        format!("{} years ago", duration.num_days() / 365)
    } else if duration.num_days() > 30 {
        format!("{} months ago", duration.num_days() / 30)
    } else if duration.num_days() > 0 {
        format!("{} days ago", duration.num_days())
    } else if duration.num_hours() > 0 {
        format!("{} hours ago", duration.num_hours())
    } else {
        format!("{} min ago", duration.num_minutes())
    }
}
