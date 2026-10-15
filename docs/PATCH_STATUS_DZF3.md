# Patch status on the One UI 8.5 base (S24 FE `S721BXXSCDZF3`)

The inherited EternityROM patches were written against older source firmware. On the pinned
DZF3 base 21 of them no longer applied and were recorded in `out/skipped_patches.tsv`
(`PATCH_DRIFT_POLICY=skip`). This file says what was done about each one.

"Dry-run OK" means `patch -p1 --fuzz=0 --dry-run` succeeds against the decoded DZF3 smali.
**Nothing below has been run on a device yet.**

## Read this first: patches to SecSettings and SettingsProvider are currently inert

`scripts/apktool.sh` keeps every platform-signed APK byte-identical to the source firmware
(`KEEP_SIGNED_APKS_STOCK=true`) unless the package is on the scoped signature-bridge list
(`unica/patches/signature`: SystemUI, Accessibility, BiometricSetting, EnvironmentAdaptiveDisplay).
`SecSettings.apk` and `SettingsProvider.apk` are not on it, so the build applies patches to
their decoded trees and then throws the result away (`Keeping signed APK at stock`).

Inert until those two packages are added to the bridge (a trust-boundary change that needs an
explicit decision):

- the **Screen resolution** entry in Settings (`resolution/SecSettings.apk`; stock
  `ScreenResolutionPreferenceController.getAvailabilityStatus()` is a folded constant 3, so the
  entry stays hidden even though the framework flags are on),
- gestures by default (SecSettings + SettingsProvider),
- hotspot DualAP UI flag and Enhanced Open dropdown,
- the older SecSettings patches (outdoor mode, 4-digit PIN, real model number).

## Rebased onto DZF3 (10 patches)

| Item | Patch | Effective in the ROM? |
|---|---|---|
| Secure screenshots (opt-in) | `mods/settings/.../services.jar/0001-Allow-disabling-secure-windows` | yes. Drops the `ro.debuggable` gate, so `adb shell settings put secure disable_secure_windows 1` lets screenshots/recording capture `FLAG_SECURE` windows. **Off by default** (the old patch disabled secure windows for everyone). |
| App downgrade | `.../services.jar/0002-Allow-app-downgrade` | yes |
| Target-SDK check | `.../services.jar/0003-Bypass-app-target-SDK` | yes. Minimum installable target SDK read as 0. |
| 4-digit auto-confirm PIN | `.../services.jar/0005-Set-auto-confirm-PIN-min-digits-to-4` | yes (the SecSettings counterpart is inert) |
| Hotspot DualAP | `wifi/semwifi-service.jar/0002-...` | yes: `isWifiApEnabledWithDualBand()` returns false. The SecSettings half (`SPF_SupportMobileApDualAp`) is inert. |
| StrongBox | `strongbox/framework.jar/0001-...` | yes. Branches over both `setIsStrongBoxBacked(true)` calls in `DevRootKeyATCmd` (the Note10+ has no StrongBox). |
| Gestures by default | `.../SecSettings.apk/0004-...`, `.../SettingsProvider.apk/0001-...` | **inert** |
| Hotspot DualAP UI flag | `wifi/SecSettings.apk/0002-...` | **inert** |
| Hotspot Enhanced Open | `wifi/SecSettings.apk/0004-...` | **inert**. Dropdown uses the arrays without "Enhanced Open" (ids resolved by name from `public.xml`). |

All method-body changes keep the old body as dead code behind an early return/branch. The build's
DEX-inventory guard (`scripts/internal/dex_inventory.py`) requires every class/method/field/type
reference of the source dex to survive, and rejects a patch that deletes the last use of one.

## Covered by something else (1)

| Item | Why |
|---|---|
| Knox DAR integrity / SAK (`mods/knoxpatch/.../services.jar/0002`) | `target/d2s/patches/android16_compat/.../0002-Allow-Secure-Folder-on-unlocked-d2s` already makes `checkDeviceIntegrity()` and `isDeviceRootKeyInstalled()` return true on DZF3 (so `isKnoxKeyInstallable()` follows). A second rebased copy only duplicated it and broke the DEX guard, so the original file is left as-is and stays reported as skipped. |

## Retired (no longer needed, 3)

| Item | Why |
|---|---|
| Zipped overlay APKs (`services.jar/0004`) | The patch skips a `DEVICE_INITIAL_SDK_INT >= 35` check. The Note10+ launched on API 29, so the check already allows it. |
| ICD verification (`knoxpatch/.../services.jar/0001`) | `AttestParameterSpec` in DZF3's `services.jar` has no constructor left to patch. The `samsungkeystoreutils.jar` variant still applies. |
| HFR brightness thresholds (`hfr/framework.jar/0001`) | The panel is 60 Hz only (`HFR_MODE=0`, supported rate `60`). The patch only removes thresholds of the adaptive-refresh logic. Left in place and still reported as skipped; not verified on a device. |

## Not ported — needs a device (7 patches)

| Item | Patches | Why not |
|---|---|---|
| HW mDNIe colour modes | `mdnie/hw/framework.jar`, `services.jar` ×2, `SecSettings.apk`, `SystemUI.apk` | 3,000+ lines of `system_server` smali with 60+ hunk failures against DZF3. DZF3 already has the sysfs-based `SemMdnieManagerService` and reads `SEC_FLOATING_FEATURE_LCD_CONFIG_HW_MDNIE=DDI` (the S24 FE uses a DDI mDNIe too), and the ROM already ships the stock Note10+ mode mask. The kernel has `CONFIG_EXYNOS_DECON_MDNIE_LITE=y`. Whether the base's own path works on the Note10+ is unknown until `/sys/class/mdnie/mdnie/*` is checked on a device. A blind rewrite of `system_server` code risks a boot loop, so it is not attempted offline. |
| EAD (adaptive colour tone) | part of the above | A feature the Note10+ never had; the old patches re-implement it. Same reason. |
| HDR effect settings | `mdnie/hdr/SecSettings.apk`, `SettingsProvider.apk` | 150+ hunk failures; `SEC_FLOATING_FEATURE_COMMON_SUPPORT_HDR_EFFECT` is not read by DZF3 at all, so the UI gate has to be found by reading code on a device build. Both targets are also inert APKs (see above). |

## On-device checks that decide the open items

```
adb shell ls /sys/class/mdnie/mdnie/            # expect mode, scenario, accessibility, hdr, night_mode, whiteRGB ...
adb shell cat /sys/class/mdnie/mdnie/mode
adb shell dumpsys display | grep -i -E "mdnie|colorMode"
adb logcat -d | grep -i -E "SemMdnieManagerService|mdnie"
```
