require_relative 'libkaiser.rb'
=begin -------------------------------------------

Add Betting command to make bets on who wins
config for each users money, default to 50

Just add more events

Add event for "UseItem", which checks their inventory for items, uses one randomly
If item cant be used (full health heal) or no items in inventory, run a generic Wandering message

At night, if player has fort, they heal more naturally

Test logic for sponsor recieves

Alliance logic 
In Fights, dont add people who are in alliance
At start, add people in the districts to eachothers alliance
Negate alliances if the number of players left is alliances.size - 1

highest score record config

add inventory logic to the fight event
each player rolls, if they have weapons, add the PWR numbers to the roll

Weather system
Gamemaster command to shift weather
Weather tracking in humanize
Storm world event changes weather to stormy
Add some effects in some events based on weather
=end -------------------------------------------
class Medkit
	TYPE = "consumable"
	NAME = "Medkit"
	ARTICLE = "a"
	PWR = 10
end

class Bread
	TYPE = "consumable"
	NAME = "Bread"
	ARTICLE = "some"
	PWR = 3
end

class Water
	TYPE = "consumable"
	NAME = "Water"
	ARTICLE = "some"
	PWR = 2
end

class Knife
	TYPE = "weapon"
	NAME = "Knife"
	ARTICLE = "a"
	PWR = 4
end

class Bow
	TYPE = "weapon"
	NAME = "Bow"
	PWR = 7
	ARTICLE = "a"
end

class Event
	def initialize(world, state: "", players: 1)
		@state = state
		@players = players
		@world = world
	end
	def players
		@players
	end
	
	def state
		@state
	end
end

class EventBuildFort < Event
	def run(player)
		@world.build(player[0], 'fort')
		"**#{player[0].name}** builds a fort!\n"
	end
end

class EventInteractFort < Event
	def run(player)
		builds = @world.getAllBuilds(type: 'fort')
		if builds.size == 0 then
			return "**#{player[0].name}** camps out in a tree.\n"
		end
		fort = builds.sample
		if fort.owner.name == player[0].name then
			player[0].heal(10)
			"**#{player[0].name}** camps out in their fort.\n"
		else
			if rand(10) > 5 then
				if rand(10) > 5 then
					@world.debuild(fort)
					"**#{player[0].name}** torched down **#{fort.owner.name}**'s fort.\n"
				else
					@world.debuild(fort)
					fort.owner.damage(rand(5))
					if fort.owner.health > 0 then
						"**#{player[0].name}** torched down **#{fort.owner.name}**'s fort while they were inside, but they managed to get out in time.\n"	
					else
						"**#{player[0].name}** torched down **#{fort.owner.name}**'s fort while they were inside, burning down with it.\n"	
					end
				end
			else
				"**#{player[0].name}** tried to torch down **#{fort.owner.name}**'s fort but was scared off.\n"
			end
		end
	end
end

class EventGrabItem < Event
	def run(player)
		item = @world.itemPool.sample
		player[0].pickup(item)
		"**#{player[0].name}** grabs #{item::ARTICLE} #{item::NAME}\n"
	end
end

class EventEscapeBloodbath < Event
	def run(player)
		"**#{player[0].name}** escapes in to the woods.\n"
	end
end

class EventFormAlliance < Event
	def run(player)
		players = @world.alivePlayers
		numplayers = @players
		
		if numplayers >= players.size
			numplayers = (players.size - 1)
		end
		
		while numplayers > 0 do
			addp = players.sample
			
			if addp.health > 0
				p "Skipping #{addp.name} in alliance due to death."
				numplayers -= 1
				player.push(addp)
			end
		end

		playernames = []
		for i in 0 ... player.size
			playernames.push("**#{player[i].name}**")
			player[i].addAllianceArr(player)
		end
		
		"#{playernames.to_sentence} form an alliance.\n"
	end
end

class EventLandmine < Event
	def run(player)
		player[0].damage(10)
		"**#{player[0].name}** steps on a landmine and dies horribly.\n"
	end
end

