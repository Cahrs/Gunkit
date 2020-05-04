# gunkit

Adds an api to easily register advanced firearms within Minetest.

## Features
* Full auto guns
* Mags
* Mag Types
* Alternate fire mode
* ADS (Aim Down Sights)

## Usage (mods):
Registering a firearm:
`gunkit.register_firearm(name, firearm definition)`

Registering a mag:
`gunkit.register_mag(name, mag definition)`

Firearm Definition
------------------
Used by `gunkit.register_firearm`

```
{
    description = "Super cool Firearm",

    wield_scale = {x = 1, y = 1, z = 1},
    -- Firearm wield scale (see Minetest lua_api.txt).

    inventory_image = "your_firearm.png",

    mag_type = "smg",
    -- Type of mag the gun will load.

    sounds = {
        mag_load = "mymod:mag_load",
        -- Sound to be played when loading a mag.

        mag_drop = "mymod:mag_drop",
        -- Sound to be played when dropping a mag.

        fire_empty = "mymod:fire_empty",
        -- Sound to be played when firing a gun with an empty mag.
    },

    -- Table fields used for both fire and alt_fire.
    {
        bullet_texture = "my_bullet.png",
        -- Texture to be used for bullet projectiles.

        sounds = {
            fire = "mymod:fire",
            -- Sound to be played when firing the gun.

            shell_drop = "mymod:shell_drop",
            -- Sound to be played when firing the gun.

            fire_toggle = "mymod:fire_toggle",
            -- Sound to be played when swapping from this fire mode.
        },

        range = 60,
        -- Firearms bullet range.

        speed = 300,
        -- Speed of bullet projectiles, time to projectile hit is always range / speed.

        spread = 1,
        -- Max bullet spread (in degrees).

        dmg = 3,
        -- Bullet damage.

        shots = 1,
        -- Amount of bullets fired each shot.

        interval = 0.1,
        -- Time between shots (in seconds).

        zoom = 2,
        -- Level of zoom when using ADS (if applicable).
        
        zoom_time = 1,
        -- Time in seconds till fov hits fov*zoom
    },

    callbacks = {
        -- Table fields used for both fire and alt_fire
        fire = {
            on_fire = function({itemstack, user}),
            -- Function to be called when firearm is used.
            -- Return false to prevent default behavior.

            on_hit = function({itemstack, hitter, object}),
            -- Function to be called when an object is hit by a bullet.
            -- Return false to prevent default behavior.
        },

        on_drop_mag = function({itemstack, user}),
        -- Function to be called when a player attempts to drop a guns mag.
        -- Return false to prevent default behavior.

        on_load_mag = function({itemstack, user}),
        -- Function to be called when a player attempts to load a gun.
        -- Return false to prevent default behavior.
    },
}
```

Magazine Definition
-------------------
Used by `gunkit.register_mag`

```
{
    description = "Super cool gun magazine",

    inventory_image = "your_firearm_magazine.png",

    mag_type = "smg",
    -- Set this magazine as loadable by all guns with corresponding mag type.

    ammo = "mymod:bullet",
    -- Ammo used by this magazine (Itemstring).

    max_ammo = 120,
    -- Amount of ammo this magazine can hold.
}
```