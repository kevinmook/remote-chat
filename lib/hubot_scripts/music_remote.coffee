# Description:
#   Control a shared music server
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_MUSIC_API_KEY
#
# Commands:
#   hubot play <spotify_uri>      - Starts playing the given spotify uri (get by right clicking a song in spotify and clicking "Copy Spotify URI")
#   hubot pause                   - Pauses the music
#   hubot stop                    - Pauses the music
#   hubot unpause                 - Resumes the music
#   hubot resume                  - Resumes the music
#   hubot next                    - Skips to the next song
#   hubot skip                    - Skips to the next song
#   hubot previous                - Goes to the previous song
#   hubot back                    - Goes to the previous song
#   hubot shuffle                 - Shuffles the music
#   hubot don't shuffle           - Stops shuffling the music
#   hubot loop                    - Loops the music
#   hubot don't loop              - Stops looping the music
#   hubot repeat                  - Loops the music
#   hubot don't repeat            - Stops looping the music
#   hubot what's the volume?      - Gets the current volume
#   hubot set volume <0 to 100>   - Sets the volume to the given percentage
#   hubot what's playing?         - Lists what's currently being played
#   hubot list clients            - Lists the music clients
#   hubot select client <id>      - Selects the active music client
#
# Author:
#   Kevin Mook (@kevinmook)

module.exports = (robot) ->

  robot.respond /^\s*play <?(.*?)>?$/i, (msg) ->
    # note: slack surrounds spotify uris with <>
    
    tellMusicRemote robot, msg, 'play', 'POST', {uri: msg.match[1]}, (response) ->
      status = response['status']
      track = status['track']
      artist = status['artist']
      msg.send "Now playing '#{track}' by '#{artist}.'"
  
  robot.respond /^\s*(?:pause|stop)(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "pause", 'POST', {}, (response) ->
      msg.send "The music has been paused."
  
  robot.respond /^\s*(?:unpause|resume|play)(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "resume", 'POST', {}, (response) ->
      msg.send "The music has been resumed."
  
  robot.respond /^\s*(?:skip|next)(?: song)?$/i, (msg) ->
    tellMusicRemote robot, msg, "next", 'POST', {}, (response) ->
      msg.send "The current song has been skipped."
  
  robot.respond /^\s*(?:previous|back)(?: song)?$/i, (msg) ->
    tellMusicRemote robot, msg, "previous", 'POST', {}, (response) ->
      msg.send "Going back to the previous song."
  
  robot.respond /^\s*shuffle(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "shuffle", 'POST', {shuffle: true}, (response) ->
      msg.send "The playlist will now be shuffled."
  
  robot.respond /^\s*(?:don.?t|stop) (?:shuffle|shuffling)(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "shuffle", 'POST', {shuffle: false}, (response) ->
      msg.send "The playlist will not be shuffled."
  
  robot.respond /^\s*(?:loop|repeat)(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "repeat", 'POST', {repeat: true}, (response) ->
      msg.send "The playlist will now be looped."
  
  robot.respond /^\s*(?:don.?t|stop) (?:loop|repeat|looping|repeating)(?: the)?(?: music)?$/i, (msg) ->
    tellMusicRemote robot, msg, "repeat", 'POST', {repeat: false}, (response) ->
      msg.send "The playlist will not be looped."
  
  robot.respond /^\s*set (?:the )?volume (?:to )?([0-9]+)$/i, (msg) ->
    tellMusicRemote robot, msg, "volume", 'POST', {volume: msg.match[1]}, (response) ->
      volume = response['status']['volume']
      msg.send "The volume has been set to #{volume}."
  
  robot.respond /^\s*what.?s (?:the )?volume\??$/i, (msg) ->
    tellMusicRemote robot, msg, "status", 'GET', {}, (response) ->
      volume = response['status']['volume']
      msg.send "The volume is at #{volume}."
  
  robot.respond /^\s*what.?s playing\??$/i, (msg) ->
    tellMusicRemote robot, msg, "status", 'GET', {}, (response) ->
      status = response['status']
      track = status['track']
      artist = status['artist']
      uri = status['uri']
      url = uri.replace(/:/g, "/").replace("spotify/", "http://open.spotify.com/")
      msg.send "#{url}"
  
  robot.respond /^\s*list clients$/i, (msg) ->
    tellMusicRemote robot, msg, "clients", 'GET', {}, (response) ->
      clients = []
      
      counter = 1
      for client in response['clients']
        hostname = client['hostname'] || "unknown"
        connected_str = if client['connected'] then "connected" else "disconnected"
        active_str = if client['active'] then ", selected" else ""
        client_message = "#{counter}: #{hostname} (#{connected_str}#{active_str})"
        clients.push(client_message)
        counter += 1
      
      if clients.length > 0
        msg.send "Clients: #{clients.join(", ")}"
        if clients.length > 1
          msg.send "You may select a different active client with 'select client [number]'"
      else
        msg.send "No known clients"
  
  robot.respond /^\s*select client ([0-9]+)$/i, (msg) ->
    tellMusicRemote robot, msg, "clients", 'GET', {}, (response) ->
      client_id = msg.match[1] - 1
      selected_client = response['clients'][client_id]
      if selected_client?
        hostname = selected_client['hostname'] || "unknown"
        client_name = selected_client['name']
        tellMusicRemote robot, msg, "active_client", 'POST', {client_name: client_name}, (response) ->
          msg.send "Active client set to #{hostname}"
      else
        msg.send "Unknown client. Please get the client id with 'list clients'"


tellMusicRemote = (robot, msg, command, method, params, callback) ->
  musicKey = process.env.HUBOT_MUSIC_API_KEY || msg.musicApiKey
  if !musicKey
    msg.send "Music API key is not set, unable to continue"
    return
  
  params_array = []
  params_array_str = ""
  
  for key, value of params
    clean_key = escape(key)
    clean_value = escape(value)
    params_array.push "#{clean_key}=#{clean_value}"
  
  if params_array.length > 0
    params_array_str = params_array.join("&")
  
  urlBase = process.env.API_ROOT || "https://music-remote.herokuapp.com"
  url = "#{urlBase}/api/v1/#{musicKey}/#{command}"
  remote_call = null
  switch method
    when 'GET'
      url = "#{url}?#{params_array_str}" if params_array_str.length > 0
      remote_call = msg.http(url).get()
    when 'POST'
      remote_call = msg.http(url).post(params_array_str)
  
  if remote_call
    remote_call (err, res, body) =>
      if err
        msg.send "Error communicating with the music client: #{err}"
        return
      try
        content = JSON.parse(body)
        
        if content?
          if content['success']
            callback(content)
          else if content['error']
            msg.send content['error']
          else
            msg.send "Error communicating with the music client"
        else
          msg.send "Invalid response"
      catch error
        msg.send "Invalid response"
  else
    msg.send "Invalid request"
