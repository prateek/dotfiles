---
status: draft
doc_type: research
owner: Prateek
created: 2026-09-06
updated: 2026-09-06
related:
  - ../research/nix-target-state-research.md
  - ../research/nix-migration-research.md
  - ../references/jamf-self-service-elevation.md
  - ../adr/0008-sudo-askpass-1password.md
status_detail: "On-box readiness readout for the Jamf-managed work Mac, measured 2026-09-04 without installing anything. Answers the media-restriction half of the target-state doc's open question 3; endpoint-agent tolerance of /nix stays untested until a real install."
---

# Work Mac Nix Readiness: What The Managed Laptop Allows

## Question

[Nix Migration Research](nix-migration-research.md) left one go/no-go check
that nothing in the repo could answer: does the Jamf-managed work Mac permit
the Nix installer and the shape of activation that follows? This doc records
what the machine itself reports, measured on 2026-09-04, and what each
finding means for the three shapes the work host could take: standalone
home-manager, nix-darwin, or NixOS in an OrbStack VM.

Employer-identifying details (vendor product names, MDM server, certificate
names) are deliberately left out; the repo is public. The findings are
about the class of control, which is what the decision needs.

## Method

Two passes, both without `sudo` and without installing anything.

1. A read-only pass from an agent session on the laptop: managed
   preference domains under `/Library/Managed Preferences`, every installed
   device profile (`system_profiler SPConfigurationProfileDataType`),
   LaunchDaemons, `/etc/sudoers.d`, the sudo PAM stack, the System keychain,
   `scutil --proxy`, shell init files, APFS layout, and a handshake-only TLS
   probe of the four hosts Nix talks to.
2. A self-contained readout script Prateek ran in his own terminal, because
   the machine's managed Claude Code policy denies `curl` and `wget` to the
   agent. It repeated the passive checks and added HTTP reachability through
   the content filter, a certifi-versus-corporate-bundle check, and the
   Determinate nix-installer's non-mutating `plan` step. The script lived
   under `~/code/scratch` and is not in the repo; the checks it ran are
   listed at the end so it can be rewritten.

Two cautions from running it. The installer's `plan` subcommand re-execs
itself through `sudo` before it plans anything, so it triggers a Touch ID
prompt and, off an admin grant, fails with "not in the sudoers file" and a
line saying the incident was reported to the administrator. Run it only
inside a live grant, and expect the denial to be visible to IT if you run
it outside one.

## Findings

