//! HTTP transport with a slot for the HTTPS:4430 + Basic auth path (MET-6, provisional).
use crate::{protocol, Error, Result};
use serde_json::Value;
use std::time::Duration;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scheme { Http, Https }

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Auth { pub user: String, pub password: String }

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Endpoint { pub host: String, pub scheme: Scheme, pub port: u16, pub auth: Option<Auth> }

impl Endpoint {
    pub fn http(host: &str) -> Self {
        Self { host: host.to_owned(), scheme: Scheme::Http, port: protocol::PORT, auth: None }
    }
    pub fn https(host: &str, auth: Option<Auth>) -> Self {
        Self { host: host.to_owned(), scheme: Scheme::Https, port: protocol::HTTPS_PORT, auth }
    }
    pub fn base_url(&self) -> String {
        let s = match self.scheme { Scheme::Http => "http", Scheme::Https => "https" };
        format!("{s}://{}:{}", self.host, self.port)
    }
}

pub(crate) struct Transport { pub endpoint: Endpoint, agent: ureq::Agent }

impl Transport {
    pub fn new(endpoint: Endpoint) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(2))
            .timeout(Duration::from_secs(5))
            .build();
        Self { endpoint, agent }
    }

    fn check(&self) -> Result<()> {
        // TLS with the speaker's pinned anchor + Basic auth slots in here once the handshake is known.
        if self.endpoint.scheme == Scheme::Https {
            return Err(Error::Unsupported("HTTPS:4430 transport pending MET-6 live test".into()));
        }
        Ok(())
    }

    fn auth(&self, r: ureq::Request) -> ureq::Request {
        match &self.endpoint.auth {
            Some(a) => r.set("Authorization", &format!("Basic {}", b64(&format!("{}:{}", a.user, a.password)))),
            None => r,
        }
    }

    pub fn get_json(&self, path: &str, q: &[(&str, &str)], timeout: Option<Duration>) -> Result<Value> {
        self.check()?;
        let mut r = self.auth(self.agent.get(&format!("{}{}", self.endpoint.base_url(), path)));
        for (k, v) in q { r = r.query(k, v); }
        if let Some(t) = timeout { r = r.timeout(t); }
        r.call().map_err(|e| Error::Http(e.to_string()))?
            .into_json().map_err(|e| Error::Decode(e.to_string()))
    }

    pub fn post_json(&self, path: &str, body: Value) -> Result<Value> {
        self.check()?;
        self.auth(self.agent.post(&format!("{}{}", self.endpoint.base_url(), path)))
            .send_json(body).map_err(|e| Error::Http(e.to_string()))?
            .into_json().map_err(|e| Error::Decode(e.to_string()))
    }
}

fn b64(s: &str) -> String {
    const A: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let b = s.as_bytes();
    let mut o = String::new();
    for c in b.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        for i in 0..4 {
            if i <= c.len() { o.push(A[(n >> (18 - 6 * i) & 63) as usize] as char) } else { o.push('=') }
        }
    }
    o
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn base64_matches_rfc4648() {
        assert_eq!(b64("user:pass"), "dXNlcjpwYXNz");
        assert_eq!(b64("a"), "YQ==");
        assert_eq!(b64("ab"), "YWI=");
    }
    #[test]
    fn default_is_http_80_and_https_is_gated() {
        assert_eq!(Endpoint::http("10.0.0.2").base_url(), "http://10.0.0.2:80");
        let t = Transport::new(Endpoint::https("10.0.0.2", None));
        assert!(matches!(t.get_json("/x", &[], None), Err(Error::Unsupported(_))));
    }
}
