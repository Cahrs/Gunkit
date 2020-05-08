gunkit = {}
gunkit.firing = {}
gunkit.timer = {}

--Interval for gun-cooldown checks
gunkit.count_interval = 0.1

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
    --Check if mag_type and bullet textures are specified

    if not def.mag_type or not def.fire.bullet_texture or def.alt_fire
    and not def.alt_fire.bullet_texture then return end

    --Define some default values
    local fire = {
        range = 60,
        speed = 300,
        spread = 1,
        dmg = 7,
        shots = 1,
        interval = 0.15,
        zoom = 2,
        zoom_time = 2,
    }

    --Use defaults for any value not set if def.fire is present
    if def.fire then
        for k, value in pairs(def.fire) do
            fire[k] = value
        end
    end

    --Get callbacks table
    local calls = def.callbacks

    --Fancy item descrips
    local descrip = {
        def.description,
        minetest.colorize("#dbc217", "Mag type: " .. def.mag_type),
    }

    minetest.register_tool(name, {
        description = table.concat(descrip, "\n"),
        inventory_image = def.inventory_image,
        wield_scale = def.wield_scale or nil,

        --[[We set range to 0 so that the gun cant interact with
            nodes when a user tries to ADS (Aim Down Sights)]]
        range = 0,

        --Fields defined by the api

        fire = fire,
        alt_fire = def.alt_fire or nil,
        mag_type = def.mag_type,

        sounds = def.sounds or nil,

        callbacks = calls or nil,

        on_use = function(itemstack, user, pointed_thing)
            --Get the guns meta
            local meta = itemstack:get_meta()

            --Get the itemdef of the wielded firearm
            local gun = minetest.registered_items[name]

            --Set the guns fire mode if not already done
            if not meta:contains("mode") then
                meta:set_string("mode", "fire")
            end

            --Check if gun is loaded
            if not meta:contains("mag") and (not calls or not calls.on_load_mag
            or calls.on_load_mag({user = user, itemstack = itemstack})) then

                --[[Search through the players inv looking for the mag with the most ammo,
                    mag must have > 0 bullets]]
                local upper, upper_bullets, index

                for idx, stack in ipairs(user:get_inventory():get_list("main")) do
                    --Get stack meta
                    local stack_meta = stack:get_meta()

                    --Check if stack exists and if it 'contains bullets'
                    if not stack:is_empty() and stack_meta:contains("bullets") then
                        --Get meta field and itemdef
                        local bullets = stack_meta:get_int("bullets")
                        local itemdef = minetest.registered_items[stack:get_name()]

                        if bullets > 0 and itemdef.mag_type == gun.mag_type
                        and (not upper or bullets > upper_bullets) then

                            upper, upper_bullets, index = stack, bullets, idx
                        end
                    end
                end

                --Load the mag
                if upper and upper_bullets and index then
                    if gun.sounds and gun.sounds.mag_load then
                        minetest.sound_play(gun.sounds.mag_load, {object = user})
                    end

                    meta:set_string("mag", upper:get_name() .. "," .. upper_bullets)
                    itemstack:set_wear(upper:get_wear())
                    user:get_inventory():set_stack("main", index, nil)
                end

                return itemstack

            --Fire the gun
            else
                local temp = itemstack:get_meta():get_string("mag"):split(",")
                local mag, ammo = temp[1], tonumber(temp[2])

                if ammo > 0 then
                    if not gunkit.firing[user] then
                        --Add to firing queue
                        gunkit.firing[user] = {
                            stack = itemstack,
                            wield_index = user:get_wield_index(),
                            mag = {name = mag, ammo = ammo}
                        }
                    end
                elseif gun.sounds and gun.sounds.fire_empty then
                    minetest.sound_play(gun.sounds.fire_empty, {object = user})
                end
            end
        end,

        on_secondary_use = function(itemstack, user, pointed_thing)
            --Get the guns meta
            local meta = itemstack:get_meta()

            --Set the guns fire mode if not already done
            if not meta:contains("mode") then
                meta:set_string("mode", "fire")
            end

            --Check if gun is loaded
            if meta:contains("mag") then
                local temp = meta:get_string("mag"):split(",")
                local mag, ammo = temp[1], tonumber(temp[2])

                if ammo > 0 and not gunkit.firing[user] then
                    --Get mode def
                    local mode_def = minetest.registered_items[itemstack:get_name()][meta:get_string("mode")]

                    if user:get_fov() == 0 and mode_def.zoom and mode_def.zoom_time then
                        user:set_fov(1 / mode_def.zoom, true, mode_def.zoom_time)
                    end

                    --Add to firing queue
                    gunkit.firing[user] = {
                        stack = itemstack,
                        wield_index = user:get_wield_index(),
                        mag = {name = mag, ammo = ammo}
                    }
                end
            end
        end,

        on_drop = function(itemstack, dropper, pos)
            local meta = itemstack:get_meta()
            local wield = dropper:get_wield_index()
            local inv = dropper:get_inventory()
            local gun = minetest.registered_items[itemstack:get_name()]

            --Check if gun is loaded
            if meta:contains("mag") then
                local temp = meta:get_string("mag"):split(",")
                local mag, ammo = temp[1], tonumber(temp[2])

                --Check if mag is empty
                if ammo == 0 and (not calls or not calls.on_drop_mag
                or calls.on_drop_mag({user = dropper, itemstack = itemstack})) then

                    if gun.sounds and gun.sounds.mag_drop then
                        minetest.sound_play(gun.sounds.mag_drop, {object = dropper})
                    end

                    local stack = ItemStack(mag)
                    stack:set_wear(65534)

                    if inv:room_for_item("main", stack) then
                        inv:add_item("main", stack)
                    else
                        minetest.item_drop(stack, dropper, pos)
                    end

                    itemstack:set_wear(0)
                    meta:set_string("mag", "")

                --If not then swap fire mode
                elseif meta:contains("mode") then
                    meta:set_string("mode", gunkit.swap_mode(dropper, gun, meta:get_string("mode")))
                end

            --Otherwise drop gun
            else
                minetest.item_drop(itemstack, dropper, pos)
            end

            inv:set_stack("main", wield, itemstack)
        end,
    })
