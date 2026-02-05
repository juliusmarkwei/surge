use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
    Frame,
};

use crate::app::App;
use crate::ui::common;

pub fn render(frame: &mut Frame, _app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner
            Constraint::Length(3),  // Title
            Constraint::Min(10),    // Content
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    // Title
    let title = Paragraph::new("SURGE - Help")
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(title, chunks[1]);

    // Help content
    let help_items = vec![
        ListItem::new(Line::from(vec![
            Span::styled("Navigation Keys", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ])),
        ListItem::new("  ↑↓ or j/k     - Move up/down in lists"),
        ListItem::new("  ←→ or h/l     - Move left/right (tabs)"),
        ListItem::new("  1-2           - Jump to feature (Storage/TreeMap)"),
        ListItem::new("  g             - Go home"),
        ListItem::new("  PageUp/Down   - Fast scroll"),
        ListItem::new(""),
        ListItem::new(Line::from(vec![
            Span::styled("Selection Keys", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ])),
        ListItem::new("  Space         - Toggle selection"),
        ListItem::new("  a             - Select all"),
        ListItem::new("  n             - Select none"),
        ListItem::new(""),
        ListItem::new(Line::from(vec![
            Span::styled("Action Keys", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ])),
        ListItem::new("  Enter         - Confirm action / Open dir"),
        ListItem::new("  d             - Delete selected"),
        ListItem::new("  s             - Sort items"),
        ListItem::new("  p             - Toggle preview (TreeMap)"),
        ListItem::new("  o             - Open file (TreeMap)"),
        ListItem::new(""),
        ListItem::new(Line::from(vec![
            Span::styled("Global Keys", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
        ])),
        ListItem::new("  q             - Quit application"),
        ListItem::new("  Esc           - Go back / Cancel"),
        ListItem::new("  h or ?        - Show this help"),
        ListItem::new(""),
        ListItem::new(Line::from(vec![
            Span::styled("Press Esc to close", Style::default().fg(Color::Green)),
        ])),
    ];

    let help_list = List::new(help_items)
        .block(Block::default().borders(Borders::ALL).title("Keyboard Shortcuts"));

    frame.render_widget(help_list, chunks[2]);
}
