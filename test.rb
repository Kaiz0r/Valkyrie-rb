require 'discordrb'
require 'steam-condenser'
require_relative 'memory.rb'
require_relative 'libkaiser.rb'
require_relative 'Triple.rb'
require_relative 'stack.rb'
require_relative 'hungergames.rb'
require 'httparty'

$cfg = Memory.new('bot.json')
$hungergames = HGInfo.new
$hgreactor = nil
bot = Discordrb::Commands::CommandBot.new token: $cfg.get('token'), prefix: '.'

bot.message(with_text: "begin the games") do |event|
	t = Time.new
	
	if t.hour >= 3 and t.hour <= 11 then
		moment = "morning"
	elsif t.hour > 11 and t.hour <= 6 then
		moment = "afternoon"
	else
		moment = "evening"
	end
	
	if $hungergames.time == 0 and $hungergames.gamestate == "off" then
		$hungergames.gamemaster = event.user.name
		hgc = $cfg.get('hgcount', 1)
		$cfg.set('hgcount', hgc+1)
		$hgreactor = event.channel.send("Good #{moment} and welcome to the #{humanizeInt(hgc)} Hunger Games.\nIf you wish to volunteer, react to this message!")
		$hgreactor.react("👍")
		$hungergames.gamestate = "reaping"
		if $hungergames.tributes.size == 24
			event.channel.send("We have the tributes. The game will start shortly.\nMay the odds ever be in your favour.")
			$hungergames.gamestate = "bloodbath"
			$hungergames.beginGames()
		end
	else
		puts $hungergames.time
		puts $hungergames.gamestate
	end
end

bot.reaction_add(from: not!(['Valkyrie'])) do |event|
	if $hungergames.gamestate == "reaping" and event.channel == $hgreactor.channel then
		$hungergames.addTribute(event.user.name)
		event.channel.send("Welcome to the Games, #{event.user.mention}.")
		if $hungergames.tributes.size == 24
			event.channel.send("We have the tributes. The game will start shortly.\nMay the odds ever be in your favour.")
			$hungergames.gamestate = "bloodbath"
			$hungergames.beginGames()
		end
	end
end

def capture
  old_stdout = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old_stdout
end

bot.command(:set) do |event, key, value|
	$cfg.set(key, value)
	$cfg.get(key)
end

bot.command(:cfg) do |event, key, value|
	msgs = ""
	$cfg.data.each do |key, value|
		if key == "token" or key == "trellotoken" or key == "trelloapikey" then
			msgs << "#{key} => [REDACTED]\n"
		else
			msgs << "#{key} => #{value}\n"
		end
	end
	return msgs
end

bot.command(:gamemaster) do |event, type, *args|
	if event.user.name != $hungergames.gamemaster then return "You don't have access to this feature." end
	if $hungergames.gamestate != "playing" then return "Game must be running first." end
	if type == nil then return "Needs a sub-command." end
		
	if type == "flood" then
		return $hungergames.worldEvent('flood')
	end
	if type == "fire" then
		return $hungergames.worldEvent('fire')
	end
	if type == "storm" then
		return $hungergames.worldEvent('storm')
	end
	if type == "swarm" then
		return $hungergames.worldEvent('swarm', arg: args.join(" "))
	end
	if type == "weather" then
		return $hungergames.setWeather(args[0])
	end
end

bot.command(:proceed) do |event|
	if $hungergames.gamestate == "reaping" then
		event.channel.send("The game has not yet started, not all players are in.")
		return
	end
	
	if $hungergames.gamestate == "bloodbath" then
		event.channel.send($hungergames.bloodbath())
	end
	
	event.channel.send("It is a #{$hungergames.weather} #{$hungergames.humanizeTime} in the arena.\n#{$hungergames.proceed()}")
	if $hungergames.gamestate == "playing" then
		$hungergames.shift
	end
	return
end

bot.command(:hg) do |event|
	event << "**#{$hungergames.gamemaster}'s game**"
	event << "It is a #{$hungergames.weather} #{$hungergames.humanizeTime}, the game is #{$hungergames.gamestate}\n\n"
	event << $hungergames.humanizeDistricts

