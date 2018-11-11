# docker_logs
A short script written in Crystal lang that will incrementally upload all of your docker logs to a Postgres database

# To build on Ubuntu 18

* [Make sure you have Crystal 0.27 installed](https://crystal-lang.org/docs/installation/on_debian_and_ubuntu.html)
* Make sure [logtail2](https://packages.ubuntu.com/cosmic/admin/logtail) is installed - on Ubuntu `apt get install logtail2`
* Clone the repo: `git clone https://github.com/weirdbricks/docker_logs.git`
* Edit the `settings` file to point to your Postgres database
* Get shards (Crystal lang dependencies): `shards install`
* Build: `crystal build --static --release docker_logs.cr`
* Run: `./docker_logs`

Sample run:

```
./docker_logs 
[ INFO ] - Check if the "docker" command exists...
[  OK  ] - the "docker" command has been found
[ INFO ] - Check if the "logtail2" command exists...
[  OK  ] - the "logtail2" command has been found
[ INFO ] - Check if we can get the hostname...
[  OK  ] - I got the hostname: "lampros-HP-Notebook"
[ INFO ] - Check if docker is running...
[  OK  ] - the docker service is running
[ INFO ] - Checking if we got the docker root directory...
[  OK  ] - I got the docker root directory: "/var/lib/docker"
[ INFO ] - Get list of containers...
[  OK  ] - Got 4 containers.
[ INFO ] - Check that you can connect to postgres...
[  OK  ] - Successfull connection to Postgres
[ INFO ] - Getting the list of tables in the "$PG_DATABASE" database...
[ INFO ] - 4 tables were found - these are:
[ INFO ] - lampros_hp_notebook_lampros_postgres
[ INFO ] - lampros_hp_notebook_metabase
[ INFO ] - lampros_hp_notebook_dependency_test
[ INFO ] - lampros_hp_notebook_headless
[ INFO ] - Getting the container logs...
[  OK  ] - The table "lampros_hp_notebook_lampros_postgres" already exists
[ INFO ] - Found the file "/var/lib/docker/containers/bab263ac495fe664e1329f5201ace3d53d71b4b1896bf6f0170d0c3bc80c791e/bab263ac495fe664e1329f5201ace3d53d71b4b1896bf6f0170d0c3bc80c791e-json.log"
[  OK  ] - No new lines for container "lampros_postgres"
[  OK  ] - The table "lampros_hp_notebook_metabase" already exists
[ INFO ] - Found the file "/var/lib/docker/containers/bdec2e0360433e2143192d3ae34fad2cd6f9de19545ad6b7d39bf0bab3ab216b/bdec2e0360433e2143192d3ae34fad2cd6f9de19545ad6b7d39bf0bab3ab216b-json.log"
[  OK  ] - 14011 new lines for container "metabase"
Processing line 1000 of 14011 (7.1%) - Seconds: 2.02
Processing line 2000 of 14011 (14.3%) - Seconds: 2.06
Processing line 3000 of 14011 (21.4%) - Seconds: 2.11
Processing line 4000 of 14011 (28.5%) - Seconds: 2.09
Processing line 5000 of 14011 (35.7%) - Seconds: 2.18
Processing line 6000 of 14011 (42.8%) - Seconds: 2.14
Processing line 7000 of 14011 (50.0%) - Seconds: 2.16
Processing line 8000 of 14011 (57.1%) - Seconds: 2.16
Processing line 9000 of 14011 (64.2%) - Seconds: 2.1
Processing line 10000 of 14011 (71.4%) - Seconds: 2.08
Processing line 11000 of 14011 (78.5%) - Seconds: 2.21
Processing line 12000 of 14011 (85.6%) - Seconds: 2.16
Processing line 13000 of 14011 (92.8%) - Seconds: 2.19
Processing line 14000 of 14011 (99.9%) - Seconds: 2.13
[  OK  ] - The table "lampros_hp_notebook_dependency_test" already exists
[ INFO ] - Found the file "/var/lib/docker/containers/dc88fa0d2688b294147196769ae667746900b7e7a98c538ee8bc474e0dd74dc5/dc88fa0d2688b294147196769ae667746900b7e7a98c538ee8bc474e0dd74dc5-json.log"
[  OK  ] - No new lines for container "dependency-test"
[  OK  ] - The table "lampros_hp_notebook_headless" already exists
[ INFO ] - Found the file "/var/lib/docker/containers/5179d9a4750dc66dc861cee234dfeccf9e45f7652c3ad1e74af4f70157269364/5179d9a4750dc66dc861cee234dfeccf9e45f7652c3ad1e74af4f70157269364-json.log"
[  OK  ] - No new lines for container "headless"
```