class EventSponser < Event
	def run(player)
		s = @world.getSponsor(player[0])
		if s != nil then
			"**#{player[0].name}** gets an #{s['item']} from a sponser #{s['sender']}!\n"
		else
			"**#{player[0].name}** is missing home.\n"
		end
	end
end

class EventWander < Event
	def run(player)
		msg = rand(10)
		case msg
		when 0
			"**#{player[0].name}** wanders around the woods.\n"
		when 1
			"**#{player[0].name}** goes fishing.\n"
		when 2
			"**#{player[0].name}** questions their sanity.\n"
		when 3
			"**#{player[0].name}** contemplates the concept of bacon.\n"
		when 4
			"**#{player[0].name}** skips stones across the water.\n"
		when 5
			"**#{player[0].name}** hides up a tree.\n"
		when 6
			"**#{player[0].name}** gets lost in the woods.\n"
		when 7
			"**#{player[0].name}** hunts for food.\n"
		when 8
			"**#{player[0].name}** hears random noises.\n"
		when 9
			"**#{player[0].name}** goes hunting.\n"
		when 10
			"**#{player[0].name}** hums a song to themself.\n"
		else
			"**#{player[0].name}** dances like nobodies watching, cause nobody is watching...\n"
		end
	end
end

class EventSetTrap < Event
	def run(player)
		#@world.addTrap(player)
		@world.build(player[0], 'trap')
		"**#{player[0].name}** sets a trap.\n"
	end
end

class EventTriggersTrap < Event
	def run(player)
		trp = @world.getAllBuilds(type: 'trap')
		if trp.size == 0
			"**#{player[0].name}** wanders around the woods safely.\n"
		else
			trapper = trp.sample
			tname = trapper.owner.name
			@world.debuild(trapper)
			if player[0].name == tname then
				player[0].damage(10)
				"**#{player[0].name}** falls in to their own trap.\n"
			else
				trapper.owner.score
				player[0].damage(10)
				"**#{player[0].name}** falls in to **#{tname}**'s trap.\n"
			end
		end
	end
end

class EventFight < Event
	def run(player)
		players = @world.alivePlayers
		numplayers = @players
		puts "Running a fight for #{numplayers} players."
		if numplayers >= players.size
			numplayers = (players.size - 1)
			puts "Redacted: Running a fight for #{numplayers} players."
		end
		
		while numplayers > 0 do
			addp = players.sample
			unless player.include?(addp)
				if addp.health > 0
					numplayers -= 1
					player.push(addp)
				end
			end
		end
		
		winner = player.sample
		playernames = []
		for i in 0 ... player.size
			playernames.push("**#{player[i].name}**")
			if player[i] != winner then
				player[i].damage(6)
				if player[i].health < 0
					winner.score
				end
			end
		end
		
		"#{playernames.to_sentence} fight and **#{winner.name}** won.\n"
	end
end

class WorldEvent
	def initialize(world)
		@world = world
	end
end

class WorldEventFlood < WorldEvent
	def run
		msgs = "**A flood courses through the arena, covering every inch.**\n"
		players = @world.alivePlayers
		if @world.structures.size > 0 then
			msgs << "#{@world.structures.size} structures were destroyed.\n"
			@world.structures = []
		end
		
		for i in 0...players.size
			if players[i].health > 0 then
				effect = rand(4)
				case effect
				when 0 #safe
					msgs << "**#{players[i].name}** escaped the flooding.\n"
				when 1 #damage 5, check death
					players[i].damage(5)
					if players[i].health > 0 then
						msgs << "**#{players[i].name}** barely managed to escape.\n"
					else
						msgs << "**#{players[i].name}** tried valliantly to escape, but ended up slipping in to the depths.\n"
					end
				when 2 #damage 10, instadeath
					players[i].damage(10)
					msgs << "**#{players[i].name}** was caught off guard and drowns.\n"			
				when 3 #throw someone else in, then THEY get a roll to see if they survive
					sac = @world.alivePlayers.sample
					sac.damage(rand(10))
					if sac.health > 0
						msgs << "**#{players[i].name}** throws **#{sac.name}** in to the water, but they survive.\n"
					else
						msgs << "**#{players[i].name}** throws **#{sac.name}** in to the water, and they drown.\n"
					end
				end
			end
		end
		puts msgs
		return msgs
	end
