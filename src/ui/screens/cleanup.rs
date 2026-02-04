use humansize::{format_size, BINARY};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::app::App;

pub fn render(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Title
            Constraint::Min(5),     // Items list
            Constraint::Length(4),  // Status/actions
        ])
        .split(area);

    // Title
    let title = if app.scanning {
        format!("Storage Cleanup - {} Scanning...", app.get_spinner())
    } else {
        "Storage Cleanup".to_string()
    };

    let title_widget = Paragraph::new(title)
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(title_widget, chunks[0]);

    // Items list
    if app.cleanable_items.is_empty() {
        let message = if app.scanning {
            format!("{} Scanning your system for cleanable items...", app.get_spinner())
        } else {
            "No items found.".to_string()
        };
        let empty = Paragraph::new(message)
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL).title("Items"));
        frame.render_widget(empty, chunks[1]);
    } else {
        let items: Vec<ListItem> = app
            .cleanable_items
            .iter()
            .enumerate()
            .map(|(i, item)| {
                let checkbox = if item.selected { "[✓]" } else { "[ ]" };
                let highlight = if i == app.selected_index {
                    Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                } else {
                    Style::default()
                };

                let line = Line::from(vec![
                    Span::styled(
                        format!("{} ", checkbox),
                        Style::default().fg(if item.selected { Color::Green } else { Color::Gray }),
                    ),
                    Span::styled(
                        item.category.name(),
                        Style::default().fg(Color::Cyan),
                    ),
                    Span::raw(" - "),
                    Span::styled(
                        item.path.display().to_string(),
                        highlight,
                    ),
                    Span::raw(" ("),
                    Span::styled(
                        format_size(item.size, BINARY),
                        Style::default().fg(Color::Yellow),
                    ),
                    Span::raw(")"),
                ]);

                ListItem::new(line)
            })
            .collect();

        let list = List::new(items)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title("Items (Space=Toggle, a=All, n=None, Enter=Confirm)"),
            )
            .highlight_style(
                Style::default()
                    .bg(Color::DarkGray)
                    .add_modifier(Modifier::BOLD),
            );

        // Create list state with current selection
        let mut list_state = ListState::default();
        list_state.select(Some(app.selected_index));

        frame.render_stateful_widget(list, chunks[1], &mut list_state);
    }

    // Status and actions
    let selected_size = format_size(app.get_selected_size(), BINARY);
    let selected_count = app.cleanable_items.iter().filter(|i| i.selected).count();

    let mut status_lines = vec![
        Line::from(vec![
            Span::styled("Selected: ", Style::default().fg(Color::White)),
            Span::styled(
                format!("{} items ({})", selected_count, selected_size),
                Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
            ),
        ]),
    ];

    // Show status or error messages
    if let Some(msg) = &app.status_message {
        status_lines.push(Line::from(Span::styled(
            msg,
            Style::default().fg(Color::Yellow),
        )));
    }
    if let Some(err) = &app.error_message {
        status_lines.push(Line::from(Span::styled(
            err,
            Style::default().fg(Color::Red),
        )));
    }

    status_lines.push(Line::from(vec![
        Span::styled("[Enter] ", Style::default().fg(Color::Green)),
        Span::raw("Clean  "),
        Span::styled("[Esc] ", Style::default().fg(Color::Red)),
        Span::raw("Back"),
    ]));

    let status = Paragraph::new(status_lines)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    frame.render_widget(status, chunks[2]);
}
