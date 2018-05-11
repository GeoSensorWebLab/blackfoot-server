# Server Configuration Document

This document covers the setup of a server for the services on the Arctic Sensor Web expansion project.

## Services

The instance has the following services:

* PostgreSQL 10, for GOST database
* GOST, for OGC SensorThings API
* Nginx, for proxy to GOST and front-end
* Arctic Sensor Web Community Front-end UI

## Instance Setup

The server is provisioned on Cybera's Rapid Access Cloud, which runs OpenStack.

```
Server Name:        blackfoot
Flavor:             m1.small
Boot Source:        Ubuntu 18.04 Image
VCPUs:              2
Root Disk:          20 GB
Ephemeral Disk:     0
Total Disk:         20 GB
RAM:                2048 MB
```

After the initial instance is created, login and update the packages using `apt`. Then use OpenStack to create an instance snapshot image as a backup.

```sh
$ sudo apt update
$ sudo apt upgrade -y
$ sudo apt dist-upgrade
$ sudo apt autoremove
$ sudo reboot
```

An image snapshot can be made from the Rapid Access Cloud dashboard.

### Installing PostgreSQL

Using the PostgreSQL Apt repository.

```sh
$ echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
$ wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
$ sudo apt update
$ sudo apt install postgresql-10 postgresql-client-10 postgresql-10-postgis-2.4 postgresql-10-postgis-2.4-scripts postgis
$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
10  main    5432 online postgres /var/lib/postgresql/10/main /var/log/postgresql/postgresql-10-main.log
```

PostgreSQL should now be running on port 5432 and bound to localhost, and have a socket at `/var/run/postgresql/10-main.pid`.


