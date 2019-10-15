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

CITY_MESSAGE_DURATION = 3000 --ms
CITY_NEXT_MESSAGE_AFTER_MIN = 10000 --ms
CITY_NEXT_MESSAGE_AFTER_MAX = 20000 --ms

CLOUD_FRICTION = 0.98
CLOUD_DISTANCE_BASED_POWER = 0.0001
CLOUD_SIZE_BASED_POWER = 0.0001
CLOUD_ACTIVATION_TIME = 2000 --ms
CLOUD_OUT_OF_MAP_DEACTIVATION_DISTANCE = 30

function distanceLineToPoint(x1, y1, x2, y2, xp, yp)
	-- https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
	return abs(((y2-y1)*xp)-((x2-x1)*yp)+(x2*y1)-(y2*x1))/sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function distancePointToPoint(x1, y1, x2, y2)
	return sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function createMiniMap(trans, cities)
	return {
		update = function()
		end,

		draw = function()
			local w = (MAP_MAX_X / 10)
			local h = (MAP_MAX_Y / 10)
			local viewX, viewY = trans.getCurrent()
			rect(MAX_X - w, MAX_Y - h, w, h, 15)
			rectb((MAX_X - w) + (viewX // 10), (MAX_Y - h) + (viewY // 10), (MAX_X // 10), (MAX_Y // 10) + 1, 14)
			for _, c in pairs(cities) do
				pix((MAX_X - w) + (c.x() // 10), (MAX_Y - h) + (c.y() // 10), 1)
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
				curY = curY - speed
			end
			if btn(1) then -- DOWN
				curY = curY + speed
			end
			if btn(2) then -- LEFT
				curX = curX - speed
			end
			if btn(3) then -- RIGHT
				curX = curX + speed
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

	return {
		update = function()
			if time() - last > CLOUD_ACTIVATION_TIME then
				last = time()
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
	local radius = 0
	local x = 0
	local y = 0
	local vx = 0
	local vy = 0
	local raining = false;
	local growing = true;

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

		p.vx = frnd(params.maxstartvx-params.minstartvx)+params.minstartvx
		p.vy = frnd(params.maxstartvy-params.minstartvy)+params.minstartvy
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
			params = { minstartvx = -0.5, maxstartvx = 0.5, minstartvy = 0, maxstartvy=0 }
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
			params = { damping = 0.2, zoneminx = 40, zonemaxx = 200, zoneminy = 100, zonemaxy = 136 }
		}
	)

	local updateState = function()
		local t = lifeTime // 1000;

		if t < 10 then
			radius = t
		elseif t < 15 then
			radius = 10
		elseif t < 30 then
			 raining = true
		elseif t < 35 then
			raining = false
		elseif t < 45 then
			radius = 45 - t
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
			radius = 0
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
			local power = (max(0, 100 - dist) * CLOUD_DISTANCE_BASED_POWER) + (max(0, 10 - radius) * CLOUD_SIZE_BASED_POWER)
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
			spr(2, trans.x(x) - 16, trans.y(y) - 24, 0, 1, 0, 0, 4, 2)
			-- circb(trans.x(x), trans.y(y), radius, 8)
			-- if raining then	print("rain", trans.x(x - 10), trans.y(y - 3), 8) end
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

		update = function()
			for _, c in pairs(clouds) do
				if c.isRaining() and distancePointToPoint(c.x(), c.y(), x, y) <= (radius + c.radius()) then
					isUnderCloud = true
					happiness = min(20, happiness + HAPPINESS_GROWTH)
					return
				end
			end
			isUnderCloud = false
			happiness = max(0, happiness - HAPPINESS_DEGRADATION)

			if nextMessageTime < time() then
				nextMessageTime = time() + random(CITY_NEXT_MESSAGE_AFTER_MIN, CITY_NEXT_MESSAGE_AFTER_MAX)
				startMessageTime = time()
				if happiness < 8 then
					displayedMessage = badText[random(1, #badText)]
				end
				if happiness > 13 then
					displayedMessage = goodText[random(1, #badText)]
				end
			end

			if startMessageTime + CITY_MESSAGE_DURATION < time() then
				displayedMessage = nil
			end
		end,

		draw = function()
			-- if isUnderCloud then
			-- 	circ(trans.x(x), trans.y(y), radius, 3)
			-- else
			-- 	circ(trans.x(x), trans.y(y), radius, 1)
			-- end
			spr(0, trans.x(x) - 8, trans.y(y) - 8, 0, 1, 0, 0, 2, 2)
		end,

		drawGui = function()
			rect(trans.x(x-9), trans.y(y+10), 20, 2, 6)
			rect(trans.x(x-9), trans.y(y+10), happiness, 2, 11)

			if displayedMessage then
				local width = print(displayedMessage, 0, -32, 0)
				print(displayedMessage, trans.x(x) - (width / 2) + 1, trans.y(y) - 10 + 1, 0)
				print(displayedMessage, trans.x(x) - (width / 2), trans.y(y) - 10, 13)
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
			mouseBlower.draw()

			-- c = string.format("(%03i,%03i)", x, y)
			-- print(c, 0, 0, 6)
		end
	}
end

function TIC()
	if not scene then scene = createGameScene() end
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
