<!-- $size: 16:9 -->

# ε Deps Ops
or
## how to get a working server in seven commands
and
## what to do with the thing

---

# ε?
##
## Mario Zupan: Zero Deps Webapps in March
### Actually wrote a web-app only relying on J8RE stdlib
### the absolute madman!
# ε!
## You're not gonna write your own OS
## Ditto remote access, frontend proxy…

---

# But…
##
## Contemp ops is a convolute of huge complexity
- systemd, docker, (-compose), (-swarm), kubernetes, cloud services …
## Much solves no real problem (most) real shops really have
## At least on JVM!
## Maybe there is simpler way to do this?

---

# Basically

![](./periscope.png)

---

# Goals
## Run JVM-based web service
## Desiderata: autostart, restart, log, simplicity
# Non-Goals
## Have one thing that fits every tech/org
## Google scale, containerization, devops, …
All of these things can make sense. But not necessarily for all the many, many people doing them out of hype-following (or fear of being left behind)!

---

[https://www.infoq.com/presentations/Simple-Made-Easy](https://www.infoq.com/presentations/Simple-Made-Easy)
# ![](./simple-easy.png)
(Simple not only <> easy, also <> less work _per se_! Mario’s 0deps app: 5581c. Reimplemented w/ Spring Boot: 1740c. *__But__*: ~ 16.99 / 17 MiB smaller!)

---

# Show, Then Tell
##
## (Demo of deployment using the tech being presented)

---

# Tech
### FreeBSD 11.0
### runit
### OpenJDK 8
### PostgreSQL
### nginx
## NB: You'd Run JRE/\*SQL/nginx Anyway
#### I'm just talking about *how* to run it

---

# Remotely Manageable in 7 Commands
##
## Download image @ [official download archives](https://download.freebsd.org/ftp/releases/VM-IMAGES/11.0-RELEASE/amd64/Latest/)
## **For real machines, just get a boot stick/CD and bare metal it**
## Run in virtualbox
### I recommend two network interfaces, host only and NAT
Allows both Internet connection and host connection, unlike bridged no dep on host connectivity (also better protected).
## when booted, run:

---

### (deep breath)
```sh
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
fdesc   /dev/fd     fdescfs     rw  0   0
proc    /proc       procfs      rw  0   0
EOF
```
7 commands! (not the _shortest_, but just count ’em!) – I also put them in the repo. :)

---

# That’s Basic, But Functional
## Time to reboot!
## Just add SSH pubkey for passwordless access!

```sh
rsync --rsync-path "mkdir -p .ssh && rsync" .ssh/id_rsa.pub \
  username@vm:.ssh/authorized_keys
```

---

# This Needs to be (Somewhat) Automated!
### Everything needs to be automated!
## Script’s in this repo under `support-iso-contents`.
### Pro tip: add your SSH pubkey there – another skipped password prompt!
### Mac: `sh make-cd-image.sh`
### Others: `¯\_(ツ)_/¯` – GLHF!
### Use the ISO as a virtual CD in VirtualBox
* Boot, then `mkdir /blah && mount -t cd9660 /dev/cd0r /blah`

---

# Configure Services
##
## runit comes into active play – a _process supervisor_
## Very simple software: makes sure processes are running
## Needs some features from supervised software
### Mostly same as Docker, though: Foreground & stdout log

---

# runit Service
##
## Service consists of a directory
### With at least a single executable file, `run`
### Executed by runit, restarted if it dies

---

# runit logging
##
## Service subdirectory `log` which also has a `run`
### `stdout` of the main service is sent to `log` process
### `stderr` should only get startup errors or other fatalities – not covered
#### `runsvdir` has a little goodie there, which I’ll cover later, with`runsvdir`

---

# Example Service

`postgres/run`:

```sh
#!/bin/sh
exec chpst -u postgres -U postgres '/usr/local/bin/postgres' -D "$DATA_DIR"
```

`postgres/log/run`:

```sh
#!/bin/sh
exec '/usr/local/bin/svlogd' -t .
```

---

# runit Services Directory
##
## A directory with the services to run
### Services can be links to dirs
* Often useful pattern: one dir with all the service scripts …
* … and one (the one that’s actually supervised) with links to the active ones.
## But what does that supervising?
* `runsvdir /active-services-directory ......`
* $n$ dots at the end will be used to show last $n$ characters of services’ stderrors
* don’t send secrets there - visible in `ps(1)` output!
* that’s right - runsvdir writes urgent maintenance messages right into `argv` :D

---

# Service Management
##
## creating new service dir starts at once
#### `sv t` kills (with kindness – and runsv restarts immediately)
#### `sv d` downs (until reboot)
#### `sv u` ups (removes flag, runsv restarts)
#### `sv h` sends hangup signal (most services reread conf)
#### `sv s` show status (most services reread conf)
## (just deleting the service dir is `d`, but _sustainable_)

---

# Services Configuration (e.g.! That’s just how I do!)
### Set locations of rc file & base dir for other stuff in env of runsvdir

`env -i RC_CONF=/path/to/rc.config BASE_DIR=/path/to/basedir runsvdir /service …`

### Set config values in `/path/to/rc.config`:

```
redis_ip=10.0.5.3
postgres_host=127.0.0.1
postgres_db=bla_private
```

### Use ’em in `someservice/run`:
```
#!/bin/sh
. "$RC_CONF"
exec chpst -u blauser java -jar /…/bla.jar --spring.redis.host="$redis_ip" \
  --spring.datasource.url="jdbc:postgresql://$postgres_host/$postgres_db"
```

---

# Development…
##
## One reason for Docker / vagrant: same env in dev & prod
### a) Don't overestimate that
### b) `brew install runit`
* also allows multiple envs - just have multiple rc files & services dirs
* but this is _really_ fast, native and resource-sparing
---

# But Really…

Shell 1:
```sh
./gradlew bootRun --debug-jvm
```
Shell 2:
```sh
postgres -D data-dir
```
[MAYBE!] Shell 3:
```sh
devd -w project/statics-dir http://localhost:8080
```

✅

---

# Production
## You will need some extra work
* creating service users
* isolating permissions
* assigning ports
* modifying (some) service scripts
* managing storage
* …
## You _will_ need some extra work _whatever_ you run!
* All I can say is: I can recommend a great freelance sysadmin
* Don’t let devops hype trick you into believing you can ops just ’cause you can dev

---

# Benefits
## It’s simple
## No incredible journeys
## It’s comfy once you’ve adjusted your seat
The people who build operating systems didn’t just sit around awaiting what 2013 might bring – there’s *lots* of great stuff, if one’s willing to look around!
# Drawbacks
## It might not be easy …yet
*lots* of great stuff means reading *lots* of man pages

---

# Conclusion
## Make your environment easy for you (by learning!)
## Research options for your team’s specific needs
## End up with something _as simple and automated as possible_
### …but _no simpler_!

---

# Hi!
##
## I’m Bernd Haug [\<haug@berndhaug.net\>](mailto:haug@berndhaug.net)
I’ve been doing ops and development for ~20y.
##
## Get in touch!
##
### Working at [xaidat.com](http://www.xaidat.com), trying to make things simpler for customers
(and sometimes easier)
