# Xray Codex Client

A complete Linux client toolkit that exposes a local HTTP proxy for Codex and routes traffic through an existing VLESS + TLS server. It supports RAW/TCP + TLS, WebSocket + TLS, and gRPC + TLS, with an independent systemd service and reversible shell proxy settings.

The default endpoint is `http://127.0.0.1:17890`. The default transport is ordinary RAW/TCP + TLS with an empty `flow`. Configure the client to match your server; REALITY is outside this toolkit's configuration.

## Included files

The original archive contains 21 files, including its checksum manifest:

| File | Purpose |
| --- | --- |
| `config.json` | Complete default RAW/TCP + TLS configuration with placeholders |
| `configs/config-tcp-tls.json` | Complete RAW/TCP + TLS template |
| `configs/config-ws-tls.json` | Complete WebSocket + TLS template |
| `configs/config-grpc-tls.json` | Complete gRPC + TLS template |
| `settings.example.json` | Example connection settings |
| `configure.sh` | Generate a complete configuration from connection settings |
| `xray-codex.service` | Independent systemd service running under a dedicated account |
| `install-xray.sh` | Download an official Xray release and verify its SHA256 |
| `install-service.sh` | Install the service, configuration, and session helpers |
| `apply-config.sh` | Validate and deploy configuration, with rollback on restart failure |
| `update-xray.sh` | Update the core, with rollback on restart failure |
| `proxy.sh` | Enable proxy variables in the current Bash shell |
| `unproxy.sh` | Restore the original variables and export attributes |
| `run-codex.sh` | Enable the proxy only for this Codex invocation |
| `check.sh` | Check the local listener and an HTTPS request through the proxy |
| `service.sh` | Manage service status, logs, and lifecycle |
| `uninstall-service.sh` | Remove the service unit while retaining configuration and files |
| `lib.sh` | Shared deployment functions |
| `README.md` | Deployment and usage instructions |
| `VERIFICATION.md` | Original verification record and testing scope |
| `SHA256SUMS` | Checksums for the extracted toolkit files |

## First deployment

Run these commands on the client server where Codex runs. Requirements: Linux with systemd, Bash 4.3 or newer, Python 3, curl, and CA certificates. Codex must already be installed and available on your user's `PATH`. Installation requires root privileges; session proxy commands run as your normal user.

On Debian or Ubuntu, install the dependencies if needed:

```bash
sudo apt-get update
sudo apt-get install -y bash python3 curl ca-certificates
```

This repository already contains the extracted files directly in its root. Run the following from that directory:

```bash
chmod +x ./*.sh
sudo ./install-xray.sh
cp settings.example.json settings.json
chmod 600 settings.json
nano settings.json
./configure.sh
sudo ./install-service.sh ./config.json
./check.sh
```

If deploying the original ZIP on another server, extract it and enter its enclosing directory first (requires `unzip`):

```bash
unzip xray-codex-client.zip
cd xray-codex-client
```

The installer resolves the latest stable release from the official GitHub API on each run, verifies its SHA256 using official release metadata or the digest asset, and installs a private binary at `/usr/local/lib/xray-codex/xray`. The client server needs access to the GitHub API and release downloads. Supported architectures are x86_64, aarch64, and armv7l.

## Connection settings

Edit `settings.json` with your actual server address, port, UUID, TLS SNI, and transport before running `configure.sh`. Example addresses and the all-zero UUID are rejected.

| Setting | Value to provide |
| --- | --- |
| `server_address` | Remote server IP address or hostname |
| `server_port` | Server's VLESS TLS port; default `443` |
| `uuid` | UUID authorized by the server |
| `tls_server_name` | Certificate hostname and TLS SNI; may differ from the connection IP |
| `transport` | `raw` or `tcp`, `ws`, or `grpc` |
| `flow` | Empty for ordinary TLS; match the server's Vision setting when used |
| `vless_encryption` | Usually `none`; use matching parameters if the server uses VLESS Encryption |
| `local_http_port` | Local loopback HTTP port; default `17890`, allowed range `1024..65535` |
| `ws_path` | Server's WebSocket path |
| `ws_host` | WebSocket Host; empty uses `tls_server_name` |
| `grpc_service_name` | Server's gRPC `serviceName` |

