SlackClient = require 'slack-client'
pg = require('pg')
responder = require('../responder')

autoReconnect = true
autoMark = true

conString = process.env.DATABASE_URL

accountToClientsMap = {}

connectToClient = (accountId, slackKey, musicKey) =>
  slack = new SlackClient(slackKey, autoReconnect, autoMark)
  accountToClientsMap[accountId] ||= []
  accountToClientsMap[accountId] << slack

  slack.on 'open', ->
    channels = []
    groups = []
    unreads = slack.getUnreadCount()

    # Get all the channels that bot is a member of
    channels = ("##{channel.name}" for id, channel of slack.channels when channel.is_member)

    # Get all groups that are open and not archived 
    groups = (group.name for id, group of slack.groups when group.is_open and not group.is_archived)

    console.log "Welcome to Slack. You are @#{slack.self.name} of #{slack.team.name}"
    console.log 'You are in: ' + channels.join(', ')
    console.log 'As well as: ' + groups.join(', ')

    messages = if unreads is 1 then 'message' else 'messages'

    console.log "You have #{unreads} unread #{messages}"


  slack.on 'message', (message) ->
    channel = slack.getChannelGroupOrDMByID(message.channel)
    user = slack.getUserByID(message.user)
    response = ''

    {type, ts, text} = message

    channelName = if channel?.is_channel then '#' else ''
    channelName = channelName + if channel then channel.name else 'UNKNOWN_CHANNEL'

    userName = if user?.name? then "@#{user.name}" else "UNKNOWN_USER"

    console.log """
      Received: #{type} #{channelName} #{userName} #{ts} "#{text}"
    """

    # Respond to messages with the reverse of the text received.
    if type is 'message' and text? and channel?
      directMessage = channelName.indexOf("#") != 0
      responder.handleMessage(slack.self.name, channel, text, musicKey, directMessage)
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

# bootstrap connecting to all known accounts:
pg.connect conString, (err, client, done) =>
  if(err)
    return console.error('error fetching client from pool', err)
  
  client.query 'SELECT chats.account_id AS account_id, chats.api_key AS slack_key, accounts.key AS music_key FROM chats INNER JOIN accounts ON chats.account_id = accounts.id WHERE service = \'slack\'', (err, result) =>
    # call `done()` to release the client back to the pool
    done()
    
    if(err)
      return console.error('error running query', err)
    
    for index, row of result.rows
      connectToClient(row.account_id, row.slack_key, row.music_key)
    client.end()