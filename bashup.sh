#!/bin/bash
if [ "$1" == "setup" ]; then
        mkdir -p /srv/store/backup/$(hostname -s)
        mount /srv/store/backup/$(hostname -s)
        echo -en "\n#Tom's Crusty backup\n" >> /etc/crontab
        p=$(df -lP -x tmpfs -x devtmpfs -x iso9660 | awk '/\//{print $6 "/."}' | sed 's^//^/^' | xargs)
        echo "0 3 1    * * root /srv/store/backup/$(hostname -s)/backup.sh \"$p\" full" >> /etc/crontab
        echo "0 3 2-31 * * root /srv/store/backup/$(hostname -s)/backup.sh \"$p\" inc" >> /etc/crontab
        exit
fi

# Restore
# tar --extract --listed-incramental=/dev/null --verbose --file ../foobar-full-20170610-030003.tar.bz2 #full
# tar --extract --listed-incramental=/dev/null --verbose --file ../foobar-inc-20170619-030002.tar.bz2  #latest inc

set -eux
base="$(dirname $0)"
name="$(hostname -s)"
date="$(date +%Y%m%d-%H%M%S)"
dir="$1"
level="$2"

lockdir="$base/$name.lock"
if mkdir "$lockdir"; then
        trap 'rm -rf "$lockdir"' 0
else
        exit 0
fi

test ! -f "$base/$name-snap" && level=full
test "$level" == "full" && oldfiles="$(find $base/. -maxdepth 1 -type f -name "${name}-*" | xargs)"
test "$level" == "inc"  && oldfiles="$(find $base/. -maxdepth 1 -type f -name "${name}-inc-*" | xargs)"
test "$level" == "inc"  && cp "$base/$name-snap" "$base/$name-snap-run"

exec > "$base/$name-$level-$date.log"
exec 2>&1

cat <<EOF > "$base/$name-$level-$date.info"
#Host $(hostname)
# ip a
$(ip a)
# ip l
$(ip l)
# ip r
$(ip r)
# df -h
$(df -h)
# lsblk
$(lsblk)
# pvdisplay
$(pvdisplay 2> /dev/null)
# vgdisplay
$(vgdisplay 2> /dev/null)
# lvdisplay
$(lvdisplay 2> /dev/null)
# fdisk -l
$(fdisk -l)
EOF

export HOME=/root; umask 177; cd /; set +e
tar --create --bzip2 --one-file-system --sparse --xattrs --acls --selinux \
        --listed-incremental "$base/$name-snap-run" \
        --exclude '/./tmp/ssh-*' \
        --exclude '/./tmp/tmux-*' \
        --exclude '/var/./run/*' \
        $dir \
        > "$base/$name-$level-$date.tar.bz2"
set -e

test "$level" == "full" && cp "$base/$name-snap-run" "$base/$name-snap"
rm -f "$base/$name-snap-run"
rm -f $oldfiles
echo 0