end

bot.command(:endgame) do |event|
	$hungergames.endGames()
	"The game has ended."
end

bot.command(:tributes) do |event|
	$hungergames.tributes.to_sentence
end

bot.command(:structs) do |event|
	if $hungergames.structures.size == 0
		return "No buildings made."
	end
	
	out = ""
	for i in 0...$hungergames.structures.size
		strut = $hungergames.structures[i]
		out << "#{strut.type} (#{strut.owner.name})\n"
	end
	return out
end

bot.command(:sponsor) do |event, player, item|
	players = $hungergames.alivePlayers
	for i in 0...players.size
		if player == players[i].name
			if item == nil
				item = "food"
			end
			$hungergames.sponsor(players[i], event.user.name, item)
			event.channel.send("#{players[i].name} has been sponsored by #{event.user.name}, giving #{item}.")
			return
		end
	end
end

bot.command(:sponsors) do |event|
	msg = ""
	for i in 0...$hungergames.sponsors.size
		s = $hungergames.sponsors[i]
		p s
		msg << "#{s['target'].name}, sponsored by #{s['sender']}. (#{s['item']})\n"
	end
	return msg
end

bot.command(:volunteer) do |event, *member|
	unless $hungergames.gamestate == "reaping" then
		return "Game isn't allowing new members."
	end
	
	if member.size == 0 then
		unless $hungergames.tributes.include?(event.user.name) 
			$hungergames.addTribute(event.user.name)
			return "Volunteered."
		else
			return "You're already in."
		end
	end
	
	p member.size
	p member
	msgs = ""
	for i in 0...member.size
		if $hungergames.tributes.size < 24
			unless $hungergames.tributes.include?(member[i])
				msgs << "Adding #{member[i]}\n"
				$hungergames.addTribute(member[i])
			end
		end
	end
	
	if $hungergames.tributes.size == 24
		msgs << "We have the tributes. The game will start shortly.\nMay the odds ever be in your favour."
		$hungergames.gamestate = "bloodbath"
		$hungergames.beginGames()
	end
	return msgs
end

bot.command(:addrandoms) do |event|
	unless $hungergames.gamestate == "reaping" then
		return "Game isn't allowing new members."
	end
	
	while $hungergames.tributes.size < 24 do
		np = event.server.members.sample
		unless $hungergames.tributes.include?(np.name)
			printk("Adding #{np.name}")
			$hungergames.addTribute(np.name)
		end
	end
	event.channel.send("We have the tributes. The game will start shortly.\nMay the odds ever be in your favour.")
	$hungergames.gamestate = "bloodbath"
	$hungergames.beginGames()
end

bot.command(:raw) do |event, *message|
	"```#{message}```"
end

bot.command(:g) do |event, *message|
	message = message.join(" ")
	title = message.tokenize[0]
	msg = message.tokenize
	msg.delete_at(0)
	msg = msg.join(" ")

	response = HTTParty.post("https://api.trello.com/1/lists/5bbddbf1c2ecac69e374f413/cards", 
		body: {
			name: title,
			desc: msg,
			idList: "list_id",
			keepFromSource: "all",
			key: $cfg.get('trellokey'),
			token: $cfg.get('trellotoken')
		}
	)
	
	puts response.body
	puts response.code
	if response.code == 200 then
		return "Thanks, your suggestion has been sent."
	else
		return "Sorry, there was a problem. ERROR: #{response.code}\n#{response.body}"
	end
end

bot.command(:say) do |event, target, *message|
	message = message.join(" ")
	
	bot.users.each do |key, user|
		if user.name == target or user.id == target.to_i
			user.pm(message)
			return "Message sent to #{user.username}"
		end
	end

	bot.servers.each do |key, server|
		for i in 0 ... server.channels.size
			channel = server.channels[i]
			if channel.name == target or channel.id == target.to_i
				channel.send(message)
				return "Message sent to #{channel.name}"
			end
		end
	end
