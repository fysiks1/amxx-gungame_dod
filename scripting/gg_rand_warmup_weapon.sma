#include <amxmodx>
#include <amxmisc>

new const dod_weapons[][] = {
	"bar",
	// "bazooka",
	"bren",
	// "colt",
	"enfield",
	"fg42",
	"garand",
	"greasegun",
	"k43",
	"kar",
	// "luger",
	"m1carbine",
	// "mg34",
	// "mg42",
	"mp40",
	"mp44",
	// "piat",
	// "pschreck",
	// "scopedenfield",
	// "scopedfg42",
	// "spring",
	"sten",
	// "webley",
	"thompson"
}

public plugin_cfg()
{
	register_plugin("GG Random WarmUp Wpn (DOD)", "1.0", "Fysiks")
	set_task(1.5,"set_warmup_weapon")
}

public set_warmup_weapon()
{
	// Set random warmup weapon.
	set_cvar_string("gg_warmup_weapon",dod_weapons[random(sizeof(dod_weapons))])
}
