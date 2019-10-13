-- title:   Cumulus
-- author:  Drakir & Lowcase
-- desc:    Be Relatively Evil
-- script:  lua
-- input:   mouse
-- version: 0.1

sin,cos,sqrt,floor,ceil,abs,min,max,random=math.sin,math.cos,math.sqrt,math.floor,math.ceil,math.abs,math.min,math.max,math.random

MAX_X = 240
MAX_Y = 136

MAP_MAX_X = 400
MAP_MAX_Y = 300

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
	local maxX = 600
	local mayY = 300
	local curX = 0.0
	local curY = 0.0
	local speed = 4
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
			if time() - last > 1000 then
				last = time()
				for _, c in pairs(clouds) do
					if not c.isActive() then
						local city = cities[random(0,#cities)]
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
	local cloudFriction = 0.98
	local deactivationDistance = 10

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
			local power = (max(0, 100 - dist) * 0.0001) + (max(0, 10 - radius) * 0.0001)
			vx = (endx - startx) * power
			vy = (endy - starty) * power
		end,

		update = function()
			if not active then return end

			lifeTime = time() - startTime

			updateState()

			x = (x + vx)
			y = (y + vy)

			if (x < -deactivationDistance) or (x > (MAP_MAX_X + deactivationDistance)) or
			   (y < -deactivationDistance) or (y > (MAP_MAX_Y + deactivationDistance))
			then
				active = false
			end

			vx = vx * cloudFriction
			vy = vy * cloudFriction
		end,

		draw = function()
			if not active then return end

			circb(trans.x(x), trans.y(y), radius, 8)
			if raining then	print("rain", trans.x(x - 10), trans.y(y - 3)) end
		end
	}
end

function createCity(trans, clouds, x, y)
	local radius = 5
	local happiness = 10.0
	local isUnderCloud = false
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
					happiness = min(20, happiness + 0.01)
					return
				end
			end
			isUnderCloud = false
			happiness = max(0, happiness - 0.001)
		end,

		draw = function()
			if isUnderCloud then
				circ(trans.x(x), trans.y(y), radius, 3)
			else
				circ(trans.x(x), trans.y(y), radius, 1)
			end
			rect(trans.x(x-9), trans.y(y+10), 20, 2, 6)
			rect(trans.x(x-9), trans.y(y+10), happiness, 2, 5)
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

	-- create 10 cities
	for i = 0, 9, 1 do
		local x, y = getFreeCityLocation(cities)
		cities[i] = createCity(trans, clouds, x, y)
	end

	-- create 20 clouds
	for i = 0, 19, 1 do
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
		end,
		draw = function()
			cls(2)
			for _, c in pairs(cities) do c.draw() end
			for _, c in pairs(clouds) do c.draw() end
			minimap.draw()
			mouseBlower.draw()
			-- c = string.format("(%03i,%03i)", x, y)
			-- print(c, 0, 0, 6)
		end
	}
end

scene = createGameScene()

function TIC()
	scene.update()
	scene.draw()
end
