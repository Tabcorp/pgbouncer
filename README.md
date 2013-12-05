pgbouncer
=========

Node wrapper for pgbouncer

## Basic usage

```coffee
PgBouncer = require 'PgBouncer'

#create a new PgBouncer instance, point to the location of the pgbouncer.ini file
pgb = new PgBouncer
  configFile: '/etc/pgbouncer.ini'

#reload the databases
pgb.reload
  'wift_racing': 'postgresql://dbserver:5432/wift_racing'
  'wift_sports': 'postgresql://postgres@:5433/wift_sports'

#query and print out the status of current databases
pgb.status().then (databases) ->
  console.dir database for database in databases  
```

## Extra command

PgBouncer cand execte pgbouncer command as

```coffee
pgb.execute 'show users'
```
Please check [pgbouncer documentation](http://pgbouncer.projects.pgfoundry.org/doc/usage.html) for a list of commands

## Asynchronous

All PgBouncer's method are made asynchronous with [Q](https://github.com/kriskowal/q)


