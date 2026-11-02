#!/system/bin/sh
# Test builds only: return to recovery after repeated failed boots, keeping the kernel log of each boot.
D=/cache/dbg
mkdir -p $D; chmod 755 $D
seq=$(cat $D/seq 2>/dev/null); seq=$((${seq:-0}+1)); echo $seq > $D/seq
fails=$(cat $D/fails 2>/dev/null); fails=$((${fails:-0}+1)); echo $fails > $D/fails
cat /proc/last_kmsg > $D/last_kmsg.$seq 2>/dev/null
chmod 644 $D/*
sync
if [ "$fails" -ge 3 ]; then
    echo 0 > $D/fails; echo "$seq bootloop" >> $D/events; sync
    setprop sys.powerctl reboot,recovery
    exit 0
fi
t=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5; t=$((t+5))
    if [ "$t" -ge 600 ]; then
        echo 0 > $D/fails; echo "$seq boot-timeout" >> $D/events
        logcat -b all -d -v threadtime > $D/logcat.$seq 2>&1
        dmesg > $D/dmesg.$seq 2>&1
        sync
        setprop sys.powerctl reboot,recovery
        exit 0
    fi
done
echo "$seq completed ${t}s" >> $D/events
sleep 120
echo 0 > $D/fails
sync
# Unattended stability test: /cache/dbg/loop holds the reboots left. adb is not needed.
left=$(cat $D/loop 2>/dev/null)
if [ "${left:-0}" -gt 0 ]; then
    echo $((left-1)) > $D/loop
    logcat -b crash -d -v threadtime > $D/crash.$seq 2>&1
    sync
    if [ "$left" -eq 1 ]; then setprop sys.powerctl reboot,recovery; else setprop sys.powerctl reboot,loop; fi
fi
