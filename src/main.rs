use anyhow::Result;
use clap::Parser;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers},
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

    // Debug mode - print startup info before TUI takes over
    if args.debug {
        eprintln!("SURGE v{} - Debug Mode Enabled", env!("CARGO_PKG_VERSION"));
        eprintln!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        eprintln!("Preview mode: {}", args.preview);
        if let Some(ref scan_path) = args.scan {
            eprintln!("Custom scan path: {}", scan_path);
        } else {
            eprintln!("Scan path: Default (Home directory)");
        }
        eprintln!("Platform: {}", std::env::consts::OS);
        eprintln!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
        std::thread::sleep(std::time::Duration::from_secs(2));
    }

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app state with optional custom scan path
    let mut app = App::new(args.preview, args.scan.clone());

    // If scan path was provided, auto-navigate to TreeMap and start scanning
    if args.scan.is_some() {
        app.navigate_to_screen(2); // 2 = Disk TreeMap
    }

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
    use crate::app::state::Screen;

    match key.code {
        KeyCode::Char('q') | KeyCode::Char('Q') => return Ok(true),
        KeyCode::Esc => {
            app.clear_number_buffer();
            match app.current_screen {
                Screen::DiskTreeMap => {
                    // If we're in a subdirectory, go back one level
                    if !app.treemap_path_stack.is_empty() {
                        app.treemap_go_back();
                    } else {
                        // Otherwise, go back to home screen
                        app.go_back();
                    }
                }
                _ => app.go_back(),
            }
        }
        KeyCode::Char('h') | KeyCode::Char('?') => app.show_help(),
        KeyCode::Char('g') | KeyCode::Char('G') | KeyCode::Home => {
            app.clear_number_buffer();
            app.go_home();
        }

        // Number keys: context-aware navigation
        KeyCode::Char(c) if c.is_ascii_digit() => {
            match app.current_screen {
                Screen::Home => {
                    // On home screen: navigate to feature (only 1-2 available)
                    if let Some(digit) = c.to_digit(10) {
                        if digit >= 1 && digit <= 2 {
                            app.navigate_to_screen(digit as usize);
                        }
                    }
                }
                Screen::StorageCleanup => {
                    // On cleanup screen: accumulate digits in buffer
                    app.add_digit_to_buffer(c);
                }
                _ => {}
            }
        }

        KeyCode::Up | KeyCode::Char('k') => {
            app.clear_number_buffer();
            match app.current_screen {
                Screen::DiskTreeMap => app.treemap_move_up(),
                Screen::DuplicateFinder => app.duplicate_move_up(),
                Screen::LargeFiles => app.move_up(),
                _ => app.move_up(),
            }
        }
        KeyCode::Down | KeyCode::Char('j') => {
            app.clear_number_buffer();
            match app.current_screen {
                Screen::DiskTreeMap => app.treemap_move_down(),
                Screen::DuplicateFinder => app.duplicate_move_down(),
                Screen::LargeFiles => app.move_down(),
                _ => app.move_down(),
            }
        }
        KeyCode::PageUp => {
            app.clear_number_buffer();
            app.page_up();
        }
        KeyCode::PageDown => {
            app.clear_number_buffer();
            app.page_down();
        }
        KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.clear_number_buffer();
            app.jump_up();
        }
        KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            app.clear_number_buffer();
            app.jump_down();
        }
        KeyCode::Left => app.move_left(),
        KeyCode::Right | KeyCode::Char('l') => app.move_right(),
        KeyCode::Char(' ') => {
            app.clear_number_buffer();
            app.toggle_selection();
        }
        KeyCode::Char('a') => {
            app.clear_number_buffer();
            app.select_all();
        }
        KeyCode::Char('n') => {
            app.clear_number_buffer();
            app.select_none();
        }
        KeyCode::Enter => {
            // Execute number buffer jump if there's a number typed
            if !app.number_buffer.is_empty() {
                app.execute_number_buffer();
            } else {
                match app.current_screen {
                    Screen::DiskTreeMap => app.treemap_enter_directory(),
                    _ => app.confirm_action()?,
                }
            }
        }
        KeyCode::Char('d') => {
            app.clear_number_buffer();
            app.delete_selected()?;
        }
        KeyCode::Char('s') | KeyCode::Char('S') => {
            app.clear_number_buffer();
            app.toggle_sort();
        }
        KeyCode::Char('p') | KeyCode::Char('P') => {
            match app.current_screen {
                Screen::DiskTreeMap => app.treemap_toggle_preview(),
                _ => {}
            }
        }
        KeyCode::Char('o') | KeyCode::Char('O') => {
            match app.current_screen {
                Screen::DiskTreeMap => app.treemap_open_file(),
                _ => {}
            }
        }
        _ => {}
    }
    Ok(false)
}
