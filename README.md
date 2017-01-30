BaseBox Ubuntu
==============

This is a simple vagrant repo that allows for getting a very basic ubuntu web server up and running.

Before running `Vagrant up` make sure to create a `Vagrantfile` by copying `Vagrantfile.master` and configuring as necessary.
Also make sure to setup a `scripts/provision-secrets.sh` using `provision-secrets-example.sh` as a reference. Otherwise
the default database name, user, and password will be used.