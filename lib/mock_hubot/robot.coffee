HttpClient     = require 'scoped-http-client'

actions = []

module.exports = {
  respond: (regex, callback) ->
    actions.push [regex, callback]
  
  messageReceived: (channel, text, musicKey) ->
    for action in actions
      regex = action[0]
      callback = action[1]
      
      if match = text.match(regex)
        callback(mockHubotMessage(channel, match, musicKey))
        return
}

mockHubotMessage = (channel, match, musicKey) ->
  {
    match: match
    musicApiKey: musicKey
    http: (url, options) ->
      HttpClient.create(url, options)
        .header('User-Agent', "MusicRemoteChat/0.0.1")
    send: (message) -> channel.send(message)
  }