| Constraint | Evidence | Standalone home-manager | nix-darwin |
| --- | --- | --- | --- |
| Admin is a rolling one-hour grant | A vendor LaunchDaemon revokes admin membership every 3600 s. `/etc/sudoers.d/mscp` sets `timestamp_timeout=0` ([ADR 0008](../adr/0008-sudo-askpass-1password.md)). Touch ID (`pam_tid.so` in `sudo_local`) satisfies each prompt. Off a grant, `sudo` is unavailable outright, not merely password-gated. | Unaffected after the one-time install. | Every switch is Self Service elevation plus a Touch ID tap. No unattended switch, ever. |
| No media-restrictions profile | No `com.apple.systemuiserver` managed domain; no `mount-controls` payload in any of the 70-plus device profiles. | The installer's only MDM hard-fail is absent. | Same. |
| What the installer would do | From `nix-installer plan` (v3.22.3), run once inside a grant: an encrypted "Nix Store" APFS volume, `/etc/synthetic.conf`, `/etc/fstab`, two LaunchDaemons (store mount and `determinate-nixd`), 32 `_nixbld` users from uid 350, edits to `/etc/zshrc`, `/etc/bashrc`, `/etc/zshenv`, `/etc/profile.d`, Time Machine exclusions. | Root once, inside one grant window. | Same, then `nix.enable = false` in nix-darwin. |
| TLS interception on every Nix host | `cache.nixos.org`, `github.com`, `codeload.github.com`, and `install.determinate.systems` all terminate at the corporate inspection CA. No ALPN is negotiated, so HTTP/1.1 only. System trust verifies the chain. The 29-certificate corporate bundle already at `NODE_EXTRA_CA_CERTS` also verifies it. | Determinate nixd feeds Keychain certificates to Nix. Anything that vendors its own roots (rustls, certifi) needs the bundle; it is usable as `ssl-cert-file`. | Same. |
| HTTP reachability through the filter | `cache.nixos.org` 200, `api.github.com` 200, `install.determinate.systems` 307, `channels.nixos.org` 302, GitHub tarball hosts 200 (a ranged request also prints a spurious "Recv failure" through the interception; the 200 is the real result). A known-filtered control path returns 503. Homebrew `python3` with certifi succeeds with default trust and with the bundle. | Fetches work. | Same. |
| Endpoint agents | An EDR agent with security and network system extensions, a DLP network filter, an always-on VPN client, and the MDM vendor's agents. An ad-hoc-signed, unknown binary fetched with `gh` ran from `/tmp` with no quarantine attribute and no block. | Tolerance of the `/nix` volume, the build users, and unsigned store binaries is untested. Only an install answers it. | Same. |
| Security posture | SIP on. Gatekeeper on with identified developers allowed and user override permitted. FileVault on, disable forbidden, key escrowed. Firewall on, signed apps auto-allowed, stealth mode. Secure token enabled. System-extension policy allows user overrides. Managed login items auto-approve only the MDM vendor's team IDs; other background items are permitted but visible. | Unsigned Nix-built listeners on non-loopback ports will prompt; `nix-daemon` appears as a visible background item. | Same. |
| Managed Claude Code policy | An MDM-owned `com.anthropic.claudecode` managed preference: `allowManagedHooksOnly`, mandatory audit hooks pointing at a hook script that does not exist on disk, permission denies for `Bash(curl *)`, `Bash(wget *)`, `WebFetch`, and secret paths; bypass mode disabled. | Target-state open question 16 answered for Claude: the managed seam exists on this Mac and is not ours to write. `/etc/codex` untested. | Same. |
| Hourly MDM check-in | Rewrites the hostname. | Host identity must be the flake attribute, as the target-state doc plans. | Same. |
| Software update policy | Forced deferrals (30 days minor, 90 days major). macOS updates rewrite `/etc/zshrc` and `/etc/bashrc`, where the installer puts its hook; the installer plants a repair daemon. | Source Nix from `$ZDOTDIR/.zshenv` regardless, per the repo's shell-startup rule. | Same. |
| Footprint and room | No `/nix`, `/etc/nix`, `/etc/synthetic.conf`, or Nix daemons. 47 to 49 GiB free. Homebrew at `/opt/homebrew` owned by the user. Command Line Tools present. | Clean slate. | Same. |
| Virtualisation | OrbStack is installed and permitted; no VM restriction in any profile; no VM exists yet. | Enables the third shape below. | Same. |

## Verdict

The constraints decide Nix's shape, not whether it can run. Install once
with Determinate inside an admin window, run standalone home-manager day to
day, and treat any nix-darwin switch as a manual elevated ritual if it is
wanted at all. That is what the target-state doc's Problem B predicted, now
with evidence. The one genuine unknown is whether the endpoint agent
tolerates the `/nix` volume, which only an install answers; treat that
install as the go/no-go test itself.

Two questions only a human can answer: whether Self Service or the software
policy already covers Nix, and whether IT would create the Determinate MDM
exception if it were ever needed.

## The Third Shape: NixOS In An OrbStack VM

The mitchellh route sidesteps the whole `/nix`-on-macOS question: no APFS
volume, no build users on the Mac, no installer, no endpoint question.
`nixos-rebuild switch` runs as root inside a VM the user owns outright, so
the privilege problem above disappears for the Linux side. What replaces it,
checked on the box on 2026-09-05:

