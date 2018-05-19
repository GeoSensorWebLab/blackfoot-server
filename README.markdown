# Server Configuration Document

This document covers the setup of a server for the services on the Arctic Sensor Web expansion project.

Arctic Sensor Web is a part of the [Arctic Connect][] platform of research services.

[Arctic Connect]: http://arcticconnect.org

## Services

The instance has the following services:

* [PostgreSQL][] 10, for GOST database
* [GOST][], for [OGC SensorThings API][OGC STA]
* [Nginx][], for proxy to GOST and front-end
* Arctic Sensor Web Community Front-end UI

[GOST]: https://github.com/gost/server
[Nginx]: http://nginx.org
[OGC STA]: http://docs.opengeospatial.org/is/15-078r6/15-078r6.html
[PostgreSQL]: https://www.postgresql.org

## Instance Setup

The server is provisioned on [Cybera's Rapid Access Cloud](https://www.cybera.ca/services/rapid-access-cloud/), which runs OpenStack.

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

## Installing GOST

We will download the v0.5 release.

```sh
$ wget https://github.com/gost/server/releases/download/0.5/gost_ubuntu_x64.zip
$ sudo apt install unzip
$ unzip gost_ubuntu_x64.zip -d gost
```

And download the database initialization scripts too:

```sh
$ cd ~/gost
$ git clone https://github.com/gost/gost-db.git
```

Now create a postgres role, database, and the GOST schema:

```sh
$ sudo -u postgres psql postgres
postgres=# create role "gost" with login;
postgres=# create database "gost" with owner "gost";
postgres=# \c gost
gost=# \i /home/ubuntu/gost/gost-db/gost_init_db.sql
gost=# alter schema "v1" owner to "gost";
gost=# grant all on database gost to gost;
gost=# grant all privileges on all tables in schema v1 to gost;
gost=# grant all privileges on all sequences in schema v1 to gost;
gost=# \q
```

And update Postgres to allow the default `ubuntu` user access to the GOST database.

```sh
$ echo "gost            ubuntu                  gost" | sudo tee -a /etc/postgresql/10/main/pg_ident.conf
$ echo "local gost gost peer map=gost" | sudo tee -a /etc/postgresql/10/main/pg_hba.conf
$ sudo sed -E -i 's/^(local +all +all +peer)$/local gost gost peer map=gost\n\1/' /etc/postgresql/10/main/pg_hba.conf
$ sudo service postgresql reload
$ psql -U gost gost -c '\dt+ v1.*'
```

That last command should list all the tables in the `v1` schema with no error.

Next update the GOST configuration with the contents of `contrib/gost/config.yaml`, and start up the server.

```sh
$ cd ~/gost/linux64
$ chmod +x gost
$ ./gost
```

In a new terminal or tmux window, use `curl` to verify the server is running:

```sh
$ curl localhost:8080/v1.0/Things
{
   "value": []
}
```

The response should be an empty collection of `Thing` entities.

Next we install a Systemd unit file to have GOST automatically start with the server. Copy the contents of `contrib/systemd/gost.service` to `/etc/systemd/system/gost.service` on the system, then update Systemd:

```sh
$ sudo systemctl daemon-reload
$ sudo systemctl enable gost
$ sudo systemctl start gost
$ sudo systemctl status gost
● gost.service - GOST (Go SensorThings) API service
   Loaded: loaded (/etc/systemd/system/gost.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2018-05-12 00:20:38 UTC; 4min 25s ago
 Main PID: 6943 (gost)
    Tasks: 7 (limit: 2362)
   CGroup: /system.slice/gost.service
           └─6943 /home/ubuntu/gost/linux64/gost -config /home/ubuntu/gost/linux64/config.yaml

May 12 00:20:38 blackfoot systemd[1]: Started GOST (Go SensorThings) API service.
May 12 00:20:38 blackfoot gost[6943]: 2018/05/12 00:20:38 Starting GOST....
May 12 00:20:38 blackfoot gost[6943]: 2018/05/12 00:20:38 Showing debug logs
May 12 00:20:38 blackfoot gost[6943]: 2018/05/12 00:20:38 Creating database connection, host: "/var/run/postgresql/", po
May 12 00:20:38 blackfoot gost[6943]: 2018/05/12 00:20:38 Connected to database
May 12 00:20:38 blackfoot gost[6943]: 2018/05/12 00:20:38 Started GOST HTTP Server on localhost:8080
```

## Installing Nginx

Nginx will act as a reverse-proxy to GOST, allowing only GET/HEAD/OPTIONS requests and blocking other HTTP requests from the internet. It will also serve the front-end UI HTML site.

```sh
$ sudo apt install nginx-full
$ curl -I localhost:80
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Sat, 12 May 2018 00:30:06 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Sat, 12 May 2018 00:29:02 GMT
Connection: keep-alive
ETag: "5af6354e-264"
Accept-Ranges: bytes
```

This shows that nginx is running. Next is setting up a virtual host for controlling access to GOST. Copy the contents of `contrib/nginx/gost.conf` to `/etc/nginx/sites-available/gost`. Then link the configuration to the enabled sites.

```sh
$ sudo ln -s /etc/nginx/sites-available/gost /etc/nginx/sites-enabled/gost
$ sudo systemctl reload nginx
$ curl localhost:6443/v1.0/Things
{
   "value": []
}
```

We are using port 6443 as an upstream server will have SSL enabled for this port. *This* server does not have to worry about SSL at all.

## Installing Backend Service

This service will ingest data from the data providers and insert it into GOST. First clone the repository to the server:

```sh
$ git clone <REPO URL>
```

Then install Ruby 2.3 or newer. Ubuntu 18.04 includes Ruby 2.5.

```sh
$ sudo apt install ruby ruby-dev
$ mkdir ~/.ruby
$ echo "export GEM_HOME=~/.ruby" >> ~/.bashrc
$ echo 'export PATH="$PATH:~/.ruby/bin"' >> ~/.bashrc
$ source ~/.bashrc
```

Install bundler and the gem pre-requisites:

```sh
$ cd ~/data-transloader
$ gem install bundler
$ sudo apt install build-essential patch zlib1g-dev liblzma-dev
$ bundle install
```

You should be able to get the help message for the tool now:

```sh
$ ruby transload --help
Usage: transload <get|put> <metadata|observations> <arguments>
--source SOURCE             Data source; allowed: 'environment_canada'
--station STATION           Station identifier
--cache CACHE               Path for filesystem storage cache
--date DATE                 ISO8601 date for 'put observations'. Also supports 'latest'
--help                      Print this help message
```

Next we will set up the station metadata for our stations.

```sh
$ mkdir ~/data
$ for station in YYQ WCA WAY YEV YZF XCM XFB XRB XZC MFX WUM; do
echo "Getting metadata for $station"
ruby transload get metadata --source environment_canada --station $station --cache ~/data
done
```

We are going to fool the transloader into going directly to the local nginx instance for uploads, instead of to the web and the upstream server that has HTTPs enabled. This allows us to access GOST for uploads, as the requests are coming from the same server.

```sh
$ echo "127.0.0.1 sensors.arcticconnect.org" | sudo tee -a /etc/hosts
```

And then convert and upload the metadata into GOST.

```sh
$ for station in YYQ WCA WAY YEV YZF XCM XFB XRB XZC MFX WUM; do
echo "Uploading metadata for $station"
ruby transload put metadata --source environment_canada --station $station --cache ~/data --destination http://localhost:8080/v1.0/
done
```

If you check GOST, you can see the uploaded items: [https://sensors.arcticconnect.org:6443/v1.0/Datastreams](https://sensors.arcticconnect.org:6443/v1.0/Datastreams).

Now we can download observations.

```sh
$ for station in YYQ WCA WAY YEV YZF XCM XFB XRB XZC MFX WUM; do
echo "Downloading observations for $station"
ruby transload get observations --source environment_canada --station $station --cache ~/data
done
```

And then upload the observations.

```sh
$ for station in YYQ WCA WAY YEV YZF XCM XFB XRB XZC MFX WUM; do
echo "Uploading observations for $station"
ruby transload put observations --source environment_canada --station $station --cache ~/data --date latest --destination http://localhost:8080/v1.0/
done
```

The observations can then be viewed online: [https://sensors.arcticconnect.org:6443/v1.0/Observations][Observations].

[Observations]: https://sensors.arcticconnect.org:6443/v1.0/Observations

### Scheduling the Transloader with Cron

As observations from Environment Canada are published every hour<sup>1</sup>, we will need to automatically download them every hour to get the latest results. Ideally we would download the observations immediately after they have been updated by Environment Canada, however the time that the observations are uploaded varies, as can be seen by the "Last Modified" times in the [observations directory listing][listing].

There are two main ways to get the observations while they are fresh. First is to use the Data Mart AMQP service to be automatically notified when an observation is published. This is more complicated to code and the Data Transloader does not support AMQP. The second option is to issue GET requests more frequently than the update interval, and use HTTP headers to avoid downloading data we already have. We will use the second option.

We will use cron to run a script every 20 minutes checking for new data. Supporting [conditional GET headers][Conditional] will require an update to the Data Transloader, so until then we will issue simple GET requests.

Start by creating a file with a list of the station ids. Observations will be downloaded from these stations only. As this will be read by a shell script, it will be formatted with one station id per line. See `contrib/auto-download/stations.txt` for a sample. Save this file to `~/auto-download`.

Next add the automatic download script `contrib/auto-download/auto-transload.sh` to the same directory, and make it executable:

```sh
$ cd ~/auto-download
$ chmod +x auto-transload.sh
```

Now we can edit the crontab to run the script automatically. Open the crontab editor, and if prompted choose your preferred command-line editor. (If you are unsure, then pick `nano` as it is easiest.)

```sh
$ crontab -e
```

At the end of the file, add a new line:

```
SHELL=/bin/bash
GEM_HOME="/home/ubuntu/.ruby"
GEM_PATH="/home/ubuntu/.ruby"
5,25,45 * * * * $HOME/auto-download/auto-transload.sh $HOME/auto-download/stations.txt
```

This runs the automatic download script every 5 minutes, 25 minutes, and 45 minutes past the hour, every hour.

This should now automatically run the script, and we can see the results in GOST on the [Observations page](https://sensors.arcticconnect.org:6443/v1.0/Observations).


[Conditional]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Conditional_requests
[listing]: http://dd.weather.gc.ca/observations/swob-ml/latest/

----

1. Some observations are published every minute, but only a handful of stations support this.

### Setting Up Log Rotation

The logs generated by the transloader will quickly consume quite a bit of disk space. I recommend keeping them around for debugging any potential issues. To keep them around without taking up too much space or being too large to read we will use the [logrotate][] tool to automatically segment the log files and compress them with gzip.

The file `contrib/logrotate.d/auto-transload` contains configuration to rotate the log files we set up in the previous step. Install this file to `/etc/logrotate.d/auto-transload`; you will need admin access to do this.

[logrotate]: https://linux.die.net/man/8/logrotate

## Installing Front-end UI

TODO

## License

This documentation is available under Creative Commons [Attribution-ShareAlike 4.0 International](http://creativecommons.org/licenses/by-sa/4.0/).