end

class WorldEventStorm < WorldEvent
	def run
		msgs = "**A fierce storm rages up in the arena.**\n"
		msgs << @world.setWeather('stormy')
		players = @world.alivePlayers		
		for i in 0...players.size
			if players[i].health > 0 then
				effect = rand(4)
				case effect
				when 0 #safe
					msgs << "**#{players[i].name}** escaped from the storm.\n"
				when 1 #damage 5, check death
					players[i].damage(5)
					if players[i].health > 0 then
						msgs << "**#{players[i].name}** barely managed to dodge a bolt of lightning.\n"
					else
						msgs << "**#{players[i].name}** tried valliantly to escape, but was struck by lightning.\n"
					end
				when 2 #damage 10, instadeath
					players[i].damage(10)
					msgs << "**#{players[i].name}** was caught off guard, struck by lightning.\n"			
				when 3 #throw someone else in, then THEY get a roll to see if they survive
					sac = @world.alivePlayers.sample
					sac.damage(rand(10))
					if sac.health > 0
						msgs << "**#{players[i].name}** throws **#{sac.name}** to the wild, but they survive.\n"
					else
						msgs << "**#{players[i].name}** kills **#{sac.name}** to take their cover .\n"
					end
				end
			end
		end
		puts msgs
		return msgs
	end
end

class WorldEventFire < WorldEvent
	def run
		msgs = "**A forest fire ignites, spreading through the arena.**\n"
		players = @world.alivePlayers
		if @world.structures.size > 0 then
			msgs << "#{@world.structures.size} structures were destroyed.\n"
			@world.structures = []
		end
		
		for i in 0...players.size
			if players[i].health > 0 then
				effect = rand(4)
				case effect
				when 0 #safe
					msgs << "**#{players[i].name}** escaped the blaze.\n"
				when 1 #damage 5, check death
					players[i].damage(5)
					if players[i].health > 0 then
						msgs << "**#{players[i].name}** barely managed to escape.\n"
					else
						msgs << "**#{players[i].name}** tried valliantly to escape, but ended up slipping in to the embers and burning alive.\n"
					end
				when 2 #damage 10, instadeath
					players[i].damage(10)
					msgs << "**#{players[i].name}** was caught off guard, being burned in their sleep.\n"			
				when 3 #throw someone else in, then THEY get a roll to see if they survive
					sac = @world.alivePlayers.sample
					sac.damage(rand(10))
					if sac.health > 0
						msgs << "**#{players[i].name}** throws **#{sac.name}** in to the fires, but they survive.\n"
					else
						msgs << "**#{players[i].name}** throws **#{sac.name}** in to the fires, and they catch fire, burning to death.\n"
					end
				end
			end
		end
		puts msgs
		return msgs
	end
end

class WorldEventSwarm < WorldEvent
	def run(swarm)
		@swarm = swarm
		msgs = "**A swarm of #{@swarm}s flood the arena, hunting down any survivors.**\n"
		players = @world.alivePlayers
		
		for i in 0...players.size
			if players[i].health > 0 then
				
				if @world.getBuild(players[i], type: 'fort') != nil then
					msgs << "**#{players[i].name}** hides from the swarm in their shelter.\n"
				else
					effect = rand(4)
					case effect
					when 0 #safe
						msgs << "**#{players[i].name}** escaped the swarm.\n"
					when 1 #damage 5, check death
						players[i].damage(rand(5))
						if players[i].health > 0 then
							msgs << "**#{players[i].name}** barely managed to escape.\n"
						else
							msgs << "**#{players[i].name}** tried valliantly to escape, but ended up getting caught by a #{@swarm}.\n"
						end
					when 2 #damage 10, instadeath
						players[i].damage(10)
						msgs << "**#{players[i].name}** was caught off guard and murdered by a #{@swarm}.\n"			
					when 3 #throw someone else in, then THEY get a roll to see if they survive
						sac = @world.alivePlayers.sample
						sac.damage(rand(10))
						if sac.health > 0
							msgs << "**#{players[i].name}** throws **#{sac.name}** in to the swarm, but they manage to escape.\n"
						else
							msgs << "**#{players[i].name}** throws **#{sac.name}** in to the swarm, and are ripped apart by the #{@swarm}s.\n"
						end
					end
				end
			end
		end
		return msgs
	end
