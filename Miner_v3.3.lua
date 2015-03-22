--[[
Miner - v3.3
March 20, 2015
By Blueberrys
]]

--
-- Constants
--

local t = turtle

local items = {
	torch = "minecraft:torch",

	cobble = "minecraft:cobblestone",
	sandstone = "minecraft:sandstone",

	chest = "minecraft:chest",

	coal = "minecraft:coal",
	blz_rod = "minecraft:blaze_rod",
	lava = "minecraft:lava_bucket",

	bucket = "minecraft:bucket",
	lava_block = "minecraft:flowing_lava",
}

local settings_file = "MinerSettings"


--
-- Settings
--

local debug = false
local aggressive = true
local neat = true
local safe = true

local dim = {
	main_shaft = {
		w=2,
	},
	base_room = {
		w=3,
		l=3,
	},
	strips = {
		l=20,
		w=1,
	},
}

local fuel_items_whitelist = {
	items.coal,
	items.lava,
	items.blz_rod,
}


--
-- Variable values
--

local dist_from_chest
local dist_across_shaft

local strip_spacing
local strip_total_w

local torch_spacing
local torch_per_strip

local ave_speed
local max_place_tries
local wait_period

local function valid_sett(sett)
	local function use_valid(opt, default)
		if (opt~=nil) then return opt
		else return default
		end
	end

	sett.aggressive = use_valid(sett.aggressive, aggressive)
	sett.neat = use_valid(sett.neat, neat)
	sett.safe = use_valid(sett.safe, safe)
	sett.debug = use_valid(sett.debug, debug)

	sett.strip_len = use_valid(sett.strip_len, dim.strips.l)
	sett.strip_spacing = use_valid(sett.strip_spacing, strip_spacing)
	sett.ave_speed = use_valid(sett.ave_speed, ave_speed)

	sett.fuel_items_whitelist = use_valid(sett.fuel_items_whitelist, fuel_items_whitelist)
end

local function init(sett)
	if (sett) then
		valid_sett(sett)

		aggressive = sett.aggressive
		neat = sett.neat
		safe = sett.safe
		debug = sett.debug

		dim.strips.l = sett.strip_len
		strip_spacing = sett.strip_spacing
		ave_speed = sett.ave_speed

		fuel_items_whitelist = sett.fuel_items_whitelist
	end

	dist_from_chest = dim.base_room.l-1
	dist_across_shaft = dim.main_shaft.w-1

	strip_spacing = strip_spacing or 3
	strip_total_w = strip_spacing + dim.strips.w

	torch_spacing = torch_spacing or 6
	torch_spacing=torch_spacing+1
	torch_per_strip = dim.strips.l/torch_spacing

	ave_speed = ave_speed or 5
	max_place_tries = 10-ave_speed
	wait_period = 1-(ave_speed/10)
end

init()


--
-- Tables
--

local save_items = {}
local function add_save_item(item_fn, quantity, ui_name)
	if (quantity < 1) then return end
	local item = item_fn()
	if item then
		table.insert(save_items, {name=item, quantity=quantity})
	elseif ui_name then
		print("Don't have any ", ui_name)
	end
end

local get = {}

local tested_items = {}
local slots_mem = {}
local function reset_item_slots(set_saves, torches)
	print("Scanning slots..")

	tested_items = {}
	slots_mem = {}

	if set_saves then
		if not torches then torches = 64 end
		add_save_item(get.torch, torches, "torches")
		add_save_item(get.cobble, 64*(neat and 2 or 1), "cobblestone")
		add_save_item(get.fuel, 64, "fueling items")
		add_save_item(get.chest, 2, "chests")
		add_save_item(get.bucket, 3, "bucket")
	end
end


--
-- I/O
--

local function log(...)
	if debug then
		print(...)
	end
end

local function print_ln(...)
	for i=1, #arg, 1 do
		print(arg[i])
	end
end

local function clear()
	for i=1, 12, 1 do
		print()
	end

	print_ln("Miner - By Blueberrys", "")
end

local function input_bool()
	print("(y/n)")
	local answer = io.read():sub(1,1)
	return (answer=="y" or answer=="Y")
end

local function input_num()
	print("Number:")
	return tonumber(io.read()) or 0
end

local function wait_enter(msg)
	if not msg then msg = "continue" end
	print_ln("", "Press enter to " .. msg)
	io.read()
end

