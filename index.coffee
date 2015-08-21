irc    = require "irc"
debug  = require("debug") "tdmmix bot"
require("cson-config").load()
config = process.config

channel = "#tdmmix"

status = {}

client = new irc.Client config.ircserver, config.nickname, channels: []

client.on "error", (err) ->
	console.log "client.on error:", err

client.on "registered", () ->
	status.connected = yes
	console.log "Connected to #{config.ircserver} as #{config.nickname} channels: #{status.channels}"
	client.say "Q@CServe.quakenet.org", "AUTH #{config.auth.name} #{config.auth.pass}"
	client.conn.write "MODE MrsIna +x\r\n"

	# join channel after +x with small timeout
	setTimeout () ->
		client.conn.write "JOIN #{channel}\r\n" for channel in status.channels
	, 500


client.addListener "message", (from, to, message) ->
	message = message.trim()
	debug "got message from: #{from} to: #{to} msg: #{message}"
	return unless to is channel
	processLine from, message if message[0] is "!"


processLine = (user, line) ->
	line = line.replace /,/g, " "
	line = line.split " "
	params = []
	for word in line
		if word and not command # store first non-empty parameter as command
			command = word
			continue
		params.push word if word

	processCommand user, command, params


processCommand = (user, command, params) ->
	command = command.toLowerCase()
	return debug "invalid command '#{command}'" unless commandHandlers[command]
	debug "processing command #{command} user: #{user} params: #{JSON.stringify params}"
	commandHandlers[command] user, params


addPlayerToTeam = (teamName, player) ->
	teamName = "queue" if status.players[teamName].length is 4

	# player is already added
	for team, players of status.players
		continue if players.indexOf(player) is -1
		client.say channel, "Player #{player} is already in team #{team}"
		return

	debug "adding player #{player} to #{teamName} team"
	status.players[teamName].push player


addPlayer = (user, params, team) ->
	team = params[0]

	unless team
		team = "red"
		team = "blue" if status.players.blue.length < status.players.red.length

	player = params[1] if params[1]
	player = params[0] if params[0] and not config.players[params[0]]
	player ?= user

	return unless config.players[team]

	addPlayerToTeam team, player
	updateTopic()


remPlayer = (user, params) ->
	debug "removing player"
	player = params[0]
	player ?= user

	for team, players of status.players
		i = players.indexOf player
		status.players[team].splice(i, 1) if i >= 0

	updateTopic()


initValues = () ->
	status.connected = no
	status.channels = [ channel ]
	resetValues()


resetValues = () ->
	status.maps = config.maps
	status.server = config.server
	status.topic = JSON.parse JSON.stringify config.topic
	status.players = JSON.parse JSON.stringify config.players
	updateTopic()


setTopic = (user, params) ->
	debug "setting topic #{params}"
	status.topic = params.join " "
	updateTopic()


updateTopic = () ->
	return unless status.connected

	t = "#{ircColors.bold}#{status.topic}#{ircColors.reset}"
	for name, players of status.players
		continue unless players.length

		players = JSON.parse JSON.stringify players
		if players.length < 4 and name isnt "queue"
			players.push "" for i in [1..4-players.length]
		t += " #{ircColors[name]}#{name}#{ircColors.reset}: [#{players.join ", "}]"

	t += " -> #{status.server}" if status.server

	debug "showing topic #{t}"
	client.send "TOPIC", channel, t


mapsHandler = (user, maps) ->
	status.maps = maps if maps.length
	client.say channel, "Maps: #{status.maps.join ", "}"


handleTeamAdd = (team, user, params) ->
	if params.length
		addPlayerToTeam team, player for player in params
	else
		addPlayerToTeam team, user
	updateTopic()


addRed = (user, params) ->
	handleTeamAdd "red", user, params


addBlue = (user, params) ->
	handleTeamAdd "blue", user, params


addGreen = (user, params) ->
	handleTeamAdd "green", user, params


addYellow = (user, params) ->
	handleTeamAdd "yellow", user, params


addQueue = (user, params) ->
	handleTeamAdd "queue", user, params


addServer = (user, params) ->
	return client.say channel, "Server: #{status.server}" unless params[0]

	status.server = params[0]
	updateTopic()


printHelp = (user) ->
	client.say user, """current commands: !a [team] [players...], !r [players], !red/!blue/!green/!yellow/!queue [players], !topic [topic], !reset, !maps [maps]"""


commandHandlers =
	"!a": addPlayer
	"!r": remPlayer
	"!s": addServer
	"!h": printHelp
	"!help": printHelp
	"!red": addRed
	"!blue": addBlue
	"!green": addGreen
	"!yellow": addYellow
	"!queue": addQueue
	"!topic": setTopic
	"!reset": resetValues
	"!maps": mapsHandler

ircColors =
	red: "\x035"
	blue: "\x032"
	green: "\x033"
	yellow: "\x038"
	queue: "\x0314"
	reset: "\x0f"
	bold: "\x02"


initValues()


