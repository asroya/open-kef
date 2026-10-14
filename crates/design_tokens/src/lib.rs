//! Typed loader for `design/tokens.json`. Every UI value must come from here.
use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Deserialize)]
pub struct Tokens {
    #[serde(rename = "$meta")]
    pub meta: Meta,
    pub color: Colors,
    pub font: Font,
    #[serde(rename = "type")]
    pub type_scale: TypeScale,
    pub space: BTreeMap<String, f32>,
    pub radius: Radius,
    pub size: Size,
    pub motion: Motion,
    #[serde(default)]
    pub rules: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct Meta { pub name: String, pub version: String, pub units: String }

#[derive(Debug, Deserialize)]
pub struct Colors { pub light: Palette, pub dark: Palette }

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Palette {
    pub bg: String, pub surface: String, pub text: String, pub text_muted: String,
    pub line: String, pub accent: String, pub danger: String,
}

#[derive(Debug, Deserialize)]
pub struct Font { pub family: String, pub mono: String }

#[derive(Debug, Deserialize)]
pub struct TypeScale { pub title: TypeStyle, pub body: TypeStyle, pub label: TypeStyle, pub numeric: TypeStyle }

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TypeStyle {
    pub size: f32, pub weight: u16, pub tracking: f32, pub line_height: f32,
    #[serde(default)] pub features: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct Radius { pub control: f32, pub panel: f32, pub art: f32 }

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Size { pub panel_width: f32, pub row_height: f32, pub art: f32, pub icon_hit: f32, pub slider: f32 }

#[derive(Debug, Deserialize)]
pub struct Motion { pub fast: u32, pub base: u32, pub easing: String }

#[derive(Debug)]
pub enum Error { Parse(serde_json::Error), Invalid(String) }

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self { Error::Parse(e) => write!(f, "tokens.json parse error: {e}"), Error::Invalid(m) => write!(f, "tokens.json invalid: {m}") }
    }
}
impl std::error::Error for Error {}

fn is_hex(c: &str) -> bool {
    c.len() == 7 && c.starts_with('#') && c[1..].chars().all(|ch| ch.is_ascii_hexdigit())
}

impl Tokens {
    pub fn from_json(s: &str) -> Result<Self, Error> {
        let t: Tokens = serde_json::from_str(s).map_err(Error::Parse)?;
        t.validate()?;
        Ok(t)
    }
    pub fn validate(&self) -> Result<(), Error> {
        for (name, p) in [("light", &self.color.light), ("dark", &self.color.dark)] {
            for (k, v) in [("bg",&p.bg),("surface",&p.surface),("text",&p.text),("textMuted",&p.text_muted),("line",&p.line),("accent",&p.accent),("danger",&p.danger)] {
                if !is_hex(v) { return Err(Error::Invalid(format!("color.{name}.{k} = {v:?} is not #RRGGBB"))); }
            }
        }
        if self.space.is_empty() { return Err(Error::Invalid("space is empty".into())); }
        if self.space.values().any(|v| *v <= 0.0) { return Err(Error::Invalid("space values must be > 0".into())); }
        Ok(())
    }
    /// Spacing step by key ("1".."6").
    pub fn space(&self, step: &str) -> Option<f32> { self.space.get(step).copied() }
}

/// The repo's tokens, embedded at compile time so builds can't drift from the file.
pub const EMBEDDED: &str = include_str!("../../../design/tokens.json");

pub fn embedded() -> Result<Tokens, Error> { Tokens::from_json(EMBEDDED) }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn repo_tokens_load_and_validate() {
        let t = embedded().expect("design/tokens.json must be valid");
        assert_eq!(t.size.panel_width, 320.0);
        assert_eq!(t.space("4"), Some(16.0));
        assert!(t.type_scale.numeric.features.iter().any(|f| f == "tnum"));
    }
    #[test]
    fn rejects_bad_colour() {
        let bad = EMBEDDED.replacen("#FFFFFF", "white", 1);
        assert!(matches!(Tokens::from_json(&bad), Err(Error::Invalid(_))));
    }
}
