iniparser = require 'iniparser'
cnx = require '../src/connection-string'


describe 'Connection strings', ->

  describe 'toLibPq', ->

    describe 'from a URI', ->

      it 'should convert a URI to a connection string', ->
        libpq = cnx.toLibPq('postgresql://admin:1234@localhost:5433/mydb')
        libpq.should.eql 'user=admin password=1234 host=localhost port=5433 dbname=mydb'

      it 'should convert full connection uri start with pg://', ->
        libpq = cnx.toLibPq 'pg://admin:1234@localhost:5433/mydb'
        libpq.should.eql 'user=admin password=1234 host=localhost port=5433 dbname=mydb'

      it 'should convert full connection uri start with postgres://', ->
        libpq = cnx.toLibPq 'postgres://admin:1234@localhost:5433/mydb'
        libpq.should.eql 'user=admin password=1234 host=localhost port=5433 dbname=mydb'

      it 'should convert minimal connection uri', ->
        libpq = cnx.toLibPq 'postgresql://'
        libpq.should.eql ''

      it 'should convert connection uri with host only', ->
        libpq = cnx.toLibPq 'postgresql://localhost'
        libpq.should.eql 'host=localhost'

      it 'should convert connection uri with dbname only', ->
        libpq = cnx.toLibPq 'postgresql:///mydb'
        libpq.should.eql 'dbname=mydb'

      it 'should convert connection uri with host and dbname only', ->
        libpq = cnx.toLibPq 'postgresql://localhost/mydb'
        libpq.should.eql 'host=localhost dbname=mydb'

      it 'should convert connection uri with host and user only', ->
        libpq = cnx.toLibPq 'postgresql://user@localhost'
        libpq.should.eql 'user=user host=localhost'

    describe 'from an object', ->

      it 'should convert hash object', ->
        libpq = cnx.toLibPq(user: 'bob', host: 'localhost')
        libpq.should.eql 'user=bob host=localhost'

  describe 'toURI', ->

    describe 'invalid', ->

      it 'should convert null string', ->
        uri = cnx.toURI null
        uri.should.eql 'postgresql://'

      it 'should convert undefined string', ->
        uri = cnx.toURI()
        uri.should.eql 'postgresql://'

    describe 'from a LibPq string', ->

      it 'should convert empty string', ->
        uri = cnx.toURI ''
        uri.should.eql 'postgresql://'

      it 'should convert with host property only', ->
        uri = cnx.toURI 'host=localhost'
        uri.should.eql 'postgresql://localhost'

      it 'should convert with dbname property only', ->
        uri = cnx.toURI 'dbname=mydb'
        uri.should.eql 'postgresql:///mydb'

      it 'should convert with host and dbname properties only', ->
        uri = cnx.toURI 'host=localhost dbname=mydb'
        uri.should.eql 'postgresql://localhost/mydb'

      it 'should convert with host and user properties only', ->
        uri = cnx.toURI 'host=localhost user=user1'
        uri.should.eql 'postgresql://user1@localhost'

      it 'should convert all properties', ->
        uri = cnx.toURI 'dbname=mydb host=localhost port=5433 user=admin password=1234'
        uri.should.eql 'postgresql://admin:1234@localhost:5433/mydb'

    describe 'from an object', ->

      it 'should convert hash object', ->
        uri = cnx.toURI(user: 'user1', host: 'localhost')
        uri.should.eql 'postgresql://user1@localhost'