- **The corporate CA must go into the VM.** OrbStack NATs VM traffic through
  the host, so with the always-on VPN up every HTTPS call from the VM crosses
  the same interception. In NixOS that is one line,
  `security.pki.certificateFiles = [ ./corp-ca-bundle.pem ];`, using the same
  29-certificate bundle the host already points `NODE_EXTRA_CA_CERTS` at.
  Miss it and nothing works.
- **Vertex.** `gcloud` from nixpkgs plus the existing application-default
  credentials file copied into the VM; it refreshes over the network. Same
  project and location variables as today. The no-ALPN wall applies inside
  the VM exactly as on the host, so any gRPC client needs the same HTTP/1.1
  fallback.
- **MCP servers.** The configured servers are remote HTTP endpoints, so
  from the VM they are HTTPS calls: CA plus network. A host-local gateway
  is reached through OrbStack's host bridge.
- **droid OAuth.** Log in once on the host and copy `~/.factory`, or use a
  device-code flow, or rely on OrbStack's two-way localhost forwarding for
  the browser redirect.
- **Untested:** whether the VM's NAT egress actually clears the corporate
  tunnel and network filter. One `curl https://cache.nixos.org/nix-cache-info`
  and one `gcloud auth print-access-token` from inside a NixOS machine with
  the CA installed settle it.

The cost is that the dev shell becomes Linux. chezmoi keeps the Mac host:
Brewfile, macOS defaults, plists, GUI apps, Karabiner. The VM carves out the
CLI and agent surface, which is the "reproducible Nix environment for the
CLI world" the migration doc already ranked as the live option, in a heavier
and more principled form, and it needs no MDM admin to rebuild.

## Reproducing The Readout

All read-only. Run in a normal terminal; the agent cannot run the `curl`
lines on this machine.

```sh
profiles status -type enrollment
id -Gn | tr ' ' '\n' | grep -c '^admin$'          # 0 outside a grant
ls /Library/Managed\ Preferences/
system_profiler SPConfigurationProfileDataType | grep -i -E 'mount-controls|systemuiserver'
csrutil status; spctl --status; fdesetup status
sysadminctl -secureTokenStatus "$USER"
ls -la /nix /etc/nix /etc/synthetic.conf 2>&1; grep -l nix /etc/zshrc /etc/bashrc
for h in cache.nixos.org github.com codeload.github.com install.determinate.systems; do
  openssl s_client -connect "$h:443" -servername "$h" -alpn h2,http/1.1 </dev/null 2>/dev/null \
    | grep -E 'issuer=|ALPN|Verify return code'
done
openssl s_client -connect cache.nixos.org:443 -servername cache.nixos.org \
  -CAfile "$NODE_EXTRA_CA_CERTS" </dev/null 2>/dev/null | grep 'Verify return code'
curl -sS -o /dev/null -w 'cache %{http_code} %{http_version}\n' https://cache.nixos.org/nix-cache-info
curl -sS -o /dev/null -w 'api.github %{http_code}\n' https://api.github.com/
curl -sS -o /dev/null -w 'determinate %{http_code}\n' https://install.determinate.systems/nix
/opt/homebrew/bin/python3 -c "import urllib.request;print(urllib.request.urlopen('https://cache.nixos.org/nix-cache-info').status)"
SSL_CERT_FILE="$NODE_EXTRA_CA_CERTS" /opt/homebrew/bin/python3 -c "import urllib.request;print(urllib.request.urlopen('https://cache.nixos.org/nix-cache-info').status)"
```

Installer dry run, only inside a live admin grant, one Touch ID prompt,
installs nothing:

```sh
D=$(mktemp -d); gh release download v3.22.3 --repo DeterminateSystems/nix-installer \
  --pattern nix-installer-aarch64-darwin --dir "$D" && chmod +x "$D"/nix-installer-aarch64-darwin
"$D"/nix-installer-aarch64-darwin plan > "$D"/plan.json   # re-execs through sudo
rm -rf "$D"
```
