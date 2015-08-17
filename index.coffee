irc    = require "irc"
debug  = require("debug") "tdmmix bot"
require("cson-config").load()
config = process.config

channel = "#mrdka"

status =
	connected: no
	channels: [ channel ]

client = new irc.Client config.server, config.nickname, channels: []

client.on "error", (err) ->
	console.log "client.on error:", err

client.on "registered", () ->
	status.connected = yes
	console.log "Connected to #{config.server} as #{config.nickname} channels: #{status.channels}"
	client.say "Q@CServe.quakenet.org", "AUTH #{config.auth.name} #{config.auth.pass}"
	client.conn.write "MODE MrsIna +x\r\n"
	# join channel after +x
	client.conn.write "JOIN #{channel}\r\n" for channel in status.channels

client.addListener "message", (from, to, message) ->
	message = message.trim()
	debug "#{from} #{to} #{message}"
	return unless to is channel
	processLine from, message if message[0] is "!"

processLine = (user, line) ->
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
	debug "processing command #{command} user: #{user} params: #{params}"
	commandHandlers[command] user, params

addPlayer = (user, params) ->
	debug "adding player"
	team = params[0]
	team = "queue" if status.players.blue.length is 4 and status.players.red.length is 4

	unless team
		team = "red" if status.players.red.length < status.players.blue.length
		team = "blue"

	player = params[1] if params[1]
	player = params[0] if params[0] and params[0] not in ["red", "blue", "yellow", "green", "queue"]
	player ?= user

	# player is already added
	for team, players of status.players
		continue if players.indexOf(player) is -1
		client.say channel, "Player #{player} is already in team #{team}"
		return

	status.players[team].push player
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
	status.topic = JSON.parse JSON.stringify config.topic
	status.players = JSON.parse JSON.stringify config.players
	updateTopic()

setTopic = (user, params) ->
	debug "setting topic #{params}"
	topic = params.join " "
	updateTopic()

updateTopic = () ->
	return unless status.connected

	t = "#{status.topic}"
	for name, players of status.players
		continue unless players.length
		players = JSON.parse JSON.stringify players
		players.push " " for i in [players.length..4]
		t += " #{name}: [#{players}]"

	client.send "TOPIC", channel, t

commandHandlers =
	"!a": addPlayer
	"!r": remPlayer
	"!t": setTopic



initValues()


