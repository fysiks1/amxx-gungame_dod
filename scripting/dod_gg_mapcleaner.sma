#include <amxmodx>
#include <engine>
#include <dodx>

public plugin_init( )
{
	register_plugin( "DOD GG Map Cleaner", "1.1", "Fysiks" );

	new szWeaponList[][] = {
		"weapon_30cal",
		"weapon_amerknife",
		"weapon_bar",
		"weapon_bazooka",
		"weapon_bren",
		"weapon_colt",
		"weapon_enfield",
		"weapon_garand",
		"weapon_gerknife",
		"weapon_gewehr",
		"weapon_greasegun",
		"weapon_kar",
		"weapon_luger",
		"weapon_m1carbine",
		"weapon_mg34",
		"weapon_mg42",
		"weapon_mp40",
		"weapon_mp44",
		"weapon_piat",
		"weapon_pschreck",
		"weapon_spade",
		"weapon_spring",
		"weapon_sten",
		"weapon_thompson",
		"ammo_30cal",
		"ammo_bar",
		"ammo_bazooka",
		"ammo_bren",
		"ammo_colt",
		"ammo_enfield",
		"ammo_garand",
		"ammo_gewehr",
		"ammo_kar",
		"ammo_luger",
		"ammo_m1carbine",
		"ammo_mg34",
		"ammo_mg42",
		"ammo_mp40",
		"ammo_mp44",
		"ammo_piat",
		"ammo_spring",
		"ammo_sten",
		"ammo_thompson",
		"player_weaponstrip"
	}

	for( new i = 0; i < sizeof(szWeaponList); i++ )
	{
		remove_entity_name(szWeaponList[i])
	}
}