end

bot.command(:run) do |event, type, target, *command|
	command = command.join(" ")
	
	if type == "as" then
		bot.users.each do |key, user|
			if user.name == target or user.id == target.to_i
				event.author = user
				bot.simple_execute(command, event)
			end
		end
	end
	
	if type == "in" then
		bot.servers.each do |key, server|
			for i in 0 ... server.channels.size
				channel = server.channels[i]
				if channel.name == target or channel.id == target.to_i
					channel.send(message)
					return "Message sent to #{channel.name}"
				end
			end
		end
	end
end

bot.command(:gmp) do |event, hostname|
	if hostname == nil then hostname = '185.44.76.146:27085' end
	server = SourceServer.new('185.44.76.146: 27085')
	server.init
	players = server.players
	numplayers = server.players.length
	puts players
	
	if numplayers == 0 then
		return "There is noone online, feelsbadman."
	end
	
	outp = ""
	
	players.each do |key, player|
		unless player.name == "" then
			outp << "#{player.name}\n"
		end
	end
	return outp
end

bot.command(:gm) do |event, hostname|
	if hostname == nil then hostname = '185.44.76.146:27085' end
	puts hostname
	server = SourceServer.new(hostname)
	server.init
	info = server.server_info
	puts server.to_s
	event << "**Name**: #{info[:server_name]}"
	event << "**Ping**: #{server.ping.round}"
	event << "**Version**: #{info[:game_version]}"
	event << "**Map Name**: #{info[:map_name]} (#{info[:game_description]})"
	event << "**Click to Join**: steam://connect/185.44.76.146:27085"
	event << ""
	event << "There are #{info[:number_of_players]} players..."
end

bot.command(:triple) do |event, game|
	ms = Triple.new
	servers = ms.getList(game)
	outp = "#{servers[1]['total']} servers, #{servers[1]['players']} players.\n"
	servers[0].each do |server|
		#if server != nil then
			#puts key
			puts server
			puts "--"
			outp << " [#{server['country']}] **#{server['hostname']}** | **Map**: #{server['mapname']} (#{server['maptitle']}) | **Game**: #{server['gametype']} | **Players**: #{server['numplayers']}/#{server['maxplayers']} | **IP**: #{server['ip']}\n"
		#end
	end
	return outp
end

bot.message() do |event|
	if event.message.content != ""
		printk("#{event.user.name} in #{event.channel.name}: #{event.message.content}", tag: 'say')
	end
end

bot.command(:eval, help_available: false) do |event, *code|
  break unless event.user.id == 206903283090980864 or event.user.id == 542827048234909737

  begin
    capture { eval code.join(' ') }
  rescue => e
	msg = e.message

	trace = ""
	for i in 0...e.backtrace.size
		trace << "#{e.backtrace[i]}\n"
	end
    "An error occurred 😞\n```-= #{msg}\n#{trace}```"
  end
end

bot.command(:exit, help_available: false) do |event|
  break unless event.user.id == 206903283090980864 # Replace number with your ID

  event.channel.send("Shutting down.")
  bot.stop
end

bot.command [:choose, :choice] do |_event, *args|
  "**#{args.sample}**"
end

bot.command :flip do |event|
%w(Heads Tails).sample
end

bot.command(:invite, chain_usable: false) do |event|
  # This simply sends the bot's invite URL, without any specific permissions,
  # to the channel.
  event.bot.invite_url
end

bot.command(:random, min_args: 0, max_args: 2, description: 'Generates a random number between 0 and 1, 0 and max or min and max.', usage: 'random [min/max] [max]') do |_event, min, max|
  # The `if` statement returns one of multiple different things based on the condition. Its return value
  # is then returned from the block and sent to the channel
  if max
    rand(min.to_i..max.to_i)
  elsif min
    rand(0..min.to_i)
  else
    rand
  end
end

bot.run(true)
bot.game = "on Ruby #{RUBY_VERSION}-#{RUBY_PATCHLEVEL}"
printk('Started.', tag: 'info')
bot.join
