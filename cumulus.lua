-- title:   Cumulus
-- author:  Drakir & Lowcase
-- desc:    Be Relatively Evil
-- script:  lua
-- input:   mouse
-- version: 0.1

cloudFiction = 0.98
windPower = 0.02

cloud = {x = 40, y = 60, vx = 0, vy = 0}

function draw()
	cls(2)
	if (startBlow and endBlow) then
		line(startBlow.x, startBlow.y, endBlow.x, endBlow.y, 8)
	end
	circ(cloud.x, cloud.y, 5, 8)
end

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
		influenceClouds()
		startBlow = nil
		endBlow = nil
	end
end

function influenceClouds()
		cloud.vx = (endBlow.x - startBlow.x) * windPower
		cloud.vy = (endBlow.y - startBlow.y) * windPower
end

function moveClouds()
	cloud.x = cloud.x + cloud.vx
	cloud.y = cloud.y + cloud.vy

	cloud.vx = cloud.vx * cloudFiction
	cloud.vy = cloud.vy * cloudFiction
end

function TIC()
	x, y, pressed = processMouse()
	processBlowing(x, y, pressed)
	moveClouds()
	
	draw()

	c = string.format("(%03i,%03i)", x, y)
	print(c, 0, 0, 6)
end
