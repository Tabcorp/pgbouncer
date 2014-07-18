# pgbouncer

Node.js wrapper for [pgbouncer](https://wiki.postgresql.org/wiki/PgBouncer). All methods are asynchronous, using [Q](https://github.com/kriskowal/q) promises.

[![Build Status](https://travis-ci.org/TabDigital/pgbouncer.svg?branch=master)](https://travis-ci.org/TabDigital/pgbouncer)

[![Dependency Status](https://david-dm.org/TabDigital/pgbouncer.png?theme=shields.io)](https://david-dm.org/TabDigital/pgbouncer) 
[![devDependency Status](https://david-dm.org/TabDigital/pgbouncer/dev-status.png?theme=shields.io)](https://david-dm.org/TabDigital/pgbouncer#info=devDependencies)

[![NPM](https://nodei.co/npm/pgbouncer.svg?downloads=true)](https://nodei.co/npm/pgbouncer/)


## Basic usage

```coffee
PgBouncer = require 'pgbouncer'

# create a new PgBouncer instance
# pointing to the location of the pgbouncer.ini file
pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
```

## Reading the INI file

```coffee
pgb.read()
   .then (config) ->

  # [pgbouncer] section

  # config.pgbouncer.listen_port:  5434
  # config.pgbouncer.listen_addr:  '127.0.0.1'
  # config.pgbouncer.auth_type:    'any'  

  # [databases] section

  # config.databases.mydb1:  'postgresql://localhost/db1'
  # config.databases.mydb2:  'postgresql://localhost/db2'
```

## Updating the INI file

```coffee
config =
  pgbouncer:
    listen_port:  5434
    listen_addr:  '127.0.0.1'
    auth_type:    'any'  
  databases:
    mydb1:  'postgresql://localhost/db1'
    mydb2:  'postgresql://localhost/db2'

pgb.write(config)
   .then -> console.log('done')
```

## Updating the database list only

If you don't need to change the `[pgbouncer]` section, you can also update the `[databases]` list only.

```coffee
databases:
  mydb1:  'postgresql://localhost/db1'
  mydb2:  'postgresql://localhost/db2'

pgb.writeDatabases(databases)
   .then -> console.log('done')
```

## Reloading the config

After updating the INI file, you need to manually trigger a `reload` command to update the live routing.

```coffee
pbg.reload()
   .then -> console.log('done')
```

## Getting the current routing status

You can get the current routing status from the *pgbouncer* `show databases` command:

```coffee
pbg.status()
   .then (databases) ->

   # databases[0].name
   # databases[0].host
   # databases[0].port
   # databases[0].database
   # databases[0].force_user
   # databases[0].pool_size
```


## Executing other commands

You can also execute any valid *pgbouncer* command:

```coffee
pgb.execute('show users')
   .then (results) -> console.log(results.rows)
```

Please check [pgbouncer documentation](http://pgbouncer.projects.pgfoundry.org/doc/usage.html) for a list of commands.
