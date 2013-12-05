assert    = require 'assert'
should    = require 'should'
mocks     = require 'mocks'
iniparser = require 'iniparser'
sinon     = require 'sinon'
Q         = require 'q'
fs        = require 'fs'
pg        = require 'pg'
PgBouncer = require '../src/index'

describe 'PgBouncer', ->
  before ->
    Q.longStackSupport = true

  describe 'constructor', ->
    it 'should set configFile from the argument', ->
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.should.have.property 'configFile'
      pgb.configFile.should.eql '/etc/pgbouncer.ini'

    it 'should not do anything if there is no argument', ->
      pgb = new PgBouncer
      pgb.should.not.have.property 'configFile'

    it 'should not do anything if the argument does not have configFile entry', ->
      pgb = new PgBouncer
        other_entry: 'value'
      pgb.should.not.have.property 'configFile'

  describe 'readConfig', ->
    beforeEach ->
      sinon.stub(iniparser, 'parse')
    
    afterEach ->
      iniparser.parse.restore()

    it 'should read config file and generate pgb connection string if config has valid pgbouncer entry', (done) ->
      iniparser.parse.callsArgWith(1, null, 
        databases:
          name: 'databases array'
        pgbouncer:  
          listen_port: 5434
          listen_addr: '127.0.0.1'
          auth_type: 'any'
      )
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.readConfig().then ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        pgb.should.have.property 'config'
        pgb.config.should.not.have.property 'databases'
        pgb.config.should.have.property 'listen_port'
        pgb.config.listen_port.should.eql 5434
        pgb.config.should.have.property 'listen_addr'
        pgb.config.listen_addr.should.eql '127.0.0.1'    
        pgb.config.should.have.property 'auth_type'
        pgb.config.auth_type.should.eql 'any'
        pgb.should.have.property 'configFile'
        pgb.configFile.should.eql '/etc/pgbouncer.ini'
        pgb.should.have.property 'pgbConnectionString'
        pgb.pgbConnectionString.should.eql 'postgres://:5434/pgbouncer'
        done()
      .done()  

    it 'should read config file and generate pgb connection string with default port if config does not have listen_port', (done) ->
      iniparser.parse.callsArgWith(1, null,
        some_config:
          name1: 'value1'
          name2: 'value2'
      )
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.readConfig().then ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        pgb.should.have.property 'config'
        pgb.config.should.be.empty
        pgb.should.have.property 'configFile'
        pgb.configFile.should.eql '/etc/pgbouncer.ini'
        pgb.should.have.property 'pgbConnectionString'
        pgb.pgbConnectionString.should.eql "postgres://:#{PgBouncer.default_port}/pgbouncer"
        done()
      .done()  

    it 'should reset config and pgbConnectionString if parser return error', (done) ->
      iniparser.parse.callsArgWith(1, new Error('parse error'), {})
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.config = 'previous config'
      pgb.pgbConnectionString = 'previous connection string'
      pgb.readConfig().catch (error) ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        assert pgb.config == null
        assert pgb.pgbConnectionString == null
        error.should.not.empty
        done()
      .done()
        

    it 'should reset config and pgbConnectionString if configFile property is empty', (done) ->
      pgb = new PgBouncer
      pgb.config = 'previous config'
      pgb.pgbConnectionString = 'previous connection string'
      pgb.readConfig().catch (error) ->
        sinon.assert.notCalled iniparser.parse
        assert pgb.config == null
        assert pgb.pgbConnectionString == null
        error.should.not.empty
        done()
      .done() 

  describe 'writeConfig', ->    
    beforeEach ->
      sinon.stub(fs, 'writeFile')
    afterEach ->
      fs.writeFile.restore()  

    it 'should write to config file with values from config and databases properties', (done) ->
      fs.writeFile.callsArgWith(2, null) 
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.writeConfig(
        listen_addr: '127.0.0.1'
        listen_port: 5434
        auth_type: 'any'  
      ,
        {
          'wift_racing': 'postgresql://dbserver:5432/wift_racing'
          'wift_sports': 'postgresql://postgres@:5433/wift_sports'
        }
      ).then ->  
        sinon.assert.calledOnce fs.writeFile
        fs.writeFile.args[0][0].should.eql '/etc/pgbouncer.ini'
        config = iniparser.parseString fs.writeFile.args[0][1]
        config.should.have.property 'databases'
        config.databases.should.have.property 'wift_racing'
        wift_racing_config = iniparser.parseString config.databases['wift_racing'].split(/\s+/).join('\n')
        wift_racing_config.should.have.property 'host', 'dbserver'
        wift_racing_config.should.have.property 'port', '5432'
        wift_racing_config.should.have.property 'dbname', 'wift_racing'
        wift_racing_config.should.not.have.property 'user'
        config.databases.should.have.property('wift_sports')
        wift_sports_config = iniparser.parseString config.databases['wift_sports'].split(/\s+/).join('\n')
        wift_sports_config.should.not.have.property 'host'
        wift_sports_config.should.have.property 'port', '5433'
        wift_sports_config.should.have.property 'dbname', 'wift_sports'
        wift_sports_config.should.have.property 'user', 'postgres'
        config.should.have.property('pgbouncer')
        config.pgbouncer.listen_port.should.eql '5434'
        config.pgbouncer.listen_addr.should.eql '127.0.0.1'
        config.pgbouncer.auth_type.should.eql 'any'
        done()
      .done()  

    it 'should return error if write to config file returns error', (done) ->
      fs.writeFile.callsArgWith(2, new Error('write error')) 
      pgb = new PgBouncer
        configFile: '/etc/pgbouncer.ini'
      pgb.writeConfig({}, []).catch (error) ->
        error.should.not.be.empty
        done()
      .done()  

    it 'should return error if configFile property is empty', (done) ->
      pgb = new PgBouncer
      pgb.writeConfig({}, []).catch (error) ->
        error.should.not.be.empty
        done()
      .done()  

  describe 'reload', ->    
    it 'should read config and then write the new config and reload pgbouncer', (done) ->
      pgb = new PgBouncer
      readDefer = Q.defer()
      writeDefer = Q.defer()
      executeDefer = Q.defer()
      sinon.stub(pgb, 'readConfig').returns(readDefer.promise)
      sinon.stub(pgb, 'writeConfig').returns(writeDefer.promise)
      sinon.stub(pgb, 'execute').returns(executeDefer.promise)
      databases = {name: 'databases array'}
      pgb.reload(databases).then ->
        sinon.assert.calledOnce pgb.readConfig
        sinon.assert.calledOnce pgb.writeConfig
        sinon.assert.alwaysCalledWith pgb.writeConfig, pgb.config, databases
        sinon.assert.calledOnce pgb.execute
        sinon.assert.alwaysCalledWith pgb.execute, 'reload'
        done()
      .done()  
      readDefer.resolve()  
      writeDefer.resolve()  
      executeDefer.resolve()  

    it 'should stop and return error if read config returns error', (done) ->
      pgb = new PgBouncer
      readDefer = Q.defer()
      sinon.stub(pgb, 'readConfig').returns(readDefer.promise)
      sinon.stub(pgb, 'writeConfig')
      sinon.stub(pgb, 'execute')
      pgb.reload().catch (error) ->
        error.should.not.be.empty
        sinon.assert.calledOnce pgb.readConfig
        sinon.assert.notCalled pgb.writeConfig
        sinon.assert.notCalled pgb.execute
        done()
      .done()  
      readDefer.reject(new Error('read error'))  

    it 'should stop and return error if write config returns error', (done) ->
      pgb = new PgBouncer
      readDefer = Q.defer()
      writeDefer = Q.defer()
      sinon.stub(pgb, 'readConfig').returns(readDefer.promise)
      sinon.stub(pgb, 'writeConfig').returns(writeDefer.promise)
      sinon.stub(pgb, 'execute')
      databases = {name: 'databases array'}
      pgb.reload(databases).catch (error) ->
        error.should.not.be.empty
        sinon.assert.calledOnce pgb.readConfig
        sinon.assert.calledOnce pgb.writeConfig
        sinon.assert.alwaysCalledWith pgb.writeConfig, pgb.config, databases
        sinon.assert.notCalled pgb.execute
        done()
      .done()  
      readDefer.resolve()  
      writeDefer.reject(new Error('write error'))  

    it 'should return error if pgbouncer reload returns error', (done) ->
      pgb = new PgBouncer
      readDefer = Q.defer()
      writeDefer = Q.defer()
      executeDefer = Q.defer()
      sinon.stub(pgb, 'readConfig').returns(readDefer.promise)
      sinon.stub(pgb, 'writeConfig').returns(writeDefer.promise)
      sinon.stub(pgb, 'execute').returns(executeDefer.promise)
      databases = {name: 'databases array'}
      pgb.reload(databases).catch (error) ->
        sinon.assert.calledOnce pgb.readConfig
        sinon.assert.calledOnce pgb.writeConfig
        sinon.assert.alwaysCalledWith pgb.writeConfig, pgb.config, databases
        sinon.assert.calledOnce pgb.execute
        sinon.assert.alwaysCalledWith pgb.execute, 'reload'
        done()
      .done()  
      readDefer.resolve()  
      writeDefer.resolve()  
      executeDefer.reject(new Error('pgbouncer error'))  

  describe 'execute', ->        
    pg_connect = null
    pg_query = null    
    pg_done = null
    pgbConnectionString = 'postgres://localhost:5433/pgbouncer'

    beforeEach ->
      pg_done = sinon.spy()
      pg_query = sinon.stub()
      sinon.stub(pg, 'connect')   

    afterEach ->
      pg.connect.restore()  

    it 'should send the command to pgbouncer and return results', (done) ->
      query_results = {name: 'query_results'}
      pg_query.callsArgWith(1, null, {rows: query_results})
      pg.connect.callsArgWith(1, null, {query: pg_query}, pg_done)      
      pgb = new PgBouncer
      pgb.pgbConnectionString = pgbConnectionString
      pgb.execute('some command').then (results) ->
        results.should.eql query_results
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        sinon.assert.alwaysCalledWith pg_query, 'some command;'
        sinon.assert.calledOnce pg_done
        done()
      .done()  

    it 'should returns error when connecting to pgbouncer', (done) ->
      pg.connect.callsArgWith(1, new Error('connect error'), null, pg_done)      
      pgb = new PgBouncer
      pgb.pgbConnectionString = pgbConnectionString
      pgb.execute('some command').catch (error) ->
        error.should.not.be.empty
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        sinon.assert.alwaysCalledWith pg_done, error
        done()
      .done()  

    it 'should returns error when issue command to pgbouncer', (done) ->
      pg_query.callsArgWith(1, new Error('query error'), null)
      pg.connect.callsArgWith(1, null, {query: pg_query}, pg_done)      
      pgb = new PgBouncer
      pgb.pgbConnectionString = pgbConnectionString
      pgb.execute('some command').catch (error) ->
        error.should.not.be.empty
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        sinon.assert.alwaysCalledWith pg_query, 'some command;'
        sinon.assert.alwaysCalledWith pg_done, error
        done()
      .done()       

    it 'should returns error when pgbConnectionString property is empty', (done) ->  
      pgb = new PgBouncer
      pgb.execute('some command').catch (error) ->
        error.should.not.be.empty
        sinon.assert.notCalled pg.connect
        done()
      .done()

  describe 'status', ->        
    executeDefer = null
    pgb = null

    beforeEach ->
      pgb = new PgBouncer
      executeDefer = Q.defer()
      sinon.stub(pgb, 'execute').returns(executeDefer.promise)   

    afterEach ->
      pgb.execute.restore()  

    it 'should execute show databases command and process the results', (done) ->      
      pgb.status().then (results) ->
        results.should.eql [
          {name: 'wift_racing'},
          {name: 'wift_sports'}
        ]
        sinon.assert.alwaysCalledWith pgb.execute, 'show databases'
        done()
      .done()     
      executeDefer.resolve [
          {name: 'pgbouncer'},
          {name: 'wift_racing'},
          {name: 'wift_sports'}
        ]

    it 'should returns error when execute return error', (done) ->  
      pgb.status().catch (error) ->
        error.should.not.be.empty
        sinon.assert.alwaysCalledWith pgb.execute, 'show databases'
        done()
      .done()
      executeDefer.reject('execute error')

  describe 'toLibPqConnectionString', (database) ->
    it 'should covert full connection uri', ->
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString('postgresql://admin:1234@localhost:5433/mydb').split(/\s+/).join('\n'))
      result.should.have.property 'host', 'localhost'
      result.should.have.property 'port', '5433'
      result.should.have.property 'dbname', 'mydb'
      result.should.have.property 'user', 'admin'
      result.should.have.property 'password', '1234'

    it 'should covert minimal connection uri', ->  
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString('postgresql://').split(/\s+/).join('\n'))
      result.should.eql {}

    it 'should covert connection uri with host only', ->    
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString('postgresql://localhost').split(/\s+/).join('\n'))
      result.should.have.property 'host', 'localhost'
      result.should.not.have.property 'port'
      result.should.not.have.property 'dbname'
      result.should.not.have.property 'user'
      result.should.not.have.property 'password'

    it 'should covert connection uri with host and dbname only', ->    
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString('postgresql://localhost/mydb').split(/\s+/).join('\n'))
      result.should.have.property 'host', 'localhost'
      result.should.not.have.property 'port'
      result.should.have.property 'dbname', 'mydb'
      result.should.not.have.property 'user'
      result.should.not.have.property 'password'  

    it 'should covert connection uri with host and user only', ->    
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString('postgresql://user@localhost').split(/\s+/).join('\n'))
      result.should.have.property 'host', 'localhost'
      result.should.not.have.property 'port'
      result.should.not.have.property 'dbname'
      result.should.have.property 'user', 'user'
      result.should.not.have.property 'password'  

    it 'should covert hash object', ->    
      result = iniparser.parseString(PgBouncer.toLibPqConnectionString({user: 'user', host: 'localhost'}).split(/\s+/).join('\n'))
      result.should.have.property 'host', 'localhost'
      result.should.not.have.property 'port'
      result.should.not.have.property 'dbname'
      result.should.have.property 'user', 'user'  
      result.should.not.have.property 'password'  


  