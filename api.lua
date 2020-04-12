gunkit = {}
gunkit.firing = {}
gunkit.timer = {}

--
-- Initate some helper functions
--

function get_random_float(lower, upper)
    return lower + math.random() * (upper - lower)
end

function get_table_size(tbl)
    local count = 0
    for k, v in pairs(tbl) do
        count = count + 1
    end
    return count
end

--
-- Lets define some functions to register guns/mags
--

function gunkit.register_firearm(name, def)
    --create some defaults
    local fire = {
        range = 30,
        speed = 1000,
        spread = 1,
        dmg = 7,
        shots = 1,
        interval = 0.15,
        zoom = 2,
    }

    if def.fire then
        for k, _ in pairs(def.fire) do
            fire[k] = def.fire[k] or fire[k]
        end
    end

    if not fire.bullet_texture or alt_fire and not alt_fire.bullet_texture then return end

    minetest.register_tool(name, {
        description = def.description,
        inventory_image = def.inventory_image,
        wield_scale = def.wield_scale or nil,
        range = 0,
        fire = fire,
        alt_fire = def.alt_fire or nil,
        mode = "fire",
        mag_type = def.mag_type or nil,
        callbacks = {fire = def.callbacks.fire or nil, alt_fire = def.callbacks.alt_fire or nil},

        on_use = function(itemstack, user, pointed_thing)
            local meta = itemstack:get_meta()
            
            if not meta:contains("mode") then
                meta:set_string("mode", "fire")
            end

            if not meta:contains("mag") then
                local gun = minetest.registered_items[itemstack:get_name()]

                local upper, upper_bullets, idx
                for index, stack in ipairs(user:get_inventory():get_list("main")) do
                    local meta = stack:get_meta()

                    if not stack:is_empty() and minetest.registered_items[stack:get_name()].mag_type == gun.mag_type then
                        if meta:contains("bullets") and (not upper or meta:get_int("bullets") > upper_bullets) then
                            upper, upper_bullets, idx = stack, meta:get_int("bullets"), index
                        end
                    end
                end

                if upper and upper_bullets and idx then
                    meta:set_string("mag", upper:get_name() .. "," .. upper_bullets)
                    itemstack:set_wear(65534 - (65534 / minetest.registered_items[upper:get_name()].max_ammo * upper_bullets) + 1)
                    user:get_inventory():set_stack("main", idx, nil)
                end
                return itemstack
            else
                local temp = meta:get_string("mag"):split(",")
                local mag, ammo = temp[1], tonumber(temp[2])

                if not gunkit.firing[user] and ammo > 0 then
                    gunkit.firing[user] = {stack = itemstack, wield_index = user:get_wield_index(), mag = {name = mag, ammo = ammo}}
                end
            end
        end,

        on_secondary_use = function(itemstack, user, pointed_thing)
            local meta = itemstack:get_meta()

            if not meta:get_string("mode") then
                meta:set_string("mode", "fire")
                return itemstack
            end

            if meta:contains("mag") then
                local temp = meta:get_string("mag"):split(",")
                local mag, ammo = temp[1], tonumber(temp[2])

                if not gunkit.firing[user] and ammo > 0 then
                    gunkit.firing[user] = {stack = itemstack, wield_index = user:get_wield_index(), mag = {name = mag, ammo = ammo}}
                end
            end
        end,

        on_drop = function(itemstack, dropper, pos)
            local meta = itemstack:get_meta()
            local wield = dropper:get_wield_index()
            local inv = dropper:get_inventory()

            --is the gun loaded?
            if meta:contains("mag") then
                local mag = meta:get_string("mag"):split(",")

                --is the mag empty?
                if tonumber(mag[2]) == 0 then
                    local stack = ItemStack(mag[1])
                    if inv:room_for_item("main", stack) then
                        inv:add_item("main", stack)
                    else
                        minetest.item_drop(stack, dropper, pos)
                    end
                    itemstack:set_wear(0)
                    meta:set_string("mag", "")
                
                --if not then swap fire mode
                elseif meta:contains("mode") then
                    meta:set_string("mode", gunkit.swap_mode(meta:get_string("mode")))
                    minetest.sound_play("toggle_fire", {pos = dropper:get_pos()})
                end
            else
                minetest.item_drop(itemstack, dropper, pos)
            end

            inv:set_stack("main", wield, itemstack)
        end,
    })
