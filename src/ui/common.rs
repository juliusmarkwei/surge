use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, BorderType, Paragraph},
    Frame,
};

// ASCII art banner using line characters (like npkill)
const SURGE_BANNER: &str = r#"
   -----       ____    _   _    ____     ____    ____
   -          / ___|  | | | |  |  _ \   / ___|  | ___|
   ------     \___ \  | | | |  | |_) | | |  _   |  _|
   ----        ___) | | |_| |  |  _ <  | |_| |  | |___
   --         |____/   \___/   |_| \_\  \____|  |_____|
   -------
"#;

pub fn render_banner(frame: &mut Frame, area: Rect) {
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
        Span::styled("1.0.0", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
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
