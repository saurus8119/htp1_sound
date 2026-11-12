# HTPlex Project Handoff

Last reviewed: 2026-11-12  
Repository: https://github.com/saurus8119/htp1_sound  
Primary branch: `main`  
Product name: **HTPlex**  
HTP-1 add-on/internal ID: `caldera`

This document is the project source-of-truth handoff. Update it when behavior, release status, architecture, or operating decisions change. Distinguish verified repository facts from behavior that still needs testing on the HTP-1.

## 1. Current status

- Latest published release: **1.2.9** (1.2.10 is being prepared).
- Release page: https://github.com/saurus8119/htp1_sound/releases/tag/v1.2.9
- Installer: https://github.com/saurus8119/htp1_sound/releases/download/v1.2.9/htp1-addon-caldera-1.2.9.tar.gz
- SHA256: `6ecc29a69652b53e92aa2dafbb450a5abc02ed4e582a4aed28bab3139013f9da`
- Installer size: `8535548` bytes.
- The HTP-1 catalog `index.json` lists version 1.2.9 with the same URL, checksum, and size.
- Successful ARMv7 build/release run: https://github.com/saurus8119/htp1_sound/actions/runs/43254287314 (commit `4ec9ff446b6bd10b2ce0c4aeeb0414b8b2c04ba4`).
- The 1.2.9 artifact was downloaded and inspected: its launcher sets `audio.audioBufferMs=100` and `cache.precacheCount=1`; the archive checksum was independently recalculated and matched.
- The build diagnostic reports Caldera Music Headless `1.1.0 (5729b05)`. The build still obtains Caldera through the live official installer; this version is not pinned and the player advertises background self-updating.
- This verifies the ARMv7 package, GitHub release assets, checksum, and catalog entry. It does **not** mean the release was installed or tested on the user's HTP-1.
- Final workflow run succeeded: https://github.com/saurus8119/htp1_sound/actions/runs/43254859683 (commit `4d794f0063bea9ae33979d6bd6912378ab12da58`). It rebuilt the ARMv7 package, updated the GitHub release description with the detailed 1.2.9 notes, refreshed the assets, and completed the catalog step successfully.

## 2. Non-negotiable project constraints

1. **Do not suggest SSH access to the HTP-1.** The user cannot SSH into this unit. Work through the repository, add-on package, HTP-1 UI, and available build/release mechanisms.
2. Do not claim that an add-on was installed, that the HTP-1 was tested, or that playback was verified unless the user explicitly reports that test or a supported tool actually verifies it.
3. Keep changes narrow. Do not refactor, rename internal identifiers, add libraries, alter working audio preferences, or change unrelated behavior without explicit approval.
4. Do not make a release merely by changing a version number. Inspect the source diff, run the actual build, inspect its result, publish the release assets, verify the checksum, and verify the catalog entry.
5. Clearly distinguish: source commit, workflow start, successful ARMv7 build, packaged artifact, GitHub release publication, catalog update, and real-device testing. These are separate milestones.
6. Do not create extra branches, tags, version bumps, or releases as a workaround unless needed and explained. Prefer rerunning the existing intended build when possible.
7. Do not mention AirPlay unless the user explicitly asks about it.
8. The user wants a complete release when requested—not instructions to perform repository work manually, and not repeated requests for information already established here.

## 3. Naming and paths

The user-facing product is **HTPlex**. Keep internal identifiers as they are to preserve upgrade compatibility.

- Repository: `saurus8119/htp1_sound`
- Branch: `main`
- Add-on ID / input code: `caldera`
- Add-on path: `addons/caldera/`
- HTP-1 install path: `/var/lib/olympia/addons/caldera`
- Player executable wrapper: `/var/lib/olympia/addons/caldera/bin/caldera-music`
- Bundled player binary: `caldera-music.bin`
- Player config: `state/.config/caldera-music`
- Main service: `caldera.service`
- Auth service/timer: `caldera-auth.service`, `caldera-auth.timer`
- Auth page: `/addons/caldera/`