local function bool_str(bool)
	return (bool and "Yes" or "No")
end


--
-- File management
--

local function save_settings(settings)
	if fs.exists(settings_file) then
		fs.delete(settings_file)
	end

	local h = fs.open(settings_file, "w")
	h.write(textutils.serialize(settings))
	h.close()
end

local function load_settings()
	if fs.exists(settings_file) then
		local h = fs.open(settings_file, "r")
		local str = h.readAll()
		h.close()

		local sett = textutils.unserialize(str)
		clear()
		print_ln("Load previous settings?")
		if (input_bool()) then
			init(sett)
		else
			print_ln("", "Delete previous settings?")
			if (input_bool()) then
				fs.delete(settings_file)
			end
		end -- ask load
	end -- file exists
end -- load fn

--
-- Item Selection
--

local function is_selected(item_name)
	local info = t.getItemDetail()
	return info and (info.name == item_name)
end

local function select_item(item_name)
	-- -- Getting item detail takes more time than just selecting
	--	if is_selected(item_name) then
	--		return true
	--	end

	if slots_mem[item_name] then
		t.select(slots_mem[item_name])
		if is_selected(item_name) then
			return item_name
		else
			slots_mem[item_name] = nil
		end
	end

	-- local old_slot = t.getSelectedSlot()

	for i=1,16,1 do
		t.select(i)
		if is_selected(item_name) then
			slots_mem[item_name] = i
			return item_name
		end
	end

	-- t.select(old_slot)
	t.select(1)
	return false
end

local function use_tested_items(id, test_items)
	if not tested_items[id] then
		for _, item in pairs(test_items) do
			if (select_item(item)) then
				tested_items[id] = item
				break
			end
		end

		if not tested_items[id] then
			tested_items[id] = 0
		end
	end

	if (tested_items[id] ~= 0) then
		local sel_item = select_item(tested_items[id])
		if not sel_item then
			tested_items[id] = nil
		end
		return sel_item
	else
		return false
	end
end

get.torch = function()
	return use_tested_items("light", {
		items.torch,
	})
end

get.cobble = function()
	return use_tested_items("solid", {
		items.cobble,
		items.sandstone,
	})
end

get.chest = function()
	return use_tested_items("store", {
		items.chest,
	})
end

get.fuel = function()
	return use_tested_items("fuel", fuel_items_whitelist)
end

get.bucket = function()
	return use_tested_items("bucket", {
		items.bucket,
	})
end


--
-- Fuel Management
--

local function items_for_fuel(fuel, item_name)
	if not item_name then
		local info = t.getItemDetail()
		if info then
			item_name = info.name
		else
			return "Error"
		end
	end

	local items_needed = 0

	local divi = 0
	if item_name==items.coal then
		divi = 80
	elseif item_name == items.lava then
		divi = 1000
	elseif item_name == items.blz_rod then
		divi = 120
	end

	items_needed = fuel/divi

	return items_needed
end

-- Tested
local function calc_fuel_dig_shaft_total(l, w)
	if (not l) or (not w) then
		return 0
	end

	local fuel_needed = 0
		+ (1) -- up + 1
		+ (l*w) -- + l*w
		+ (1) -- down + 1
		+ ( (w%2~=0) and (l-1) or 0 ) -- if odd w, + l
		+ (w-1) -- + w
		+ (1) -- forward + 1

	return fuel_needed
end

-- Tested
local function calc_fuel_next_shaft(shaft_num)
	if not shaft_num then
		return 0
	end

	local fuel_needed = 0
		+ (dist_from_chest*2) -- to/from chest
		+ ((shaft_num*strip_total_w) * 2) -- to/from shaft

		+ (calc_fuel_dig_shaft_total(dim.strips.l, dim.strips.w) * 2) -- both shafts
		+ (dist_across_shaft * 2) -- across main shaft twice
	return fuel_needed
end

-- Tested
local function calc_fuel_setup(depth)
	local fuel_needed = 0
		+ (depth*2) -- stairs
		+ (calc_fuel_dig_shaft_total(dim.base_room.l, dim.base_room.w)) -- Base room
		+ (2) -- Chest
		+ (7) -- make roof space
		+ (dist_from_chest) -- move to wall

	return fuel_needed
end