end

function gunkit.register_mag(name, def)
    --Fancy item descrips
    local descrip = {
        def.description,
        minetest.colorize("#dbc217", "Mag type: " .. def.mag_type),
        minetest.colorize("#40c3cb", "Ammo: " .. def.ammo),
    }

    minetest.register_tool(name, {
        description = table.concat(descrip, "\n"),
        inventory_image = def.inventory_image,

        --Fields defined by the api

        mag_type = def.mag_type,
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
        output = name .. " 1 65534",
        recipe = {name},
    })

    minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
        local mag, ammo, meta, count

        --Check for corresponding mag and ammo
        for idx, stack in pairs(old_craft_grid) do
            --Get stack name
            local stack_name = stack:get_name()

            if mag and ammo then
                break
            elseif not mag and stack_name == name then
                mag = stack
                meta = mag:get_meta()
                count = meta:get_int("bullets")
            elseif not ammo and stack_name == def.ammo then
                ammo = stack
            end
        end

        --Empty mag
        if mag and not ammo then
            meta:set_int("bullets", 0)
            craft_inv:add_item("craft", {name = def.ammo, count = count})

        --Fill empty mag
        elseif mag and ammo then
            local bullets = ammo:get_count()
            local needs = def.max_ammo - count

            if needs == 0 then
                craft_inv:add_item("craft", {name = def.ammo})
                itemstack:get_meta():set_int("bullets", count)

                return
            else
                local use

                if needs > bullets then
                    use = bullets
                else
                    use = needs
                end

                craft_inv:remove_item("craft", {name = def.ammo, count = use})
                itemstack:get_meta():set_int("bullets", count + use)
                itemstack:set_wear(65534 - (65534 / def.max_ammo * (count + use - 1)))
            end
        end

        return itemstack
    end)
end

--
-- Create some internal functions that we will call later
--

--This should be pretty obvious
function gunkit.swap_mode(user, def, mode)
    local modes = {fire = "alt_fire", alt_fire = "fire"}

    --Get alternate mode
    local alt_mode = modes[mode]

    --Check for alternate mode
    if def[alt_mode] then
        local sounds = def[mode].sounds

        if sounds.fire_toggle then
            minetest.sound_play(sounds.fire_toggle, {object = user})
        end

        return alt_mode
    else

        return mode
    end
end

--[[get the end of a vector calculated from user pos, look dir, and item range.
    best not to touch the math here, im not completely sure how it works either]]
function gunkit.get_vector(user, p_pos, def)
    --Add eyeheight offset
    p_pos.y = p_pos.y + user:get_properties().eye_height or 1.625

    local cam = {
        x = minetest.yaw_to_dir(user:get_look_horizontal()),
        z = user:get_look_dir()
    }

    local dir = vector.multiply(minetest.yaw_to_dir(math.rad(1)), def.range)

    local e_pos = vector.add(p_pos, vector.multiply(cam.z, dir.z))
    e_pos = vector.add(e_pos, vector.multiply(cam.x, dir.x))

    return p_pos, e_pos
