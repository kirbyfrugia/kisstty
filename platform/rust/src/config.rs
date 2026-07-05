use std::net::IpAddr;
use std::path::PathBuf;
use dirs;

use serde::{Deserialize, Serialize};

use color_eyre::eyre::eyre;

// DNS limits from RFC 1035
pub const MAX_HOST_LEN: usize = 253;
const MAX_SEGMENT_LEN: usize = 63;

pub fn validate_host(host: &str) -> Result<(), String> {
    let host = host.trim();
    if host.is_empty() {
        return Err("host cannot be empty".into());
    }

    if host.parse::<IpAddr>().is_ok() {
        return Ok(());
    }

    if host.len() > MAX_HOST_LEN {
        return Err("host is too long".into());
    }

    for segment in host.split('.') {
        if segment.is_empty() {
            return Err("host cannot contain an empty segment".into());
        }
        if segment.len() > MAX_SEGMENT_LEN {
            return Err("host segment is too long".into());
        }
        if segment.starts_with('-') || segment.ends_with('-') {
            return Err("host segment cannot start or end with '-'".into());
        }
        if !segment.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
            return Err("host must be a valid hostname or IP address".into());
        }
    }

    Ok(())
}

fn default_kiss_host() -> String {
    "127.0.0.1".into()
}

fn default_kiss_port() -> u16 {
    8001
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Config {
    pub callsign: String,
    #[serde(default="default_kiss_host")]
    pub kiss_host: String,
    #[serde(default="default_kiss_port")]
    pub kiss_port: u16,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            callsign: String::new(),
            kiss_host: default_kiss_host(),
            kiss_port: default_kiss_port(),
        }
    }
}

impl Config {
    pub fn config_path() -> Option<PathBuf> {
        dirs::config_dir().map(|dir| dir.join("kisstty").join("config.toml"))
    }

    pub fn load() -> color_eyre::Result<Config> {
        let path = Self::config_path()
            .ok_or_else(|| eyre!("could not determine config path"))?;

        if !path.exists() {
            let default = Self::default();
            default.save()?;
            return Ok(default);
        }

        let contents = std::fs::read_to_string(&path)?;
        let config: Config = toml::from_str(&contents)?;
        Ok(config)
    }

    pub fn save(&self) -> color_eyre::Result<()> {
        let path = Self::config_path()
            .ok_or_else(|| eyre!("could not determine config path"))?;

        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let toml_str = toml::to_string_pretty(self)?;
        std::fs::write(path, toml_str)?;
        Ok(())
    }
}
