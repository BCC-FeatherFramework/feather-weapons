WeaponComponentCatalog = WeaponComponentCatalog or {}

-- Model-specific component categories, keyed by native weapon name.
WeaponComponentCatalog.models = {
    ["WEAPON_REVOLVER_CATTLEMAN"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_REVOLVER_CATTLEMAN_BARREL_SHORT",     label = "Short Barrel" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG",      label = "Long Barrel" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_BARREL_LEGENDARY", label = "Legendary Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP",            label = "Standard Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL",      label = "Pearl Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_EBONY",      label = "Ebony Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_IRONWOOD",   label = "Ironwood Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_GOOD_HONOR", label = "Good Honor Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_BURLED",     label = "Burled Grip" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_GRIP_LEGENDARY",  label = "Legendary Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REVOLVER_CATTLEMAN_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_SHORTARM_ROLE_ENGRAVING_CATTLEMAN_LEGENDARY", label = "Legendary Engraving" },
            }
        },
    },
    ["WEAPON_REVOLVER_DOUBLEACTION"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP",           label = "Standard Grip" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_EBONY",     label = "Ebony Grip" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_IRONWOOD",  label = "Ironwood Grip" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_PEARL",     label = "Pearl Grip" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BAD_HONOR", label = "Bad Honor Grip" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BURLED",    label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_WIDE",   label = "Wide Sight" },
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_NARROW", label = "Narrow Sight" },
            }
        },
    },
    ["WEAPON_REVOLVER_DOUBLEACTION_EXOTIC"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_DOUBLEACTION_GRIP_EXOTIC", label = "Exotic Grip" },
            }
        },
    },
    ["WEAPON_REVOLVER_SCHOFIELD"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT",  label = "Short Barrel" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_BARREL_LONG",   label = "Long Barrel" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_BARREL_BOUNTY", label = "Bounty Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP_PEARL",    label = "Pearl Grip" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP_EBONY",    label = "Ebony Grip" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP_BOUNTY",   label = "Bounty Grip" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REVOLVER_SCHOFIELD_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE",   label = "Wide Sight" },
                { name = "COMPONENT_REVOLVER_SCHOFIELD_SIGHT_BOUNTY", label = "Bounty Sight" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_SHORTARM_FRAME_ENGRAVING_SCHOFIELD_BOUNTY", label = "Bounty Engraving" },
            }
        },
    },
    ["WEAPON_PISTOL_MAUSER"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_PISTOL_MAUSER_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_PISTOL_MAUSER_BARREL_LONG",  label = "Long Barrel" },
                { name = "COMPONENT_PISTOL_MAUSER_BARREL_AZTEC", label = "Aztec Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_PISTOL_MAUSER_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_PISTOL_MAUSER_GRIP_PEARL",    label = "Pearl Grip" },
                { name = "COMPONENT_PISTOL_MAUSER_GRIP_EBONY",    label = "Ebony Grip" },
                { name = "COMPONENT_PISTOL_MAUSER_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_PISTOL_MAUSER_GRIP_BURLED",   label = "Burled Grip" },
                { name = "COMPONENT_PISTOL_MAUSER_GRIP_AZTEC",    label = "Aztec Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_PISTOL_MAUSER_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_PISTOL_MAUSER_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_PISTOL_MAUSER_CLIP",       label = "Standard Clip" },
                { name = "COMPONENT_PISTOL_MAUSER_CLIP_EMPTY", label = "Empty Clip" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_SHORTARM_ROLE_ENGRAVING_MAUSER_AZTEC", label = "Aztec Engraving" },
            }
        },
    },
    ["WEAPON_PISTOL_SEMIAUTO"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_PISTOL_SEMIAUTO_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_PISTOL_SEMIAUTO_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_GRIP_PEARL",    label = "Pearl Grip" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_GRIP_EBONY",    label = "Ebony Grip" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_PISTOL_SEMIAUTO_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_PISTOL_SEMIAUTO_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_PISTOL_SEMIAUTO_CLIP", label = "Standard Clip" },
            }
        },
    },
    ["WEAPON_PISTOL_VOLCANIC"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_PISTOL_VOLCANIC_BARREL_SHORT",     label = "Short Barrel" },
                { name = "COMPONENT_PISTOL_VOLCANIC_BARREL_LONG",      label = "Long Barrel" },
                { name = "COMPONENT_PISTOL_VOLCANIC_BARREL_COLLECTOR", label = "Collector Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP",           label = "Standard Grip" },
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP_PEARL",     label = "Pearl Grip" },
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP_EBONY",     label = "Ebony Grip" },
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP_IRONWOOD",  label = "Ironwood Grip" },
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP_COLLECTOR", label = "Collector Grip" },
                { name = "COMPONENT_PISTOL_VOLCANIC_GRIP_BURLED",    label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_PISTOL_VOLCANIC_SIGHT_NARROW",    label = "Narrow Sight" },
                { name = "COMPONENT_PISTOL_VOLCANIC_SIGHT_WIDE",      label = "Wide Sight" },
                { name = "COMPONENT_PISTOL_VOLCANIC_SIGHT_COLLECTOR", label = "Collector Sight" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_FRAME_ENGRAVING_VOLCANIC_COLLECTOR", label = "Collector Engraving" },
            }
        },
    },
    ["WEAPON_PISTOL_M1899"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_PISTOL_M1899_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_PISTOL_M1899_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_PISTOL_M1899_CLIP", label = "Standard Clip" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_PISTOL_M1899_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_PISTOL_M1899_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_PISTOL_M1899_GRIP_PEARL",    label = "Pearl Grip" },
                { name = "COMPONENT_PISTOL_M1899_GRIP_EBONY",    label = "Ebony Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_PISTOL_M1899_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_PISTOL_M1899_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
    },
    ["WEAPON_REVOLVER_LEMAT"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_REVOLVER_LEMAT_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_REVOLVER_LEMAT_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_LEMAT_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_REVOLVER_LEMAT_GRIP_PEARL",    label = "Pearl Grip" },
                { name = "COMPONENT_REVOLVER_LEMAT_GRIP_EBONY",    label = "Ebony Grip" },
                { name = "COMPONENT_REVOLVER_LEMAT_GRIP_IRONWOOD", label = "Ironwood Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REVOLVER_LEMAT_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REVOLVER_LEMAT_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
    },
    ["WEAPON_REVOLVER_NAVY"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_REVOLVER_NAVY_BARREL_SHORT",     label = "Short Barrel" },
                { name = "COMPONENT_REVOLVER_NAVY_BARREL_LONG",      label = "Long Barrel" },
                { name = "COMPONENT_REVOLVER_NAVY_BARREL_CROSSOVER", label = "Crossover Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REVOLVER_NAVY_GRIP",           label = "Standard Grip" },
                { name = "COMPONENT_REVOLVER_NAVY_GRIP_IRONWOOD",  label = "Ironwood Grip" },
                { name = "COMPONENT_REVOLVER_NAVY_GRIP_PEARL",     label = "Pearl Grip" },
                { name = "COMPONENT_REVOLVER_NAVY_GRIP_EBONY",     label = "Ebony Grip" },
                { name = "COMPONENT_REVOLVER_NAVY_GRIP_CROSSOVER", label = "Crossover Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REVOLVER_NAVY_SIGHT_NARROW",    label = "Narrow Sight" },
                { name = "COMPONENT_REVOLVER_NAVY_SIGHT_WIDE",      label = "Wide Sight" },
                { name = "COMPONENT_REVOLVER_NAVY_SIGHT_CROSSOVER", label = "Crossover Sight" },
            }
        },
    },
    ["WEAPON_REPEATER_CARBINE"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REPEATER_CARBINE_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_REPEATER_CARBINE_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_REPEATER_CARBINE_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_REPEATER_CARBINE_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REPEATER_CARBINE_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REPEATER_CARBINE_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_REPEATER_CARBINE_CLIP", label = "Standard Clip" },
            }
        },
        TUBE = {
            label = "Tube",
            items = {
                { name = "COMPONENT_REPEATER_CARBINE_TUBE", label = "Standard Tube" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_REPEATER_CARBINE_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_REPEATER_CARBINE_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_REPEATER_CARBINE_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_REPEATER_CARBINE_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_REPEATER_CARBINE_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_REPEATER_CARBINE_WRAP6", label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_REPEATER_HENRY"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REPEATER_HENRY_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_REPEATER_HENRY_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_REPEATER_HENRY_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_REPEATER_HENRY_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REPEATER_HENRY_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REPEATER_HENRY_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_REPEATER_HENRY_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_REPEATER_HENRY_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_REPEATER_HENRY_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_REPEATER_HENRY_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_REPEATER_HENRY_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_REPEATER_HENRY_WRAP6", label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_REPEATER_EVANS"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REPEATER_EVANS_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_REPEATER_EVANS_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_REPEATER_EVANS_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_REPEATER_EVANS_GRIP_BURLED",   label = "Burled Grip" },
                { name = "COMPONENT_REPEATER_EVANS_GRIP_WINTER",   label = "Winter Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REPEATER_EVANS_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REPEATER_EVANS_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_REPEATER_EVANS_WRAP",        label = "Wrap 1" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP2",       label = "Wrap 2" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP3",       label = "Wrap 3" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP4",       label = "Wrap 4" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP5",       label = "Wrap 5" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP6",       label = "Wrap 6" },
                { name = "COMPONENT_REPEATER_EVANS_WRAP_WINTER", label = "Winter Wrap" },
            }
        },
        FRAME_ENGRAVING = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_EVANS_WINTER", label = "Winter Engraving" },
            }
        },
    },
    ["WEAPON_REPEATER_WINCHESTER"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_REPEATER_WINCHESTER_GRIP",           label = "Standard Grip" },
                { name = "COMPONENT_REPEATER_WINCHESTER_GRIP_IRONWOOD",  label = "Ironwood Grip" },
                { name = "COMPONENT_REPEATER_WINCHESTER_GRIP_ENGRAVED",  label = "Engraved Grip" },
                { name = "COMPONENT_REPEATER_WINCHESTER_GRIP_COLLECTOR", label = "Collector Grip" },
                { name = "COMPONENT_REPEATER_WINCHESTER_GRIP_BURLED",    label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REPEATER_WINCHESTER_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REPEATER_WINCHESTER_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP1",          label = "Wrap 1" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP2",          label = "Wrap 2" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP3",          label = "Wrap 3" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP4",          label = "Wrap 4" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP5",          label = "Wrap 5" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP6",          label = "Wrap 6" },
                { name = "COMPONENT_REPEATER_WINCHESTER_WRAP_COLLECTOR", label = "Collector Wrap" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_FRAME_ENGRAVING_WINCHESTER_COLLECTOR", label = "Collector Engraving" },
            }
        },
    },
    ["WEAPON_RIFLE_VARMINT"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_RIFLE_VARMINT_GRIP",            label = "Standard Grip" },
                { name = "COMPONENT_RIFLE_VARMINT_GRIP_ENGRAVED",   label = "Engraved Grip" },
                { name = "COMPONENT_RIFLE_VARMINT_GRIP_IRONWOOD",   label = "Ironwood Grip" },
                { name = "COMPONENT_RIFLE_VARMINT_GRIP_NATURALIST", label = "Naturalist Grip" },
                { name = "COMPONENT_RIFLE_VARMINT_GRIP_BURLED",     label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_REPEATER_PUMPACTION_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE",   label = "Wide Sight" },
                { name = "COMPONENT_RIFLE_VARMINT_SIGHT_NATURALIST",   label = "Naturalist Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_RIFLE_VARMINT_CLIP",            label = "Standard Clip" },
                { name = "COMPONENT_RIFLE_VARMINT_CLIP_ENGRAVED",   label = "Engraved Clip" },
                { name = "COMPONENT_RIFLE_VARMINT_CLIP_IRONWOOD",   label = "Ironwood Clip" },
                { name = "COMPONENT_RIFLE_VARMINT_CLIP_NATURALIST", label = "Naturalist Clip" },
                { name = "COMPONENT_RIFLE_VARMINT_CLIP_BURLED",     label = "Burled Clip" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_VARMINT_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_VARMINT_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_RIFLE_VARMINT_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_RIFLE_VARMINT_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_RIFLE_VARMINT_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_RIFLE_VARMINT_WRAP6", label = "Wrap 6" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_VARMINT_NATURALIST", label = "Naturalist Engraving" },
            }
        },
    },
    ["WEAPON_RIFLE_BOLTACTION"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_RIFLE_BOLTACTION_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_RIFLE_BOLTACTION_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_RIFLE_BOLTACTION_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_RIFLE_BOLTACTION_GRIP_BOUNTY",   label = "Bounty Grip" },
                { name = "COMPONENT_RIFLE_BOLTACTION_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_RIFLE_BOLTACTION_SIGHT_WIDE",   label = "Wide Sight" },
                { name = "COMPONENT_RIFLE_BOLTACTION_SIGHT_NARROW", label = "Narrow Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP",  label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_RIFLE_BOLTACTION_WRAP6", label = "Wrap 6" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_FRAME_ENGRAVING_BOLTACTION_BOUNTY", label = "Bounty Engraving" },
            }
        },
    },
    ["WEAPON_RIFLE_ELEPHANT"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_RIFLE_ELEPHANT_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_RIFLE_ELEPHANT_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_RIFLE_ELEPHANT_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_RIFLE_ELEPHANT_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_RIFLE_ELEPHANT_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_RIFLE_ELEPHANT_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        MAG = {
            label = "Magazine",
            items = {
                { name = "COMPONENT_RIFLE_ELEPHANT_MAG",          label = "Standard Magazine" },
                { name = "COMPONENT_RIFLE_ELEPHANT_MAG_IRONWOOD", label = "Ironwood Magazine" },
                { name = "COMPONENT_RIFLE_ELEPHANT_MAG_ENGRAVED", label = "Engraved Magazine" },
                { name = "COMPONENT_RIFLE_ELEPHANT_MAG_BURLED",   label = "Burled Magazine" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_RIFLE_ELEPHANT_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_RIFLE_ELEPHANT_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_ELEPHANT_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_ELEPHANT_WRAP2", label = "Wrap 2" },
            }
        },
    },
    ["WEAPON_RIFLE_SPRINGFIELD"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_RIFLE_SPRINGFIELD_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_RIFLE_SPRINGFIELD_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_RIFLE_SPRINGFIELD_WRAP6", label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_SNIPERRIFLE_CARCANO"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_RIFLE_CARCANO_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_RIFLE_CARCANO_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_RIFLE_CARCANO_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_RIFLE_CARCANO_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_RIFLE_CARCANO_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_RIFLE_CARCANO_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_RIFLE_CARCANO_CLIP",       label = "Standard Clip" },
                { name = "COMPONENT_RIFLE_CARCANO_CLIP_EMPTY", label = "Empty Clip" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_CARCANO_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_CARCANO_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_RIFLE_CARCANO_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_RIFLE_CARCANO_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_RIFLE_CARCANO_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_RIFLE_CARCANO_WRAP6", label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_SNIPERRIFLE_ROLLINGBLOCK"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_EXOTIC",   label = "Exotic Grip" },
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_REAPER",   label = "Reaper Grip" },
                { name = "COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_RIFLE_ROLLINGBLOCK_WRAP6", label = "Wrap 6" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_ROLLINGBLOCK_REAPER", label = "Reaper Engraving" },
            }
        },
    },
    ["WEAPON_SHOTGUN_REPEATING"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_SHOTGUN_REPEATING_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_SHOTGUN_REPEATING_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SHOTGUN_REPEATING01_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_SHOTGUN_REPEATING01_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_SHOTGUN_REPEATING01_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_SHOTGUN_REPEATING_GRIP_BURLED",     label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_SHOTGUN_REPEATING_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_SHOTGUN_REPEATING_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_SHOTGUN_REPEATING01_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_SHOTGUN_REPEATING01_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_SHOTGUN_REPEATING_WRAP3",   label = "Wrap 3" },
                { name = "COMPONENT_SHOTGUN_REPEATING_WRAP4",   label = "Wrap 4" },
                { name = "COMPONENT_SHOTGUN_REPEATING_WRAP5",   label = "Wrap 5" },
                { name = "COMPONENT_SHOTGUN_REPEATING_WRAP6",   label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_SHOTGUN_PUMP"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_SHOTGUN_PUMP_BARREL_SHORT",     label = "Short Barrel" },
                { name = "COMPONENT_SHOTGUN_PUMP_BARREL_LONG",      label = "Long Barrel" },
                { name = "COMPONENT_SHOTGUN_PUMP_BARREL_HALLOWEEN", label = "Halloween Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP",           label = "Standard Grip" },
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP_IRONWOOD",  label = "Ironwood Grip" },
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP_ENGRAVED",  label = "Engraved Grip" },
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP_TRADER",    label = "Trader Grip" },
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP_BURLED",    label = "Burled Grip" },
                { name = "COMPONENT_SHOTGUN_PUMP_GRIP_HALLOWEEN", label = "Halloween Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_SHOTGUN_PUMP_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_SHOTGUN_PUMP_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        CLIP = {
            label = "Clip",
            items = {
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP",           label = "Standard Clip" },
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP_IRONWOOD",  label = "Ironwood Clip" },
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP_ENGRAVED",  label = "Engraved Clip" },
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP_TRADER",    label = "Trader Clip" },
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP_BURLED",    label = "Burled Clip" },
                { name = "COMPONENT_SHOTGUN_PUMP_CLIP_HALLOWEEN", label = "Halloween Clip" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_SHOTGUN_PUMP_WRAP6", label = "Wrap 6" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_SHOTGUN_FRAME_ENGRAVING_PUMP_TRADER",   label = "Trader Engraving" },
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_PUMP_HALLOWEEN", label = "Halloween Engraving" },
            }
        },
    },
    ["WEAPON_SHOTGUN_DOUBLEBARREL"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_SHORT",   label = "Short Barrel" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_LONG",    label = "Long Barrel" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_KRAMPUS", label = "Krampus Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC",   label = "Exotic Grip" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_KRAMPUS",  label = "Krampus Grip" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP6", label = "Wrap 6" },
            }
        },
        MAG = {
            label = "Magazine",
            items = {
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG",          label = "Standard Magazine" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_IRONWOOD", label = "Ironwood Magazine" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_ENGRAVED", label = "Engraved Magazine" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_EXOTIC",   label = "Exotic Magazine" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_KRAMPUS",  label = "Krampus Magazine" },
                { name = "COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_BURLED",   label = "Burled Magazine" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_DOUBLEBARREL_KRAMPUS", label = "Krampus Engraving" },
            }
        },
    },
    ["WEAPON_SHOTGUN_SAWEDOFF"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_GRIP",            label = "Standard Grip" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_GRIP_IRONWOOD",   label = "Ironwood Grip" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_GRIP_EBONY",      label = "Ebony Grip" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_GRIP_MOONSHINER", label = "Moonshiner Grip" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_GRIP_BURLED",     label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_SHOTGUN_SAWED_SIGHT_NARROW",     label = "Narrow Sight" },
                { name = "COMPONENT_SHOTGUN_SAWED_SIGHT_WIDE",       label = "Wide Sight" },
                { name = "COMPONENT_SHOTGUN_SAWED_SIGHT_MOONSHINER", label = "Moonshiner Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_WRAP5", label = "Wrap 5" },
            }
        },
        STOCK = {
            label = "Stock",
            items = {
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_STOCK",            label = "Standard Stock" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_STOCK_IRONWOOD",   label = "Ironwood Stock" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_STOCK_EBONY",      label = "Ebony Stock" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_STOCK_MOONSHINER", label = "Moonshiner Stock" },
                { name = "COMPONENT_SHOTGUN_SAWEDOFF_STOCK_BURLED",     label = "Burled Stock" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_LONGARM_ROLE_ENGRAVING_SAWEDOFF_MOONSHINER", label = "Moonshiner Engraving" },
            }
        },
    },
    ["WEAPON_SHOTGUN_SEMIAUTO"] = {
        BARREL = {
            label = "Barrel",
            items = {
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_BARREL_SHORT", label = "Short Barrel" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_BARREL_LONG",  label = "Long Barrel" },
            }
        },
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_GRIP",          label = "Standard Grip" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_GRIP_IRONWOOD", label = "Ironwood Grip" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_GRIP_ENGRAVED", label = "Engraved Grip" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_GRIP_BURLED",   label = "Burled Grip" },
            }
        },
        SIGHT = {
            label = "Sights",
            items = {
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_NARROW", label = "Narrow Sight" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_WIDE",   label = "Wide Sight" },
            }
        },
        WRAP = {
            label = "Wrap",
            items = {
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP1", label = "Wrap 1" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP2", label = "Wrap 2" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP3", label = "Wrap 3" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP4", label = "Wrap 4" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP5", label = "Wrap 5" },
                { name = "COMPONENT_SHOTGUN_SEMIAUTO_WRAP6", label = "Wrap 6" },
            }
        },
    },
    ["WEAPON_BOW_IMPROVED"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_BOW_IMPROVED_GRIP",              label = "Standard Grip" },
                { name = "COMPONENT_BOW_IMPROVED_GRIP_ALLIGATOR",    label = "Alligator Grip" },
                { name = "COMPONENT_BOW_IMPROVED_GRIP_HORNED",       label = "Horned Grip" },
                { name = "COMPONENT_BOW_IMPROVED_GRIP_JAGUAR",       label = "Jaguar Grip" },
                { name = "COMPONENT_BOW_IMPROVED_GRIP_WOODEN_INLAY", label = "Wooden Inlay Grip" },
            }
        },
        CYLINDER_TINT = {
            label = "Cylinder Tint",
            items = {
                { name = "COMPONENT_BOW_FRAME_TINT_A_1", label = "Tint 1" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_2", label = "Tint 2" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_3", label = "Tint 3" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_4", label = "Tint 4" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_5", label = "Tint 5" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_6", label = "Tint 6" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_7", label = "Tint 7" },
                { name = "COMPONENT_BOW_FRAME_TINT_A_8", label = "Tint 8" },
            }
        },
        BARREL_TINT = {
            label = "Barrel Tint",
            items = {
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_1", label = "Tint 1" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_2", label = "Tint 2" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_3", label = "Tint 3" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_4", label = "Tint 4" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_5", label = "Tint 5" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_6", label = "Tint 6" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_7", label = "Tint 7" },
                { name = "COMPONENT_BOW_GRIPSTOCK_TINT_A_8", label = "Tint 8" },
            }
        },
        TRIGGER_TINT = {
            label = "Trigger Tint",
            items = {
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_1", label = "Tint 1" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_2", label = "Tint 2" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_3", label = "Tint 3" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_4", label = "Tint 4" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_5", label = "Tint 5" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_6", label = "Tint 6" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_7", label = "Tint 7" },
                { name = "COMPONENT_BOW_TRIGGER_TINT_A_8", label = "Tint 8" },
            }
        },
        FRAME_VERTDATA = {
            label = "Frame Engraving",
            items = {
                { name = "COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_ALLIGATOR",    label = "Alligator Engraving" },
                { name = "COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_HORNED",       label = "Horned Engraving" },
                { name = "COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_JAGUAR",       label = "Jaguar Engraving" },
                { name = "COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_WOODEN_INLAY", label = "Wooden Inlay Engraving" },
            }
        },
    },
    ["WEAPON_MELEE_KNIFE"] = {
        GRIP = {
            label = "Grip",
            items = {
                { name = "COMPONENT_MELEE_KNIFE02_GRIP", label = "Grip 1" },
                { name = "COMPONENT_MELEE_KNIFE13_GRIP", label = "Grip 2" },
            }
        },
    },
    ["WEAPON_THROWN_DYNAMITE"] = {
        TORCH_MATCHSTICK = {
            label = "Torch/Matchstick",
            items = {
                { name = "COMPONENT_DYNAMITE_MOLOTOV_TORCH_MATCHSTICK", label = "Torch/Matchstick" },
            }
        },
    },
    ["WEAPON_KIT_BINOCULARS"] = {
        TORCH_MATCHSTICK = {
            label = "Scope",
            items = {
                { name = "COMPONENT_BINOCULARS_SCOPE01", label = "Scope" },
            }
        },
    },
    ["WEAPON_FISHINGROD"] = {
        COMPONENT_FISHING_LINE = {
            label = "Fishing Line",
            items = {
                { name = "COMPONENT_FISHING_LINE", label = "Fishing Line" },
            }
        },
    },
}
