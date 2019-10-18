-- title:   Cumulus
-- author:  Drakir & Lowcase
-- desc:    Be Relatively Evil
-- script:  lua
-- input:   mouse
-- version: 0.1

sin,cos,sqrt,floor,ceil,abs,min,max,random=math.sin,math.cos,math.sqrt,math.floor,math.ceil,math.abs,math.min,math.max,math.random

-- Display size
MAX_X = 240
MAX_Y = 136

MAP_MAX_X = 400
MAP_MAX_Y = 300

SCROLL_SPEED = 4

CITY_COUNT = 10
CLOUD_COUNT = 8

HAPPINESS_DEGRADATION = 0.001
HAPPINESS_GROWTH = 0.01
HAPPINESS_BUFFER = 1

HAPPY_CITY_COUNT_FOR_WIN = 1

CITY_MESSAGE_DURATION = 3000 --ms
CITY_NEXT_MESSAGE_AFTER_MIN = 10000 --ms
CITY_NEXT_MESSAGE_AFTER_MAX = 20000 --ms
CITY_LOW_MEDIUM_BORDER = 8
CITY_MEDIUM_HIGH_BORDER = 13
CITY_MAX_HAPPINESS = 20 -- do not change this (health bar is hardcoded to 20px)

CLOUD_FRICTION = 0.98
CLOUD_DISTANCE_BASED_POWER = 0.0001
CLOUD_SIZE_BASED_POWER = 0.0001
CLOUD_ACTIVATION_TIME_MIN = 3000 --ms
CLOUD_ACTIVATION_TIME_MAX = 7000 --ms
CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE = 30

function distanceLineToPoint(x1, y1, x2, y2, xp, yp)
	-- https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
	return abs(((y2-y1)*xp)-((x2-x1)*yp)+(x2*y1)-(y2*x1))/sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function distancePointToPoint(x1, y1, x2, y2)
	return sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function printWithShadow(str, x, y, c)
    print(str, x+1, y+1, 0)
    return print(str, x, y, c)
end

