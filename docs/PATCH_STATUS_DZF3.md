# Patch status on the One UI 8.5 base (S24 FE `S721BXXSCDZF3`)

The inherited EternityROM patches were written against older source firmware. On the pinned
DZF3 base 21 of them no longer applied and were recorded in `out/skipped_patches.tsv`
(`PATCH_DRIFT_POLICY=skip`). This file says what was done about each one.

"Dry-run OK" means `patch -p1 --fuzz=0 --dry-run` succeeds against the decoded DZF3 smali and
the apktool rebuild accepts the result. **Nothing below has been run on a device yet.**

## Rebased onto DZF3 (11 patches)

| Item | Patch | What it does now |
|---|---|---|
| Secure screenshots | `mods/settings/.../services.jar/0001-Allow-disabling-secure-windows` | Drops the `ro.debuggable` gate, so `adb shell settings put secure disable_secure_windows 1` lets screenshots/recording capture `FLAG_SECURE` windows. **Off by default** (the old patch disabled secure windows for everyone). |
| App downgrade | `.../services.jar/0002-Allow-app-downgrade` | `isDowngradePermitted()` returns true. |
| Target-SDK check | `.../services.jar/0003-Bypass-app-target-SDK` | Minimum installable target SDK read as 0. |
| 4-digit auto-confirm PIN | `.../services.jar/0005-Set-auto-confirm-PIN-min-digits-to-4` | Threshold 6 → 4. |
| Gestures by default | `.../SecSettings.apk/0004-...`, `.../SettingsProvider.apk/0001-...` | `isGestureDefault()` true; first-boot settings seed gestures and `navigationbar_splugin_flags=4` (bit 4 = no "simplified gesture"). |
| Hotspot DualAP | `wifi/semwifi-service.jar/0002-...`, `wifi/SecSettings.apk/0002-...` | `isWifiApEnabledWithDualBand()` false, `SPF_SupportMobileApDualAp` false. The old `is5GhzBandSupported` hunk is dropped: that method no longer exists. |
| Hotspot Enhanced Open | `wifi/SecSettings.apk/0004-...` | Hotspot security dropdown uses the arrays without "Enhanced Open" (resource ids resolved by name from `public.xml`). |
| Knox DAR | `mods/knoxpatch/.../services.jar/0002-Disable-SAK-in-DarManagerService` | `checkDeviceIntegrity`, `isDeviceRootKeyInstalled`, `isKnoxKeyInstallable` return true, so Knox DAR does not reject a ROM that is not signed with Samsung's attestation keys. |
| StrongBox | `strongbox/framework.jar/0001-Disable-StrongBox-in-DevRootKeyATCmd` | Removes both `setIsStrongBoxBacked(true)` calls (the Note10+ has no StrongBox keymaster). |

## Retired (no longer needed)

| Item | Why |
|---|---|
| Zipped overlay APKs (`services.jar/0004`) | The patch skips a `DEVICE_INITIAL_SDK_INT >= 35` check. The Note10+ launched on API 29, so the check already allows it. |
| ICD verification (`knoxpatch/.../services.jar/0001`) | `AttestParameterSpec` in DZF3's `services.jar` has no constructor left to patch. The `samsungkeystoreutils.jar` variant still applies. |
| HFR brightness thresholds (`hfr/framework.jar/0001`) | The panel is 60 Hz only (`HFR_MODE=0`, supported rate `60`). The patch only removes thresholds of the adaptive-refresh logic. Left in place and still reported as skipped; not verified on a device. |

## Not ported — needs a device (7 patches)

| Item | Patches | Why not |
|---|---|---|
| HW mDNIe colour modes | `mdnie/hw/framework.jar`, `services.jar` ×2, `SecSettings.apk`, `SystemUI.apk` | 3,000+ lines of `system_server` smali with 60+ hunk failures against DZF3. DZF3 already has the sysfs-based `SemMdnieManagerService` and reads `SEC_FLOATING_FEATURE_LCD_CONFIG_HW_MDNIE=DDI` (the S24 FE uses a DDI mDNIe too), and the ROM already ships the stock Note10+ mode mask. The kernel has `CONFIG_EXYNOS_DECON_MDNIE_LITE=y`. Whether the base's own path works on the Note10+ is unknown until `/sys/class/mdnie/mdnie/*` is checked on a device. A blind rewrite of `system_server` code risks a boot loop, so it is not attempted offline. |
| EAD (adaptive colour tone) | part of the above | This is a feature the Note10+ never had; the old patches re-implement it. Same reason. |
| HDR effect settings | `mdnie/hdr/SecSettings.apk`, `SettingsProvider.apk` | 150+ hunk failures; `SEC_FLOATING_FEATURE_COMMON_SUPPORT_HDR_EFFECT` is not read by DZF3 at all, so the UI gate has to be found by reading code on a device build. |

## On-device checks that decide the open items

```
adb shell ls /sys/class/mdnie/mdnie/            # expect mode, scenario, accessibility, hdr, night_mode, whiteRGB ...
adb shell cat /sys/class/mdnie/mdnie/mode
adb shell dumpsys display | grep -i -E "mdnie|colorMode"
adb logcat -d | grep -i -E "SemMdnieManagerService|mdnie"
```
