if [[ $TARGET_SINGLE_SYSTEM_IMAGE == "qssi" || \
        $TARGET_SINGLE_SYSTEM_IMAGE == "essi" || \
        $TARGET_SINGLE_SYSTEM_IMAGE == "essi85" ]]; then
    LOG_STEP_IN "- Target device with 32-Bit HALs detected."

    MULTILIB_SOURCE="r11sxxx"
    if [[ "$TARGET_SINGLE_SYSTEM_IMAGE" == "essi85" ]]; then
        [ -n "${MULTILIB_FIRMWARE:-}" ] || \
            ABORT "MULTILIB_FIRMWARE is required for essi85"
        MULTILIB_SOURCE="$MULTILIB_FIRMWARE"
    fi

    LOG_STEP_IN "- Adding multilib system runtime from $MULTILIB_SOURCE"
    DELETE_FROM_WORK_DIR "system" "system/lib"
    ADD_TO_WORK_DIR "$MULTILIB_SOURCE" "system" "system/lib"

    BLOBS_LIST="
    system/apex/com.android.i18n.apex
    system/apex/com.android.runtime.apex
    system/bin/bootstrap/linker
    system/bin/bootstrap/linker_asan
    "
    if [ "${IMPULSE_DONOR_API:-36}" -gt 36 ]; then
        # The multilib donor is one Android release behind: its 64-bit bionic and ICU
        # cannot run the donor system, so only add its 32-bit payload to the donor APEXes.
        BLOBS_LIST="
        system/bin/bootstrap/linker
        system/bin/bootstrap/linker_asan
        "
        CERT_PREFIX="aosp"
        $ROM_IS_OFFICIAL && CERT_PREFIX="impulse"
        for apex in com.android.i18n.apex com.android.runtime.apex
        do
            EVAL "python3 \"$SRC_DIR/scripts/internal/merge_multilib_apex.py\" \
                \"$WORK_DIR/system/system/apex/$apex\" \
                \"$FW_DIR/$(cut -d "/" -f 1,2 <<< "$MULTILIB_SOURCE" | tr "/" "_")/system/system/apex/$apex\" \
                \"$WORK_DIR/system/system/apex/$apex.merged\" \
                avbtool signapk \
                \"$SRC_DIR/security/${CERT_PREFIX}_platform.x509.pem\" \
                \"$SRC_DIR/security/${CERT_PREFIX}_platform.pk8\"" || \
                ABORT "Failed to merge the multilib payload into $apex"
            mv -f "$WORK_DIR/system/system/apex/$apex.merged" "$WORK_DIR/system/system/apex/$apex"
        done
        unset CERT_PREFIX apex
    fi
    if [[ "$TARGET_SINGLE_SYSTEM_IMAGE" != "essi85" ]]; then
        # The legacy Android 15 source module carried its matching tzdata APEX.
        # The essi85 donor already supplies an API 36 architecture-neutral one.
        BLOBS_LIST+=" system/apex/com.google.android.tzdata6.apex"
    fi
    for blob in $BLOBS_LIST
    do
        DELETE_FROM_WORK_DIR "system" "$blob"
        ADD_TO_WORK_DIR "$MULTILIB_SOURCE" "system" "$blob"
    done
    LOG_STEP_OUT

    LOG_STEP_IN "- Creating symlinks"
    ln -sf "/apex/com.android.runtime/bin/linker" "$WORK_DIR/system/system/bin/linker"
    ln -sf "/apex/com.android.runtime/bin/linker" "$WORK_DIR/system/system/bin/linker_asan"
    SET_METADATA "system" "system/bin/linker" 0 0 755 "u:object_r:system_linker_exec:s0"
    SET_METADATA "system" "system/bin/linker_asan" 0 0 755 "u:object_r:system_linker_exec:s0"

    ln -sf "/apex/com.android.runtime/lib/bionic/libc.so" "$WORK_DIR/system/system/lib/libc.so"
    ln -sf "/apex/com.android.runtime/lib/bionic/libdl.so" "$WORK_DIR/system/system/lib/libdl.so"
    ln -sf "/apex/com.android.runtime/lib/bionic/libdl_android.so" "$WORK_DIR/system/system/lib/libdl_android.so"
    ln -sf "/apex/com.android.runtime/lib/bionic/libm.so" "$WORK_DIR/system/system/lib/libm.so"
    SET_METADATA "system" "system/lib/libc.so" 0 0 644 "u:object_r:system_lib_file:s0"
    SET_METADATA "system" "system/lib/libdl.so" 0 0 644 "u:object_r:system_lib_file:s0"
    SET_METADATA "system" "system/lib/libdl_android.so" 0 0 644 "u:object_r:system_lib_file:s0"
    SET_METADATA "system" "system/lib/libm.so" 0 0 644 "u:object_r:system_lib_file:s0"
    LOG_STEP_OUT

    LOG_STEP_IN "- Setting props"
    SET_PROP "vendor" "ro.vendor.product.cpu.abilist" "arm64-v8a"
    SET_PROP "vendor" "ro.vendor.product.cpu.abilist32" ""
    SET_PROP "vendor" "ro.vendor.product.cpu.abilist64" "arm64-v8a"
    SET_PROP "vendor" "ro.zygote" "zygote64"
    SET_PROP "vendor" "dalvik.vm.dex2oat64.enabled" "true"
    LOG_STEP_OUT

    unset MULTILIB_SOURCE BLOBS_LIST blob
    LOG_STEP_OUT
else
    LOG "- Target device does not use 32-Bit HALs. Ignoring."
fi
