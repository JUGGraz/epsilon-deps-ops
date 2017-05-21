passwd          # set root password - make this good, won't need it much
dhclient em1    # get an IP address
# install runtime environment:
pkg install -g sudo rsync lsof screen runit \
  openjdk8\* nginx-lite-1.10\* \
  postgresql96-client\* postgresql96-contrib\* \
  postgresql96-plpython\* postgresql96-server\*
adduser         # create user for a human managing the box
visudo          # give that user root privileges, just NOPASSWD: ALL it
# persistently enable some things
cat >> /etc/rc.conf <<EOF
sshd_enable="YES"
ifconfig_em0="DHCP"
ifconfig_em1="DHCP"
runsvdir_enable="YES"
runsvdir_path="/service"
EOF
# OpenJDK needs fdescfs & proc
cat >> /etc/fstab << EOF
fdesc	/dev/fd		fdescfs		rw	0	0
proc	/proc		procfs		rw	0	0
EOF