end

function gunkit.register_mag(name, def)
    minetest.register_tool(name, {
        description = def.description,
        inventory_image = def.inventory_image,
        mag_type = def.type,
        ammo = def.ammo,
        max_ammo = def.max_ammo,
    })
    
    minetest.register_craft({
        type = "shapeless",
        output = name,
        recipe = {name, def.ammo},
    })
    minetest.register_craft({
        type = "shapeless",
        output = name,
        recipe = {name},
    })

    minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
        local mag, ammo, meta, count
        local item = minetest.registered_items[name]

        --check for corresponding mag and ammo
        for k, stack in pairs(old_craft_grid) do
            if not mag and stack:get_name() == item.name then
                mag = stack
                meta = mag:get_meta()
                count = meta:get_int("bullets")
            elseif stack:get_name() == item.ammo then
                ammo = stack
            elseif not stack:is_empty() then
                return
            end
            if mag and ammo then
                break
            end
        end

        --empty mag
        if mag and not ammo then
            meta:set_int("bullets", 0)
            craft_inv:add_item("craft", {name = item.ammo, count = count})

        --fill mag if its not full
        elseif mag and ammo then
            local bullets = ammo:get_count()
            local needs = item.max_ammo - count

            if needs == 0 then 
                craft_inv:add_item("craft", {name = item.ammo})
                itemstack:get_meta():set_int("bullets", count)
                return
            end

            local use
            if needs >= bullets then
                use = count + bullets
                craft_inv:remove_item("craft", {name = item.ammo, count = bullets})
            else
                use = count + needs
                craft_inv:remove_item("craft", {name = item.ammo, count = (needs - 1)})
            end

            itemstack:get_meta():set_int("bullets", use)
            itemstack:set_wear(65534 - (65534 / item.max_ammo * use - 1))
        end

        return itemstack
    end)
end

--
-- Create some internal functions that we will call later
--

--this should be pretty obvious
function gunkit.swap_mode(str)
    if str == "fire" then
        return "alt_fire"
    elseif str == "alt_fire" then
        return "fire"
    end
end

--runs functions and returns returned bool, or true
function gunkit.check_bools(func, itemstack, user, obj)
    local bool = true

    if obj then
        bool = func(itemstack, user, obj)
    else
        bool = func(itemstack, user)
    end

    return bool
end

--[[get the end of a vector calculated from user pos, look dir, and item range.
    best not to touch the math here, im not completely sure how it works either]]
function gunkit.get_vector(user, p_pos, def)
    local cam = {z = user:get_look_dir(), x = minetest.yaw_to_dir(user:get_look_horizontal())}

    p_pos.y = p_pos.y + user:get_properties().eye_height or 1.625
    local dir = vector.multiply(minetest.yaw_to_dir(math.rad(1)), def.range)
    
    local e_pos = vector.add(p_pos, vector.multiply(cam.z, dir.z))
    e_pos = vector.add(e_pos, vector.multiply(cam.x, dir.x))

    return p_pos, e_pos
end

--handles raycasts for bullets, fire!
function gunkit.fire(user, stack, mag, p_pos, e_pos)
    local meta = stack:get_meta()
    local item = minetest.registered_items[stack:get_name()]
    local mode = meta:get_string("mode")

    local shots = item[mode].shots
    if shots > mag.ammo then
        shots = mag.ammo
    end

    mag.ammo = math.max(0, mag.ammo - item[mode].shots)
    stack:set_wear(65534 - (65534 / minetest.registered_items[mag.name].max_ammo * mag.ammo))

    if item[mode].bullet_sound then
        minetest.sound_play(item[mode].bullet_sound, {pos = user:get_pos()})
    end
    if item[mode].bullet_shell_sound then
        minetest.sound_play(item[mode].bullet_shell_sound, {pos = user:get_pos()})
    end

    for i = 1, shots do
        --3d offset calculated from bullet spread value (in degrees)
        e_pos = vector.apply(e_pos, function(n)
            return n + math.rad(get_random_float(-item[mode].spread, item[mode].spread)) * item[mode].range
        end)

        for pointed_thing in minetest.raycast(p_pos, e_pos, true, false) do
            minetest.add_particle({
                pos = p_pos,
                velocity = vector.multiply(vector.subtract(e_pos, p_pos), 2),
                expirationtime = 3,
                collisiondetection = true,
                collision_removal = true,
                size = 2,
                texture = item[mode].bullet_texture,
            })
            if pointed_thing.type == "node" then
                break
            end
            if pointed_thing.type == "object" and pointed_thing.ref ~= user then
                if not item.callbacks or not item.callbacks[mode] or not item.callbacks[mode].hit or gunkit.check_bools(item.callbacks[mode].hit, stack, user, pointed_thing.ref) then
                    pointed_thing.ref:punch(user, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = item[mode].dmg}})
                    break
                end
            end
        end
    end

    return mag
