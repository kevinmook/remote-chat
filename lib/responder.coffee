mockHubot = require('./mock_hubot/robot')

require('./hubot_scripts/music_remote')(mockHubot)

messageRegex = /^([^ :,]+)(?:[:,\s]+)(.*)?/

module.exports.handleMessage = (botName, channel, text, musicKey, directMessage) ->
  if directMessage
    actOnMessage(channel, text, musicKey)
  else if match = text.match(messageRegex)
    if botName.toLowerCase() == match[1].toLowerCase()
      messageText = match[2]
      actOnMessage(channel, messageText, musicKey)

actOnMessage = (channel, text, musicKey) ->
  mockHubot.messageReceived(channel, text, musicKey)
