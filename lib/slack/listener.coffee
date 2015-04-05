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
      updateClientStatus(accountId, slackKey, true, "")

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
        responder.handleMessage(["@#{slack.self.name}", "<@#{slack.self.id}>"], channel, text, musicKey, directMessage)
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
      if error == "account_inactive"
        slack.autoReconnect = false
        updateClientStatus(accountId, slackKey, false, error)
      else if error == "invalid_auth"
        slack.autoReconnect = false
        updateClientStatus(accountId, slackKey, false, error)
      else
        console.error "Slack error: #{error}"

    try
      slack.login()
    catch error
      console.log error

  disconnectClient = (accountId, slackKey) =>
    if slack = clientMap[accountId]?[slackKey]
      updateClientStatus(accountId, slackKey, false, "disabled")
      slack.disconnect()
      accountMap = clientMap[accountId]
      delete accountMap[slackKey]
      if Object.keys(accountMap).length == 0
        delete clientMap[accountId]

  sqlQuery = (sql, params, rowCallback) =>
    if (typeof params) == "function"
      rowCallback = params
      params = null
    
    pg.connect conString, (err, client, done) =>
      if(err)
        return console.error('error fetching client from pool', err)
      
      client.query sql, params, (err, result) =>
        # call `done()` to release the client back to the pool
        done()
        
        if(err)
          console.log('error running query', err) 
          return
        
        if rowCallback?
          for index, row of result.rows
            rowCallback(row)

  updateClientStatus = (accountId, slackKey, active, statusCode) =>
    sqlQuery 'UPDATE chats SET active = $1, status_code = $2 WHERE service = \'slack\' AND chats.account_id = $3 AND chats.api_key = $4', [active, statusCode, accountId, slackKey]

  bindToClientEvents = =>
    clientEventHandler.on 'connect', (chatId) =>
      # console.log "Got connect for #{chatId}"
      sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key, accounts.key AS music_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\' AND chats.id = $1', [chatId], (row) =>
        connectToClient(row.account_id, row.slack_key, row.music_key)

    clientEventHandler.on 'disconnect', (chatId) =>
      # console.log "Got disconnect for #{chatId}"
      sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\' AND chats.id = $1', [chatId], (row) =>
        disconnectClient(row.account_id, row.slack_key)

  loadExistingClients = =>
    sqlQuery 'SELECT accounts.id AS account_id, chats.api_key AS slack_key, accounts.key AS music_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\' AND active = true', (row) =>
      connectToClient(row.account_id, row.slack_key, row.music_key)


  bindToClientEvents()
  loadExistingClients()
