# HTPlex Project Handoff

Last reviewed: 2026-11-11  
Repository: https://github.com/saurus8119/htp1_sound  
Primary branch: `main`  
Product name: **HTPlex**  
HTP-1 add-on/internal ID: `caldera`

This document is the project source-of-truth handoff. Update it when behavior, release status, architecture, or operating decisions change. Distinguish verified repository facts from behavior that still needs testing on the HTP-1.

## 1. Current status

- Latest published release: **1.2.8**.
- Release page: https://github.com/saurus8119/htp1_sound/releases/tag/v1.2.8
- Installer: https://github.com/saurus8119/htp1_sound/releases/download/v1.2.8/htp1-addon-caldera-1.2.8.tar.gz
- SHA256: `d1e59ee66385273070541eb35913bb9dcace26b4023a4b90a2afabda6f2a6cd8`
- Installer size: `8535555` bytes.
- The HTP-1 catalog `index.json` currently lists version 1.2.8 with the same URL, checksum, and size.
- The latest observed `main` commit is `06c88674349ff741844e22316b64c716b1729ccf`, titled `Publish HTPlex 1.2.8 in add-on catalog`.
- The 1.2.8 ARMv7 package and GitHub release assets were verified in GitHub. This does **not** mean the release was installed or tested on the user's HTP-1.
- No 1.2.9 release is required or requested at this point.

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
- The 1.2.7 additions set Wi-Fi and cellular maximum bitrate to zero and disable stereo downmix. This was intended to avoid bitrate-limit-triggered transcoding and downmixing.
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
  "version": "1.2.8",
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

## 8. Build and release workflow

Workflow file: `.github/workflows/build-caldera.yml`  
Workflow name: `Build HTPlex ARMv7`

Triggers:
- Push to `main` when files under `addons/caldera/**`, the workflow file, or `tools/pack.sh` change.
- Manual `workflow_dispatch`.

The workflow currently:
1. Reads the version from `addons/caldera/addon.json`.
2. Checks whether GitHub release `vVERSION` already exists.
3. Sets up QEMU and Docker Buildx.
4. Builds the ARMv7 installer environment from `addons/caldera/build`.
5. Runs the official player installer under ARMv7 emulation.
6. Stages the ARMHF player binary and selected runtime libraries.
7. Runs `tools/pack.sh caldera dist`.
8. Checks that the archive and checksum exist, verifies the checksum, and lists archive contents.
9. Uploads the archive/checksum and diagnostics as a workflow artifact.
10. If the release did not already exist at the initial check, creates/uploads the GitHub release assets and updates `index.json`.

### Important workflow weakness to fix carefully

The workflow's `publish_check` sets `publish=false` whenever the GitHub release tag already exists. Both the release-upload step **and the catalog-update step** are gated on `publish=true`. This means rerunning a workflow after a release exists will rebuild/package and upload an artifact, but will skip the catalog update—even if the catalog needs repair. It also means the workflow is not fully idempotent.

The catalog step unconditionally runs `git commit` after generating `index.json`. If the generated catalog is identical to the current file, `git commit` exits non-zero with “nothing to commit,” which can mark the workflow failed even though the catalog is already correct. A robust future fix should:
- Separate “release exists” from “catalog needs updating.”
- Always calculate and validate the desired catalog entry.
- Only commit/push when `git diff --quiet -- index.json` indicates a real change.
- Treat an already-correct catalog as success.
- Handle concurrent workflow runs/push races safely, without creating duplicate releases or version bumps.
- Preserve the existing successful build/package behavior and keep the change narrowly scoped.

Do not modify this workflow merely as part of an unrelated feature. Make and test a focused workflow fix when the user asks.

### Release verification checklist

For every requested release, verify all of the following independently:

- [ ] Intended source changes are present on `main`.
- [ ] Version in `addons/caldera/addon.json` is correct.
- [ ] The intended workflow run corresponds to the intended commit.
- [ ] ARMv7 build job completed successfully (not merely queued or cancelled).
- [ ] Packaging step succeeded.
- [ ] Archive and `.sha256` asset exist on the GitHub release.
- [ ] Downloaded/reported SHA256 matches the release asset and catalog.
- [ ] GitHub release is published, not draft.
- [ ] `index.json` points to the correct version, archive URL, SHA256, and byte size.
- [ ] No unrelated source files or behavior changed.
- [ ] Device testing is reported separately and only if actually performed.

If a workflow is cancelled, inspect the run attempt and job logs before retrying. A cancellation is not a compiler failure. Do not keep bumping versions to work around an unexplained cancellation. If the release already exists, do not assume a rerun will update the catalog: inspect the workflow's publish gating and current catalog.

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