end

class HGInfo
	def initialize
		@cfg = Memory.new('hungergames.json')
		@gamemaster = ""
		@weather = "clear"
		@districts = []
		@tributes = []
		@time = 0
		@gamestate = "off"
		#@worldTraps = []
		@structures = []
		@sponsors = []
		@itemPool = [
			Medkit,
			Bread,
			Bow,
			Knife,
			Water
		]
		@worldEvents = Hash.new
		@worldEvents['flood'] = WorldEventFlood.new(self)
		@worldEvents['fire'] =	WorldEventFire.new(self)
		@worldEvents['swarm'] =	WorldEventSwarm.new(self)
		@worldEvents['storm'] = WorldEventStorm.new(self)
		@events = [
			EventGrabItem.new(self), 
			EventLandmine.new(self, state: 'bloodbath'), 
			EventFormAlliance.new(self, state: 'bloodbath'),
			EventWander.new(self),
			EventWander.new(self),
			EventWander.new(self),
			EventWander.new(self),
			EventWander.new(self),
			EventWander.new(self),
			EventSponser.new(self),
			EventEscapeBloodbath.new(self, state: 'bloodbath'),
			EventEscapeBloodbath.new(self, state: 'bloodbath'),
			EventEscapeBloodbath.new(self, state: 'bloodbath'),
			EventEscapeBloodbath.new(self, state: 'bloodbath'),
			EventEscapeBloodbath.new(self, state: 'bloodbath'),
			EventSetTrap.new(self),
			EventTriggersTrap.new(self),
			EventBuildFort.new(self),
			EventInteractFort.new(self),
			EventFight.new(self, players: 2),
			EventFight.new(self, players: 2),
			EventFight.new(self, players: 3),
			EventFight.new(self, players: 4)
		]
		@dead = []
		@validWeathers = [
			'clear',
			'cloudy',
			'raining',
			'stormy'
		]
	end

	def weather
		@weather
	end
	
	def setWeather(weather_name)
		if @validWeathers.include?(weather_name) then
			@weather = weather_name
			"Weather changed to #{weather_name}\n"
		else
			puts "Weather name #{weather_name} isn't valid, defaulting to clear."
			@weather = 'clear'
			"Weather changed to clear.\n"
		end
	end
	
	def itemPool
		@itemPool
	end
	
	def bloodbath
		msgs = ""
		tributes = self.allPlayers
		for i in 0 ... tributes.size
			tribute = tributes[i]
			ev = self.findValidEvent([tribute], state: 'bloodbath').sample
			msgs << ev.run([tribute])
		end
		p msgs
		@gamestate = "playing"
		@time = 1
		return msgs
	end
	
	def proceed		
		tributes = self.allPlayers
		msgs = ""
		for i in 0 ... tributes.size
			tribute = tributes[i]
			if tribute.health > 0 then
				ev = self.findValidEvent([tribute]).sample
				msgs << ev.run([tribute])
			end
		end
		
		msgs << self.runDead
		return msgs
	end	
	
	def runDead
		if @dead.size > 0 then
			msgs = "\n"
			msgs << "The cannons fire for this rounds dead;\n"
			for i in 0...@dead.size 
				msgs << " - *#{@dead[i].name}* from District #{@dead[i].district}\n"
			end
			@dead = []
			
			livings = self.alivePlayers
			if livings.size == 1 then
				winners = @cfg.get('winners', Array.new)
				winners.push(livings[0].name)
				@cfg.set('winners', winners)
				@gamestate = "ended"
				msgs << "**#{livings[0].name}** has won with #{livings[0].kills} kills!"
			elsif livings.size == 0 then
				@gamestate = "ended"
				msgs << "The game ended with no winners."
			end
			
			if @gamestate == "ended" then
				self.endGames
			end
			
			return msgs
		else
			return ""
		end
	end
	
	def worldEvent(event, arg: "")
		if arg == "" then
			msgs = @worldEvents[event].run
			msgs << self.runDead
			puts msgs
			return msgs			
		else
			msgs = @worldEvents[event].run(arg)
			msgs << self.runDead
			puts msgs
			return msgs			
		end
	end
	
	def gamemaster
		@gamemaster
	end
	
	def gamemaster=(ngamemaster)
		@gamemaster = ngamemaster
	end	
	
	def sponsors
		@sponsors
	end
	
	def getSponsor(player)
		for i in 0...@sponsors.size
			if @sponsors[i]['target'] == player then
				ref = @sponsers[i]
				@sponsers.delete(ref)
				return ref
			end
		end
		return nil
	end
	
	def sponsor(player, sender, thing)
		spons = Hash.new
		spons['target'] = player
		spons['sender'] = sender
		spons['item'] = thing
		@sponsors.push(spons)
	end
	
	def build(owner, type)
		@structures.push(HGStruct.new(owner, type))
	end
	
	def debuild(struct)
		@structures.delete(struct)
	end
	
	def structures
		@structures
	end
	
	def structures=(list)
		@structures = list
	end	
	
	def getAllBuilds(owner: nil, type: "")
		builds = []
		for i in 0...@structures.size
			if owner
				if @structures[i].owner.name == owner.name
					builds.push(@structures[i])
				end
			end
			
			if type == @structures[i].type
				builds.push(@structures[i])
			end
		end
		return builds
	end
	
	def getBuild(owner, type: "")
		for i in 0...@structures.size
			if @structures[i].owner.name == owner.name
				if type == ""
					return @structures[i]
				elsif type == @structures[i].type
					return @structures[i]
				end
			end
		end
		return nil
	end
	
	def findValidEvent(members, state: '', time: 10)
		valids = []
		for i in 0 ... @events.size
			ev = @events[i]
			valid = false
			#p ev
			#if members.size == ev.players then
				#p "Valid player size (#{members.size} -> #{ev.players})"
				#valid = true
			#else
				#p "Invalid player size (#{members.size} -> #{ev.players})"
				#valid = false
			#end
			
			if ev.state == state then
				#p "Works in this stage  (#{ev.state} -> #{state})"
				valid = true
			else
				#p "Doesn't work in this stage (#{ev.state} -> #{state})"
				valid = false
			end
			
			if time != 10 and valid == true then
				if ev.time == time then
					#p "Works at this time (#{ev.time} -> #{time})"
					valid = true
				else
					#p "Doesn't work at this time (#{ev.time} -> #{time})"
					valid = false
				end
			end
			
			if valid then valids.push(ev) end
		end
		#p valids
		return valids
	end
	
	def dead
		@dead
	end
	
	def addDeath(player)
		@dead.push(player)
	end
	
	def clearDeaths
		@dead = []
	end
	
	def alivePlayers
		alives = []
		tributes = self.allPlayers
		for i in 0 ... tributes.size
			tribute = tributes[i]
			if tribute.health > 0 then
				alives.push(tribute)
			end
		end		
		return alives
	end
	
	def endGames
		@districts = []
		@structures = []
		@sponsors = []
		@gamestate = "off"
		@time = 0
	end
	
	def beginGames
		curdist = []
		districtnum = 1
		for i in 0 ... @tributes.size
			curdist.push(@tributes[i])
			if curdist.size == 2 then
				self.addDistrict(curdist, districtnum)
				districtnum += 1
				curdist = []
			end
		end
		return
	end
	
	def humanizeTime
		if @time == 0 then
			"early morning"
		elsif @time == 1 then
			"morning"
		elsif @time == 2 then
			"mid day"
		elsif @time == 3 then
			"afternoon"
		elsif @time == 4 then
			"evening"
		elsif @time == 5 then
			"night"
		elsif @time == 6 then
			"late night"
		end
	end
	
	def shift
		@time += 1
		if @time == 7 then @time == 0 end
		return @time
	end
	
	def humanizeDistricts
		lines = ""
		for i in 0 ... @districts.size
			line = "**District #{i+1}**\n"
			if @districts[i].players[0].health > 0 then
				line << "#{@districts[i].players[0].name} [#{@districts[i].players[0].humanizeHealth}] (#{@districts[i].players[0].kills} kills)\n"
			else
				line << "~~#{@districts[i].players[0].name}~~ [Dead] (#{@districts[i].players[0].kills} kills)\n"
			end
			
			if @districts[i].players[1].health > 0 then
				line << "#{@districts[i].players[1].name} [#{@districts[i].players[0].humanizeHealth}] (#{@districts[i].players[1].kills} kills)\n"
			else
				line << "~~#{@districts[i].players[1].name}~~ [Dead] (#{@districts[i].players[1].kills} kills)\n"
			end
			lines << line
		end	
		return lines
	end
	
	def districts
		@districts
	end
	
	def tributes
		@tributes
	end
	
	def addTribute(volunteer)
		@tributes.push(volunteer)
	end
	
	def time
		@time
	end
	
	def gamestate
		@gamestate
	end

	def time=(time)
		@time = time
	end
 
 	def gamestate=(gamestate)
		@gamestate = gamestate
	end
	
	def allPlayers
		players = []
		for i in 0 ... @districts.size
			#p @districts[i].players
			players << @districts[i].players[0]
			players << @districts[i].players[1]
		end
		#p players
		return players
	end
	
	def addDistrict(memberlist, number)
		#p "District added #{memberlist}"
		nd = HGDistrict.new(memberlist, number, self)
		@districts.push(nd)
		return nd
	end