-- Tested
local function calc_fuel_mine_strips(total_strips, start_strip)
	if not start_strip then start_strip = 1 end

	local fuel_needed = 0

	for i=start_strip, total_strips, 1 do
		fuel_needed = fuel_needed + calc_fuel_next_shaft(i) -- Strips
	end

	return fuel_needed
end

-- Tested
local function calc_fuel_strip_mine_total(total_strips)
	local fuel_needed = 0
		+ (calc_fuel_dig_shaft_total(total_strips*strip_total_w, dim.main_shaft.w)) -- Main shaft
		+ (dist_from_chest)--*(2-1) -- Fill chest, go back +2 (-1 for last trip)
		+ (calc_fuel_mine_strips(total_strips, 1))

	return fuel_needed
end

local function ensure_fuel(min, calc)
	local msg
	local msg_calc = {
		coal = "- Coal/Charcoal",
		blz = "- Blaze Rod",
		lava = "- Lava Bucket",
	}
	local function set_msg_calc(need)
		if calc then
			msg_calc = {
				coal = "[" .. math.ceil(items_for_fuel(need, items.coal)) .. "] - Coal/Charcoal",
				blz = "[" .. math.ceil(items_for_fuel(need, items.blz_rod)) .. "] - Blaze Rod",
				lava = "[" .. math.ceil(items_for_fuel(need, items.lava)) .. "] - Lava Bucket",
			}
		end
	end

	local fuel_max = t.getFuelLimit()
	local fuel_lvl = t.getFuelLevel()

	if not min then
		min = 1
		msg = "Out of fuel"
	else
		msg = "Low on fuel"
		set_msg_calc(min-fuel_lvl)
		fuel_max = min
	end

	if (type(fuel_lvl)=="number") then
		while (fuel_lvl<min) do
			print("Checking for fuel..")
			while (not get.fuel()) do
				clear()
				set_msg_calc(min-fuel_lvl)
				print_ln(msg
					, "(Required: " .. min .. ") (Current: " .. fuel_lvl .. ")" , ""
					, "Please ensure there is at least one of the following in the bots inventory:"
					, msg_calc.coal, msg_calc.blz, msg_calc.lava)

				wait_enter()
				tested_items.fuel = nil
			end

			local fuel_amt = math.min(items_for_fuel(fuel_max-fuel_lvl), 64)
			if fuel_amt < 1 then fuel_amt = 1 end
			t.refuel(fuel_amt)
			fuel_lvl = t.getFuelLevel()
		end
	end

	return true
end


--
-- Torch Management
--

local function calc_torches_setup(depth)
	local torches_needed = 0
		+ (depth/3) -- stairs
		+ (2) -- base room

	return torches_needed
end

local function calc_torches_strip_mine(total_strips)
	if not total_strips then
		return 64
	end

	local torches_needed = 0
		+ ((total_strips*strip_total_w)/torch_spacing) -- shaft
		+ (torch_per_strip * total_strips) -- strips
		+ 1 -- in case

	return torches_needed
end

local function ensure_torches(min)
	if not min then min = 64 end

	local have = 0

	for i=1, 16, 1 do
		t.select(i)
		local info = t.getItemDetail()
		if (info and info.name==items.torch) then
			have = have + info.count
		end
	end

	if (have < min) then
		clear()
		print_ln("Need more torches"
			, "(Required: " .. min .. ") (Current: " .. have .. ")")

		wait_enter()
	end
end

--
-- Inventory Management
--

local function move_to_start()
	if t.getItemCount() > 0 then
		for i=1, 16, 1 do
			if t.transferTo(i) then
				break
			end
		end
	end
end

local function move_to_end()
	if t.getItemCount() > 0 then
		for i=16, 1, -1 do
			if t.transferTo(i) then
				break
			end
		end
	end
end

