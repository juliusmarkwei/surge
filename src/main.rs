use anyhow::Result;
use clap::Parser;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    Terminal,
};
use std::io;

mod app;
mod models;
mod operations;
mod scanner;
mod security;
mod system;
mod ui;

use app::App;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,

    /// Scan a specific directory
    #[arg(short, long)]
    scan: Option<String>,

    /// Preview mode (dry-run, no deletion)
    #[arg(short, long)]
    preview: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app state
    let mut app = App::new(args.preview);

    // Run main event loop
    let res = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Error: {:?}", err);
    }

    Ok(())
}

fn run_app<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
) -> Result<()> {
    loop {
        terminal.draw(|f| app.render(f))?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    if handle_key(app, key)? {
                        return Ok(());
                    }
                }
            }
        }

        // Update app state (refresh system stats, etc.)
        app.update()?;
    }
}

fn handle_key(app: &mut App, key: KeyEvent) -> Result<bool> {
    match key.code {
        KeyCode::Char('q') | KeyCode::Char('Q') => return Ok(true),
        KeyCode::Esc => app.go_back(),
        KeyCode::Char('h') | KeyCode::Char('?') => app.show_help(),
        KeyCode::Char('1') => app.navigate_to_screen(1),
        KeyCode::Char('2') => app.navigate_to_screen(2),
        KeyCode::Char('3') => app.navigate_to_screen(3),
        KeyCode::Char('4') => app.navigate_to_screen(4),
        KeyCode::Char('5') => app.navigate_to_screen(5),
        KeyCode::Char('6') => app.navigate_to_screen(6),
        KeyCode::Char('7') => app.navigate_to_screen(7),
        KeyCode::Char('8') => app.navigate_to_screen(8),
        KeyCode::Up | KeyCode::Char('k') => app.move_up(),
        KeyCode::Down | KeyCode::Char('j') => app.move_down(),
        KeyCode::Left => app.move_left(),
        KeyCode::Right | KeyCode::Char('l') => app.move_right(),
        KeyCode::Char(' ') => app.toggle_selection(),
        KeyCode::Char('a') => app.select_all(),
        KeyCode::Char('n') => app.select_none(),
        KeyCode::Enter => app.confirm_action()?,
        KeyCode::Char('d') => app.delete_selected()?,
        _ => {}
    }
    Ok(false)
}