end

--
-- Globalstep to keep track of firing players and weapon cooldowns
--

minetest.register_globalstep(
    function(dtime)
        local current = minetest.get_us_time() / 100000
        
        --check users gun cooldowns
        for user, items in pairs(gunkit.timer) do
            for item, modes in pairs(items) do
                minetest.chat_send_all(dump(modes))
                for mode, time in pairs(modes) do
                    if current - time > minetest.registered_items[item][mode].interval then
                        --minetest.chat_send_all(dump(minetest.registered_items[item][mode].interval))
                        --minetest.chat_send_all(dump(time))
                        gunkit.timer[user][item][mode] = nil
                    end
                end
                if get_table_size(modes) == 0 then
                    gunkit.timer[user][item] = nil
                end
            end
            if get_table_size(items) == 0 then
                gunkit.timer[user] = nil
            end
        end

        --loop through users who are currently 'firing'
        for user, tbl in pairs(gunkit.firing) do
            local item = minetest.registered_items[user:get_wielded_item():get_name()]

            if item.name == tbl.stack:get_name() and user:get_wield_index() == tbl.wield_index then
                local name = item.name
                local meta = tbl.stack:get_meta()
                local mode = meta:get_string("mode")
                local keys = user:get_player_control()
                local wield_index = user:get_wield_index()

                if keys.LMB then
                    local timer = gunkit.timer[user]
                    --minetest.chat_send_all(dump(timer))

                    if (not timer or not timer[name] or not timer[name][mode]) or current - timer[name][mode] > item[mode].interval then
                        if not item.callbacks or not item.callbacks[mode] or not item.callbacks[mode][mode] or gunkit.check_bools(item.callbacks[mode][mode], tbl.stack, user) then
                            if meta:contains("mag") and tbl.mag.ammo > 0 then

                                local def = item[mode]
                                local p_pos, e_pos = gunkit.get_vector(user, user:get_pos(), def)

                                minetest.after(def.range / def.speed, gunkit.fire, user, tbl.stack, tbl.mag, p_pos, e_pos)

                                gunkit.timer[user] = gunkit.timer[user] or {}
                                gunkit.timer[user][name] = gunkit.timer[user][name] or {}
                                gunkit.timer[user][name][mode] = current

                                --minetest.chat_send_all(dump(gunkit.timer[user]))
                            end
                        end
                    end
                end

                local fov = user:get_fov()
                local zoom = item[mode].zoom or item[gunkit.swap_mode(meta:get_string("mode"))].zoom

                if keys.RMB and item[mode].zoom then
                    if fov == 0 then
                        fov = 1
                    end

                    if fov > 1 / zoom then
                        fov = fov - (1 / zoom) / 5
                        user:set_fov(fov, true)
                    end

                elseif fov ~= 0 then
                    if fov < 1 then
                        fov = fov + (1 / zoom) / 5
                        user:set_fov(fov, true)
                    else
                        user:set_fov(0)
                    end
                end

                if not keys.LMB and user:get_fov() == 0 then
                    --minetest.chat_send_all("removing user from table")
                    gunkit.firing[user] = nil
                    meta:set_string("mag", tbl.mag.name .. "," .. tbl.mag.ammo)
                    user:set_wielded_item(tbl.stack)
                end
            else
                gunkit.firing[user] = nil
                tbl.stack:get_meta():set_string("mag", tbl.mag.name .. "," .. tbl.mag.ammo)
                user:get_inventory():set_stack("main", tbl.wield_index, tbl.stack)
                user:set_fov(0)
            end
        end
    end
)