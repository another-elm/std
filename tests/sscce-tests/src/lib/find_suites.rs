use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;

#[derive(Debug)]
pub enum Error {
    ProvidedPathIsNotDir,
    ReadingDir(io::Error),
}

pub fn find_suites(suites_dir: &Path) -> Result<Box<[PathBuf]>, Error> {
    if suites_dir.is_dir() {
        if suites_dir.join("elm.json").exists() {
            Ok(Box::new([suites_dir.to_path_buf()]))
        } else {
            let mut suites = vec![];
            add_suites(suites_dir, &mut suites)?;
            suites.sort_unstable();
            Ok(suites.into_boxed_slice())
        }
    } else {
        Err(Error::ProvidedPathIsNotDir)
    }
}

fn add_suites(suites_dir: &Path, suites_list: &mut Vec<PathBuf>) -> Result<(), Error> {
    let entries = fs::read_dir(suites_dir).map_err(Error::ReadingDir)?;
    for entry in entries {
        let entry = entry.map_err(Error::ReadingDir)?;
        let suite_path = entry.path();
        if suite_path.join("elm.json").exists() {
            suites_list.push(suite_path);
        } else if suite_path.is_dir() {
            add_suites(&suite_path, suites_list)?;
        }
    }
    Ok(())
}
