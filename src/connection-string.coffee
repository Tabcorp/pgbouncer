_ = require 'lodash'
iniparser = require 'iniparser'


keyValue = (value, key) -> ("#{key}=#{value}" if value)


# URI    -> connection string
# object -> connection string
exports.toLibPq = (database) ->
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

  _(db).map(keyValue).compact().join(' ')


# connection string -> URI
# libpq object      -> URI
exports.toURI = (properties) ->
  if _.isString(properties)
    exports.toURI(iniparser.parseString(properties.split(/\s+/).join('\n')))
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
