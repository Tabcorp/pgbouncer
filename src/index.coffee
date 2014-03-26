iniparser = require 'iniparser'
Q         = require 'q'
fs        = require 'fs'
pg        = require 'pg'
_         = require 'lodash'
cnx       = require './connection-string'

class PgBouncer

  constructor: (config = {}) ->
    @configFile = config.configFile
    if typeof @configFile != 'string'
      throw new Error("Invalid configFile: #{@configFile}")

  # Read the current INI file
  read: ->
    defer = Q.defer()
    @pgbConnectionString = null
    if @configFile
      iniparser.parse @configFile, (error, data) =>
        if error
          console.warn("Cannot read #{@configFile}:\n #{error}")
          defer.reject(error)
        else
          config = data.pgbouncer ? {}
          if data.databases?
            databases = {}
            databases[key] = cnx.toURI(db) for key,db of data.databases
          @pgbConnectionString = "postgresql://:#{config.listen_port ? PgBouncer.default_port}/pgbouncer"
          defer.resolve
            pgbouncer: config
            databases: databases
    else
      defer.reject(new Error('No config file'))
    defer.promise

  # Update the INI file
  write: (contents) ->
    defer = Q.defer()
    if @configFile
      databaseContent = for name,database of contents.databases
        "#{name} = #{cnx.toLibPq(database)}"
      configContent = for configName, configValue of contents.pgbouncer
        "#{configName} = #{configValue}"
      configFileContent =
      """
      [databases]
      #{databaseContent.join('\n')}

      [pgbouncer]
      #{configContent.join('\n')}
      """
      fs.writeFile @configFile, configFileContent, (error) =>
        if (error)
          console.warn("Cannot write #{@configFile}:\n #{error}")
          defer.reject(error)
        else
          defer.resolve(@)
    else
      defer.reject(new Error('No config file'))
    defer.promise

  # Write new databases without changing the config
  writeDatabases: (newDatabases) ->
    @read()
    .then ({pgbouncer, databases}) => @write(pgbouncer: pgbouncer, databases: newDatabases)

  # Reload the routing from the config on disk
  reload: ->
    @execute('reload')

  # Get current routing status
  status: ->
    @execute('show databases').then (results) ->
      _.reject results.rows, (database) -> database.name == 'pgbouncer'

  # Execute any PGB command
  execute: (command) ->
    if @pgbConnectionString
      @run(command)
    else
      @read().then => @run(command)

  # Low level run that re-uses the current connection
  run: (command) ->
    if @pgbConnectionString
      Q.ninvoke(pg, 'connect', @pgbConnectionString).then ([client, done]) ->
        Q.ninvoke(client, 'query', command).finally -> done()
    else
      Q.reject(new Error('Connection string is empty'))

PgBouncer.default_port = 6432

module.exports = PgBouncer