end

--Handle weapon firing
function gunkit.fire(user, stack, mag, p_pos, e_pos)
    local mode = stack:get_meta():get_string("mode")
    local def = minetest.registered_items[stack:get_name()]
    local mode_def = def[mode]

    local shots = mode_def.shots
    if shots > mag.ammo then
        shots = mag.ammo
    end

    mag.ammo = math.max(0, mag.ammo - shots)
    stack:set_wear(65534 - (65534 / minetest.registered_items[mag.name].max_ammo * mag.ammo))

    --Get mode_def sounds table
    local sounds = mode_def.sounds

    --Check if table exists
    if sounds then
        if sounds.fire then
            minetest.sound_play(sounds.fire, {pos = p_pos})
        end
        if sounds.shell_drop then
            minetest.sound_play(sounds.shell_drop, {pos = p_pos})
        end
    end

    for i = 1, shots do
        --3d bullet spread (in degrees)
        e_pos = vector.apply(e_pos, function(n)
            return n + math.rad(get_random_float(-mode_def.spread, mode_def.spread)) * mode_def.range
        end)

        minetest.add_particle({
            pos = p_pos,
            velocity = vector.multiply(vector.direction(p_pos, e_pos), 80),
            expirationtime = 3,
            collisiondetection = true,
            collision_removal = true,
            size = 2,
            texture = mode_def.bullet_texture,
        })

        for pointed_thing in minetest.raycast(p_pos, e_pos, true, false) do
            if pointed_thing.type == "node" then
                break

            elseif pointed_thing.type == "object" and pointed_thing.ref ~= user then
                local luaent = pointed_thing.ref:get_luaentity()

                if not luaent or not luaent.name:find("builtin") then
                    local calls = def.callbacks

                    if not calls or not calls[mode] or not calls[mode].on_hit
                    or calls[mode].on_hit({itemstack = stack, user = user, obj = pointed_thing.ref}) then

                        pointed_thing.ref:punch(user, 1.0, {full_punch_interval = 1.0, damage_groups = {fleshy = mode_def.dmg}})
                        break
                    end
                end
            end
        end
    end

    return mag
end

--
-- Globalstep to keep track of firing players and weapon cooldowns
--

local counter = 0

minetest.register_globalstep(
    function(dtime)
        local current = minetest.get_us_time() / 1000000

        counter = counter + dtime

        if counter > gunkit.count_interval then
            --Check users gun cooldowns
            for user, items in pairs(gunkit.timer) do
                for item, modes in pairs(items) do
                    for mode, time in pairs(modes) do
                        if current - time > minetest.registered_items[item][mode].interval then
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

            counter = 0
        end

        --Loop through currently firing users
        for user, tbl in pairs(gunkit.firing) do
            local def = minetest.registered_items[user:get_wielded_item():get_name()]

            if def.name == tbl.stack:get_name() and user:get_wield_index() == tbl.wield_index then
                local name = def.name
                local meta = tbl.stack:get_meta()
                local mode = meta:get_string("mode")
                local mode_def = def[mode]
                local keys = user:get_player_control()

                if keys.LMB then
                    local timer = gunkit.timer[user]
                    local calls = def.callbacks

                    if (not timer or not timer[name] or not timer[name][mode] or current - timer[name][mode] > mode_def.interval)
                    and (not calls or not calls[mode] or not calls[mode].on_fire or calls[mode].on_fire({itemstack = tbl.stack, user = user})) then
                        if meta:contains("mag") and tbl.mag.ammo > 0 then

                            local p_pos, e_pos = gunkit.get_vector(user, user:get_pos(), mode_def)

                            minetest.after(mode_def.range / mode_def.speed, gunkit.fire, user, tbl.stack, tbl.mag, p_pos, e_pos)

                            gunkit.timer[user] = gunkit.timer[user] or {}
                            gunkit.timer[user][name] = gunkit.timer[user][name] or {}
                            gunkit.timer[user][name][mode] = current
                        end
                    end
                end

                local fov = user:get_fov()
                local zoom = mode_def.zoom
                local zoom_time = mode_def.zoom_time

                if zoom and zoom_time then
                    if not keys.RMB and fov ~= 0 then
                        user:set_fov(0, true, zoom_time)
                    elseif keys.RMB and fov == 0 then
                        user:set_fov(1 / zoom, true, zoom_time)
                    end
                end

                if not keys.LMB and not keys.RMB then
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