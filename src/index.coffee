jsm       = require 'js-match'
iniparser = require 'iniparser'
Q         = require 'q'
fs        = require 'fs'
pg        = require 'pg'

class PgBouncer 
  constructor: (config) ->
    errors = jsm.validate config || {},
      configFile: 
        match: 'string'
    if errors.length == 0
      @configFile = config.configFile

  readConfig: ->
    defer = Q.defer()
    @config = null
    @pgbConnectionString = null  
    if @configFile
      iniparser.parse @configFile, (error, data) =>        
        if error
          console.warn("Cannot read #{@configFile}:\n #{error}")
          defer.reject(error)
        else   
          @config = data.pgbouncer || {}
          @pgbConnectionString = "postgres://#{@config.listen_addr ? 'localhost'}:#{@config.listen_port ? PgBouncer.default_port}/pgbouncer"
          defer.resolve(@)        
    else
      defer.reject('No config file')
    defer.promise  

  writeConfig: (config, databases) ->
    defer = Q.defer()
    if @configFile
      databaseContent = for db in databases
        "#{db.name} = #{if db.host then 'host=' + db.host else ''} port=#{db.port} dbname=#{db.database} #{if db.user then 'user=' + db.user else ''}"
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
      defer.reject('No config file')  
    defer.promise  


  reload: (databases) ->
    @readConfig()
    .then =>
      @writeConfig(@config, databases)
    .then => 
      @execute('reload')
  
  execute: (command)->
    defer = Q.defer()
    if @pgbConnectionString
      pg.connect @pgbConnectionString, (error, client, done) ->
        if (error)
          defer.reject(error)
          done(error)
        else
          client.query "#{command};", (error, results) ->  
            if (error)
              defer.reject(error)
              done(error)
            else 
              defer.resolve(results.rows) 
              done()
    else
      defer.reject('Connection string is empty')
    defer.promise  

  status: ->
    @execute('show databases')

PgBouncer.default_port = 6432
  

module.exports = PgBouncer