# Test builds only: lets the host capture logcat from a boot loop on a freshly formatted
# device (no adb_keys on /data yet). Never enabled for releases.
if [[ "${IMPULSE_DEBUG_ADB_KEY:-}" == "" ]]; then
    LOG "- Skipping (IMPULSE_DEBUG_ADB_KEY not set)"
    return 0
fi
[ -f "$IMPULSE_DEBUG_ADB_KEY" ] || ABORT "IMPULSE_DEBUG_ADB_KEY does not exist: $IMPULSE_DEBUG_ADB_KEY"
mkdir -p "$WORK_DIR/product/etc/security"
cp "$IMPULSE_DEBUG_ADB_KEY" "$WORK_DIR/product/etc/security/adb_keys"
SET_METADATA "product" "etc/security/adb_keys" 0 0 644 "u:object_r:adb_keys_file:s0"
SET_PROP "product" "persist.sys.usb.config" "mtp,adb"

# Return to recovery after repeated failed boots so unattended tests cannot get stuck in a loop.
cp "$MODPATH/dbgwatch.sh" "$WORK_DIR/system/system/etc/dbgwatch.sh"
SET_METADATA "system" "system/etc/dbgwatch.sh" 0 2000 755 "u:object_r:system_file:s0"
cat > "$WORK_DIR/system/system/etc/init/zz_dbgwatch.rc" <<'EOF'
on post-fs
    start dbgwatch

service dbgwatch /system/bin/sh /system/etc/dbgwatch.sh
    disabled
    oneshot
    user root
    group root system log cache
    seclabel u:r:shell:s0
EOF
SET_METADATA "system" "system/etc/init/zz_dbgwatch.rc" 0 0 644 "u:object_r:system_file:s0"
cat >> "$WORK_DIR/system/system/etc/selinux/plat_sepolicy.cil" <<'EOF'
(typepermissive shell)
(allow init shell (process (transition rlimitinh siginh noatsecure)))
(allow init shell_exec (file (execute read getattr open map)))
EOF
