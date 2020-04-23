# gunkit

Adds an api to easily register advanced firearms within Minetest.

## Features
    Full auto guns
    Mags
    Mag Types
    Alternate fire mode
    ADS (Aim Down Sights)

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
    -- Type of mag the gun will load

    -- Table fields used for both fire and alt_fire.
    {
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
    },

    callbacks = {
        -- Table fields used for both fire and alt_fire
        fire = {
            on_fire = function(itemstack, user),
            -- Function to be called when firearm is used.
            -- Return false to prevent default behavior.

            on_hit = function(itemstack, hitter, object),
            -- Function to be called when an object is hit by a bullet.
            -- Return false to prevent default behavior.
        },
    }
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