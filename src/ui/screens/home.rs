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
    // Create main layout
    let main_block = Block::default();
    frame.render_widget(main_block, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner (increased for version info)
            Constraint::Min(10),    // Content area
            Constraint::Length(5),  // Status bar
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    // Split content area into two columns
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(70), // Left: Menu (70%)
            Constraint::Percentage(30), // Right: Info (30%)
        ])
        .split(chunks[1]);

    // Render menu
    render_menu(frame, app, content_chunks[0]);

    // Render info panel
    render_info(frame, content_chunks[1]);

    // Render status bar
    render_status_bar(frame, app, chunks[2]);
}

fn render_menu(frame: &mut Frame, app: &App, area: Rect) {
    let menu_items = vec![
        ("1", "Storage Cleanup", "Clean caches & junk files"),
        ("2", "Disk TreeMap", "Visual disk usage analyzer"),
        ("3", "Duplicate Finder", "Find duplicate files"),
        ("4", "Large Files", "Find large/old files"),
        ("5", "Performance", "RAM/CPU optimization"),
        ("6", "Security Scan", "Malware detection"),
    ];

    let max_width = area.width.saturating_sub(4); // Account for borders

    // Calculate vertical centering
    let available_height = area.height.saturating_sub(3); // Account for borders and title
    let num_items = menu_items.len();
    let spacing_per_item = 1; // Empty line between items
    let total_content_height = num_items + (num_items - 1) * spacing_per_item; // Items + spacing
    let top_padding = if available_height > total_content_height as u16 {
        (available_height - total_content_height as u16) / 2
    } else {
        0
    };

    let mut items: Vec<ListItem> = Vec::new();

    // Add top padding for vertical centering
    for _ in 0..top_padding {
        items.push(ListItem::new(Line::from("")));
    }

    // Add friendly header message
    let header_msg = "What would you like to do?";
    let header_len = header_msg.len() as u16;
    let header_padding = if max_width > header_len {
        (max_width - header_len) / 2
    } else {
        0
    };
    let header_pad = " ".repeat(header_padding as usize);

    items.push(ListItem::new(Line::from(vec![
        Span::raw(header_pad),
        Span::styled(
            header_msg,
            Style::default()
                .fg(Color::Gray)
                .add_modifier(Modifier::ITALIC),
        ),
    ])));

    // Add spacing after header
    items.push(ListItem::new(Line::from("")));
    items.push(ListItem::new(Line::from("")));

    // Add menu items with spacing
    for (idx, (_num, title, desc)) in menu_items.iter().enumerate() {
        let is_selected = idx == app.menu_index;

        let (prefix, title_style) = if is_selected {
            (
                "▶ ",
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            )
        } else {
            (
                "  ",
                Style::default()
                    .fg(Color::White),
            )
        };

        // Calculate the content length for this specific line (without numbers)
        let content = format!("{}{} - {}", prefix, title, desc);
        let content_len = content.len() as u16;

        // Calculate padding to center this line
        let left_padding = if max_width > content_len {
            (max_width - content_len) / 2
        } else {
            0
        };
        let padding = " ".repeat(left_padding as usize);

        let item = ListItem::new(Line::from(vec![
            Span::raw(padding),  // Center this line
            Span::raw(prefix),
            Span::styled(*title, title_style),
            Span::styled(" - ", Style::default().fg(Color::DarkGray)),
            Span::styled(*desc, Style::default().fg(Color::Gray)),
        ]));

        items.push(item);

        // Add spacing between items (except after the last item)
        if idx < menu_items.len() - 1 {
            items.push(ListItem::new(Line::from("")));
        }
    }

    // Create list state for highlighting
    let mut list_state = ListState::default();
    // Calculate the visual index including spacers and header
    // top_padding + header line + 2 blank lines after header + (menu_index * 2 for item + spacer)
    let visual_index = top_padding as usize + 3 + (app.menu_index * 2); // +3 for header and 2 blank lines
    list_state.select(Some(visual_index));

    let menu = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Color::Blue)),
        )
        .highlight_style(
            Style::default()
                .bg(Color::Rgb(30, 30, 30))
                .add_modifier(Modifier::BOLD),
        );

    frame.render_stateful_widget(menu, area, &mut list_state);
}