function createMiniMap(trans, cities)
	return {
		update = function()
		end,

		draw = function()
			local w = (MAP_MAX_X / 10)
			local h = (MAP_MAX_Y / 10)
			local viewX, viewY = trans.getCurrent()
			rect(MAX_X - w, MAX_Y - h, w, h, 11)
			rectb((MAX_X - w) + (viewX // 10), (MAX_Y - h) + (viewY // 10), (MAX_X // 10), (MAX_Y // 10) + 1, 7)
			for _, c in pairs(cities) do
				local color
				if c.getHappiness() < CITY_LOW_MEDIUM_BORDER then
					color = 6
				elseif c.getHappiness() < CITY_MEDIUM_HIGH_BORDER then
					color = 12
				elseif c.getHappiness() < CITY_MAX_HAPPINESS then
					color = 14
				else
					color = 1
				end
				pix((MAX_X - w) + (c.x() // 10), (MAX_Y - h) + (c.y() // 10), color)
			end
		end
	}
end

function createCityCounter(cities)
	return {
		draw = function()
			local happyCount = 0
			for _, c in pairs(cities) do
				if c.getHappiness() >= CITY_MAX_HAPPINESS then
					happyCount = happyCount + 1;
				end
			end
			local msg = happyCount .. "/" .. HAPPY_CITY_COUNT_FOR_WIN
			local w = print(msg, -50, -50)
			printWithShadow(msg, MAX_X - w, 0, 15)

			if happyCount >= HAPPY_CITY_COUNT_FOR_WIN then
				scene = createWinScene()
			end
		end
	}
end

function createScreenTranslation()
	local curX = 0.0
	local curY = 0.0
	local SCROLL_SPEED = 4
	local mouseStart
	local currentStart

	local processMouse = function()
		local x, y, left, middle, right = mouse()
		return (x ~= 255 and x or 0), (y ~= 255 and y or 0), right
	end

	return {
		update = function()
			local x,y,right = processMouse()
			if right and not mouseStart then
				mouseStart = {x = x, y = y}
				currentStart = {x = curX, y = curY}
			end
			if right and mouseStart then
				curX = currentStart.x + (mouseStart.x - x)
				curY = currentStart.y + (mouseStart.y - y)
			end
			if not right then
				mouseStart = nil
			end

			if btn(0) then -- UP
				curY = curY - SCROLL_SPEED
			end
			if btn(1) then -- DOWN
				curY = curY + SCROLL_SPEED
			end
			if btn(2) then -- LEFT
				curX = curX - SCROLL_SPEED
			end
			if btn(3) then -- RIGHT
				curX = curX + SCROLL_SPEED
			end

			if curX < 0 then curX = 0 end
			if curY < 0 then curY = 0 end
			if curY > MAP_MAX_Y - MAX_Y then curY = MAP_MAX_Y - MAX_Y end
			if curX > MAP_MAX_X - MAX_X then curX = MAP_MAX_X - MAX_X end
		end,

		getCurrent = function()
			return curX, curY
		end,

		x = function(x)
			return x - curX
		end,

		y = function(y)
			return y - curY
		end,

		mapX = function(x)
			return x + curX
		end,

		mapY = function(y)
			return y + curY
		end
	}
end

function createCloudActivator(clouds, cities)
	local last = time()
	local activationTime = random(CLOUD_ACTIVATION_TIME_MIN, CLOUD_ACTIVATION_TIME_MAX)

	return {
		update = function()
			if time() - last > activationTime then
				last = time()
				activationTime = random(CLOUD_ACTIVATION_TIME_MIN, CLOUD_ACTIVATION_TIME_MAX)
				for _, c in pairs(clouds) do
					if not c.isActive() then
						local city = cities[random(1,#cities)]
						local x, y = city.x(), city.y()
						c.activate(random(x - 20, x + 20), random(y - 20, y + 20))
						break
					end
				end
			end
		end
	}
end

function createCloud(trans)
	local active = false
	local startTime = 0
	local lifeTime = 0
	local radius = 10
	local spriteIndex = 0
	local x = 0
	local y = 0
	local vx = 0
	local vy = 0
	local raining = false;
	local dark = false;

	local rainEmittimer = function(ps, params)
		if (raining and params.nextemittime<=time()) then
			emit_particle(ps)
			params.nextemittime = params.nextemittime + params.speed
		end
		return true
	end

	local rainEmmiter = function(p, params)
		p.x = frnd((x+10)-(x-10))+(x-10)
		p.y = y - 10

		p.vx = 0
		p.vy = 0
	end

	local rainDraw = function(ps, params)
		for key,p in pairs(ps.particles) do
			c = math.floor(p.phase*#params.colors)+1
			line(trans.x(p.x), trans.y(p.y), trans.x(p.x)-p.vx, trans.y(p.y)-p.vy, params.colors[c])
		end
	end

	local rainForce = function (p, params)
		p.vx = p.vx + params.fx
		p.vy = p.vy + params.fy
	end

	local rainBouncezone = function(p, params)
		if (p.y>=y+6 and p.y<=y+12) then
			p.vx = -p.vx*params.damping
			p.vy = -p.vy*params.damping
		end
	end

	local ps = make_psystem(300,310, 1,2,0.5,0.5)
	ps.autoremove = false
	table.insert(ps.emittimers,
		{
			timerfunc = rainEmittimer,
			params = {nextemittime = time(), speed = 0.0001}
		}
	)
	table.insert(ps.emitters,
		{
			emitfunc = rainEmmiter,
			params = { }
		}
	)
	table.insert(ps.drawfuncs,
		{
			drawfunc = rainDraw,
			params = { colors = {15,13,2,13,13,2,13,2,2,15,15,15} }
		}
	)
	table.insert(ps.affectors,
		{
			affectfunc = rainForce,
			params = { fx = 0, fy = 0.3 }
		}
	)
	table.insert(ps.affectors,
		{
			affectfunc = rainBouncezone,
			params = { damping = 0.2 }
		}
	)

	local updateState = function()
		local t = lifeTime // 1000;

		if t < 7 then
			spriteIndex = t
		elseif t < 15 then
			spriteIndex = 7
		elseif t < 20 then
			dark = true
		elseif t < 30 then
			raining = true
		elseif t < 35 then
			raining = false
		elseif t < 40 then
			dark = false
		elseif t < 47 then
			spriteIndex = 47 - t
		elseif t < 51 then
			active = false
		end

	end

	return {
		x = function()
			return x
		end,

		y = function()
			return y
		end,

		radius = function()
			return radius
		end,

		isRaining = function()
			return raining
		end,

		isActive = function()
			return active
		end,

		activate = function(startX, startY)
			spriteIndex = 0
			x = startX
			y = startY
			vx = 0
			vy = 0
			startTime = time()
			raining = false;
			growing = true;
			active = true;
		end,

		blow = function(startx, starty, endx, endy)
			if not active then return end

			local dist = distanceLineToPoint(startx, starty, endx, endy, x, y)
			local power = (max(0, 100 - dist) * CLOUD_DISTANCE_BASED_POWER) + (max(0, 10 - spriteIndex) * CLOUD_SIZE_BASED_POWER)
			vx = (endx - startx) * power
			vy = (endy - starty) * power
		end,

		update = function()
			if not active then return end

			lifeTime = time() - startTime

			updateState()

			x = (x + vx)
			y = (y + vy)

			if (x < -CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE) or (x > (MAP_MAX_X + CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE)) or
			   (y < -CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE) or (y > (MAP_MAX_Y + CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE))
			then
				active = false
			end

			vx = vx * CLOUD_FRICTION
			vy = vy * CLOUD_FRICTION
		end,

		draw = function()
			if not active then return end
			if dark then
				spr(230, trans.x(x) - 10, trans.y(y) - 22, 0, 1, 0, 0, 3, 2)
			else
				if spriteIndex > 0 then
					spr(32 * spriteIndex, trans.x(x) - 10, trans.y(y) - 22, 0, 1, 0, 0, 3, 2)
				end
			end
			-- circb(trans.x(x), trans.y(y), radius, 8)
			-- if raining then	print("rain", trans.x(x - 10), trans.y(y - 3), 8) end
			-- print(lifeTime // 1000, 0, 0)
		end
	}
end

function createCity(trans, clouds, x, y)
	local radius = 5
	local isUnderCloud = false

	local happiness = 10.0

	-- These two arrays should have same size
	local badText = {"WE NEED WATER", "WE ARE DYING", "YOU ARE EVIL"}
	local goodText = {"WE ARE SO HAPPY", "THANK YOU", "YOU ARE GOOD"}

	local nextMessageTime = time() + random(5000, 10000)
	local startMessageTime = time()
	local displayedMessage = nil

	return {
		x = function()
			return x
		end,

		y = function()
			return y
		end,

		getHappiness = function()
			return happiness
		end,

		update = function()
			for _, c in pairs(clouds) do
				if c.isRaining() and distancePointToPoint(c.x(), c.y(), x, y) <= (radius + c.radius()) then
					isUnderCloud = true
					happiness = min(20 + HAPPINESS_BUFFER, happiness + HAPPINESS_GROWTH)
					return
				end
			end
			isUnderCloud = false
			happiness = max(0, happiness - HAPPINESS_DEGRADATION)

			if nextMessageTime < time() then
				nextMessageTime = time() + random(CITY_NEXT_MESSAGE_AFTER_MIN, CITY_NEXT_MESSAGE_AFTER_MAX)
				startMessageTime = time()
				if happiness < CITY_LOW_MEDIUM_BORDER then
					displayedMessage = badText[random(1, #badText)]
				end
				if happiness > CITY_MEDIUM_HIGH_BORDER then
					displayedMessage = goodText[random(1, #badText)]
				end
			end

			if startMessageTime + CITY_MESSAGE_DURATION < time() then
				displayedMessage = nil
			end
		end,

		draw = function()
			if happiness < CITY_LOW_MEDIUM_BORDER then
				spr(0, trans.x(x) - 8, trans.y(y) - 8, 0, 1, 0, 0, 2, 2)
			elseif happiness < CITY_MEDIUM_HIGH_BORDER then
				spr(2, trans.x(x) - 8, trans.y(y) - 8, 0, 1, 0, 0, 2, 2)
			else
				spr(4, trans.x(x) - 8, trans.y(y) - 8, 0, 1, 0, 0, 2, 2)
			end
		end,

		drawGui = function()
			rect(trans.x(x-9), trans.y(y+10), 20, 2, 6)
			rect(trans.x(x-9), trans.y(y+10), happiness, 2, 11)

			if displayedMessage then
				local width = print(displayedMessage, 0, -32, 0)
				printWithShadow(displayedMessage, trans.x(x) - (width / 2), trans.y(y) - 10, 13)
			end

			if happiness <= 0 then
				scene = createLoseScene()
			end
		end
	}
end

function createMouseBlower(trans, clouds)
	local x, y, pressed, startBlow, endBlow;

	local processMouse = function()
		local x, y, pressed = mouse()
		return (x ~= 255 and x or 0), (y ~= 255 and y or 0), pressed
	end

	local processBlowing = function(x, y, pressed)
		if (pressed and not startBlow) then
			startBlow = {x = x, y = y}
			endBlow = {x = x, y = y}
		elseif (pressed and startBlow) then
			endBlow = {x = x, y = y}
		elseif (not pressed and endBlow) then
			for _, c in pairs(clouds) do c.blow(startBlow.x, startBlow.y, endBlow.x, endBlow.y) end
			startBlow = nil
			endBlow = nil
		end
	end

	return {
		update = function()
			x, y, pressed = processMouse()
			processBlowing(trans.mapX(x), trans.mapY(y), pressed)
		end,

		draw = function()
			if (startBlow and endBlow) then
				line(trans.x(startBlow.x), trans.y(startBlow.y), trans.x(endBlow.x), trans.y(endBlow.y), 8)
			end
		end
	}
end

function getFreeCityLocation(cities)
	local getRandom = function()
		-- Do not create cities in the bottom right corner (they are hidden under minimap)
		return random(20, MAP_MAX_X - 40), random(20, MAP_MAX_Y - 40)
	end

	local isCorrect = function(x, y)
		local ok = true
		for _, c in pairs(cities) do
			if distancePointToPoint(x, y, c.x(),c.y()) < 40 then
				ok = false
				break
			end
		end
		return ok
	end

	local x, y = getRandom()
	while not isCorrect(x, y) do
		x, y = getRandom()
	end
	return x, y
end

function createGameScene()
	local trans = createScreenTranslation()
	local clouds = {}
	local cities = {}
	local activator = createCloudActivator(clouds, cities)
	local mouseBlower = createMouseBlower(trans, clouds)
	local minimap = createMiniMap(trans, cities)
	local cityCounter = createCityCounter(cities)

	for i = 0, CITY_COUNT - 1, 1 do
		local x, y = getFreeCityLocation(cities)
		cities[i] = createCity(trans, clouds, x, y)
	end

	for i = 0, CLOUD_COUNT - 1, 1 do
		clouds[i] = createCloud(trans)
	end

	return {
		update = function()
			trans.update()
			activator.update()
			mouseBlower.update()
			for _, c in pairs(cities) do c.update() end
			for _, c in pairs(clouds) do c.update() end
			minimap.update()
			update_psystems()
		end,
		draw = function()
			cls(5)
			for _, c in pairs(cities) do c.draw() end
			for _, c in pairs(clouds) do c.draw() end
			draw_psystems()

			-- GUI
			for _, c in pairs(cities) do c.drawGui() end
			minimap.draw()
			cityCounter.draw()
			mouseBlower.draw()

			-- c = string.format("(%03i,%03i)", x, y)
			-- print(c, 0, 0, 6)
		end
	}
end

function createTestScene()
	local trans = createScreenTranslation()
	local cloud = createCloud(trans)
	cloud.activate(50, 50)
	return {
		update = function()
			trans.update()
			cloud.update()
			update_psystems()
		end,
		draw = function()
			cls(5)
			cloud.draw()
			draw_psystems()
		end
	}
end

function createWinScene()
	local prevDown = false
	return {
		update = function()
			particle_systems = {} -- to remove all remaining particle systems from ended game

			local x, y, left = mouse()
			if left then
                if not prevLeft then
                    prevLeft = true
                    HAPPY_CITY_COUNT_FOR_WIN = HAPPY_CITY_COUNT_FOR_WIN + 1
                    scene = createGameScene()
                end
            else
                prevLeft = false
            end
		end,

		draw = function()
			print("YOU WIN", 22, 22, 0, false, 2)
			print("YOU WIN", 20, 20, 15, false, 2)

			printWithShadow("Your favourites thrive", 5, 70, 15)
			printWithShadow("and the others suffer a lot.", 13, 78, 15)
			printWithShadow("Splendid. Splendid indeed.", 5, 94, 15)

			printWithShadow("click to continue", 143, 123, 15)
		end,
	}
end

function createLoseScene()
	local prevDown = false
	return {
		update = function()
			particle_systems = {} -- to remove all remaining particle systems from ended game

			local x, y, left = mouse()
			if left then
                if not prevLeft then
                    prevLeft = true
                    HAPPY_CITY_COUNT_FOR_WIN = 1
                    scene = createTitleScene()
                end
            else
                prevLeft = false
            end
		end,

		draw = function()
			print("YOU LOSE", 22, 22, 0, false, 2)
			print("YOU LOSE", 20, 20, 15, false, 2)

			printWithShadow("- Without rain, a village died from thirst", 5, 70, 15)
			printWithShadow("- Keep them alive by sending them a rainy", 5, 78, 15)
			printWithShadow("cloud once in a while", 13, 86, 15)

			printWithShadow("click to continue", 143, 123, 15)
		end,
	}
end

function createTitleScene()
	local prevDown = false
	return {
		update = function()
			local x, y, left = mouse()
			if left then
                if not prevLeft then
                    prevLeft = true
                    scene = createGameScene()
                end
            else
                prevLeft = false
            end
		end,

		draw = function()
			cls(5)
			print("Cumulus", 27, 22, 0, false, 4)
			print("Cumulus", 25, 20, 15, false, 4)
			printWithShadow("a game about blowing the clouds", 20, 50, 15)

			printWithShadow("- completely irrigate a village by rain", 5, 70, 7)
			printWithShadow("- blow onto clouds using mouse", 5, 78, 7)
			printWithShadow("- do not make others die from thirst", 5, 86, 7)

            printWithShadow("Shacknews Jam: Do It IV Shacknews", 5, 107, 7)
			printWithShadow("drakir.itch.io", 5, 115, 7)
			printWithShadow("lowcase.itch.io", 5, 123, 7)
			printWithShadow("click to start", 153, 123, 15)
		end,
	}
end

function TIC()
	if not scene then scene = createTitleScene() end
	--if not scene then scene = createGameScene() end
	--if not scene then scene = createWinScene() end
	--if not scene then scene = createLoseScene() end
	--if not scene then scene = createTestScene() end
	scene.update()
	scene.draw()
end







--==================================================================================--
-- PARTICLE SYSTEM LIBRARY =========================================================--
--==================================================================================--

particle_systems = {}

-- Call this, to create an empty particle system, and then fill the emittimers, emitters,
-- drawfuncs, and affectors tables with your parameters.
function make_psystem(minlife, maxlife, minstartsize, maxstartsize, minendsize, maxendsize)
	local ps = {
	-- global particle system params

	-- if true, automatically deletes the particle system if all of it's particles died
	autoremove = true,

	minlife = minlife,
	maxlife = maxlife,

	minstartsize = minstartsize,
	maxstartsize = maxstartsize,
	minendsize = minendsize,
	maxendsize = maxendsize,

	-- container for the particles
	particles = {},

	-- emittimers dictate when a particle should start
	-- they called every frame, and call emit_particle when they see fit
	-- they should return false if no longer need to be updated
	emittimers = {},

	-- emitters must initialize p.x, p.y, p.vx, p.vy
	emitters = {},

	-- every ps needs a drawfunc
	drawfuncs = {},

	-- affectors affect the movement of the particles
	affectors = {},
	}

	table.insert(particle_systems, ps)

	return ps
end

-- Call this to update all particle systems
function update_psystems()
	local timenow = time()
	for key,ps in pairs(particle_systems) do
		update_ps(ps, timenow)
	end
end

-- updates individual particle systems
-- most of the time, you don't have to deal with this, the above function is sufficient
-- but you can call this if you want (for example fast forwarding a particle system before first draw)
function update_ps(ps, timenow)
	for key,et in pairs(ps.emittimers) do
		local keep = et.timerfunc(ps, et.params)
		if (keep==false) then
			table.remove(ps.emittimers, key)
		end
	end

	for key,p in pairs(ps.particles) do
		p.phase = (timenow-p.starttime)/(p.deathtime-p.starttime)

		for key,a in pairs(ps.affectors) do
			a.affectfunc(p, a.params)
		end

		p.x = p.x + p.vx
		p.y = p.y + p.vy

		local dead = false
		if (p.x<0 or p.x>MAP_MAX_X or p.y<0 or p.y>MAP_MAX_Y) then
			dead = true
		end

		if (timenow>=p.deathtime) then
			dead = true
		end

		if (dead==true) then
			table.remove(ps.particles, key)
		end
	end

	if (ps.autoremove==true and #ps.particles<=0) then
		local psidx = -1
		for pskey,pps in pairs(particle_systems) do
			if pps==ps then
				table.remove(particle_systems, pskey)
				return
			end
		end
	end
end

-- draw a single particle system
function draw_ps(ps, params)
	for key,df in pairs(ps.drawfuncs) do
		df.drawfunc(ps, df.params)
	end
end

-- draws all particle system
-- This is just a convinience function, you probably want to draw the individual particles,
-- if you want to control the draw order in relation to the other game objects for example
function draw_psystems()
	for key,ps in pairs(particle_systems) do
		draw_ps(ps)
	end
end

-- This need to be called from emitttimers, when they decide it is time to emit a particle
function emit_particle(psystem)
	local p = {}

	local ecount = nil
	local e = psystem.emitters[math.random(#psystem.emitters)]
	e.emitfunc(p, e.params)

	p.phase = 0
	p.starttime = time()
	p.deathtime = time()+frnd(psystem.maxlife-psystem.minlife)+psystem.minlife

	p.startsize = frnd(psystem.maxstartsize-psystem.minstartsize)+psystem.minstartsize
	p.endsize = frnd(psystem.maxendsize-psystem.minendsize)+psystem.minendsize

	table.insert(psystem.particles, p)
end

function frnd(max)
	return math.random()*max
end
