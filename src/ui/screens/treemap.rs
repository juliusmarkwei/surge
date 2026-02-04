use humansize::{format_size, BINARY};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, BorderType, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::app::App;
use crate::ui::common;

pub fn render(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner
            Constraint::Length(3),  // Title
            Constraint::Min(5),     // Content area
            Constraint::Length(4),  // Status/actions
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    // Split content area into list and preview
    let content_chunks = if app.treemap_show_preview {
        Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(60), // File list
                Constraint::Percentage(40), // Preview
            ])
            .split(chunks[2])
    } else {
        Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(100)])
            .split(chunks[2])
    };

    // Get current path for title
    let current_path = if app.treemap_path_stack.is_empty() {
        "Home".to_string()
    } else {
        app.treemap_path_stack
            .last()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .unwrap_or("Unknown")
            .to_string()
    };

    // Title (simple, no loading indicator)
    let title = format!("Disk TreeMap - {}", current_path);

    let title_widget = Paragraph::new(title)
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(title_widget, chunks[1]);

    // Items list
    if app.treemap_scanning {
        let message = format!("{} Scanning directory tree...", app.get_spinner());
        let empty = Paragraph::new(message)
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL).title("Directories"));
        frame.render_widget(empty, content_chunks[0]);
    } else {
        let items_data = app.get_current_treemap_items();

        if items_data.is_empty() {
            let empty = Paragraph::new("No items found in this directory")
                .alignment(Alignment::Center)
                .block(Block::default().borders(Borders::ALL).title("Directories"));
            frame.render_widget(empty, content_chunks[0]);
        } else {
            // Calculate total size for percentages
            let total_size: u64 = items_data.iter().map(|i| i.size).sum();

            let items: Vec<ListItem> = items_data
                .iter()
                .enumerate()
                .map(|(i, item)| {
                    let is_selected = i == app.treemap_selected_index;
                    let highlight = if is_selected {
                        Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                    } else {
                        Style::default()
                    };

                    let icon = if item.is_file { "📄" } else { "📁" };
                    let percentage = item.percentage_of(total_size);

                    let line = Line::from(vec![
                        Span::styled(
                            format!("{} ", icon),
                            Style::default().fg(Color::Cyan),
                        ),
                        Span::styled(
                            format!("{:<40}", item.name),
                            highlight,
                        ),
                        Span::styled(
                            format!("{:>12}", format_size(item.size, BINARY)),
                            Style::default().fg(Color::Yellow),
                        ),
                        Span::raw("  "),
                        Span::styled(
                            format!("({:.1}%)", percentage),
                            Style::default().fg(Color::Gray),
                        ),
                    ]);

                    ListItem::new(line)
                })
                .collect();

            let list = List::new(items)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .title("Directories (Enter=Open, Esc=Back)"),
                )
                .highlight_style(
                    Style::default()
                        .bg(Color::Rgb(30, 30, 30))
                        .add_modifier(Modifier::BOLD),
                );

            let mut list_state = ListState::default();
            list_state.select(Some(app.treemap_selected_index));

            frame.render_stateful_widget(list, content_chunks[0], &mut list_state);

            // Render preview panel if enabled
            if app.treemap_show_preview && content_chunks.len() > 1 {
                render_preview(frame, app, content_chunks[1]);
            }
        }
    }

    // Status and actions
    let preview_status = if app.treemap_show_preview {
        "ON"
    } else {
        "OFF"
    };

    let status_lines = vec![
        Line::from(vec![
            Span::styled("Total items: ", Style::default().fg(Color::White)),
            Span::styled(
                format!("{}", app.get_current_treemap_items().len()),
                Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
            ),
            Span::raw("  │  "),
            Span::styled("Preview: ", Style::default().fg(Color::White)),
            Span::styled(
                preview_status,
                Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::from(vec![
            Span::styled("[PgUp/PgDn] ", Style::default().fg(Color::Yellow)),
            Span::raw("Fast  "),
            Span::styled("[Enter] ", Style::default().fg(Color::Green)),
            Span::raw("Open  "),
            Span::styled("[o] ", Style::default().fg(Color::Green)),
            Span::raw("File  "),
            Span::styled("[p] ", Style::default().fg(Color::Cyan)),
            Span::raw("Preview  "),
            Span::styled("[g] ", Style::default().fg(Color::Yellow)),
            Span::raw("Home"),
        ]),
    ];

    let status = Paragraph::new(status_lines)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    frame.render_widget(status, chunks[3]);
}

fn render_preview(frame: &mut Frame, app: &App, area: Rect) {
    let selected = app.get_selected_treemap_item();

    if let Some(item) = selected {
        if item.is_file {
            let path = &item.path;
            let extension = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();

            // Detect file type
            let preview_content = if is_text_file(&extension) {
                // Read text file (including .srt subtitle files)
                read_text_preview(path, 50)
            } else if is_image_file(&extension) {
                // Try to display image inline
                if let Some(img_preview) = render_image_preview(path, area) {
                    let preview = Paragraph::new(img_preview)
                        .block(
                            Block::default()
                                .borders(Borders::ALL)
                                .border_type(BorderType::Rounded)
                                .title(" Image Preview ")
                                .title_style(
                                    Style::default()
                                        .fg(Color::Cyan)
                                        .add_modifier(Modifier::BOLD),
                                ),
                        );
                    frame.render_widget(preview, area);
                    return;
                } else {
                    format!(
                        "Image File\n\nName: {}\nSize: {}\nType: {}\n\nPress 'o' to open with system viewer",
                        item.name,
                        format_size(item.size, BINARY),
                        extension.to_uppercase()
                    )
                }
            } else if is_video_file(&extension) {
                format!(
                    "Video File\n\nName: {}\nSize: {}\nType: {}\n\nPress 'o' to play with system player",
                    item.name,
                    format_size(item.size, BINARY),
                    extension.to_uppercase()
                )
            } else if is_audio_file(&extension) {
                format!(
                    "Audio File\n\nName: {}\nSize: {}\nType: {}\n\nPress 'o' to play with system player",
                    item.name,
                    format_size(item.size, BINARY),
                    extension.to_uppercase()
                )
            } else {
                format!(
                    "File Information\n\nName: {}\nSize: {}\nType: {}",
                    item.name,
                    format_size(item.size, BINARY),
                    extension.to_uppercase()
                )
            };

            let preview = Paragraph::new(preview_content)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .title(" Preview ")
                        .title_style(
                            Style::default()
                                .fg(Color::Cyan)
                                .add_modifier(Modifier::BOLD),
                        ),
                )
                .wrap(ratatui::widgets::Wrap { trim: true });

            frame.render_widget(preview, area);
        } else {
            // Directory info
            let dir_info = format!(
                "Directory\n\nName: {}\nTotal Size: {}\nItems: {}",
                item.name,
                format_size(item.size, BINARY),
                item.children.len()
            );

            let preview = Paragraph::new(dir_info)
                .block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_type(BorderType::Rounded)
                        .title(" Info ")
                        .title_style(
                            Style::default()
                                .fg(Color::Cyan)
                                .add_modifier(Modifier::BOLD),
                        ),
                );

            frame.render_widget(preview, area);
        }
    } else {
        let empty = Paragraph::new("No file selected")
            .alignment(Alignment::Center)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .title(" Preview "),
            );

        frame.render_widget(empty, area);
    }
}

