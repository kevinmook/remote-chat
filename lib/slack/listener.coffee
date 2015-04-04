SlackClient = require 'slack-client'
responder = require('../responder')

autoReconnect = true
autoMark = true

conString = process.env.DATABASE_URL

module.exports = (pg, clientEventHandler) ->
  clientMap = {}

  connectToClient = (accountId, slackKey, musicKey) =>
    disconnectClient(accountId, slackKey)
    
    clientMap[accountId] ||= {}
    clientMap[accountId][slackKey] = slack = new SlackClient(slackKey, autoReconnect, autoMark)
    
    slack.on 'open', ->
      # anything?
      # console.log slack.self

    slack.on 'message', (message) ->
      channel = slack.getChannelGroupOrDMByID(message.channel)
      user = slack.getUserByID(message.user)
      {type, ts, text} = message

      if false        # enable for debugging
        channelName = if channel?.is_channel then '#' else ''
        channelName = channelName + if channel then channel.name else 'UNKNOWN_CHANNEL'

        userName = if user?.name? then "@#{user.name}" else "UNKNOWN_USER"

        console.log """
          Received: #{type} #{channelName} #{userName} #{ts} "#{text}"
        """

      if type is 'message' and text? and channel?
        directMessage = channel? && !channel.is_channel
        # note: slack.self.id is something like "U047M2UGZ". slack.self.name is the bot's actual name
        responder.handleMessage("<@#{slack.self.id}>", channel, text, musicKey, directMessage)
      else
        #this one should probably be impossible, since we're in slack.on 'message' 
        typeError = if type isnt 'message' then "unexpected type #{type}." else null
        #Can happen on delete/edit/a few other events
        textError = if not text? then 'text was undefined.' else null
        #In theory some events could happen with no channel
        channelError = if not channel? then 'channel was undefined.' else null

        #Space delimited string of my errors
        errors = [typeError, textError, channelError].filter((element) -> element isnt null).join ' '

        console.log """
          @#{slack.self.name} could not respond. #{errors}
        """

    slack.on 'error', (error) ->
      console.error "Error: #{error}"

    slack.login()

  disconnectClient = (accountId, slackKey) =>
    if slack = clientMap[accountId]?[slackKey]
      slack.disconnect()
      accountMap = clientMap[accountId]
      delete accountMap[slackKey]
      if Object.keys(accountMap).length == 0
        delete clientMap[accountId]

  sqlQuery = (sql..., rowCallback) =>
    pg.connect conString, (err, client, done) =>
      if(err)
        return console.error('error fetching client from pool', err)

      client.query sql..., (err, result) =>
        # call `done()` to release the client back to the pool
        done()
        
        if(err)
          return console.error('error running query', err)
        
        for index, row of result.rows
          rowCallback(row)
        client.end()
    

  clientEventHandler.on 'connect', (chatId) =>
    # console.log "Got connect for #{chatId}"
    sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key, accounts.key AS music_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\' AND chats.id = $1', chatId, (row) =>
      connectToClient(row.account_id, row.slack_key, row.music_key)

  clientEventHandler.on 'disconnect', (chatId) =>
    # console.log "Got disconnect for #{chatId}"
    sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\' AND chats.id = $1', chatId, (row) =>
      disconnectClient(row.account_id, row.slack_key)

  sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key, accounts.key AS music_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\'', (row) =>
    connectToClient(row.account_id, row.slack_key, row.music_key)