fn render_info(frame: &mut Frame, area: Rect) {
    let info_lines = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("  Navigation", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("↑↓", Style::default().fg(Color::Cyan)),
            Span::styled(" or ", Style::default().fg(Color::DarkGray)),
            Span::styled("j/k", Style::default().fg(Color::Cyan)),
            Span::raw("  Navigate menu"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("1-6", Style::default().fg(Color::Cyan)),
            Span::raw("       Jump to feature"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("Enter", Style::default().fg(Color::Green)),
            Span::raw("     Select feature"),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("  Actions", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("Space", Style::default().fg(Color::Green)),
            Span::raw("     Toggle selection"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("a", Style::default().fg(Color::Green)),
            Span::raw("         Select all"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("n", Style::default().fg(Color::Green)),
            Span::raw("         Select none"),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("  Global", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("h", Style::default().fg(Color::Cyan)),
            Span::styled(" or ", Style::default().fg(Color::DarkGray)),
            Span::styled("?", Style::default().fg(Color::Cyan)),
            Span::raw("    Show help"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("Esc", Style::default().fg(Color::Red)),
            Span::raw("       Go back"),
        ]),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("q", Style::default().fg(Color::Red)),
            Span::raw("         Quit app"),
        ]),
        Line::from(""),
        Line::from(vec![
            Span::styled("  About", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            Span::raw("  Cross-platform system cleaner"),
        ]),
        Line::from(vec![
            Span::raw("  Built with Rust + Ratatui"),
        ]),
        Line::from(vec![
            Span::styled("  MIT License", Style::default().fg(Color::Green)),
        ]),
    ];

    let info = Paragraph::new(info_lines).block(
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Color::Blue))
            .title(" Quick Guide ")
            .title_style(
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
    );

    frame.render_widget(info, area);
}

fn render_status_bar(frame: &mut Frame, app: &App, area: Rect) {
    let memory_pct = app.system_stats.memory_percentage();
    let disk_pct = app.system_stats.disk_percentage();

    // Determine colors based on usage
    let cpu_color = if app.system_stats.cpu_usage > 80.0 {
        Color::Red
    } else if app.system_stats.cpu_usage > 50.0 {
        Color::Yellow
    } else {
        Color::Green
    };

    let mem_color = if memory_pct > 80.0 {
        Color::Red
    } else if memory_pct > 50.0 {
        Color::Yellow
    } else {
        Color::Green
    };

    let disk_color = if disk_pct > 90.0 {
        Color::Red
    } else if disk_pct > 70.0 {
        Color::Yellow
    } else {
        Color::Green
    };

    let status_lines = vec![
        Line::from(""),
        Line::from(vec![
            Span::raw("  "),
            Span::styled("CPU: ", Style::default().fg(Color::White)),
            Span::styled(
                format!("{:.0}%", app.system_stats.cpu_usage),
                Style::default().fg(cpu_color).add_modifier(Modifier::BOLD),
            ),
            Span::raw("  │  "),
            Span::styled("RAM: ", Style::default().fg(Color::White)),
            Span::styled(
                format!(
                    "{:.1}% ({}/{}GB)",
                    memory_pct,
                    app.system_stats.memory_used / (1024 * 1024 * 1024),
                    app.system_stats.memory_total / (1024 * 1024 * 1024)
                ),
                Style::default().fg(mem_color).add_modifier(Modifier::BOLD),
            ),
            Span::raw("  │  "),
            Span::styled("Disk: ", Style::default().fg(Color::White)),
            Span::styled(
                format!(
                    "{:.1}% ({}/{}GB)",
                    disk_pct,
                    app.system_stats.disk_used / (1024 * 1024 * 1024),
                    app.system_stats.disk_total / (1024 * 1024 * 1024)
                ),
                Style::default().fg(disk_color).add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::from(""),
    ];

    let status = Paragraph::new(status_lines)
        .alignment(Alignment::Left)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Color::Green))
                .title(" System Status ")
                .title_style(
                    Style::default()
                        .fg(Color::Green)
                        .add_modifier(Modifier::BOLD),
                ),
        );

    frame.render_widget(status, area);
}
