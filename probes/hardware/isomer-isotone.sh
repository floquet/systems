echo "========== $(hostname) =========="

echo
echo "=== CPU ==="
lscpu | grep -E \
'Model name|Socket|Core|Thread|CPU\(s\)|CPU max MHz|CPU min MHz|L1d|L2|L3'

echo
echo "=== MEMORY ==="
free -h
sudo dmidecode --type memory | grep -E \
'Size:|Speed:|Configured Memory Speed:' | grep -v 'No Module'

echo
echo "=== STORAGE ==="
findmnt /
lsblk -d -o NAME,SIZE,MODEL,TRAN,ROTA

echo
echo "=== TMP ==="
findmnt /tmp
df -h /tmp
printf 'TMPDIR=%s\n' "$TMPDIR"

echo
echo "=== SPACK STAGE ==="
spack python -c \
'import spack.stage; print(spack.stage.get_stage_root())'

echo
echo "=== SWAP ==="
swapon --show
free -h

echo
echo "=== GOVERNOR ==="
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null

echo
echo "=== KERNEL ==="
uname -a

