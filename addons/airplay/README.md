# HTP-1 AirPlay addon (experimental)

This addon tree is prepared for Shairport Sync 5.6.1 plus NQPTP 1.2.9 (`smi11`). The GitHub Actions workflow builds ARMv7 binaries in a Debian 9 userspace, checks ELF architecture and shared-library resolution, verifies the shared-memory interface pair, and uploads a versioned-by-commit artifact.

**Status:** CI build/test package only. Hardware playback, firmware audio routing, addon install/remove/upgrade, and long-duration playback have not been verified on an HTP-1. A successful CI run is not a claim of hardware compatibility.

See `build/README.md` for the test boundary and artifact details.
