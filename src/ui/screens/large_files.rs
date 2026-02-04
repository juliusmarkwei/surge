use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(frame: &mut Frame, _app: &App, area: Rect) {
    let widget = Paragraph::new("Large Files - Coming Soon\n\nPress Esc to go back")
        .style(Style::default().fg(Color::White).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL).title("Large Files"));
    frame.render_widget(widget, area);
}