Keep `caldera` in internal service names, paths, config names, and add-on ID unless there is a deliberate migration plan. User-facing labels, player name, page text, README, and release title should say HTPlex.

## 4. Known-good baseline and audio behavior

The user explicitly confirmed **1.2.5 works as expected**: “good 1.2.5 does exactly what it should.” Treat it as the behavioral baseline when diagnosing regressions.

The launcher in the repository currently sets these preferences before starting the player:

```bash
audio.sampleRate=0
audio.channels=0
audio.masterVolume=100
audio.audioBufferMs=100
cache.precacheCount=1
player.loudnessLeveling=no
player.sweetFades=no
streaming.maxBitrateWiFi=0
streaming.maxBitrateCellular=0
streaming.downmixToStereo=no
```

Important details:

- `audio.sampleRate=0` and `audio.channels=0` leave format selection to the player's automatic/source-matching behavior; do not replace these casually.
- `audio.masterVolume=100` is the established setting.
- Loudness leveling and sweet fades are disabled.
- 1.2.10 removes the explicit Wi-Fi and cellular bitrate overrides entirely; Caldera's own defaults now apply. Stereo downmix remains explicitly disabled.
- **These settings do not guarantee “no transcoding at all.”** Plex may still transcode when the client/player cannot directly decode a media format or for other server/client compatibility reasons.
- The user previously reported a 24-bit/96-kHz source being observed at 44.1 kHz in an earlier version and wanted playback to follow the incoming format. The 1.2.5 default-device/source-matching configuration was retained. Do not claim bit-perfect or sample-rate matching is verified without a device test.
- Volume response had previously been described as slow, but the exact cause was not established. Do not state that FIFO scheduling fixes volume response; it is a testable hypothesis, not a confirmed fix.

## 5. 1.2.8 service scheduling change

The current `addons/caldera/units/caldera.service` contains:

```ini
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=45
ExecStartPost=/bin/bash -c 'echo $MAINPID > /sys/fs/cgroup/cpuset/user/cgroup.procs 2>/dev/null || true'
```

Rationale copied from the user's DLNA receiver configuration:

- Without real-time scheduling, audio threads may run under normal `SCHED_OTHER` scheduling at priority 0 and may be delayed enough to underrun I2S DMA on the PREEMPT_RT kernel.
- `CPUSchedulingPolicy=fifo` and priority 45 request real-time FIFO scheduling for the service.
- The `ExecStartPost` command attempts to place the main process in `/sys/fs/cgroup/cpuset/user`; errors are deliberately ignored.

This is included in 1.2.8. It has **not** been confirmed on the user's HTP-1. FIFO scheduling is a real-time policy: retain the priority only with care, because a process that does not yield appropriately can affect other system services. Test audio stability and volume response separately.

## 6. Add-on metadata currently in the repository

The current `addons/caldera/addon.json` includes:

```json
{
  "id": "caldera",
  "version": "1.2.10",
  "label": "HTPlex",
  "summary": "HTPlex network music player with Plex sign-in",
  "requires": {
    "capabilities": ["source/1"]
  },
  "units": {
    "caldera.service": "link",
    "caldera-auth.service": "link",
    "caldera-auth.timer": "enable"
  },
  "service": {
    "unit": "caldera.service",
    "defaultOn": true
  },
  "input": {
    "code": "caldera",
    "label": "HTPlex",
    "routesTo": "i2s",
    "order": 218,
    "formatDetectOption": "biased",
    "release": "restart",
    "shield": true
  },
  "ui": {
    "switch": true,
    "page": "/addons/caldera/"
  }
}
```

The user asked what `input.order` and `ui.switch` mean. Prior discussion suggested order controls placement and switch controls visibility/availability, but their exact firmware semantics have **not** been independently verified. Do not change either value or present those interpretations as confirmed without checking the HTP-1 add-on specification/source.

