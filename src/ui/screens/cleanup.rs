use humansize::{format_size, BINARY};
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::app::App;
use crate::app::state::SortOrder;
use crate::ui::common;

pub fn render(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Banner
            Constraint::Length(3),  // Title
            Constraint::Min(5),     // Items list
            Constraint::Length(4),  // Status/actions
        ])
        .split(area);

    // Render banner
    common::render_banner(frame, chunks[0]);

    // Title (always "Storage Cleanup")
    let title_widget = Paragraph::new("Storage Cleanup")
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(title_widget, chunks[1]);

    // Items list
    if app.cleanable_items.is_empty() {
        let message = if app.deleting {
            format!("{} Deleting selected files...", app.get_spinner())
        } else if app.scanning {
            format!("{} Scanning your system for cleanable items...", app.get_spinner())
        } else {
            "No items found.".to_string()
        };

        let message_style = if app.deleting {
            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
        } else if app.scanning {
            Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
        } else {
            Style::default()
        };

        let empty = Paragraph::new(message)
            .style(message_style)
            .alignment(Alignment::Center)
            .block(Block::default().borders(Borders::ALL).title("Items"));
        frame.render_widget(empty, chunks[2]);
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

        // Create title with sort indicator
        let sort_indicator = match app.sort_order {
            SortOrder::None => "",
            SortOrder::SizeDesc => " [↓ Size]",
            SortOrder::SizeAsc => " [↑ Size]",
        };
        let list_title = format!("Items (Space=Toggle, a=All, n=None, s=Sort){}", sort_indicator);

        let list = List::new(items)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(list_title),
            )
            .highlight_style(
                Style::default()
                    .bg(Color::Rgb(30, 30, 30))  // Very subtle dark gray background
                    .add_modifier(Modifier::BOLD),
            );

        // Create list state with current selection
        let mut list_state = ListState::default();
        list_state.select(Some(app.selected_index));

        frame.render_stateful_widget(list, chunks[2], &mut list_state);
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

    // Show number buffer if user is typing
    if !app.number_buffer.is_empty() {
        status_lines.push(Line::from(vec![
            Span::styled("Jump to item: ", Style::default().fg(Color::Cyan)),
            Span::styled(
                &app.number_buffer,
                Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD),
            ),
            Span::styled(" (press Enter)", Style::default().fg(Color::Gray)),
        ]));
    }

    // Show status or error messages (but not during scanning/deleting, as that's shown in title)
    if let Some(msg) = &app.status_message {
        // Only show status message if we're not scanning or deleting
        // (those states are already shown in the title bar)
        if !app.scanning && !app.deleting {
            status_lines.push(Line::from(Span::styled(
                msg,
                Style::default().fg(Color::Yellow),
            )));
        }
    }
    if let Some(err) = &app.error_message {
        status_lines.push(Line::from(Span::styled(
            err,
            Style::default().fg(Color::Red),
        )));
    }

    // Show appropriate actions based on state
    if app.deleting {
        status_lines.push(Line::from(vec![
            Span::styled("⏳ ", Style::default().fg(Color::Red)),
            Span::styled("Deletion in progress... Please wait", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
        ]));
    } else {
        status_lines.push(Line::from(vec![
            Span::styled("[PgUp/PgDn] ", Style::default().fg(Color::Yellow)),
            Span::raw("Fast  "),
            Span::styled("[Ctrl+U/D] ", Style::default().fg(Color::Yellow)),
            Span::raw("Jump  "),
            Span::styled("[s] ", Style::default().fg(Color::Cyan)),
            Span::raw("Sort  "),
            Span::styled("[Enter] ", Style::default().fg(Color::Green)),
            Span::raw("Clean"),
        ]));
    }

    let status = Paragraph::new(status_lines)
        .alignment(Alignment::Center)
        .block(Block::default().borders(Borders::ALL));

    frame.render_widget(status, chunks[3]);
}
