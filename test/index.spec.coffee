assert    = require 'assert'
should    = require 'should'
mocks     = require 'mocks'
iniparser = require 'iniparser'
sinon     = require 'sinon'
Q         = require 'q'
fs        = require 'fs'
pg        = require 'pg'
PgBouncer = require '../src/index'
cnx       = require '../src/connection-string'

describe 'PgBouncer', ->

  before ->
    Q.longStackSupport = true

  describe 'constructor', ->

    it 'should set configFile from the argument', ->
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.should.have.property 'configFile'
      pgb.configFile.should.eql '/etc/pgbouncer.ini'

    it 'should throw an error if there is no configFile', ->
      (-> new PgBouncer()).should.throw /Invalid/
      (-> new PgBouncer(configFile: 3)).should.throw /Invalid/


  describe 'read', ->

    beforeEach ->
      sinon.stub(iniparser, 'parse')
      sinon.stub(cnx, 'toURI')

    afterEach ->
      iniparser.parse.restore()
      cnx.toURI.restore()

    it 'should read config file and parse pgbouncer and databases entry', (done) ->
      iniparser.parse.callsArgWith(1, null,
        databases:
          db1: 'database 1 properties'
          db2: 'database 2 properties'
        pgbouncer:
          listen_port: 5434
          listen_addr: '127.0.0.1'
          auth_type: 'any'
      )
      cnx.toURI.withArgs('database 1 properties').returns('database 1 connection string')
      cnx.toURI.withArgs('database 2 properties').returns('database 2 connection string')
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.read().then ({config, databases}) ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        config.should.have.property 'listen_port'
        config.listen_port.should.eql 5434
        config.should.have.property 'listen_addr'
        config.listen_addr.should.eql '127.0.0.1'
        config.should.have.property 'auth_type'
        config.auth_type.should.eql 'any'
        databases.should.property 'db1'
        databases.db1.should.eql 'database 1 connection string'
        databases.should.property 'db2'
        databases.db2.should.eql 'database 2 connection string'
        done()
      .done()

    it 'should read config file and generate pgb connection string if config has valid pgbouncer entry', (done) ->
      iniparser.parse.callsArgWith(1, null,
        pgbouncer:
          listen_port: 5434
          listen_addr: '127.0.0.1'
          auth_type: 'any'
      )
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.read().then ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        pgb.should.have.property 'pgbConnectionString'
        pgb.pgbConnectionString.should.eql 'postgresql://:5434/pgbouncer'
        done()
      .done()

    it 'should read config file and generate pgb connection string with default port if config does not have listen_port', (done) ->
      iniparser.parse.callsArgWith(1, null,
        some_config:
          name1: 'value1'
          name2: 'value2'
      )
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.read().then ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        pgb.should.have.property 'pgbConnectionString'
        pgb.pgbConnectionString.should.eql "postgresql://:#{PgBouncer.default_port}/pgbouncer"
        done()
      .done()

    it 'should reset pgbConnectionString if parser return error', (done) ->
      iniparser.parse.callsArgWith(1, new Error('parse error'), {})
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.pgbConnectionString = 'previous connection string'
      pgb.read().catch (error) ->
        sinon.assert.alwaysCalledWith iniparser.parse, '/etc/pgbouncer.ini'
        assert pgb.pgbConnectionString == null
        error.should.have.property 'message'
        done()
      .done()


  describe 'write', ->

    beforeEach ->
      sinon.stub(fs, 'writeFile')

    afterEach ->
      fs.writeFile.restore()

    it 'should write to config file with values from config and databases properties', (done) ->
      fs.writeFile.callsArgWith(2, null)
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.write(
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
      fs.writeFile.yields new Error('write error')
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.write({}, []).catch (error) ->
        error.should.have.property 'message'
        done()
      .done()


  describe 'writeDatabases', ->

    before ->
      sinon.stub(fs, 'readFile')
      sinon.stub(fs, 'writeFile').yields null

    after ->
      fs.readFile.restore()
      fs.writeFile.restore()

    it 'only re-writes the database list', ->
      fs.readFile.yields null,
        """
        [databases]
        mydb = host=localhost dbname=old_db

        [pgbouncer]
        listen_addr = localhost
        listen_port = 6543
        """
      pgb = new PgBouncer(configFile: 'foo.ini')
      pgb.writeDatabases(mydb: 'postgres://localhost/new_db')
      .then ->
        expected =
          """
          [databases]
          mydb = host=localhost dbname=new_db

          [pgbouncer]
          listen_addr = localhost
          listen_port = 6543
          """
        fs.writeFile.args[0][1].should.eql expected


  describe 'run', ->
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
      pg_query.callsArgWith(1, null, query_results)
      pg.connect.callsArgWith(1, null, {query: pg_query}, pg_done)
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.pgbConnectionString = pgbConnectionString
      pgb.run('some command').then (results) ->
        results.should.eql query_results
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        sinon.assert.alwaysCalledWith pg_query, 'some command'
        sinon.assert.calledOnce pg_done
        sinon.assert.alwaysCalledWith pg_done
        done()
      .done()

    it 'should returns error when connecting to pgbouncer', (done) ->
      pg.connect.callsArgWith(1, new Error('connect error'), null, pg_done)
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.pgbConnectionString = pgbConnectionString
      pgb.run('some command').catch (error) ->
        error.should.have.property 'message'
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        done()
      .done()

    it 'should returns error when issue command to pgbouncer', (done) ->
      pg_query.callsArgWith(1, new Error('query error'), null)
      pg.connect.callsArgWith(1, null, {query: pg_query}, pg_done)
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.pgbConnectionString = pgbConnectionString
      pgb.run('some command').catch (error) ->
        error.should.have.property 'message'
        sinon.assert.alwaysCalledWith pg.connect, pgbConnectionString
        sinon.assert.alwaysCalledWith pg_query, 'some command'
        sinon.assert.calledOnce pg_done
        sinon.assert.alwaysCalledWithExactly pg_done
        done()
      .done()

    it 'should returns error when pgbConnectionString property is empty', (done) ->
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      pgb.run('some command').catch (error) ->
        error.should.have.property 'message'
        sinon.assert.notCalled pg.connect
        done()
      .done()

  describe 'execute', ->
    it 'should run the command if pgbConnectionString property is not emty', (done) ->
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      runDefer = Q.defer()
      sinon.stub(pgb, 'run').returns(runDefer.promise)
      pgb.pgbConnectionString = "something"
      pgb.execute('some command').then ->
        sinon.assert.alwaysCalledWith pgb.run, 'some command'
        done()
      .done()
      runDefer.resolve()

    it 'should try to read config and then run the command if pgbConnectionString property is emty', (done) ->
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
      runDefer = Q.defer()
      read = Q.defer()
      sinon.stub(pgb, 'run').returns(runDefer.promise)
      sinon.stub(pgb, 'read').returns(read.promise)
      pgb.execute('some command').then ->
        sinon.assert.calledOnce pgb.read
        sinon.assert.alwaysCalledWith pgb.run, 'some command'
        done()
      .done()
      read.resolve()
      runDefer.resolve()

  describe 'status', ->
    executeDefer = null
    pgb = null

    beforeEach ->
      pgb = new PgBouncer(configFile: '/etc/pgbouncer.ini')
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
      executeDefer.resolve
        rows: [
          {name: 'pgbouncer'},
          {name: 'wift_racing'},
          {name: 'wift_sports'}
        ]

    it 'should returns error when execute return error', (done) ->
      pgb.status().catch (error) ->
        error.should.have.property 'message'
        sinon.assert.alwaysCalledWith pgb.execute, 'show databases'
        done()
      .done()
      executeDefer.reject(new Error('execute error'))
