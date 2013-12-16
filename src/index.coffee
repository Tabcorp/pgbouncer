jsm       = require 'js-match'
iniparser = require 'iniparser'
Q         = require 'q'
fs        = require 'fs'
pg        = require 'pg'
_         = require 'lodash'

class PgBouncer 
  constructor: (config) ->
    errors = jsm.validate config || {},
      configFile: 
        match: 'string'
    if errors.length == 0
      @configFile = config.configFile

  readDatabasesConfig: ->

  readConfig: ->
    defer = Q.defer()
    @config = null
    @databases = null
    @pgbConnectionString = null  
    if @configFile
      iniparser.parse @configFile, (error, data) =>        
        if error
          console.warn("Cannot read #{@configFile}:\n #{error}")
          defer.reject(error)
        else   
          @config = data.pgbouncer ? {}
          if data.databases?
            @databases = {}
            @databases[key] = PgBouncer.toConnectionURI(db) for key,db of data.databases
          @pgbConnectionString = "postgresql://:#{@config.listen_port ? PgBouncer.default_port}/pgbouncer"
          defer.resolve(@)        
    else
      defer.reject(new Error('No config file'))
    defer.promise  

  writeConfig: (config, databases) ->
    defer = Q.defer()
    if @configFile
      databaseContent = for name,database of databases
        "#{name} = #{PgBouncer.toLibPqConnectionString(database)}"
      configContent = for configName, configValue of config
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

  reload: (databases) ->
    @execute('reload')

  run: (command)->
    if @pgbConnectionString
      Q.nfcall(pg.connect, @pgbConnectionString).then ([client, done]) ->
        Q.ninvoke(client, 'query', command).finally -> done()  
    else
      Q.reject(new Error('Connection string is empty'))

  execute: (command)->
    if @pgbConnectionString
      @run(command)
    else
      @readConfig().then => @run(command)

  status: ->
    @execute('show databases').then (results) ->
      _.reject results.rows, (database) -> database.name == 'pgbouncer'

PgBouncer.default_port = 6432

PgBouncer.toLibPqConnectionString = (database) ->
  db = {}
  if _.isString(database)
    m = database.trim().match(/^.+\:\/\/(?:([a-z0-9_\-.]+)(?::([a-z0-9_\-.]+))?@)?([a-z0-9_\-.]+)?(?::(\d+))?(?:\/([a-z0-9_\-.]+))?/i)
    if m
      db.user = m[1]
      db.password = m[2]
      db.host = m[3]
      db.port = m[4]
      db.dbname = m[5]
  else if _.isObject(database)
    db = database    
  (for key,value of db
    "#{key}=#{value}" if value
  ).join(' ')
     
PgBouncer.toConnectionURI = (properties) ->     
  if _.isString(properties) 
    PgBouncer.toConnectionURI(iniparser.parseString(properties.split(/\s+/).join('\n')))
  else if _.isObject(properties) 
    if properties.user? and properties.password?
      authentication = "#{properties.user}:#{properties.password}@" 
    else if properties.user?   
      authentication = "#{properties.user}@"
    else   
      authentication = ''
    if properties.port?
      port = ":#{properties.port}"  
    else
      port = ''  
    if properties.dbname?  
      dbname = "/#{properties.dbname}"
    else
      dbname = ''
    "postgresql://#{authentication}#{properties.host ? ''}#{port}#{dbname}" 
  else
    "postgresql://"  

module.exports = PgBouncer