use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, BorderType, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::app::App;

// ASCII art banner using line characters (like npkill)
const SURGE_BANNER: &str = r#"
   -----       ____    _   _    ____     ____    ____
   -          / ___|  | | | |  |  _ \   / ___|  | ___|
   ------     \___ \  | | | |  | |_) | | |  _   |  _|
   ----        ___) | | |_| |  |  _ <  | |_| |  | |___
   --         |____/   \___/   |_| \_\  \____|  |_____|
   -------
"#;

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
    render_banner(frame, chunks[0]);

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

fn render_banner(frame: &mut Frame, area: Rect) {
    // Split the banner into multiple lines and style each one
    let mut banner_lines: Vec<Line> = SURGE_BANNER
        .lines()
        .map(|line| {
            Line::from(Span::styled(
                line.to_string(),
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ))
        })
        .collect();

    // Add blank line for spacing
    banner_lines.push(Line::from(""));

    // Add the info line
    banner_lines.push(Line::from(vec![
        Span::styled("  Version: ", Style::default().fg(Color::Gray)),
        Span::styled("2.0.0", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
        Span::styled("  │  ", Style::default().fg(Color::DarkGray)),
        Span::styled("Released: ", Style::default().fg(Color::Gray)),
        Span::styled("2026-02-04", Style::default().fg(Color::Yellow)),
        Span::styled("  │  ", Style::default().fg(Color::DarkGray)),
        Span::styled("Created by: ", Style::default().fg(Color::Gray)),
        Span::styled("SURGE Contributors", Style::default().fg(Color::Magenta).add_modifier(Modifier::ITALIC)),
    ]));

    let banner = Paragraph::new(banner_lines)
        .alignment(Alignment::Left)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Color::Cyan)),
        );

    frame.render_widget(banner, area);
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

    let items: Vec<ListItem> = menu_items
        .iter()
        .enumerate()
        .map(|(idx, (num, title, desc))| {
            let is_selected = idx == app.menu_index;

            let (prefix, num_style, title_style) = if is_selected {
                (
                    "▶ ",
                    Style::default()
                        .fg(Color::Black)
                        .bg(Color::Cyan)
                        .add_modifier(Modifier::BOLD),
                    Style::default()
                        .fg(Color::Cyan)
                        .add_modifier(Modifier::BOLD),
                )
            } else {
                (
                    "  ",
                    Style::default()
                        .fg(Color::Cyan),
                    Style::default()
                        .fg(Color::White),
                )
            };

            ListItem::new(Line::from(vec![
                Span::raw(prefix),
                Span::styled(format!("[{}] ", num), num_style),
                Span::styled(*title, title_style),
                Span::styled(" - ", Style::default().fg(Color::DarkGray)),
                Span::styled(*desc, Style::default().fg(Color::Gray)),
            ]))
        })
        .collect();

    let menu = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Color::Blue))
            .title(" Features ")
            .title_style(
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
    );

    frame.render_widget(menu, area);
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