fn is_text_file(ext: &str) -> bool {
    matches!(
        ext,
        "txt" | "md" | "rs" | "toml" | "json" | "xml" | "yaml" | "yml" | "sh" | "py" | "js" | "ts"
            | "html" | "css" | "c" | "cpp" | "h" | "hpp" | "java" | "go" | "rb" | "php" | "swift"
            | "kt" | "log" | "csv" | "ini" | "conf" | "cfg" | "srt" | "vtt" | "ass" | "sub"
    )
}

fn is_image_file(ext: &str) -> bool {
    matches!(
        ext,
        "jpg" | "jpeg" | "png" | "gif" | "bmp" | "svg" | "webp" | "ico" | "tiff" | "tif"
    )
}

fn is_video_file(ext: &str) -> bool {
    matches!(
        ext,
        "mp4" | "avi" | "mkv" | "mov" | "wmv" | "flv" | "webm" | "m4v" | "mpg" | "mpeg"
    )
}

fn is_audio_file(ext: &str) -> bool {
    matches!(
        ext,
        "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" | "wma" | "opus" | "alac" | "ape"
    )
}

fn read_text_preview(path: &std::path::Path, max_lines: usize) -> String {
    use std::fs::File;
    use std::io::{BufRead, BufReader};

    match File::open(path) {
        Ok(file) => {
            let reader = BufReader::new(file);
            let lines: Vec<String> = reader
                .lines()
                .take(max_lines)
                .filter_map(|l| l.ok())
                .collect();

            if lines.is_empty() {
                "(Empty file)".to_string()
            } else {
                lines.join("\n")
            }
        }
        Err(_) => "(Unable to read file)".to_string(),
    }
}

fn render_image_preview(path: &std::path::Path, _area: Rect) -> Option<String> {
    use image::io::Reader;

    // Try to load the image to get its dimensions
    let img = Reader::open(path).ok()?.decode().ok()?;

    // Return image information
    Some(format!(
        "{}x{} {} image\n\nPress 'o' to open in system viewer",
        img.width(),
        img.height(),
        path.extension()
            .and_then(|e| e.to_str())
            .unwrap_or("unknown")
            .to_uppercase()
    ))
}

