use std::fs::File;
use std::io;
use std::path::PathBuf;

use fs2::FileExt;

pub struct InstanceGuard {
    _file: File,
}

pub fn acquire() -> io::Result<Option<InstanceGuard>> {
    let path: PathBuf = std::env::temp_dir().join("kisstty.lock");
    let file = File::create(&path)?;

    match file.try_lock_exclusive() {
        Ok(()) => Ok(Some(InstanceGuard { _file: file })),
        Err(e) if e.kind() == io::ErrorKind::WouldBlock => Ok(None),
        Err(e) => Err(e),
    }
}
