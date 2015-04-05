mockHubot = require('./mock_hubot/robot')

require('./hubot_scripts/music_remote')(mockHubot)
require('./hubot_scripts/help')(mockHubot)

messageRegex = /^([^ :,]+)(?:[:,\s]+)(.*)?/

module.exports.handleMessage = (botNames, channel, text, musicKey, directMessage) ->
  if directMessage
    actOnMessage(botNames, channel, text, musicKey)
  else if match = text.match(messageRegex)
    lowerNameMatch = match[1].toLowerCase()
    if(botNames.some (botName) -> botName.toLowerCase() == lowerNameMatch)
      messageText = match[2]
      actOnMessage(botNames, channel, messageText, musicKey)

actOnMessage = (botNames, channel, text, musicKey) ->
  mockHubot.messageReceived(botNames, channel, text, musicKey)
