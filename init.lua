minetest.register_privilege("jailbox",
    {
        description = "Player can encapsulate an area inside an impenetrable and indestructible box.",
        give_to_singleplayer = false,
    }
)

local jailbox = {}

-- Save jailbox to a file
local savebox = function()
	local datastr = minetest.serialize(jailbox)
	if not datastr then
		minetest.log("error", "[jailbox] Failed to serialize jailbox data!")
		return
	end
	local file, err = io.open(minetest.get_worldpath() .. "/jailbox", "w")
	if err then
		return err
	end
	file:write(datastr)
	file:close()
end

-- Load jailbox from file
local loadbox = function()
	local file, err = io.open(minetest.get_worldpath() .. "/jailbox", "r")
	if err then
		jailbox = jailbox or {}
		return err
	end
	jailbox = minetest.deserialize(file:read("*a"))
	if type(jailbox) ~= "table" then
		jailbox = {}
	else
		minetest.log("info", "[jailbox] Jailbox loaded from file.")
	end
	file:close()
end

loadbox()

minetest.register_node("jailbox:solid_wall", {
	description = "Solid unbreakable wall",
	stack_max = 99,
	tiles = {"solid.png"},
	drop = "",
	paramtype = "light",
	light_source = 4,
	post_effect_color = {a=255, r=0, g=0, b=0},
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("jailbox:invis_wall", {
	description = "Invisible unbreakable wall",
	stack_max = 99,
	inventory_image = "invis.png",
	drop = "",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	drop = "",
	groups = {unbreakable = 1, not_in_creative_inventory = 1},
})

local nodeset = function(pos)
	local node = minetest.get_node(pos)
	local pickle = minetest.serialize({ name = node.name, param1 = node.param1, param2 = node.param2 })
	local meta = minetest.get_meta(pos)
	meta:set_string("old", pickle)
	if node.name == "air" or node.name == "ignore" then
		node.name = "jailbox:invis_wall"
	else
		node.name = "jailbox:solid_wall"
	end
	minetest.swap_node(pos, node)
end

local nodeunset = function(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local pickle = minetest.deserialize(meta:get_string("old"))
	if pickle then
		node.name = pickle.name
		node.param1 = pickle.param1
		node.param2 = pickle.param2
		meta:set_string("old", nil)
	else
		--fallback
		if node.name == "jailbox:invis_wall" then
			node.name = "air"
		elseif node.name == "jailbox:solid_wall" then
			node.name = "default:dirt"
		end
	end
	minetest.set_node(pos, node)
end

minetest.register_chatcommand("jailbox_set",
    {
        params = "<radius(max=50)>",
        description = "Create an impenetrable and indestructible box around player's position.",
        privs = { jailbox = true },
        func = function(name, param)
			if not param then
				minetest.chat_send_player(name, "---Error: Argument missing (radius).")
				return
			end
			if not tonumber(param) then
				minetest.chat_send_player(name, "---Error: Radius should be a number.")
				return
			end
			if tonumber(param) > 50 then
				minetest.chat_send_player(name, "---Error: Radius too big, should not exceed 50.")
				return
			end
			if #jailbox > 0 then
				minetest.chat_send_player(name, "---Error: Jailbox already exists. Only one is allowed.")
				return
			end
			minetest.chat_send_player(name, "---Erecting jailbox with radius " .. param .. ". It takes time, please be patient.")
			local center = minetest.get_player_by_name(name):getpos()
			local target = minetest.get_player_by_name(name):get_player_name()
			local radius = tonumber(param)
			local pos1 = { x = math.floor(center.x) - radius, y = math.floor(center.y) - radius, z = math.floor(center.z) - radius }
			local pos2 = { x = math.floor(center.x) + radius, y = math.floor(center.y) + radius, z = math.floor(center.z) + radius }
			-- try force loading map chunks by getting corners first
			minetest.get_node({ x = pos1.x, y = pos1.y, z = pos1.z })
			minetest.get_node({ x = pos1.x, y = pos1.y, z = pos2.z })
			minetest.get_node({ x = pos2.x, y = pos1.y, z = pos2.z })
			minetest.get_node({ x = pos2.x, y = pos1.y, z = pos1.z })
			minetest.get_node({ x = pos1.x, y = pos2.y, z = pos1.z })
			minetest.get_node({ x = pos1.x, y = pos2.y, z = pos2.z })
			minetest.get_node({ x = pos2.x, y = pos2.y, z = pos2.z })
			minetest.get_node({ x = pos2.x, y = pos2.y, z = pos1.z })
			jailbox = { pos1, pos2 }
			-- xy plane 1
			for posy = pos1.y + 1, pos2.y - 1 do
				for posx = pos1.x, pos2.x do
					nodeset({ x = posx, y = posy, z = pos1.z })
				end
			end
			-- zy plane 1
			for posy = pos1.y + 1, pos2.y - 1 do
				for posz = pos1.z + 1, pos2.z - 1 do
					nodeset({ x = pos1.x, y = posy, z = posz })
				end
			end
			-- xy plane 2
			for posy = pos1.y + 1, pos2.y - 1 do
				for posx = pos1.x, pos2.x do
					nodeset({ x = posx, y = posy, z = pos2.z })
				end
			end
			-- zy plane 2
			for posy = pos1.y + 1, pos2.y - 1 do
				for posz = pos1.z + 1, pos2.z - 1 do
					nodeset({ x = pos2.x, y = posy, z = posz })
				end
			end
			-- zx plane 2 (bottom)
			for posz = pos1.z, pos2.z do
				for posx = pos1.x, pos2.x do
					nodeset({ x = posx, y = pos1.y, z = posz })
				end
			end
			-- zx plane 1 (top)
			for posz = pos1.z, pos2.z do
				for posx = pos1.x, pos2.x do
					nodeset({ x = posx, y = pos2.y, z = posz })
				end
			end
			savebox()
			minetest.chat_send_all("---Jailbox erected.")
        end,
    }
)

minetest.register_chatcommand("jailbox_unset",
    {
        params = "",
        description = "Remove the created jailbox.",
        privs = { jailbox = true },
        func = function(name, param)
			if #jailbox == 0 then
				minetest.chat_send_player(name, "---Error: Jailbox does not exist.")
			else
				minetest.chat_send_player(name, "---Removing jailbox.")
				local pos1 = jailbox[1]
				local pos2 = jailbox[2]
				-- xy plane 1
				for posy = pos1.y + 1, pos2.y - 1 do
					for posx = pos1.x, pos2.x do
						nodeunset({ x = posx, y = posy, z = pos1.z })
					end
				end
				-- zy plane 1
				for posy = pos1.y + 1, pos2.y - 1 do
					for posz = pos1.z + 1, pos2.z - 1 do
						nodeunset({ x = pos1.x, y = posy, z = posz })
					end
				end
				-- xy plane 2
				for posy = pos1.y + 1, pos2.y - 1 do
					for posx = pos1.x, pos2.x do
						nodeunset({ x = posx, y = posy, z = pos2.z })
					end
				end
				-- zy plane 2
				for posy = pos1.y + 1, pos2.y - 1 do
					for posz = pos1.z + 1, pos2.z - 1 do
						nodeunset({ x = pos2.x, y = posy, z = posz })
					end
				end
				-- zx plane 2 (bottom)
				for posz = pos1.z, pos2.z do
					for posx = pos1.x, pos2.x do
						nodeunset({ x = posx, y = pos1.y, z = posz })
					end
				end
				-- zx plane 1 (top)
				for posz = pos1.z, pos2.z do
					for posx = pos1.x, pos2.x do
						nodeunset({ x = posx, y = pos2.y, z = posz })
					end
				end
				jailbox = {}
				savebox()
				minetest.chat_send_all("---Jailbox removed.")
			end
        end,
    }
)

