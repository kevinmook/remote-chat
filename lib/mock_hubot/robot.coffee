HttpClient     = require 'scoped-http-client'

actions = []

module.exports = {
  respond: (regex, callback) ->
    actions.push [regex, callback]
  
  messageReceived: (botNames, channel, text, musicKey) ->
    for action in actions
      regex = action[0]
      callback = action[1]
      
      if match = text.match(regex)
        callback(mockHubotMessage(botNames, channel, match, musicKey))
        return
}

mockHubotMessage = (botNames, channel, match, musicKey) ->
  {
    botName: botNames[0]
    match: match
    musicApiKey: musicKey
    http: (url, options) ->
      HttpClient.create(url, options)
        .header('User-Agent', "MusicRemoteChat/0.0.1")
    send: (message) -> channel.send(message)
  }
