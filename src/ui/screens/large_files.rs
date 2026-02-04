use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use crate::app::App;
use crate::ui::common;

pub fn render(frame: &mut Frame, _app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner
            Constraint::Min(5),     // Content
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    // Content
    let widget = Paragraph::new("Large Files - Coming Soon\n\nPress Esc to go back")
        .style(Style::default().fg(Color::White).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL).title("Large Files"));
    frame.render_widget(widget, chunks[1]);
}