Vision is supported by this generator only with RAW/TCP + TLS. WebSocket uses ALPN `http/1.1`; gRPC uses `h2` and `multiMode=false`. Match any additional server requirements, such as a TLS fingerprint or custom ALPN, in the generated `config.json` and validate it with Xray.

TLS certificate verification remains enabled. VLESS `encryption: "none"` still uses the outer TLS connection. The generator writes `config.json` with mode `0600` and tests it with the installed Xray binary when available. Keep populated settings and configurations private.

## Resume Codex inside screen

Enter the appropriate screen window, then run:

```bash
./run-codex.sh resume
```

This is the recommended method: it sets the proxy in its own process and passes all arguments to Codex. Your parent shell's environment remains unchanged, and no cleanup command is required after Codex exits.

Start a new session with `./run-codex.sh`, or pass another Codex subcommand:

```bash
./run-codex.sh exec 'Review this repository'
```

After service installation, the helper is available from any directory:

```bash
/usr/local/share/xray-codex/run-codex.sh resume
```

### Control the current shell manually

```bash
source ./proxy.sh
codex resume
# Run this after Codex exits:
source ./unproxy.sh
```

The individual on/off commands are:

```bash
source ./proxy.sh
source ./unproxy.sh
```

Use `source` (or `.`), since executing a script cannot change its parent shell. These commands do not need sudo. The installed equivalents work from any directory:

```bash
source /usr/local/share/xray-codex/proxy.sh
codex resume
source /usr/local/share/xray-codex/unproxy.sh
```

Enabling sets uppercase and lowercase HTTP/HTTPS proxy variables and `NO_PROXY` for localhost, temporarily clears `ALL_PROXY`/`all_proxy`, and saves the original values, unset states, and export attributes. Disabling restores them. Repeated enabling preserves the first backup. Variables with special attributes such as readonly or arrays are rejected.

The change applies to the current shell and subsequently started child processes. Existing Codex processes retain their environment: exit and resume them to change their proxy settings. Detaching and reattaching screen does not restart Codex. The listener check during enabling only confirms a local TCP port; run `check.sh` to check the full proxy path.

### Add convenient proxy and unproxy commands

After installing the service and helpers, run this once as your normal user:

```bash
printf '\n%s\n' 'proxy() { source /usr/local/share/xray-codex/proxy.sh; }' 'unproxy() { source /usr/local/share/xray-codex/unproxy.sh; }' >> ~/.bashrc && source ~/.bashrc
```

This appends two Bash functions to `~/.bashrc` and loads them into the current shell. Then use:

```bash
proxy
codex resume
# After Codex exits:
unproxy
```

The functions source the installed scripts, so they modify the calling shell. New interactive Bash shells load them through `~/.bashrc`; in an existing screen shell, run `source ~/.bashrc` before using them. Running the setup command repeatedly appends duplicate definitions.

### Use a different local port

If you change `local_http_port`, also override the endpoint for session helpers and checks:

```bash
XRAY_CODEX_PROXY_URL=http://127.0.0.1:18080 /usr/local/share/xray-codex/run-codex.sh resume
XRAY_CODEX_PROXY_URL=http://127.0.0.1:18080 ./check.sh
```

For manual shell switching or the shortcut functions:

```bash
export XRAY_CODEX_PROXY_URL=http://127.0.0.1:18080
proxy
```

## Service management and updates

```bash
./service.sh status
./service.sh logs
sudo ./service.sh restart
sudo ./service.sh stop
sudo ./service.sh start
sudo ./service.sh enable
sudo ./service.sh disable
```

`logs` follows the latest journal entries; press Ctrl+C to stop following. `enable` and `disable` change boot startup only; use `start` and `stop` separately for the current service state.

After changing connection settings:

```bash
./configure.sh
sudo ./apply-config.sh ./config.json
./check.sh
```

Update to the latest stable Xray, or select a release:

```bash
sudo ./update-xray.sh
# Alternatively, pin the originally tested version:
sudo ./update-xray.sh v26.3.27
```

Configuration deployment validates the configuration before replacing it and saves one `.previous` copy. Core installation validates an existing deployed configuration against the new binary and saves the previous binary. If an active service fails to restart or become ready, the update scripts attempt to restore the previous file where available. Readiness checks wait up to 20 seconds for an active service and local listener. Remote reachability still requires `check.sh`.

Restarting or updating interrupts existing connections; Codex must reconnect. Use `update-xray.sh` for updates that should restart an active service.

| Installed resource | Location |
| --- | --- |
| Configuration | `/etc/xray-codex/config.json` (`root:xray-codex`, mode `0640`) |
| Configuration directory | `/etc/xray-codex/` (mode `0750`) |
| Xray binary | `/usr/local/lib/xray-codex/xray` |
| Service unit | `/etc/systemd/system/xray-codex.service` |
| Session and management helpers | `/usr/local/share/xray-codex/` |
| Logs | `journalctl -u xray-codex.service` |

To remove the systemd service:

```bash
sudo ./uninstall-service.sh
```

This retains the configuration, binary, helper scripts, and service account.

## Connectivity checks

```bash
./check.sh
./check.sh https://example.org/
```

The default request targets `https://api.openai.com/v1/models` without an API key. HTTP 401 is an expected authentication response and passes the transport check. HTTP 403 or 429 returns exit status 2 to indicate access restrictions or rate limiting. A transport check does not establish successful Codex login or inference.

The check verifies the target certificate and explicitly uses the proxy even if existing `NO_PROXY` settings would bypass it. If it fails, inspect `./service.sh status` and `./service.sh logs`, then confirm the UUID, SNI, certificate, and transport match the server.

Traffic entering the supplied HTTP inbound routes through VLESS, without a direct fallback when that outbound fails. Only applications using the proxy are affected. The helpers do not change routing or enable TUN/transparent proxying, and cannot override Codex sandbox network permissions. Some external tools do not honor proxy environment variables.

The listener binds to loopback; other users on the same host can also reach it. Target domains use `AsIs` routing through the VLESS outbound; resolving the remote server's own hostname still uses the client's normal DNS facilities. The configured `connIdle=1800` is an inactivity timeout, not a total connection duration limit.

## Verification scope

The archive's [verification record](VERIFICATION.md), dated October 13, 2026, reports validation with official Xray **26.3.27** (`v26.3.27`), recorded as the latest stable release at that time. This is a historical test baseline; the installer dynamically resolves the latest stable release when run.

The supplied record reports successful checks for:

- Default and RAW/TCP, WebSocket, and gRPC configuration parsing with the real Xray binary.
- A local VLESS + RAW/TCP + TLS connection with verified TLS certificates.
- Rejection of an incorrect UUID and failure without direct fallback when the outbound stops.
- Proxy environment restoration, including export attributes and repeated toggling.
- Official download SHA256 verification and rejection of a tampered archive.
- Static verification of the systemd unit.

WebSocket and gRPC were checked for configuration parsing, without end-to-end transport tests. The original test environment did not run systemd, so actual service registration and startup were not tested there. Real public-server connectivity, Codex login, long streaming sessions, and reconnect behavior require your real server parameters and acceptance testing. Future core compatibility is checked during configuration validation at installation or update time.

These results are the archive's supplied test record; rewriting this README does not rerun those network or systemd tests.

## Official references

- [Xray releases](https://github.com/XTLS/Xray-core/releases/latest)
- [VLESS outbound](https://xtls.github.io/en/config/outbounds/vless.html)
- [HTTP inbound](https://xtls.github.io/en/config/inbounds/http.html)
- [TLS](https://xtls.github.io/en/config/transports/tls.html)
- [RAW transport](https://xtls.github.io/en/config/transports/raw.html)
- [WebSocket transport](https://xtls.github.io/en/config/transports/websocket.html)
- [gRPC transport](https://xtls.github.io/en/config/transports/grpc.html)
- [Policy](https://xtls.github.io/en/config/policy.html)
