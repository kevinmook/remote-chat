# Description: 
#   Generates help commands.
#
# Commands:
#   hubot help - Displays all of the help commands
#   hubot help <query> - Displays all help commands that match <query>.
#
# URLS:
#   /hubot/help
#
# Notes:
#   These commands are grabbed from comment blocks at the top of each file.
#   This all is copied from hubot's source

Path           = require 'path'
Fs             = require 'fs'

HUBOT_DOCUMENTATION_SECTIONS = [
  'description'
  'dependencies'
  'configuration'
  'commands'
  'notes'
  'author'
  'authors'
  'examples'
  'tags'
  'urls'
]

parseHelp = (path, commands) ->
  scriptName = Path.basename(path).replace /\.(coffee|js)$/, ''
  scriptDocumentation = {}

  body = Fs.readFileSync path, 'utf-8'

  currentSection = null
  for line in body.split "\n"
    break unless line[0] is '#' or line.substr(0, 2) is '//'

    cleanedLine = line.replace(/^(#|\/\/)\s?/, "").trim()

    continue if cleanedLine.length is 0
    continue if cleanedLine.toLowerCase() is 'none'

    nextSection = cleanedLine.toLowerCase().replace(':', '')
    if nextSection in HUBOT_DOCUMENTATION_SECTIONS
      currentSection = nextSection
      scriptDocumentation[currentSection] = []
    else
      if currentSection
        scriptDocumentation[currentSection].push cleanedLine.trim()
        if currentSection is 'commands'
          commands.push cleanedLine.trim()

  if currentSection is null
    scriptDocumentation.commands = []
    for line in body.split("\n")
      break    if not (line[0] is '#' or line.substr(0, 2) is '//')
      continue if not line.match('-')
      cleanedLine = line[2..line.length].replace(/^hubot/i, @name).trim()
      scriptDocumentation.commands.push cleanedLine
      commands.push cleanedLine

commands = []
parseHelp("./lib/hubot_scripts/help.coffee", commands)
parseHelp("./lib/hubot_scripts/music_remote.coffee", commands)
commands.sort()

module.exports = (robot) ->
  robot.respond /^\s*help\s*$/i, (msg) ->
    namedCommands = commands.map (command) -> command.replace(/^hubot/, msg.botName)
    msg.send namedCommands.join("\n")