## 7. Release history and decisions

### 1.2.5 — known-good baseline
- User explicitly confirmed it does what it should.
- Plex PIN authorization works and HTPlex/player visibility in Plexamp worked.
- Default audio-device discovery is used; do not force a specific ALSA device.
- Baseline preferences are listed in section 4.

### 1.2.6 — HTPlex rebrand
- User-facing product changed from Caldera Music to HTPlex.
- Internal identifiers remained `caldera` for compatibility.
- ARMv7 build and release were published.
- No HTP-1 device test is implied.

### 1.2.7 — streaming preferences and auth polling
Changes included:
- `streaming.maxBitrateWiFi=0`
- `streaming.maxBitrateCellular=0`
- `streaming.downmixToStereo=no`
- Stop `caldera-auth.timer` after a Plex token is detected.
- Existing 1.2.5 audio preferences and saved-token check were preserved.
- The top-level README was restored with installation instructions.
- Do not describe these bitrate settings as a universal force-direct-play / no-transcode switch.

### 1.2.8 — real-time scheduling
- Added the FIFO scheduling policy at priority 45 and the cgroup placement command to `caldera.service`.
- Built and published as an ARMv7 add-on.
- Release and catalog currently verified; device behavior remains unverified.

### 1.2.9 — audio buffering and conservative prefetch
- Sets `audio.audioBufferMs=100` to request a 100 ms player audio buffer.
- Sets `cache.precacheCount=1` to prefetch one upcoming track.
- Leaves Caldera's disk-cache size limit unchanged; HTP-1 free storage has not been measured.
- Preserves the existing sample-rate, channel, volume, loudness, fade, and downmix preferences; at that time it also retained the explicit bitrate overrides.
- Does not change system-wide ALSA settings, ALSA period sizes, service scheduling, cgroup placement, input integration, or the Caldera binary.
- Device playback and startup-stutter behavior remain unverified until tested on the HTP-1.

### 1.2.10 — remove explicit streaming bitrate overrides (in preparation)
- Removes `streaming.maxBitrateWiFi=0` and `streaming.maxBitrateCellular=0` from the launcher preference loop.
- Does not write replacement values for either preference; Caldera's defaults apply.
- Retains `audio.audioBufferMs=100`, `cache.precacheCount=1`, and the other existing preferences.
- Retains `streaming.downmixToStereo=no`.
- Release/build/catalog status is pending verification.

## 8. Build and release workflow

The release process is split into two lanes so small add-on changes do not rebuild Caldera.

### Package-only lane

Workflow: `.github/workflows/package-caldera.yml`

- Triggered by ordinary changes under `addons/caldera/**`, `tools/pack.sh`, and versioned HTPlex release notes.
- Skips itself when the same push changes runtime/build inputs.
- Downloads the newest earlier published HTPlex package and verifies its checksum.
- Overlays the repository-controlled add-on files while preserving `caldera-music.bin` and `lib/`.
- Fingerprints the executable and all bundled libraries before/after overlay and after packaging; any runtime change fails the job.
- Packages and publishes without Docker, QEMU, or rerunning the official Caldera installer.
- Downloads the published release assets again, verifies their checksum, updates the catalog, and reads the catalog entry back for verification.

### Full ARMv7 runtime lane

Workflow: `.github/workflows/build-caldera.yml`

- Triggered only by changes under `addons/caldera/build/**`, replacement of `bin/caldera-music.bin`, or changes under `addons/caldera/lib/**`.
- Manual `workflow_dispatch` is also available when a deliberate full runtime refresh is wanted.
- Validates the matching release-notes file before starting Docker/QEMU.
- Builds the ARMv7 installer environment, runs the official Caldera installer, assembles the runtime, and packages it.
- Publishes the release, downloads the published assets to verify the checksum, then updates and verifies the catalog.

