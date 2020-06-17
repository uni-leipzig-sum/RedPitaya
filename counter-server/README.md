# FAST COUNTER SERVER

## Contents

| paths                        | contents               |
|------------------------------|------------------------|
| `rp-counter-server/doc`      | Protocol documentation |
| `rp-counter-server/src`      | Source code            |
| `rp-counter-server/Makefile` | Main build file        |


## How to build Red Pitaya `rp-counter-server`
Before proceeding follow the [instructions](http://wiki.redpitaya.com/index.php?title=Red_Pitaya_OS) on how to set up working environment.
Then proceed by simply running the following command.
```bash
make clean all
``` 
Note: The easiest way to build `rp-counter-server` is on a running redpitaya board.
Login as root on the live redpitaya and copy the source code of `rp-counter-server`, e.g.
```bash
scp -r /path/to/rp-counter-server root@rp-host:/root/
```
Then login using ssh and build `rp-counter-server`
```bash
ssh root@rp-host
cd /root/rp-counter-server
make clean all
mount -o remount,rw /dev/mmcblk0p1 /opt/redpitaya
make install
mount -o remount,ro /dev/mmcblk0p1 /opt/redpitaya
```

This will compile `rp-counter-server` and copy the resulting binary to /opt/

## Starting Red Pitaya counter server

Before starting the counter service, make sure Nginx, Wyliodrin and SCPI services are not running.
Running them at the same time will cause conflicts, since they access the same hardware.

```bash
systemctl stop redpitaya_nginx
systemctl stop redpitaya_wyliodrin
systemctl stop redpitaya_scpi
```
Now we can try and start Red Pitaya counter server.
```bash
systemctl start redpitaya_counter
```

## Starting Red Pitaya counter server at boot time

The next commands will enable running the counter service at boot time and disable Nginx, Wyliodrin and SCPI services.
```bash
systemctl disable redpitaya_nginx
systemctl disable redpitaya_wyliodrin
systemctl disable redpitaya_scpi
systemctl enable redpitaya_counter
```
