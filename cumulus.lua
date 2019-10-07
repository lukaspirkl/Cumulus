-- title:   Cumulus
-- author:  Drakir & Lowcase
-- desc:    Be Relatively Evil
-- script:  lua
-- input:   mouse
-- version: 0.1

sin,cos,sqrt,floor,ceil,abs,min,max,random=math.sin,math.cos,math.sqrt,math.floor,math.ceil,math.abs,math.min,math.max,math.random

MAX_X = 240 - 1
MAX_Y = 136 - 1

function distanceLineToPoint(x1, y1, x2, y2, xp, yp)
	-- https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line
	return abs(((y2-y1)*xp)-((x2-x1)*yp)+(x2*y1)-y2*x1)/sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function distancePointToPoint(x1, y1, x2, y2)
	return sqrt(((y2-y1)^2)+((x2-x1)^2))
end

function createCloud()
	local startTime = time()
	local lifeTime = 0;
	local cloudFiction = 0.98
	local radius = 0
	local x = random(0, MAX_X)
	local y = random(0, MAX_Y)
	local vx = 0;
	local vy = 0;
	local raining = false;
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
		blow = function(startx, starty, endx, endy)
			-- TODO: it is not affecting clouds "around the corner"
			local dist = distanceLineToPoint(startx, starty, endx, endy, x, y)
			local power = max(0, 100 - dist) * 0.0002
			vx = (endx - startx) * power
			vy = (endy - starty) * power
		end,
		update = function()
			lifeTime = time() - startTime
			if (lifeTime / 1000) < 10 then
				radius = (lifeTime / 1000)
			else
				radius = 10
			end

			if (lifeTime / 1000) > 12 then
				raining = true
			end

			x = (x + vx) % MAX_X
			y = (y + vy) % MAX_Y

			vx = vx * cloudFiction
			vy = vy * cloudFiction
		end,
		draw = function()
			-- TODO: This is wrong
			circb(x - MAX_X - 1, y, radius, 8)
			circb(x + MAX_X, y, radius, 8)
			circb(x, y - MAX_Y - 1, radius, 8)
			circb(x, y + MAX_Y, radius, 8)
			circb(x, y, radius, 8)
			if raining then	print("rain", x - 10, y - 3) end
		end
	}
end

function createCity(clouds)
	local radius = 5
	-- TODO: add some minimal distance between cities
	local x = random(10, MAX_X - 10)
	local y = random(10, MAX_Y - 10)
	local isUnderCloud = false
	return {
		update = function()
			for _, c in pairs(clouds) do
				if c.isRaining() and distancePointToPoint(c.x(), c.y(), x, y) <= (radius + c.radius()) then
					isUnderCloud = true
					return
				end
			end
			isUnderCloud = false
		end,
		draw = function()
			if isUnderCloud then
				circ(x, y, radius, 3)
			else
				circ(x, y, radius, 1)
			end
		end
	}
end

function createGameScene()
	local x,y,pressed;
	local clouds = {createCloud()}
	local cities = {createCity(clouds), createCity(clouds), createCity(clouds)}

	function processMouse()
		local x, y, pressed = mouse()
		return (x ~= 255 and x or 0), (y ~= 255 and y or 0), pressed
	end

	function processBlowing(x, y, pressed)
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
			if btnp(4) then
				clouds[#clouds + 1] = createCloud()
			end

			x, y, pressed = processMouse()
			processBlowing(x, y, pressed)

			for _, c in pairs(cities) do c.update() end
			for _, c in pairs(clouds) do c.update() end
		end,
		draw = function()
			cls(2)

			if (startBlow and endBlow) then
				line(startBlow.x, startBlow.y, endBlow.x, endBlow.y, 8)
			end

			for _, c in pairs(cities) do c.draw() end
			for _, c in pairs(clouds) do c.draw() end

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
