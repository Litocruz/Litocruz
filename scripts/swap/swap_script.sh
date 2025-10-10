echo "PID      NAME         SWAP (kB)"
echo "---------------------------------"
for dir in /proc/[0-9]*; do
    pid=$(grep "^Pid:" "$dir/status" 2>/dev/null | awk '{print $2}')
    name=$(grep "^Name:" "$dir/status" 2>/dev/null | awk '{print $2}')
    swap=$(grep "^VmSwap:" "$dir/status" 2>/dev/null | awk '{print $2}')
    if [ -n "$swap" ] && [ "$swap" -gt 0 ]; then
        printf "%-8s %-12s %s\n" "$pid" "$name" "$swap"
    fi
done | sort -k3 -n -r | head -10
