require_relative 'libkaiser.rb'

# Add a !sponser command
# Sponser gets added to the info list
# Sponser event now checks if theyre in the sponser list before giving items

# Add a Gamemaster command
# Event, instead of triggering the scene like normal, triggers a World Event that effects everyone
# World Event 1 - Fire spreads through forest, effects; damage, avoid, death
# 2 - Like 1 but flooding
# 3+ Wild Animals attack event

# Add Betting command to make bets on who wins
# config for each users money, default to 50

# Just add more events

# Add event for "UseItem", which checks their inventory for items, uses one randomly
# If item cant be used (full health heal) or no items in inventory, run a generic Wandering message

# Build a fort event, adds an owned "fort" to the world
# Attack fort event, chance to take over and kill the occupant or burn it down
# At night, if player has fort, they heal more naturally

class Medkit
	def use(target)
		target.heal = 50
	end
end

class Bread
	def use(target)
		target.heal = 50
	end
end

class Bow
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

class EventGrabItem < Event
	def run(player)
		"**#{player[0].name}** grabs a item!\n"
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
			"**#{player[0].name}** comtemplates the concept of bacon.\n"
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
		
		if numplayers >= players.size
			numplayers = (players.size - 1)
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

class HGInfo
	def initialize
		@districts = []
		@tributes = []
		@time = 0
		@gamestate = "off"
		#@worldTraps = []
		@structures = []
		@sponsors = []
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
			EventSetTrap.new(self),
			EventTriggersTrap.new(self),
			EventBuildFort.new(self),
			EventFight.new(self, players: 2),
			EventFight.new(self, players: 2),
			EventFight.new(self, players: 3),
			EventFight.new(self, players: 4)
		]
		@dead = []
	end
	
	def sponsors
		@sponsors
	end
	
	def getSponsor(player)
		for i in 0...@sponsors.size
			if @sponsors[i].player == player then
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
		
		if @dead.size > 0 then
			msgs << ""
			msgs << "The cannons fire for this rounds dead;\n"
			for i in 0...@dead.size 
				msgs << " - *#{@dead[i].name}* from District #{@dead[i].district}\n"
			end
			@dead = []
		end

		livings = self.alivePlayers
		if livings.size == 1 then
			@gamestate = "ended"
			msgs << "**#{livings[0].name}** has won with #{livings[0].kills}!"
		elsif livings.size == 0 then
			msgs << "The game ended with no winners."
		end
		return msgs
	end
	
	def endGames
		@districts = []
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
				line << "#{@districts[i].players[0].name} (#{@districts[i].players[0].kills} kills)\n"
			else
				line << "DEAD: ~~#{@districts[i].players[0].name}~~ (#{@districts[i].players[0].kills} kills)\n"
			end
			
			if @districts[i].players[1].health > 0 then
				line << "#{@districts[i].players[1].name} (#{@districts[i].players[1].kills} kills)\n"
			else
				line << "DEAD: ~~#{@districts[i].players[1].name}~~ (#{@districts[i].players[1].kills} kills)\n"
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
			if @inventory[i].name == name then
				@inventory.delete_at(i)
				return
			end
		end
	end

	def findInvInd(name)
		for i in 0 ... @inventory.size
			if @inventory[i].name == name then
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
