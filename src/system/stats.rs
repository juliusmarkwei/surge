use anyhow::Result;
use sysinfo::{Disks, System};

use crate::models::SystemStats;

pub fn get_system_stats() -> Result<SystemStats> {
    let mut sys = System::new_all();
    sys.refresh_all();

    let cpu_usage = sys.global_cpu_info().cpu_usage();

    let memory_used = sys.used_memory();
    let memory_total = sys.total_memory();

    let disks = Disks::new_with_refreshed_list();
    let (disk_used, disk_total) = get_root_disk_stats(&disks);

    Ok(SystemStats {
        cpu_usage,
        memory_used,
        memory_total,
        disk_used,
        disk_total,
    })
}

#[cfg(target_os = "macos")]
fn get_root_disk_stats(disks: &Disks) -> (u64, u64) {
    for disk in disks {
        if disk.mount_point().to_str() == Some("/") {
            let total = disk.total_space();
            let available = disk.available_space();
            let used = total.saturating_sub(available);
            return (used, total);
        }
    }
    (0, 0)
}

#[cfg(target_os = "linux")]
fn get_root_disk_stats(disks: &Disks) -> (u64, u64) {
    for disk in disks {
        if disk.mount_point().to_str() == Some("/") {
            let total = disk.total_space();
            let available = disk.available_space();
            let used = total.saturating_sub(available);
            return (used, total);
        }
    }
    (0, 0)
}