Both workflows use the same non-cancelling release concurrency group. If a push changes runtime inputs and ordinary add-on files together, the package-only lane detects the runtime change and skips; the full runtime lane owns that release.

Detailed behavior and change classification: `docs/HTPLEX-RELEASE-WORKFLOW.md`.

### Release verification checklist

For every requested release, verify all of the following independently:

- [ ] Version in `addons/caldera/addon.json` is correct.
- [ ] The intended workflow run corresponds to the intended commit.
- [ ] The correct lane ran: package-only for source/config changes; full ARMv7 only for runtime changes.
- [ ] Package contents match the intended source changes.
- [ ] For package-only releases, executable and library fingerprints match the previous release.
- [ ] Archive and `.sha256` asset exist on the GitHub release.
- [ ] The release is published, not draft or prerelease.
- [ ] The published archive is downloaded again and its checksum passes.
- [ ] `index.json` points to the correct version, archive URL, SHA256, and byte size.
- [ ] Do not claim physical HTP-1 installation or playback testing unless actually performed.

The 1.2.10 workflow attempt exposed a missing release-notes file at the time the job checked out its commit. The ARMv7 build and archive packaging succeeded, but release publication failed at `gh release create` because the notes file was not in that commit; catalog publication was skipped. The notes were added in the next commit. The revised workflows validate notes before expensive work and verify release assets and catalog contents before reporting success.

## 9. Known functional questions / unverified items

- **Slow volume response:** Cause not established. FIFO scheduling may help if CPU scheduling delays are involved, but this is not proven. Test response latency after 1.2.8 before attributing a fix.
- **Transcoding:** Bitrate caps and stereo downmix were disabled in 1.2.7. This does not force Plex to direct-play every codec/container.
- **Sample-rate behavior:** Automatic/source-matching preferences are configured, but actual output rate needs device-side confirmation.
- **HTP-1 source/input visibility:** User previously reported that HTPlex sometimes did not appear in the input list until the HTP-1 input configuration/name was manually edited and saved. User chose to leave this issue for later; do not change it unless asked.
- **Plexamp player visibility:** Worked in the known-good 1.2.5 setup; later regression concerns were discussed during development. Do not assume current behavior without a user test.
- **Plex authorization:** PIN authorization worked in 1.2.5; saved-token handling is retained. The 1.2.7 auth polling change stops the timer once a token is present.
- **Input metadata semantics:** `order` and `switch` need authoritative firmware/spec confirmation before changing.

## 10. Working style and communication

- Be concise, direct, and factual.
- Do not make the user repeat details already in this handoff.
- When a request is ambiguous, ask only the one essential question.
- Before changing code, state the exact intended scope when it is not already explicit.
- After changing code, report exact files and commit SHA.
- For builds, report run URL, run attempt, status, and conclusion.
- Never call a release “done” while the build is queued, running, cancelled, or failed.
- If something failed, identify the failing workflow step and quote the actual error rather than guessing.
- Do not say “verified” unless the exact file, commit, run, asset, checksum, or catalog entry was actually inspected.
- Do not imply that repository success proves HTP-1 runtime success.

## 11. Useful repository links

- Repository: https://github.com/saurus8119/htp1_sound
- Releases: https://github.com/saurus8119/htp1_sound/releases
- Actions: https://github.com/saurus8119/htp1_sound/actions
- Add-on metadata: https://github.com/saurus8119/htp1_sound/blob/main/addons/caldera/addon.json
- Main service: https://github.com/saurus8119/htp1_sound/blob/main/addons/caldera/units/caldera.service
- Launcher: https://github.com/saurus8119/htp1_sound/blob/main/addons/caldera/bin/caldera-music
- Build workflow: https://github.com/saurus8119/htp1_sound/blob/main/.github/workflows/build-caldera.yml
- Catalog: https://github.com/saurus8119/htp1_sound/blob/main/index.json