local function sort_inventory()
	if (#save_items < 1) then
		return
	end

	print("Sorting inventory..")

	local save_slots = 0

	for i=1, #save_items, 1 do
		local stacks = math.ceil(save_items[i].quantity/64)
		save_slots = save_slots + stacks

		if (save_slots >= 16) then
			save_slots = 16
			break
		end
	end

	if (save_slots > 0) then
		-- Clear slots for save items
		for i=1, save_slots, 1 do
			t.select(i)
			move_to_end()
		end
	end

	-- Move save items to beginning
	for i=1, 16, 1 do
		t.select(i)
		local info = t.getItemDetail()

		if info then
			for _, item in ipairs(save_items) do
				if (info.name == item.name) then
					move_to_start()
				end
			end -- all save_items
		end -- if info
	end -- other slots

	t.select(1)
end

local function dump_all()
	for i=1, 16, 1 do
		t.select(i)
		t.drop()
	end

	t.select(1)
end

local function dump_junk(can_reset)
	if (#save_items < 1) then
		if can_reset then
			reset_item_slots(true)
		else
			dump_all()
			return
		end
	end

	local saved = {}

	for i=1, 16, 1 do
		t.select(i)
		local info = t.getItemDetail()

		local throw = true

		if info then
			for _, item in ipairs(save_items) do
				if (info.name == item.name) then
					if not saved[item.name] then
						saved[item.name] = 0
					end
					-- log("name: ", item.name, " amt: ", item.quantity)
					if (saved[item.name] < item.quantity) then
						saved[item.name] = (saved[item.name] + info.count)
						throw = false
						break -- Break save_items loop, continue slot loop
					end -- item 64
				end -- item name
			end -- all save_items

			if throw then
				t.drop()
			end
		end -- if info
	end -- for slots

	sort_inventory()
end

local function add_fuel_whitelist()
	for i=1, 16, 1 do
		t.select(i)
		local item = t.getItemDetail()
		if item and t.refuel(0) then
			local exists = false
			for _, w_item in pairs(fuel_items_whitelist) do
				if (w_item == item.name) then
					exists = true
					print_ln(item.name .. " is already in whitelist")
					break
				end
			end
			if not exists then
				table.insert(fuel_items_whitelist, item.name)
				print_ln(item.name .. " added to whitelist")
			end
		end
	end
end


--
-- Turning
--

local function turn_full()
	t.turnLeft()
	t.turnLeft()
end

local function swap_dir(dir)
	if dir==t.turnLeft then
		return t.turnRight
	else -- if dir==t.turnRight then
		return t.turnLeft
	end
end


--
-- Forced Digging
--

local function force_dig()
	while t.detect() do
		if not t.dig() then
			log("Can't dig forward")
			return false
		end
	end

	return true
end

local function force_digUp()
	while t.detectUp() do
		if not t.digUp() then
			log("Can't dig up")
			return false
		end
	end

	return true
end

local function force_digDown()
	while t.detectDown() do
		if not t.digDown() then
			log("Can't dig down")
			return false
		end
	end

	return true
end


--
-- Forced Movement
--

local function attack()
	return aggressive and t.attack()
end

local function attackUp()
	return aggressive and t.attackUp()
end

local function attackDown()
	return aggressive and t.attackDown()
end

local function force_forward()
	if not ensure_fuel() then
		return false
	end
	while (not t.forward()) do
		if not force_dig() then
			return false
		end
		attack()
	end
end

local function force_up()
	if not ensure_fuel() then
		return false
	end
	while (not t.up()) do
		if not force_digUp() then
			return false
		end
		attackUp()
	end
end

local function force_down()
	if not ensure_fuel() then
		return false
	end
	while (not t.down()) do
		if not force_digDown() then
			return false
		end
		attackDown()
	end
end

local function force_back()
	turn_full()
	force_forward()
	turn_full()
end


--
--  Forced Placement
--

local function force_place(give_up)
	local tries = 0

	while (not t.detect()) and (not t.place()) do
		log("Can't place forward. Attempt: " .. tries+1)
		attack()

		tries = tries + 1
		if give_up and (tries >= give_up) then
			break
		end

		sleep(wait_period)
	end
end

local function force_placeUp(give_up)
	local tries = 0

	while (not t.detectUp()) and (not t.placeUp()) do
		log("Can't place up. Attempt: " .. tries+1)
		attackUp()

		tries = tries + 1
		if give_up and (tries >= give_up) then
			break
		end

		sleep(wait_period)
	end
end

local function force_placeDown(give_up)
	local tries = 0

	while (not t.detectDown()) and (not t.placeDown()) do
		log("Can't place down. Attempt: " .. tries+1)
		attackDown()

		tries = tries + 1
		if give_up and (tries >= give_up) then
			break
		end

		sleep(wait_period)
	end
end


--
-- Filling
--

local function fill_floor()
	if (not t.detectDown()) and get.cobble() then
		force_placeDown(max_place_tries)
	end
end

local function fill_roof()
	if (not t.detectUp()) and get.cobble() then
		force_placeUp(max_place_tries)
	end
end

local function fill_wall(turn)
	if turn then
		turn()

		if (not t.detect()) and get.cobble() then
			force_place(max_place_tries)
		end

		swap_dir(turn)()
	end
end

local function fill_wall_torch(turn)
	if turn then

		turn()
		if (not t.detect()) and get.cobble() then
			force_place(max_place_tries)
		end

		if not get.torch() then
			swap_dir(turn)()
		else
			turn()
			force_place(max_place_tries)
			turn_full()
		end

	end
end


--
-- Digging Actions
--

local function mine_side(turn)
	turn()
	force_dig()
	swap_dir(turn)()
end

local function mine_forward_up()
	force_forward()
	force_digUp()
end

local function mine_forward_up_fill(turn, torch)
	mine_forward_up()

	fill_floor()

	if torch then
		fill_wall_torch(turn)
	else
		fill_wall(turn)
	end
end

local function mine_forward_down()
	force_forward()
	force_digDown()
end

local function mine_forward_down_fill(turn, torch)
	mine_forward_down()

	fill_roof()

	if torch then
		fill_wall_torch(turn)
	else
		fill_wall(turn)
	end
end

local function mine_uturn(turn, fill)
	turn()
	mine_forward_down_fill()
	if (fill) then
		force_place(max_place_tries)
	end
	turn()
end

local function test_pull_lava(use)
	-- return false if no bucket

	local function test(test_fn, pull_fn)
		if (not get.bucket()) then
			return false
		end

		local success, data = test_fn()
		if (success and (data.name == items.lava_block) and (data.metadata==0)) then
			pull_fn()
			if use then
				t.refuel()
			end
		end

		return true
	end

	if not test(t.inspect, t.place) then
		return false
	end
	if not test(t.inspectUp, t.placeUp) then
		return false
	end
	if not test(t.inspectDown, t.placeDown) then
		return false
	end

	return true
end


--
-- Strip Mining Actions
--

local function travel_chest_dist()
	for i=1, dist_from_chest, 1 do
		force_forward()
	end
end

local function move_fill_chest(strips_left)
	travel_chest_dist() -- to chest

	reset_item_slots((strips_left~=nil), calc_torches_strip_mine(strips_left))
	dump_junk()

	if strips_left and strips_left > 0 then
		turn_full()
		travel_chest_dist() -- back again
	end
end

local function travel_betwen_chest_shaft(num)
	for i=1, num*strip_total_w, 1 do
		force_forward()
	end
end

local function goto_strip_from_chest(num)
	travel_betwen_chest_shaft(num)
	t.turnRight()
end

local function travel_shaft_w()
	for i=1, (dist_across_shaft), 1 do
		force_forward()
	end
end

local function goto_chest_from_nextStrip(num)
	travel_shaft_w()
	t.turnRight()
	travel_betwen_chest_shaft(num)
end


--
-- Shaft Digging Process
--

local function dig_even(l, w, side, fill_sides, clear_lava)
	l = l-1 -- 0 index

	local turn = side
	local fill_turn = fill_sides and swap_dir(side)
	local fill_all = (w==1 and fill_sides)

	local even_w = (w%2 == 0)

	local torch_offset = (l%torch_spacing)
	local torch_end_wall = (w>torch_spacing)

	force_up()
	mine_forward_down_fill(fill_turn)
	if (w~=1) then mine_side(turn) end

	local put_torch_next = true

	for x=1, w, 1 do
		if (x~=1 and fill_turn) then
			fill_turn = nil
		end
		if (x==w and not fill_turn) then
			if even_w then
				fill_turn = fill_sides and swap_dir(side)
			else
				fill_turn = fill_sides and side
			end
		end

		for z=1, l, 1 do
			mine_forward_down_fill(fill_turn, put_torch_next)
			if fill_all then fill_wall(turn) end -- single file, fill both sides

			if fill_sides and get.torch() and z~=l then
				-- log("z:", z, " x:", x, " w:", w, " off:", torch_offset, " space:", torch_spacing)
				if (x==1) then -- first wall
					put_torch_next = ((z)%torch_spacing == 0)
				elseif not torch_end_wall then -- don't put on last wall
					put_torch_next = false
				elseif (x==w) then -- last wall
					put_torch_next = ((z-torch_offset)%torch_spacing == 0)
				end

				if (w~=1) and (x==1) and put_torch_next then
					-- first wall, not single file
					mine_side(turn)
				end
			end

			if clear_lava then
				test_pull_lava(true)
			end

		end -- for z

		if (x<w) then -- Not last
			mine_uturn(turn, (x==w-1))
			turn = swap_dir(turn)
		end
	end

	force_down()
end

local function dig_odd(l, w, side, fill_sides, clear_lava)
	dig_even(l, w, side, fill_sides, clear_lava)
	turn_full()

	local turn = side
	local fill_turn = fill_sides and swap_dir(side)
	local fill_all = (w==1 and fill_sides)

	for z=1, l-1, 1 do
		force_forward() -- back to z = 1
		fill_floor()
		fill_wall(fill_turn) -- won't work if not fill_sides
		if fill_all then fill_wall(turn) end -- single file, fill both sides
	end
end

local function dig_shaft(l, w, side, fill_sides, clear_lava)
	if not side then
		side = t.turnLeft
	end

	local even = (w % 2 == 0)

	if even then
		dig_even(l, w, side, fill_sides, clear_lava)
	else
		dig_odd(l, w, side, fill_sides, clear_lava)
	end

	if (w~=1) then
		side()
		for x=1, w-1, 1 do
			force_forward() -- back to x = 1
			fill_floor()
		end
		swap_dir(side)()
	end
	force_forward()
end


--
-- Stairs Digging Process
--

local function mine_single_stair()
	force_forward()
	force_digUp()
	force_down()

	fill_floor()
end

local function stairs_down(steps)
	for i=1, steps, 1 do
		mine_single_stair()
		if (i%3==0) then
			t.turnLeft()
			if get.torch() then
				force_placeUp(max_place_tries)
			end
		end
	end
end

local function make_roof_space()
	-- Uses 7 fuel
	turn_full()
	force_up()
	force_up()
	force_forward()
	force_forward()
	force_down()
	force_down()
	turn_full()
	force_forward()
end

local function place_chest(turn)
	-- Uses 2 fuel
	local turn_other = swap_dir(turn)

	-- place 1
	if get.chest() then
		force_place(max_place_tries)
	end

	-- place 2
	if get.chest() then
		turn()
		force_forward()
		turn_other()
		force_dig()
		force_place(max_place_tries)
		turn_other()
		force_forward()
		turn()
	end
end

local function make_base_room()
	dig_shaft(dim.base_room.l, dim.base_room.w, t.turnLeft, neat, safe)

	make_roof_space()

	place_chest(t.turnRight)

	reset_item_slots(true, 16*64) -- keep all torches
	dump_junk()

	turn_full()
	travel_chest_dist()

	if get.torch() then
		t.turnLeft()
		force_place(max_place_tries)
		t.turnRight()
	end
end


--
-- Strip Mining Process
--

local function mine_single_strip(strip_num, fill_sides, clear_lava)
	print("Starting shaft #", strip_num)
	goto_strip_from_chest(strip_num)
	dig_shaft(dim.strips.l, dim.strips.w, t.turnLeft, fill_sides, clear_lava)
	travel_shaft_w()
	dig_shaft(dim.strips.l, dim.strips.w, t.turnRight, fill_sides, clear_lava)
	goto_chest_from_nextStrip(strip_num)
end

local function strip_mine(strips)
	local len = strips*strip_total_w

	local old_torch_spacing = torch_spacing
	torch_spacing = strip_total_w
	dig_shaft(len, dim.main_shaft.w, t.turnLeft, neat, safe)
	torch_spacing = old_torch_spacing

	move_fill_chest(strips)

	for strip_num=1, strips, 1 do
		mine_single_strip(strip_num, neat, safe)
		move_fill_chest(strips-strip_num)
	end

	dump_all()
end


--
-- Startup
-- User Inputs
--

local function setup_start()
	clear()
	print("Enter current y coordinate")
	local current_y = input_num()
	print("Enter destination y coordinate")
	local dest_y = input_num()
	local depth = current_y-dest_y

	ensure_fuel(calc_fuel_setup(depth), true)

	local torches = calc_torches_setup(depth)
	ensure_torches(torches)
	sort_inventory()
	reset_item_slots(true, torches)

	if (not get.chest()) then
		clear()
		print("Need at least 1 chest")
		wait_enter()
		tested_items.store = nil
	end

	clear()
	print("Initializing")

	print("Making stairs..")
	stairs_down(depth)

	print("Making base room..")
	make_base_room()

	clear()
	print_ln("Miner ready!")
end

local function strip_mine_start()
	clear()
	print("Enter number of shafts")
	local strips = input_num()

	ensure_fuel(calc_fuel_strip_mine_total(strips), true)

	local torches
	if neat then
		torches = calc_torches_strip_mine(strips)
		ensure_torches(torches)
	end
	sort_inventory()
	reset_item_slots(true, torches)

	clear()
	print("Mining in progress!")

	strip_mine(strips)

	clear()
	print_ln("Mining complete"
		, "Thanks for using Miner!")
end

local function settings_start()
	local sett = {}

	clear()
	print_ln("Setting options:",""
		, "Aggressive bot? (Attack when blocked)"
		, "(Current: " .. bool_str(aggressive) .. ")")
	sett.aggressive = input_bool()

	print_ln("", "Neat bot? (Places walls and torches)"
		, "(Current: " .. bool_str(neat) .. ")")
	sett.neat = input_bool()

	print_ln("", "Safe bot? (Removes lava)"
		, "(Current: " .. bool_str(safe) .. ")")
	sett.safe = input_bool()

	print_ln("", "Debugging? (For development)"
		, "(Current: " .. bool_str(debug) .. ")")
	sett.debug = input_bool()

	print_ln("", "Set spacing and speed?")
	if (input_bool()) then
		print_ln("", "Side shafts length"
			, "(Current: " .. dim.strips.l .. ")")
		sett.strip_len = math.max(input_num(),1)

		print_ln("", "Spacing between shafts"
			, "(Current: " .. strip_spacing .. ")")
		sett.strip_spacing = math.max(input_num(), 1)

		print_ln("", "Ave. speed (1-10)"
			, "(Current: " .. ave_speed .. " )"
			, "Higher - Faster, less accurate"
			, "Lower - Slower, more accurate")
		sett.ave_speed = math.min(math.max(input_num(), 1), 10)
	end

	print_ln("", "Add items to fuel whitelist?")
	if (input_bool()) then
		print_ln("Place fueling items in bots inventory")
		wait_enter()
		add_fuel_whitelist()
		sett.fuel_items_whitelist = fuel_items_whitelist
	end

	print_ln("", "Confirm and save setttings?")
	if (input_bool()) then
		init(sett)
		save_settings(sett)
	end
end

local function debug_start()
	local function calc_fuels()
		reset_item_slots(true, 16*64)

		local estim = calc_fuel_setup(5)
		ensure_fuel(estim, true)

		local prev_lvl = t.getFuelLevel()
		stairs_down(5)
		make_base_room()

		local used = prev_lvl - t.getFuelLevel()
		print_ln("Estimate: " .. estim, "Used: " .. used)
	end

	-- print(test_pull_lava(true))

	-- calc_fuels()

	--	local prev_lvl = t.getFuelLevel()
	--	t.refuel(1)
	--	local more = t.getFuelLevel() - prev_lvl
	--	print(more)

	--	print("Enter num")
	--	print(items_for_fuel(io.read(), items.coal))

	-- dump_junk(true)
	-- sort_inventory()
end

--

local function startup()
	if not t then
		print_ln("Miner can only run on turtles")
		return
	end

	clear()
	print_ln("Welcome to Miner!", "")

	print_ln("Please ensure these items are loaded for a better experience:"
		, "- Coal, Lava, or Blaze Rods"
		, "- Torches"
		, "- Some Cobblestone"
		, "- 1-2 Chests"
		, "- 1-3 Empty Bucket")
	wait_enter()

	load_settings()

	local function pick_option()
		local opt

		clear()
		print_ln("Pick an option:"
			,"1 - Setup (Use this first)"
			,"2 - Start strip mine"
			,"3 - Settings")
		if debug then print("4 - Debug") end
		opt = input_num()

		if opt==1 then
			setup_start()
			wait_enter("start mining")
			strip_mine_start()
		elseif opt== 2 then
			strip_mine_start()
		elseif opt==3 then
			settings_start()
		elseif debug and opt==4 then
			debug_start()
		else
			opt = nil
		end

		return opt
	end

	local opt = pick_option()
	while (not opt or opt==3) do
		if not opt then print_ln("Invalid option", "") end
		opt = pick_option()
	end
end

startup()
