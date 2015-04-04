redis = require("redis")

redisEnv = process.env.REDISCLOUD_URL
redisRegexp = /^redis:\/\/rediscloud:([^@]+)@([^:]+):([0-9]+)$/
if redisEnv && (match = redisEnv.match(redisRegexp))
  redisPassword = match[1]
  redisServer = match[2]
  redisPort = match[3]

if redisPassword?
  redisClient = redis.createClient(redisPort, redisServer, {auth_pass: true})
  redisClient.auth(redisPassword)
else
  redisClient = redis.createClient()

redisClient.on "error", (err) ->
  console.log("Error connecting to redisClient: " + err)

module.exports = (clientEventHandler) ->
  redisClient.on "message", (channel, message) ->
    # console.log("redisClient channel " + channel + ": " + message)
    
    # this message came from the server, intended to go to a client
    try
      parsedMessage = JSON.parse(message)
      clientEventHandler.fire parsedMessage.event, parsedMessage.args...
    catch error
      console.log("Error parsing server message: '#{error}' ('#{message}')")

  redisClient.subscribe("chat-clients")