end

class HGPlayer
	def initialize(name, district, world)
		@name = name
		@world = world
		@alliances = []
		@inventory = []
		@health = 10
		@kills = 0
		@district = district
	end
	
	def district
		@district
	end
	
	def score
		@kills += 1
	end
	
	def kills
		@kills
	end
	
	def inventory
		@inventory
	end
	
	def pickup(item)
		@inventory.push(item)
	end

	def drop(name)
		for i in 0 ... @inventory.size
			if @inventory[i]::NAME == name then
				@inventory.delete_at(i)
				return
			end
		end
	end

	def findInvInd(name)
		for i in 0 ... @inventory.size
			if @inventory[i]::NAME == name then
				return i
			end
		end
	end
	
	def findInv(name)
		for i in 0 ... @inventory.size
			if @inventory[i].name == name then
				return @inventory[i]
			end
		end
	end
	
	def name
		@name
	end
	
	def alliances
		@alliances
	end
	
	def addAllianceArr(arr)
		for i in 0...arr.size
			if arr[i] != self then
				unless @alliances.include?(arr[i])
					@alliances.push(arr[i])
					p "Adding #{arr[i].name} alliance to #{self.name}."
				end
			end
		end
	end
	
	def humanizeHealth
		if health == 0 then
			"Dead"
		elsif health > 0 and health <= 4 then
			"Severely injured"
		elsif health > 4 and health <= 7 then
			"Injured"
		elsif health > 7 and health <= 9 then
			"Okay"
		else
			"Healthy"
		end
	end
	
	def health
		@health
	end

	def heal(health)
		@health += health
		if @health > 10 then @health = 10 end
	end
	
	def damage(health)
		@health -= health
		if @health <= 0 then @world.addDeath(self) end
	end
end

class HGStruct
	def initialize(owner, type)
		@owner = owner
		@type = type
	end
	
	def owner
		@owner
	end
	
	def type
		@type
	end
end

class HGDistrict
	def initialize(players, district, world)
		@players = []
		@number = district
		for i in 0 ... players.size
			np = HGPlayer.new(players[i], district, world)
			@players.push(np)
			p "Player #{players[i]} added."
		end
	end
	
	def number
		@number
	end
	
	def players
		@players
	end
end
