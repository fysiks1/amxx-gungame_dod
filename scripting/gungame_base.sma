
// Thanks a lot to 3volution for helping me iron out some
// bugs and for giving me some helpful suggestions.
//
// Thanks a lot to raa for helping me pinpoint the crash,
// and discovering the respawn bug.
//
// Thanks a lot to BAILOPAN for binary logging, and for
// CSDM spawn files that I could leech off of. Oh, and
// also AMXX, etcetera.
//
// Thanks to VEN for Fakemeta Utilities to ease development.
//
// Thanks a lot to all of my supporters, predominantly:
// 3volution, aligind4h0us3, arkshine, Curryking, Gunny,
// IdiotSavant, Mordekay, polakpolak, raa, Silver Dragon,
// and ToT | V!PER.
//
// Thanks especially to all of the translators:
// arkshine, b!orn, commonbullet, Curryking, Deviance,
// D o o m, Fr3ak0ut, godlike, harbu, iggy_bus, jopmako,
// KylixMynxAltoLAG, Morpheus759, SAMURAI16, TEG,
// ToT | V!PER, trawiator, Twilight Suzuka, and webpsiho.

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <dodfun>
#include <dodx>
#include <hamsandwich>

// defines to be left alone
new const GG_VERSION[] =	"2.00B4.0";
#define LANG_PLAYER_C		-76 // for gungame_print (arbitrary number)
#define TNAME_SAVE		pev_noise3 // for blocking game_player_equip and player_weaponstrip
#define MAX_PARAMS		32 // for _ggn_gungame_print and _ggn_gungame_hudmessage
#define WEAPONORDER_SIZE	(MAX_WEAPONS*16)+1 // for gg_weapon_order
#define WINSOUNDS_SIZE		(MAX_WINSOUNDS*MAX_WINSOUND_LEN)+1 // for gg_sound_winner

// more customizable-friendly defines
#define TOP_PLAYERS		10 // for !top10
#define MAX_WEAPONS		36 // for gg_weapon_order
#define MAX_WINSOUNDS		12 // for gg_sound_winnner
#define MAX_WINSOUND_LEN	48 // for gg_sound_winner
#define TEMP_SAVES		32 // for gg_save_temp
#define MAX_WEAPON_ORDERS	10 // for random gg_weapon_order
#define LEADER_DISPLAY_RATE	10.0 // for gg_leader_display

// for day of defeat
#define WPN_SCOPED_OFFSET	115
#define WPN_LINUX_DIFF		4

// toggle_gungame
enum
{
	TOGGLE_FORCE = -1,
	TOGGLE_DISABLE,
	TOGGLE_ENABLE
};

// task ids
#define TASK_END_STAR			200
#define TASK_CLEAR_SAVE		500
#define TASK_TOGGLE_GUNGAME		800
#define TASK_WARMUP_CHECK		900
#define TASK_VERIFY_WEAPON		1000
#define TASK_REFRESH_NADE		1200
#define TASK_LEADER_DISPLAY		1300
#define TASK_PLAY_LEAD_SOUNDS	1400

/**********************************************************************
* VARIABLE DEFINITIONS
**********************************************************************/

// pcvar holders
new gg_enabled, gg_ff_auto, gg_vote_setting, gg_map_setup, gg_join_msg,
gg_weapon_order, gg_max_lvl, gg_triple_on, gg_turbo, gg_knife_pro,
gg_worldspawn_suicide, gg_handicap_on, gg_top10_handicap, gg_warmup_timer_setting,
gg_warmup_weapon, gg_sound_levelup, gg_sound_leveldown, gg_sound_levelsteal,
gg_sound_nade, gg_sound_knife, gg_sound_welcome, gg_sound_triple, gg_sound_winner,
gg_kills_per_lvl, gg_vote_custom, gg_changelevel_custom, gg_ammo_amount,
gg_stats_file, gg_stats_prune, gg_refill_on_kill, gg_colored_messages, gg_tk_penalty,
gg_save_temp, gg_stats_mode, gg_pickup_others, gg_stats_winbonus, gg_map_iterations,
gg_warmup_multi, gg_stats_ip, gg_extra_nades, gg_endmap_setup, gg_autovote_rounds,
gg_autovote_ratio, gg_autovote_delay, gg_autovote_time, gg_ignore_bots, gg_nade_refresh,
gg_block_equips, gg_leader_display, gg_leader_display_x, gg_leader_display_y,
gg_sound_takenlead, gg_sound_tiedlead, gg_sound_lostlead, gg_lead_sounds, gg_knife_elite,
gg_teamplay, gg_teamplay_melee_mod, gg_teamplay_nade_mod, gg_suicide_penalty;
new g_pPointPerKill;
new gg_debugmode;

// important per-mod weapon information
new maxClip[36], maxAmmo[36], weaponSlots[36];

// misc
new scores_menu, level_menu, warmup = -1, warmupWeapon[24], len, voted, won, trailSpr, roundEnded,
weaponOrder[WEAPONORDER_SIZE], menuText[512], dummy[2], tempSave[TEMP_SAVES][27], cstrike, czero, dod,
maxPlayers, mapIteration = 1, cfgDir[32], top10[TOP_PLAYERS][81], modName[12], autovoted, autovotes[2],
roundsElapsed, gameCommenced, cycleNum = -1, ham_registered, czbot_ham_registered, pattern[MAX_PARAMS],
params[MAX_PARAMS][256], mp_friendlyfire, winSounds[MAX_WINSOUNDS][MAX_WINSOUND_LEN+1], numWinSounds,
currentWinSound, hudSyncWarmup, hudSyncReqKills, hudSyncLDisplay, shouldWarmup, ggActive,
teamLevel[3], teamLvlWeapon[3][24], teamScore[3];

// stats file stuff
new sfFile[64], sfAuthid[24], sfWins[6], sfPoints[8], sfName[32], sfTimestamp[12], sfLineData[81];

// event ids
new gmsgSayText, gmsgCurWeapon;

// player values
new level[33], levelsThisRound[33], score[33], lvlWeapon[33][24], star[33], welcomed[33],
page[33], Float:spawnTime[33], lastKilled[33];

/**********************************************************************
* INITIATION FUNCTIONS
**********************************************************************/

// plugin load
public plugin_init()
{
	register_plugin("GunGame AMXX - Base",GG_VERSION,"Avalanche");
	register_cvar("gg_version",GG_VERSION,FCVAR_SERVER);
	set_cvar_string("gg_version",GG_VERSION);

	// mehrsprachige unterst�tzung (nein, spreche ich nicht Deutsches)
	register_dictionary("gungame.txt");
	register_dictionary("common.txt");
	register_dictionary("adminvote.txt");

	// event ids
	gmsgSayText = get_user_msgid("SayText");
	gmsgCurWeapon = get_user_msgid("CurWeapon");

	// events
	register_event("CurWeapon","event_curweapon","be","1=1");
	register_event("AmmoX","event_ammox","be");
	register_event("30","event_intermission","a");

	// commands
	register_concmd("amx_gungame_status","cmd_gungame_status",ADMIN_CVAR,"<0|1> - toggles the functionality of GunGame.");
	register_concmd("amx_gungame_level","cmd_gungame_level",ADMIN_BAN,"<target> <level> - sets target's level. use + or - for relative, otherwise it's absolute.");
	register_concmd("amx_gungame_vote","cmd_gungame_vote",ADMIN_VOTE,"- starts a vote to toggle GunGame.");
	register_concmd("amx_gungame_win","cmd_gungame_win",ADMIN_BAN,"[target] - if target, forces target to win. if no target, forces highest level player to win.");
	register_concmd("amx_gungame_teamplay","cmd_gungame_teamplay",ADMIN_BAN,"<0|1> [killsperlvl] [suicidepenalty] - toggles teamplay mode. optionally specify new cvar values.");
	register_concmd("amx_gungame_restart","cmd_gungame_restart",ADMIN_BAN,"[time] - restarts GunGame. optionally specify a delay, in seconds.");
	register_clcmd("fullupdate","cmd_fullupdate");
	register_clcmd("say","cmd_say");
	register_clcmd("say_team","cmd_say");

	// menus
	register_menucmd(register_menuid("autovote_menu"),MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,"autovote_menu_handler");
	register_menucmd(register_menuid("welcome_menu"),1023,"welcome_menu_handler");
	register_menucmd(register_menuid("restart_menu"),MENU_KEY_1|MENU_KEY_0,"restart_menu_handler");
	register_menucmd(register_menuid("weapons_menu"),MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,"weapons_menu_handler");
	register_menucmd(register_menuid("top10_menu"),MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,"top10_menu_handler");
	scores_menu = register_menuid("scores_menu");
	register_menucmd(scores_menu,MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,"scores_menu_handler");
	level_menu = register_menuid("level_menu");
	register_menucmd(level_menu,1023,"level_menu_handler");

	// basic cvars
	gg_enabled = register_cvar("gg_enabled","1");
	gg_vote_setting = register_cvar("gg_vote_setting","2");
	gg_vote_custom = register_cvar("gg_vote_custom","");
	gg_changelevel_custom = register_cvar("gg_changelevel_custom","");
	gg_map_setup = register_cvar("gg_map_setup",""); // defaults are per-mod
	gg_endmap_setup = register_cvar("gg_endmap_setup","");
	gg_join_msg = register_cvar("gg_join_msg","1");
	gg_colored_messages = register_cvar("gg_colored_messages","1");
	gg_save_temp = register_cvar("gg_save_temp","300"); // = 5 * 60 = 5 minutes
	gg_map_iterations = register_cvar("gg_map_iterations","1");
	gg_ignore_bots = register_cvar("gg_ignore_bots","0");
	gg_block_equips = register_cvar("gg_block_equips","0");
	gg_leader_display = register_cvar("gg_leader_display","1");
	gg_leader_display_x = register_cvar("gg_leader_display_x","-1.0");
	gg_leader_display_y = register_cvar("gg_leader_display_y","0.0");

	// autovote cvars
	gg_autovote_rounds = register_cvar("gg_autovote_rounds","0");
	gg_autovote_delay = register_cvar("gg_autovote_delay","8.0");
	gg_autovote_ratio = register_cvar("gg_autovote_ratio","0.51");
	gg_autovote_time = register_cvar("gg_autovote_time","10.0");

	// stats cvars
	gg_stats_file = register_cvar("gg_stats_file","gungame.stats");
	gg_stats_ip = register_cvar("gg_stats_ip","0");
	gg_stats_prune = register_cvar("gg_stats_prune","2592000"); // = 60 * 60 * 24 * 30 = 30 days
	gg_stats_mode = register_cvar("gg_stats_mode","1");
	gg_stats_winbonus = register_cvar("gg_stats_winbonus","1.5");

	// gameplay cvars
	gg_ff_auto = register_cvar("gg_ff_auto","1");
	gg_weapon_order = register_cvar("gg_weapon_order",""); // defaults are per-mod
	gg_max_lvl = register_cvar("gg_max_lvl","3");
	gg_triple_on = register_cvar("gg_triple_on","0");
	gg_turbo = register_cvar("gg_turbo","1");
	gg_knife_pro = register_cvar("gg_knife_pro","1");
	gg_knife_elite = register_cvar("gg_knife_elite","0");
	gg_suicide_penalty = register_cvar("gg_suicide_penalty","1");
	gg_worldspawn_suicide = register_cvar("gg_worldspawn_suicide","1");
	gg_pickup_others = register_cvar("gg_pickup_others","0");
	gg_handicap_on = register_cvar("gg_handicap_on","1");
	gg_top10_handicap = register_cvar("gg_top10_handicap","1");
	gg_warmup_timer_setting = register_cvar("gg_warmup_timer_setting","60");
	gg_warmup_weapon = register_cvar("gg_warmup_weapon",""); // defaults are per-mod
	gg_warmup_multi = register_cvar("gg_warmup_multi","0");
	gg_extra_nades = register_cvar("gg_extra_nades","1");
	gg_nade_refresh = register_cvar("gg_nade_refresh","5.0");
	gg_kills_per_lvl = register_cvar("gg_kills_per_lvl","2");
	g_pPointPerKill = register_cvar("gg_points_per_kill", "1");
	gg_ammo_amount = register_cvar("gg_ammo_amount","200");
	gg_refill_on_kill = register_cvar("gg_refill_on_kill","1");
	gg_tk_penalty = register_cvar("gg_tk_penalty","1");
	gg_teamplay = register_cvar("gg_teamplay","0");
	gg_teamplay_melee_mod = register_cvar("gg_teamplay_melee_mod","0.33");
	gg_teamplay_nade_mod = register_cvar("gg_teamplay_nade_mod","0.50");

	// sound cvars done in plugin_precache now

	// random weapon order cvars
	new i, cvar[20];
	for(i=1;i<=MAX_WEAPON_ORDERS;i++)
	{
		formatex(cvar,19,"gg_weapon_order%i",i);
		register_cvar(cvar,"");
	}

	// update status immediately
	ggActive = get_pcvar_num(gg_enabled);
	fws_gungame_toggled(ggActive);

	// make sure to setup amx_nextmap incase nextmap.amxx isn't running
	if(!cvar_exists("amx_nextmap")) register_cvar("amx_nextmap","",FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	// make sure we have this to trick mapchooser.amxx into working
	if(!cvar_exists("mp_maxrounds")) register_cvar("mp_maxrounds","0",FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	// remember certain mods
	if(!modName[0]) set_mod_shortcuts();

	// ggfw forwards
	register_forwards();

	// set up maxClip, maxAmmo, and weaponSlots tables
	set_mod_weapon_information();

	// collect some other information that would be handy
	maxPlayers = get_maxplayers();

	// create hud sync objects
	hudSyncWarmup = CreateHudSyncObj();
	hudSyncReqKills = CreateHudSyncObj();
	hudSyncLDisplay = CreateHudSyncObj();

	// delay for server.cfg
	set_task(1.0,"toggle_gungame",TASK_TOGGLE_GUNGAME + TOGGLE_FORCE);

	// manage pruning (longer delay for toggle_gungame)
	set_task(2.0,"manage_pruning");

	// Cvar for debug testing
	gg_debugmode = register_cvar("gg_debugmode", "0");
}

// the hams that need to be hooked
hook_hams(id)
{
	 RegisterHamFromEntity(Ham_Killed,id,"ham_player_killed",1);
}

// plugin precache
public plugin_precache()
{
	// used in set_sounds_from_confg()
	get_configsdir(cfgDir,31);

	// sound cvars
	gg_sound_levelup = register_cvar("gg_sound_levelup","sound/gungame/smb3_powerup.wav");
	gg_sound_leveldown = register_cvar("gg_sound_leveldown","sound/gungame/smb3_powerdown.wav");
	gg_sound_levelsteal = register_cvar("gg_sound_levelsteal","sound/gungame/smb3_1-up.wav");
	gg_sound_nade = register_cvar("gg_sound_nade","sound/gungame/nade_level.wav");
	gg_sound_knife = register_cvar("gg_sound_knife","sound/gungame/knife_level.wav");
	gg_sound_welcome = register_cvar("gg_sound_welcome","sound/gungame/gungame2.wav");
	gg_sound_triple = register_cvar("gg_sound_triple","sound/gungame/smb_star.wav");
	gg_sound_winner = register_cvar("gg_sound_winner","media/Half-Life03.mp3;media/Half-Life08.mp3;media/Half-Life11.mp3;media/Half-Life17.mp3");
	gg_sound_takenlead = register_cvar("gg_sound_takenlead","sound/gungame/takenlead.wav");
	gg_sound_tiedlead = register_cvar("gg_sound_tiedlead","sound/gungame/tiedlead.wav");
	gg_sound_lostlead = register_cvar("gg_sound_lostlead","sound/gungame/lostlead.wav");
	gg_lead_sounds = register_cvar("gg_lead_sounds","0.8");

	// load sound values from gungame.cfg
	set_sounds_from_config();

	// really precache them
	precache_sound_by_cvar(gg_sound_levelup);
	precache_sound_by_cvar(gg_sound_leveldown);
	precache_sound_by_cvar(gg_sound_levelsteal);
	precache_sound_by_cvar(gg_sound_nade);
	precache_sound_by_cvar(gg_sound_knife);
	precache_sound_by_cvar(gg_sound_welcome);
	precache_sound_by_cvar(gg_sound_triple);

	if(get_pcvar_float(gg_lead_sounds) > 0.0)
	{
		precache_sound_by_cvar(gg_sound_takenlead);
		precache_sound_by_cvar(gg_sound_tiedlead);
		precache_sound_by_cvar(gg_sound_lostlead);
	}

	// win sounds enabled
	get_pcvar_string(gg_sound_winner,dummy,1);
	if(dummy[0])
	{
		// gg_sound_winner might contain multiple sounds
		new buffer[WINSOUNDS_SIZE], temp[MAX_WINSOUND_LEN+1], pos;
		get_pcvar_string(gg_sound_winner,buffer,WINSOUNDS_SIZE-1);

		while(numWinSounds < MAX_WINSOUNDS)
		{
			pos = contain(buffer,";");

			// no more after this, precache what we have left
			if(pos == -1)
			{
				precache_generic(buffer);
				formatex(winSounds[numWinSounds++],MAX_WINSOUND_LEN,"%s",buffer);

				break;
			}

			// copy up to the semicolon and precache that
			formatex(temp,pos,"%s",buffer);
			precache_generic(temp);

			formatex(winSounds[numWinSounds++],MAX_WINSOUND_LEN,"%s",temp);

			// copy everything after the semicolon
			format(buffer,WINSOUNDS_SIZE-1,"%s",buffer[pos+1]);
		}
	}

	// some generic, non-changing things
	precache_sound("gungame/brass_bell_C.wav");
	precache_sound("buttons/bell1.wav");
	precache_sound("common/null.wav");

	// for the star
	trailSpr = precache_model("sprites/laserbeam.spr");
}

// catch cvar pointers from mod plugins
public plugin_cfg()
{
	mp_friendlyfire = get_cvar_pointer("mp_friendlyfire");

	// Disable debugging by default
	set_pcvar_num(gg_debugmode, 0);

	// we have to let mods set these because of default values
	//gg_weapon_order = get_cvar_pointer("gg_weapon_order");
	//gg_map_setup = get_cvar_pointer("gg_map_setup");
}

// plugin ends, prune stats file maybe
public plugin_end()
{
	// run endmap setup on plugin close
	if(ggActive)
	{
		new setup[512];
		get_pcvar_string(gg_endmap_setup,setup,511);
		if(setup[0]) server_cmd(setup);
	}
}

// catch native errors
public native_filter(const name[],index,trap)
{
	// trying to USE invalid native
	if(trap == 1) return PLUGIN_CONTINUE; // that's not OK with me!

	// loading CS native in a non-CS game
	if(!cstrike && equal(name,"cs_",3))
	 	 return PLUGIN_HANDLED; // let it slide

	// loading DoD native in a non-DoD game
	if(!dod && equal(name,"dod_",4))
	 	 return PLUGIN_HANDLED; // let it slide

	return PLUGIN_CONTINUE;
}

// catch module errors
public module_filter(const module[])
{
	// loading CS module in a non-CS game
	if(!cstrike && (equal(module,"cstrike") || equal(module,"csx")))
	 	 return PLUGIN_HANDLED; // let it slide

	// loading DoD module in a non-DoD game
	if(!dod && (equal(module,"dodfun") || equal(module,"dodx")))
	 	 return PLUGIN_HANDLED; // let it slide

	return PLUGIN_CONTINUE;
}

/**********************************************************************
* OUTGOING (NON-FAKEMETA) FORWARDS
**********************************************************************/

new fwh_gungame_toggled, fwh_level_changed, fwh_score_changed, fwh_warmup_changed,
fwh_gave_level_weapon, fwh_refilled_ammo, fwh_cleared_values, fwh_on_valid_team,
fwh_is_nade, fwh_is_melee, fwh_is_nade_ammo, fwh_same_team, fwh_restart_round,
fwh_verify_death, fwh_request_weapon_info, fwh_set_user_bpammo, fwh_set_weapon_ammo;

public register_forwards()
{
	fwh_gungame_toggled = CreateMultiForward("ggfw_gungame_toggled",ET_IGNORE,FP_CELL);
	fwh_level_changed = CreateMultiForward("ggfw_level_changed",ET_IGNORE,FP_CELL,FP_CELL,FP_STRING);
	fwh_score_changed = CreateMultiForward("ggfw_score_changed",ET_IGNORE,FP_CELL,FP_CELL);
	fwh_warmup_changed = CreateMultiForward("ggfw_warmup_changed",ET_IGNORE,FP_CELL,FP_STRING);
	fwh_gave_level_weapon = CreateMultiForward("ggfw_gave_level_weapon",ET_IGNORE,FP_CELL,FP_CELL);
	fwh_refilled_ammo = CreateMultiForward("ggfw_refilled_ammo",ET_IGNORE,FP_CELL,FP_CELL);
	fwh_cleared_values = CreateMultiForward("ggfw_cleared_values",ET_IGNORE,FP_CELL);
	fwh_on_valid_team = CreateMultiForward("ggfw_on_valid_team",ET_CONTINUE,FP_CELL);
	fwh_is_nade = CreateMultiForward("ggfw_is_nade",ET_CONTINUE,FP_STRING);
	fwh_is_melee = CreateMultiForward("ggfw_is_melee",ET_CONTINUE,FP_STRING);
	fwh_is_nade_ammo = CreateMultiForward("ggfw_is_nade_ammo",ET_CONTINUE,FP_CELL);
	fwh_same_team = CreateMultiForward("ggfw_same_team",ET_CONTINUE,FP_CELL,FP_CELL);
	fwh_restart_round = CreateMultiForward("ggfw_restart_round",ET_CONTINUE,FP_CELL);
	fwh_verify_death = CreateMultiForward("ggfw_verify_death",ET_CONTINUE,FP_CELL,FP_CELL,FP_ARRAY,FP_CELL);

	if(!cstrike && !dod)
	{
		fwh_request_weapon_info = CreateMultiForward("ggfw_request_weapon_info",ET_IGNORE,FP_ARRAY,FP_ARRAY,FP_ARRAY);
		fwh_set_user_bpammo = CreateMultiForward("ggfw_set_user_bpammo",ET_IGNORE,FP_CELL,FP_CELL,FP_CELL);
		fwh_set_weapon_ammo = CreateMultiForward("ggfw_set_weapon_ammo",ET_IGNORE,FP_CELL,FP_CELL);
	}
}

// below are simple shortcuts for calling forwards and getting their return value

public fws_gungame_toggled(newStatus)
{
	if(fwh_gungame_toggled <= 0) return 0;
	return ExecuteForward(fwh_gungame_toggled,dummy[0],newStatus);
}

public fws_level_changed(id,newLevel,newWeapon[])
{
	if(fwh_level_changed <= 0) return 0;
	return ExecuteForward(fwh_level_changed,dummy[0],id,newLevel,newWeapon);
}

public fws_score_changed(id,newScore)
{
	if(fwh_score_changed <= 0) return 0;
	return ExecuteForward(fwh_score_changed,dummy[0],id,newScore);
}

public fws_warmup_changed(newValue,weapon[])
{
	if(fwh_warmup_changed <= 0) return 0;
	return ExecuteForward(fwh_warmup_changed,dummy[0],newValue,weapon);
}

public fws_gave_level_weapon(id,melee_only)
{
	if(fwh_gave_level_weapon <= 0) return 0;
	return ExecuteForward(fwh_gave_level_weapon,dummy[0],id,melee_only);
}

public fws_refilled_ammo(id,wpnid)
{
	if(fwh_refilled_ammo <= 0) return 0;
	return ExecuteForward(fwh_refilled_ammo,dummy[0],id,wpnid);
}

public fws_cleared_values(id)
{
	if(fwh_cleared_values <= 0) return 0;
	return ExecuteForward(fwh_cleared_values,dummy[0],id);
}

public fws_on_valid_team(id)
{
	if(fwh_on_valid_team <= 0) return 0;
	new ret;
	ExecuteForward(fwh_on_valid_team,ret,id);
	return ret;
}

public fws_is_nade(name[])
{
	if(fwh_is_nade <= 0) return 0;
	if(!name[0]) return 0;
	new ret;
	ExecuteForward(fwh_is_nade,ret,name);
	return ret;
}

public fws_is_melee(name[])
{
	if(fwh_is_melee <= 0) return 0;
	if(!name[0]) return 0;
	new ret;
	ExecuteForward(fwh_is_melee,ret,name);
	return ret;
}

public fws_is_nade_ammo(ammo)
{
	if(fwh_is_nade_ammo <= 0) return 0;
	new ret;
	ExecuteForward(fwh_is_nade_ammo,ret,ammo);
	return ret;
}

public fws_same_team(p1,p2)
{
	if(fwh_same_team <= 0) return 0;
	new ret;
	ExecuteForward(fwh_same_team,ret,p1,p2);
	return ret;
}

public fws_restart_round(time)
{
	// clear values
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player)) clear_values(player,1); // ignore welcome
	}

	// reset teams as well
	clear_team_values(1);
	clear_team_values(2);

	if(fwh_restart_round <= 0) return 0;
	new ret;
	ExecuteForward(fwh_restart_round,ret,time);
	return ret;
}

public fws_verify_death(killer,victim,weapon[],weaponSize)
{
	if(fwh_verify_death <= 0) return 0;
	new ret, array = PrepareArray(weapon,weaponSize,1);
	ExecuteForward(fwh_verify_death,ret,killer,victim,array,weaponSize);
	return ret;
}

public fws_request_weapon_info(maxClip[36],maxAmmo[36],weaponSlots[36])
{
	if(fwh_request_weapon_info <= 0) return 0;
	new ar1 = PrepareArray(maxClip,36,1);
	new ar2 = PrepareArray(maxAmmo,36,1);
	new ar3 = PrepareArray(weaponSlots,36,1);
	return ExecuteForward(fwh_request_weapon_info,dummy[0],ar1,ar2,ar3);
}

public fws_set_user_bpammo(id,weapon,ammo)
{
	if(fwh_set_user_bpammo <= 0) return 0;
	new ret;
	ExecuteForward(fwh_set_user_bpammo,ret,id,weapon,ammo);
	return ret;
}

public fws_set_weapon_ammo(weapon,ammo)
{
	if(fwh_set_weapon_ammo <= 0) return 0;
	new ret;
	ExecuteForward(fwh_set_weapon_ammo,ret,weapon,ammo);
	return ret;
}

/**********************************************************************
* DYNAMIC NATIVES
**********************************************************************/

// register all of our AMAZING natives!
public plugin_natives()
{
	// mods have not been realized yet
	if(!modName[0]) set_mod_shortcuts();

	// oh, it's that thing
	set_native_filter("native_filter");
	set_module_filter("module_filter");

	register_library("gungame");
	register_native("ggn_get_warmup_time","_ggn_get_warmup_time");
	register_native("ggn_is_round_over","_ggn_is_round_over");
	register_native("ggn_change_score","_ggn_change_score");
	register_native("ggn_change_level","_ggn_change_level");
	register_native("ggn_give_level_weapon","_ggn_give_level_weapon");
	register_native("ggn_refill_ammo","_ggn_refill_ammo");
	register_native("ggn_player_suicided","_ggn_player_suicided");
	register_native("ggn_clear_values","_ggn_clear_values");
	register_native("ggn_gungame_print","_ggn_gungame_print");
	register_native("ggn_gungame_hudmessage","_ggn_gungame_hudmessage");
	register_native("ggn_show_required_kills","_ggn_show_required_kills");
	register_native("ggn_notify_game_commenced","_ggn_notify_game_commenced");
	register_native("ggn_notify_new_round","_ggn_notify_new_round");
	register_native("ggn_notify_round_end","_ggn_notify_round_end");
	register_native("ggn_notify_player_spawn","_ggn_notify_player_spawn");
	register_native("ggn_notify_player_teamchange","_ggn_notify_player_teamchange");
	register_native("ggn_get_level","_ggn_get_level");
}

// native ggn_get_level(id);
public _ggn_get_level(iPlugin,iParams)
{
return level[get_param(1)];
}

// native ggn_get_warmup_time();
public _ggn_get_warmup_time(iPlugin,iParams)
{
	 return warmup;
}

// native ggn_is_round_over();
public _ggn_is_round_over(iPlugins,iParams)
{
	return roundEnded;
}

// native ggn_change_score(id,value,refill=1,effect_team=1);
public _ggn_change_score(iPlugin,iParams)
{
	if(!ggActive) return 0;
	return change_score(get_param(1),get_param(2),get_param(3),get_param(4));
}

// native ggn_change_level(id,value,show_message=1,always_score=0,effect_team=1);
public _ggn_change_level(iPlugin,iParams)
{
	if(!ggActive) return 0;
	return change_level(get_param(1),get_param(2),0,get_param(3),get_param(4),get_param(5),get_param(6));
}

// native ggn_give_level_weapon(id,notify=1);
public _ggn_give_level_weapon(iPlugin,iParams)
{
	if(!ggActive) return 0;
	return give_level_weapon(get_param(1),get_param(2));
}

// native ggn_refill_ammo(id);
public _ggn_refill_ammo(iPlugin,iParams)
{
	 if(!ggActive) return 0;
	 return refill_ammo(get_param(1));
}

// native ggn_player_suicided(id);
public _ggn_player_suicided(iPlugin,iParams)
{
	 if(!ggActive) return 0;
	 return player_suicided(get_param(1));
}

// native ggn_clear_values(id,ignoreWelcome=0);
public _ggn_clear_values(iPlugin,iParams)
{
	 return clear_values(get_param(1),get_param(2));
}

// native ggn_gungame_print(id,custom,tag,msg[],pattern[]="",{Float,Sql,Result,_}:...);
public _ggn_gungame_print(iPlugin,iParams)
{
	if(!ggActive) return 0;

	static msg[256];

	new id = get_param(1);
	new custom = get_param(2);
	new tag = get_param(3);
	get_string(4,msg,255);
	get_string(5,pattern,MAX_PARAMS-1);

	// no extra arguments
	if(!pattern[0]) return gungame_print(id,custom,tag,msg);

	static funcid;
	if(!funcid) funcid = get_func_id("gungame_print");

	if(callfunc_begin_i(funcid) != 1)
	 	 return 0;

	callfunc_push_int(id);
	callfunc_push_int(custom);
	callfunc_push_int(tag);
	callfunc_push_str(msg);

	new i = 0;
	while(pattern[i])
	{
		switch(pattern[i])
		{
			case 'i', 'f', 'd', 'c':
			{
				params[i][0] = get_param_byref(6+i);
				callfunc_push_intrf(params[i][0]);
			}
			case 's':
			{
				get_string(6+i,params[i],255);
				callfunc_push_str(params[i]);
			}
		}
		i++;
	}

	callfunc_end();

	return 1;
}

// native ggn_gungame_hudmessage(id,Float:holdTime,msg[],pattern[]="",{Float,Sql,Result,_}:...);
public _ggn_gungame_hudmessage(iPlugin,iParams)
{
	if(!ggActive) return 0;

	static msg[256];

	new id = get_param(1);
	new Float:holdTime = get_param_f(2);
	get_string(3,msg,255);
	get_string(4,pattern,MAX_PARAMS-1);

	// no extra arguments
	if(!pattern[0]) return gungame_hudmessage(id,holdTime,msg);

	static funcid;
	if(!funcid) funcid = get_func_id("gungame_hudmessage");

	if(callfunc_begin_i(funcid) != 1)
	 	 return 0;

	callfunc_push_int(id);
	callfunc_push_float(holdTime);
	callfunc_push_str(msg);

	new i = 0;
	while(pattern[i])
	{
		switch(pattern[i])
		{
			case 'i', 'f', 'd', 'c':
			{
				params[i][0] = get_param_byref(5+i);
				callfunc_push_intrf(params[i][0]);
			}
			case 's':
			{
				get_string(5+i,params[i],255);
				callfunc_push_str(params[i]);
			}
		}
		i++;
	}

	callfunc_end();

	return 1;
}

// native ggn_show_required_kills(id);
public _ggn_show_required_kills(iPlugin,iParams)
{
	 if(!ggActive) return 0;
	 return show_required_kills(get_param(1));
}

// native ggn_notify_game_commenced();
public _ggn_notify_game_commenced(iPlugin,iParams)
{
	// this is familiar!
	if(gameCommenced) return 0;

	gameCommenced = 1;

	// start warmup
	if(ggActive)
	{
		shouldWarmup = 0;
		start_warmup();
	}

	return 1;
}

// native ggn_notify_new_round();
public _ggn_notify_new_round(iPlugin,iParams)
{
	 return new_round();
}

// native ggn_notify_round_end();
public _ggn_notify_round_end(iPlugin,iParams)
{
	 return round_end();
}

// native ggn_notify_player_spawn(id,skipDelay=0);
public _ggn_notify_player_spawn(iPlugin,iParams)
{
	 if(!ggActive) return 0;
	 return player_spawn(get_param(1),get_param(2));
}

// native ggn_notify_player_teamchange(id,newTeam);
public _ggn_notify_player_teamchange(iPlugin,iParams)
{
	 if(!ggActive) return 0;

	 new id = get_param(1);
	 new team = get_param(2);

	 // we already have a level, set our values to our new team's
	 if(level[id] && get_pcvar_num(gg_teamplay) && (team == 1 || team == 2))
	 {
		 // set them directly
		 level[id] = teamLevel[team];
		 lvlWeapon[id] = teamLvlWeapon[team];
		 score[id] = teamScore[team];

		 // notify the others
		 fws_level_changed(id,level[id],lvlWeapon[id]);
		 fws_score_changed(id,score[id]);
	 }

	 return 1;
}

/**********************************************************************
* FORWARDS
**********************************************************************/

// client gets a steamid
public client_authorized(id)
{
	clear_values(id);

	get_pcvar_string(gg_stats_file,sfFile,63);

	static authid[24];

	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	// refresh timestamp if we should
	if(sfFile[0]) stats_refresh_timestamp(authid);

	// load temporary save
	if(ggActive && !get_pcvar_num(gg_teamplay) && get_pcvar_num(gg_save_temp))
	{
		new i, save = -1;

		// find our possible temp save
		for(i=0;i<TEMP_SAVES;i++)
		{
			if(equal(authid,tempSave[i],23))
			{
				save = i;
				break;
			}
		}

		// no temp save
		if(save == -1) return;

		// load values
		level[id] = tempSave[save][24];
		score[id] = tempSave[save][25];

		// clear it
		clear_save(TASK_CLEAR_SAVE+save);

		// get the name (almost forgot!)
		get_level_weapon(level[id],lvlWeapon[id],23);

		// update satellite plugins
		fws_level_changed(id,level[id],lvlWeapon[id]);
		fws_score_changed(id,score[id]);
	}
}

// client leaves, reset values
public client_disconnect(id)
{
	// remove certain tasks
	remove_task(TASK_VERIFY_WEAPON+id);
	remove_task(TASK_REFRESH_NADE+id);

	// don't bother saving if in winning period, warmup, or teamplay
	if(!won && warmup <= 0 && !get_pcvar_num(gg_teamplay))
	{
		new save_temp = get_pcvar_num(gg_save_temp);

		// temporarily save values
		if(ggActive && save_temp && (level[id] > 1 || score[id] > 0))
		{
			new freeSave = -1, oldestSave = -1, i;

			for(i=0;i<TEMP_SAVES;i++)
			{
				// we found a free one
				if(!tempSave[i][0])
				{
					freeSave = i;
					break;
				}

				// keep track of one soonest to expire
				if(oldestSave == -1 || tempSave[i][26] < tempSave[oldestSave][26])
					oldestSave = i;
			}

			// no free, use oldest
			if(freeSave == -1) freeSave = oldestSave;

			if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,tempSave[freeSave],23);
			else get_user_authid(id,tempSave[freeSave],23);

			tempSave[freeSave][24] = level[id];
			tempSave[freeSave][25] = score[id];
			tempSave[freeSave][26] = floatround(get_gametime());

			set_task(float(save_temp),"clear_save",TASK_CLEAR_SAVE+freeSave);
		}
	}

	clear_values(id);
}

// someone joins, monitor ham hooks
public client_putinserver(id)
{
	if(!ham_registered) set_task(1.0,"hook_ham",id);
	if(czero && !czbot_ham_registered) set_task(1.0,"czbot_hook_ham",id);
}

// delay for private data to initialize
public hook_ham(id)
{
	if(ham_registered || !is_user_connected(id)) return;

	// probably NOT a czero bot
	if(!czero || !(pev(id,pev_flags) & FL_FAKECLIENT) || get_cvar_num("bot_quota") <= 0)
	{
		hook_hams(id);
		ham_registered = 1;
	}
}

// delay for private data to initialize
public czbot_hook_ham(id)
{
	if(czbot_ham_registered || !is_user_connected(id)) return;

	// probably a czero bot (if czero check done before set_task)
	if((pev(id,pev_flags) & FL_FAKECLIENT) && get_cvar_num("bot_quota") > 0)
	{
		hook_hams(id);
		czbot_ham_registered = 1;
	}
}

// remove a save
public clear_save(taskid)
{
	remove_task(taskid);
	tempSave[taskid-TASK_CLEAR_SAVE][0] = 0;
}

// my info... it's changed!
public client_infochanged(id)
{
	// lots of things that we don't care about
	if(!is_user_connected(id) || !ggActive || !get_pcvar_num(gg_teamplay))
		return PLUGIN_CONTINUE;

	// invalid team
	new team = get_user_team(id);
	if(team != 1 && team != 2) return PLUGIN_CONTINUE;

	// something is out of synch
	if(teamLevel[team] && (level[id] != teamLevel[team] || score[id] != teamScore[team] || !equal(lvlWeapon[id],teamLvlWeapon[team])))
	{
		 // set them directly
		 level[id] = teamLevel[team];
		 lvlWeapon[id] = teamLvlWeapon[team];
		 score[id] = teamScore[team];

		 // notify the others
		 fws_level_changed(id,level[id],lvlWeapon[id]);
		 fws_score_changed(id,score[id]);

		 // gimme mah weapon!
		 if(is_user_alive(id)) give_level_weapon(id);
	}

	return PLUGIN_CONTINUE;
}

/**********************************************************************
* EVENT HOOKS
**********************************************************************/

// respawnish
stock player_spawn(id,skipDelay=0)
{
	if(!ggActive || !is_user_connected(id))
		return 0;

	// have not joined yet
	if(!fws_on_valid_team(id)) return 0;

	new Float:time = get_gametime();

	// SPAM control, because gaining a weapon from an event recalls that event
	if(time == spawnTime[id]) return 0;
	spawnTime[id] = time;

	// the delay is already taken care of
	if(skipDelay)
	{
		post_spawn(id);
		return 1;
	}

	// an unfortunately necessary delay because we
	// have to wait for the inventory to initialize
	set_task(0.1,"post_spawn",id);

	return 1;
}

// our delay
public post_spawn(id)
{
	if(!is_user_connected(id)) return;

	// should be frozen?
	if(won)
	{
		set_pev(id,pev_flags,pev(id,pev_flags) | FL_FROZEN);
		fm_set_user_godmode(id,1);
	}

	levelsThisRound[id] = 0;

	// just joined
	if(!level[id])
	{
		// handicap
		new handicapMode = get_pcvar_num(gg_handicap_on), teamplay = get_pcvar_num(gg_teamplay);
		if(handicapMode && !teamplay)
		{
			new rcvHandicap = 1;

			get_pcvar_string(gg_stats_file,sfFile,63);

			// top10 doesn't receive handicap -- also make sure we are using top10
			if(!get_pcvar_num(gg_top10_handicap) && sfFile[0] && file_exists(sfFile) && get_pcvar_num(gg_stats_mode))
			{
				static authid[24];

				if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
				else get_user_authid(id,authid,23);

				new i;
				for(i=0;i<TOP_PLAYERS;i++)
				{
					// blank
					if(!top10[i][0]) continue;

					// isolate authid
					strtok(top10[i],sfAuthid,23,dummy,1,'^t');

					// I'm in top10, don't give me handicap
					if(equal(authid,sfAuthid))
					{
						rcvHandicap = 0;
						break;
					}
				}
			}

			if(rcvHandicap)
			{
				new player;

				// find lowest level (don't use bots unless we have to)
				if(handicapMode == 2)
				{
					new isBot, myLevel, lowestLevel, lowestBotLevel;
					for(player=1;player<=maxPlayers;player++)
					{
						if(!is_user_connected(player) || player == id)
							continue;

						isBot = is_user_bot(player);
						myLevel = level[player];

						if(!myLevel) continue;

						if(!isBot && (!lowestLevel || myLevel < lowestLevel))
							lowestLevel = myLevel;
						else if(isBot && (!lowestBotLevel || myLevel < lowestBotLevel))
							lowestBotLevel = myLevel;
					}

					// CLAMP!
					if(!lowestLevel) lowestLevel = 1;
					if(!lowestBotLevel) lowestBotLevel = 1;

					change_level(id,(lowestLevel > 1) ? lowestLevel : lowestBotLevel,1,_,1); // just joined, always score
				}

				// find average level
				else
				{
					new Float:average, num;
					for(player=1;player<=maxPlayers;player++)
					{
						if(is_user_connected(player) && player != id)
						{
							average += float(level[player]);
							num++;
						}
					}

					average /= float(num);
					change_level(id,(average >= 0.5) ? floatround(average) : 1,1,_,1); // just joined, always score
				}
			}

			// not eligible for handicap (in top10 with gg_top10_handicap disabled)
			else change_level(id,1,1_,1); // just joined, always score
		}

		// no handicap enabled or playing teamplay
		else
		{
			if(teamplay)
			{
				new team = get_user_team(id);

				if(team == 1 || team == 2)
				{
					// my team has a level already
					if(teamLevel[team])
					{
						change_level(id,teamLevel[team],1,_,1,_,0); // just joined, always score, don't effect team
						if(teamScore[team]) change_score(id,teamScore[team],_,0); // don't effect team
					}

					// my team just started
					else
					{
						// initialize its values
						teamplay_update_level(team,1,id);
						teamplay_update_score(team,0,id);

						change_level(id,teamLevel[team],1,_,1,_,0); // just joined, always score, don't effect team
					}
				}
			}

			// solo-play
			else change_level(id,1,1,_,1); // just joined, always score
		}
	}

	// didn't just join
	else
	{
		if(star[id])
		{
			end_star(TASK_END_STAR+id);
			remove_task(TASK_END_STAR+id);
		}

		if(get_pcvar_num(gg_teamplay))
		{
			new team = get_user_team(id);

			// my team just started
			if((team == 1 || team == 2) && !teamLevel[team])
			{
				// initialize its values
				teamplay_update_level(team,1,id);
				teamplay_update_score(team,0,id);

				change_level(id,teamLevel[team]-level[id],_,_,1,_,0); // always score, don't effect team
				change_score(id,teamScore[team]-score[id],_,0); // don't effect team
			}
		}

		give_level_weapon(id);
		refill_ammo(id);
	}

	// show welcome message
	if(!welcomed[id] && get_pcvar_num(gg_join_msg))
		show_welcome(id);
}

// someone changes weapons
public event_curweapon(id)
{
	if(!ggActive) return;

	// keep star speed
	if(star[id]) fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)*1.5);
}

// ammo amount changes
public event_ammox(id)
{
	new type = read_data(1);

	// not HE grenade ammo, or not on the grenade level
	if(!fws_is_nade_ammo(type) || !fws_is_nade(lvlWeapon[id])) return;

	new amount = read_data(2);

	// still have some left, ignore
	if(amount > 0)
	{
		remove_task(TASK_REFRESH_NADE+id);
		return;
	}

	new Float:refresh = get_pcvar_float(gg_nade_refresh);

	// refreshing is disabled, or we are already giving one out
	if(refresh <= 0.0 || task_exists(TASK_REFRESH_NADE+id)) return;

	// start the timer for the new grenade
	set_task(refresh,"refresh_nade",TASK_REFRESH_NADE+id);
}

// map is changing
public event_intermission()
{
	if(!ggActive || won) return;

	new player, found;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && fws_on_valid_team(player))
		{
			found = 1;
			break;
		}
	}

	// did not find any players on a valid team, game over man
	if(!found) return;

	// teamplay, easier to decide
	if(get_pcvar_num(gg_teamplay))
	{
		new winner;

		// clear winner
		if(teamLevel[1] > teamLevel[2]) winner = 1;
		else if(teamLevel[2] > teamLevel[1]) winner = 2;
		else
		{
			// tied for level, check score
			if(teamScore[1] > teamScore[2]) winner = 1;
			else if(teamScore[2] > teamScore[1]) winner = 2;
			else
			{
				// tied for level and score, pick random
				winner = random_num(1,2);
			}
		}

		// grab a player from the winning and losing teams
		new plWinner, plLoser;
		for(player=1;player<=maxPlayers;player++)
		{
			if(is_user_connected(player) && fws_on_valid_team(player))
			{
				if(!plWinner && get_user_team(player) == winner) plWinner = player;
				else if(!plLoser) plLoser = player;

				if(plWinner && plLoser) break;
			}
		}

		win(plWinner,plLoser);
		return;
	}

	// grab highest level
	new leaderLevel;
	get_leader(leaderLevel);

	// grab player list
	new players[32], pNum, winner, i;
	get_players(players,pNum);

	// no one here
	if(pNum <= 0) return;

	new topLevel[32], tlNum;

	// get all of the highest level players
	for(i=0;i<pNum;i++)
	{
		player = players[i];

		if(level[player] == leaderLevel)
			topLevel[tlNum++] = player;
	}

	// only one on top level
	if(tlNum == 1) winner = topLevel[0];
	else
	{
		new highestKills, frags;

		// get the most kills
		for(i=0;i<tlNum;i++)
		{
			frags = get_user_frags(topLevel[i]);

			if(frags >= highestKills)
				highestKills = frags;
		}

		new topKillers[32], tkNum;

		// get all of the players with highest kills
		for(i=0;i<tlNum;i++)
		{
			if(get_user_frags(topLevel[i]) == highestKills)
				topKillers[tkNum++] = topLevel[i];
		}

		// only one on top kills
		if(tkNum == 1) winner = topKillers[0];
		else
		{
			new leastDeaths, deaths;

			// get the least deaths
			for(i=0;i<tkNum;i++)
			{
				deaths = get_mod_user_deaths(topKillers[i]);
				if(deaths <= leastDeaths) leastDeaths = deaths;
			}

			new leastDead[32], ldNum;

			// get all of the players with lowest deaths
			for(i=0;i<tkNum;i++)
			{
				if(get_mod_user_deaths(topKillers[i]) == leastDeaths)
					leastDead[ldNum++] = topKillers[i];
			}

			leastDead[random_num(0,ldNum-1)];
		}
	}

	// crown them
	win(winner,0);
}

/**********************************************************************
* HAM HOOKS
**********************************************************************/

// it's just that easy (multiplay_gamerules.cpp, ln 709)
public ham_player_killed(victim,killer,gib)
{
	if(!ggActive) return HAM_IGNORED;

	// log in bounds
	if(killer > 0 && killer < 33 && victim > 0 && victim < 33)
		lastKilled[killer] = victim;

	if(!is_user_connected(victim)) return HAM_IGNORED;

	remove_task(TASK_VERIFY_WEAPON+victim);

	star[victim] = 0;
	remove_task(TASK_END_STAR+victim);

	static wpnName[24];
	get_killer_weapon(killer,pev(victim,pev_dmg_inflictor),wpnName,23);

	new okay = fws_verify_death(killer,victim,wpnName,24);

	// check for any objections first
	if(okay <= 0)
	{
		if(okay == -1 && is_user_connected(killer)) refill_ammo(killer,1);
		return HAM_IGNORED;
	}

	// killed self with worldspawn (fall damage usually)
	if(equal(wpnName,"worldspawn"))
	{
		if(get_pcvar_num(gg_worldspawn_suicide)) player_suicided(victim);
		return HAM_IGNORED;
	}

	// killed self not with worldspawn
	if(!killer || killer == victim)
	{
		player_suicided(victim);
		return HAM_IGNORED;
	}

	// a non-player entity killed this man!
	if(!is_user_connected(killer))
	{
		// not linked so return is hit either way
		if(pev_valid(killer))
		{
			static classname[14];
			pev(killer,pev_classname,classname,13);

			// killed by a trigger_hurt, count as suicide
			if(equal(classname,"trigger_hurt"))
				player_suicided(victim);
		}

		return HAM_IGNORED;
	}

	new teamplay = get_pcvar_num(gg_teamplay);

	// team kill
	if(is_user_connected(victim) && fws_same_team(killer,victim))
	{
		new penalty = get_pcvar_num(gg_tk_penalty);

		if(penalty > 0)
		{
			new name[32];
			if(teamplay) get_team_name(get_user_team(killer),name,31);
			else get_user_name(killer,name,31);

			if(score[killer] - penalty < 0)
				gungame_print(0,killer,1,"%L",LANG_PLAYER_C,(teamplay) ? "TK_LEVEL_DOWN_TEAM" : "TK_LEVEL_DOWN",name,(level[killer] > 1) ? level[killer]-1 : level[killer]);
			else
				gungame_print(0,killer,1,"%L",LANG_PLAYER_C,(teamplay) ? "TK_SCORE_DOWN_TEAM" : "TK_SCORE_DOWN",name,penalty);

			change_score(killer,-penalty);
		}

		return HAM_IGNORED;
	}

	new canLevel = 1, scored;

	// already reached max levels this round
	new max_lvl = get_pcvar_num(gg_max_lvl);
	if(!get_pcvar_num(gg_teamplay) && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[killer] >= max_lvl)
		canLevel = 0;

	new is_nade = fws_is_nade(lvlWeapon[killer]);

	// was it a melee kill, and does it matter?
	if(fws_is_melee(wpnName) && get_pcvar_num(gg_knife_pro) && !fws_is_melee(lvlWeapon[killer]))
	{
		static killerName[32], victimName[32];
		get_user_name(killer,killerName,31);
		get_user_name(victim,victimName,31);

		new tpGainPoints, tpLosePoints, tpOverride;
		if(teamplay)
		{
			tpGainPoints = get_level_goal(level[killer],0);
			tpLosePoints = get_level_goal(level[victim],0);
			gungame_print(0,killer,1,"%L",LANG_PLAYER_C,"STOLE_LEVEL_TEAM",killerName,tpLosePoints,victimName,tpGainPoints);

			// allow points awarded on nade or final level if it won't level us
			tpOverride = (score[killer] + tpGainPoints < get_level_goal(level[killer],killer));
		}
		else gungame_print(0,killer,1,"%L",LANG_PLAYER_C,"STOLE_LEVEL",killerName,victimName);

		if(tpOverride || (canLevel && !is_nade))
		{
			if(tpOverride || level[killer] < get_weapon_num())
			{
				if(teamplay)
				{
					// gain points and possibly show kills
					if(!change_score(killer,tpGainPoints))
						show_required_kills(killer);
				}
				else change_level(killer,1,_,_,_,0); // don't play sounds
			}
		}

		play_sound_by_cvar(killer,gg_sound_levelsteal); // use this one instead!

		if(level[victim] > 1 || teamplay)
		{
			if(teamplay) change_score(victim,-tpLosePoints);
			else change_level(victim,-1);
		}
	}

	// otherwise, if he killed with his appropiate weapon, give him a point
	else if(canLevel && equal(lvlWeapon[killer],wpnName))
	{
		scored = 1;

		// didn't level off of it
		if(!change_score(killer,get_pcvar_num(g_pPointPerKill))) show_required_kills(killer);
	}

	// refresh grenades
	if(is_nade && get_pcvar_num(gg_extra_nades))
	{
		remove_task(TASK_REFRESH_NADE+killer);

		// instant refresh, and refresh_nade makes sure we don't already have a nade
		refresh_nade(TASK_REFRESH_NADE+killer);
	}

	if((!scored || !get_pcvar_num(gg_turbo)) && get_pcvar_num(gg_refill_on_kill))
		refill_ammo(killer,1);

	return HAM_IGNORED;
}

/**********************************************************************
* COMMAND HOOKS
**********************************************************************/

// turning GunGame on or off
public cmd_gungame_status(id,level,cid)
{
	// no access, or GunGame ending anyway
	if(!cmd_access(id,level,cid,2) || won)
		return PLUGIN_HANDLED;

	// already working on toggling GunGame
	if(task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_FORCE)
	|| task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_DISABLE)
	|| task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_ENABLE))
	{
		console_print(id,"[GunGame] GunGame is already being turned on or off");
		return PLUGIN_HANDLED;
	}

	new arg[32], oldStatus = ggActive, newStatus;
	read_argv(1,arg,31);

	if(equali(arg,"on") || str_to_num(arg))
		newStatus = 1;

	// no change
	if((!oldStatus && !newStatus) || (oldStatus && newStatus))
	{
		console_print(id,"[GunGame] GunGame is already %s!",(newStatus) ? "on" : "off");
		return PLUGIN_HANDLED;
	}

	new Float:time = float(fws_restart_round(5)) - 0.2;
	set_task((time < 0.1) ? 0.1 : time,"toggle_gungame",TASK_TOGGLE_GUNGAME+newStatus);

	if(!newStatus)
	{
		set_pcvar_num(gg_enabled,0);
		ggActive = 0;
		fws_gungame_toggled(ggActive);
	}

	console_print(id,"[GunGame] Turned GunGame %s",(newStatus) ? "on" : "off");

	return PLUGIN_HANDLED;
}

// voting for GunGame
public cmd_gungame_vote(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	autovote_start();
	console_print(id,"[GunGame] Started a vote to play GunGame");

	return PLUGIN_HANDLED;
}

// setting players levels
public cmd_gungame_level(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,3))
		return PLUGIN_HANDLED;

	new arg1[32], arg2[32], targets[32], name[32], tnum, i;
	read_argv(1,arg1,31);
	read_argv(2,arg2,31);

	// get player list
	if(equali(arg1,"*") || equali(arg1,"@ALL"))
	{
		get_players(targets,tnum);
		name = "ALL PLAYERS";
	}
	else if(arg1[0] == '@')
	{
		new players[32], team[32], pnum;
		get_players(players,pnum);

		for(i=0;i<pnum;i++)
		{
			get_user_team(players[i],team,31);
			if(equali(team,arg1[1])) targets[tnum++] = players[i];
		}

		formatex(name,31,"ALL %s",arg1[1]);
	}
	else
	{
		targets[tnum++] = cmd_target(id,arg1,2);
		if(!targets[0]) return PLUGIN_HANDLED;

		get_user_name(targets[0],name,31);
	}

	new intval = str_to_num(arg2);

	// relative
	if(arg2[0] == '+' || arg2[0] == '-')
		for(i=0;i<tnum;i++) change_level(targets[i],intval,_,_,1); // always score

	// absolute
	else
		for(i=0;i<tnum;i++) change_level(targets[i],intval-level[targets[i]],_,_,1); // always score

	console_print(id,"[GunGame] Changed %s's level to %s",name,arg2);

	return PLUGIN_HANDLED;
}

// forcing a win
public cmd_gungame_win(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	new arg[32];
	read_argv(1,arg,31);

	// no target given, select best player
	if(!arg[0])
	{
		console_print(id,"[GunGame] Forcing the best player to win...");
		event_intermission();
		return PLUGIN_HANDLED;
	}

	new target = cmd_target(id,arg,2);
	if(!target) return PLUGIN_HANDLED;

	new name[32];
	get_user_name(target,name,31);
	console_print(id,"[GunGame] Forcing %s to win (cheater)...",name);

	// make our target win (oh, we're dirty!)
	win(target,0);

	return PLUGIN_HANDLED;
}

// turn teamplay on or off
public cmd_gungame_teamplay(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,2))
		return PLUGIN_HANDLED;

	new oldValue = get_pcvar_num(gg_teamplay);

	new arg1[32], arg2[8], arg3[8];
	read_argv(1,arg1,31);
	read_argv(2,arg2,7);
	read_argv(3,arg3,7);

	new teamplay = str_to_num(arg1);
	new Float:killsperlvl = floatstr(arg2);
	new suicideloselvl = str_to_num(arg3);

	new result[128];
	len = formatex(result,127,"[GunGame] Turned Teamplay Mode %s",(teamplay) ? "on" : "off");

	server_cmd("gg_teamplay %i",teamplay);
	if(killsperlvl > 0.0)
	{
		server_cmd("gg_kills_per_lvl %f",killsperlvl);
		len += formatex(result[len],127-len,", set kills per level to %f",killsperlvl);
	}
	if(arg3[0])
	{
		server_cmd("gg_suicide_penalty %i",suicideloselvl);
		len += formatex(result[len],127-len,", set suicide penalty to %i",suicideloselvl);
	}

	console_print(id,"%s",result);

	if(teamplay != oldValue) fws_restart_round(1);

	return PLUGIN_HANDLED;
}

// restarts GunGame
public cmd_gungame_restart(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	new arg[32];
	read_argv(1,arg,31);

	new time = str_to_num(arg);
	if(time < 1) time = 1;

	fws_restart_round(time);
	console_print(id,"[GunGame] Restarting GunGame in %i seconds",time);

	return PLUGIN_HANDLED;
}

// block fullupdate
public cmd_fullupdate(id)
{
	return PLUGIN_HANDLED;
}

// hook say
public cmd_say(id)
{
	if(!ggActive) return PLUGIN_CONTINUE;

	static message[10];
	read_argv(1,message,9);

	// doesn't begin with !, ignore
	if(message[0] != '!') return PLUGIN_CONTINUE;

	if(equali(message,"!rules") || equali(message,"!help"))
	{
		new num = 1, max_lvl = get_pcvar_num(gg_max_lvl), turbo = get_pcvar_num(gg_turbo);

		console_print(id,"-----------------------------");
		console_print(id,"-----------------------------");
		console_print(id,"*** Avalanche's %L %s %L ***",id,"GUNGAME",GG_VERSION,id,"RULES");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE1",num++);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE2",num++);
		if(get_cvar_num("gg_cs_bomb_defuse_lvl")) console_print(id,"%L",id,"RULES_CONSOLE_LINE3",num++);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE4",num++);
		if(get_pcvar_num(gg_ff_auto)) console_print(id,"%L",id,"RULES_CONSOLE_LINE5",num++);
		if(turbo || !max_lvl) console_print(id,"%L",id,"RULES_CONSOLE_LINE6A",num++);
		else if(max_lvl == 1) console_print(id,"%L",id,"RULES_CONSOLE_LINE6B",num++);
		else if(max_lvl > 1) console_print(id,"%L",id,"RULES_CONSOLE_LINE6C",num++,max_lvl);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE7",num++);
		if(get_pcvar_num(gg_knife_pro)) console_print(id,"%L",id,"RULES_CONSOLE_LINE8",num++);
		if(turbo) console_print(id,"%L",id,"RULES_CONSOLE_LINE9",num++);
		if(get_pcvar_num(gg_knife_elite)) console_print(id,"%L",id,"RULES_CONSOLE_LINE10",num++);
		if((cstrike) && (get_cvar_num("gg_cs_dm") || get_cvar_num("csdm_active"))) console_print(id,"%L",id,"RULES_CONSOLE_LINE11",num++);
		if(get_pcvar_num(gg_teamplay)) console_print(id,"%L",id,"RULES_CONSOLE_LINE12",num++);
		console_print(id,"****************************************************************");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE13");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE14");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE15");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE16");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE17");
		console_print(id,"-----------------------------");
		console_print(id,"-----------------------------");

		len = formatex(menuText,511,"%L^n",id,"RULES_MESSAGE_LINE1");
		len += formatex(menuText[len],511-len,"\d----------\w^n");
		len += formatex(menuText[len],511-len,"%L^n",id,"RULES_MESSAGE_LINE2");
		len += formatex(menuText[len],511-len,"\d----------\w^n");
		len += formatex(menuText[len],511-len,"%L^n",id,"RULES_MESSAGE_LINE3");
		len += formatex(menuText[len],511-len,"\d----------\w^n%L",id,"PRESS_KEY_TO_CONTINUE");

		show_menu(id,1023,menuText);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!weapons") || equali(message,"!guns"))
	{
		page[id] = 1;
		show_weapons_menu(id);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!top10"))
	{
		get_pcvar_string(gg_stats_file,sfFile,63);

		// stats disabled
		if(!sfFile[0] || !get_pcvar_num(gg_stats_mode))
		{
			client_print(id,print_chat,"%L",id,"NO_WIN_LOGGING");
			return PLUGIN_HANDLED;
		}

		page[id] = 1;
		show_top10_menu(id);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!score") || equali(message,"!scores"))
	{
		page[id] = 1;
		show_scores_menu(id);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!level"))
	{
		show_level_menu(id);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!restart") || equali(message,"!reset"))
	{
		if(level[id] <= 1)
		{
			client_print(id,print_chat,"%L",id,"STILL_LEVEL_ONE");
			return PLUGIN_HANDLED;
		}

		len = formatex(menuText,511,"%L^n^n",id,"RESET_QUERY");
		len += formatex(menuText[len],511-len,"1. %L^n",id,"YES");
		len += formatex(menuText[len],511-len,"0. %L",id,"CANCEL");
		show_menu(id,MENU_KEY_1|MENU_KEY_0,menuText,-1,"restart_menu");

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

/**********************************************************************
*	MENU FUNCTIONS
**********************************************************************/

// handle the welcome menu
public welcome_menu_handler(id,key)
{
	// just save welcomed status and let menu close
	welcomed[id] = 1;
	return PLUGIN_HANDLED;
}

// this menu does nothing but display stuff
public level_menu_handler(id,key)
{
	return PLUGIN_HANDLED;
}

// handle the reset level menu
public restart_menu_handler(id,key)
{
	if(get_pcvar_num(gg_teamplay))
	{
		client_print(id,print_chat,"%L",id,"RESET_NOT_ALLOWED");
		return PLUGIN_HANDLED;
	}

	if(level[id] <= 1)
	{
		client_print(id,print_chat,"%L",id,"STILL_LEVEL_ONE");
		return PLUGIN_HANDLED;
	}

	// 1. Yes
	if(key == 0)
	{
		new name[32];
		get_user_name(id,name,31);

		change_level(id,-(level[id]-1),_,_,1); // back to level 1 -- always score
		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"PLAYER_RESET",name);
	}

	return PLUGIN_HANDLED;
}

// show the level display
show_level_menu(id)
{
	new goal, tied, leaderNum, leaderList[128], name[32];

	new leaderLevel, numLeaders, leader, runnerUp;
	new teamplay = get_pcvar_num(gg_teamplay), team;

	if(teamplay) leader = teamplay_get_lead_team(leaderLevel,numLeaders,runnerUp);
	else leader = get_leader(leaderLevel,numLeaders,runnerUp);

	len = 0;

	if(numLeaders > 1) tied = 1;

	if(teamplay)
	{
		team = get_user_team(id);

		if(numLeaders == 1)
		{
			new team1[32];
			get_team_name(leader,team1,31);
			len += formatex(leaderList[len],127-len,"%s %L",team1,id,"TEAM");
		}
		else
		{
			new team1[32], team2[32];
			get_team_name(1,team1,31);
			get_team_name(2,team2,31);
			len += formatex(leaderList[len],127-len,"%s %L, %s %L",team1,id,"TEAM",team2,id,"TEAM");
		}
	}
	else
	{
		new players[32], num, i, player;
		get_players(players,num);

		// check for multiple leaders
		for(i=0;i<num;i++)
		{
			player = players[i];

			if(level[player] == leaderLevel)
			{
				if(++leaderNum == 5)
				{
					len += formatex(leaderList[len],127-len,", ...");
					break;
				}

				if(leaderList[0]) len += formatex(leaderList[len],127-len,", ");
				get_user_name(player,name,31);
				len += formatex(leaderList[len],127-len,"%s",name);
			}
		}
	}

	goal = get_level_goal(level[id],id);

	new displayWeapon[16];
	if(level[id]) formatex(displayWeapon,15,"%s",lvlWeapon[id]);
	else formatex(displayWeapon,15,"%L",id,"NONE");

	len = formatex(menuText,511,"%L %i (%s)^n",id,(teamplay) ? "ON_LEVEL_TEAM" : "ON_LEVEL",level[id],displayWeapon);
	len += formatex(menuText[len],511-len,"%L^n",id,(teamplay) ? "LEVEL_MESSAGE_LINE1B" : "LEVEL_MESSAGE_LINE1A",score[id],goal);

	// winning
	if(!tied && ((teamplay && leader == team) || (!teamplay && leader == id)))
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM1",teamLevel[leader]-teamLevel[runnerUp]);
		else len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY1",level[id]-level[runnerUp]);
	}

	// tied
	else if(tied)
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM2");
		else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE2B");
	}

	// losing
	else
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM3",teamLevel[leader]-teamLevel[runnerUp]);
		else len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY4",leaderLevel-level[id]);
	}

	len += formatex(menuText[len],511-len,"\d----------\w^n");

	new authid[24], wins, points;

	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	stats_get_data(authid,wins,points,dummy,1,dummy[0]);

	new stats_mode = get_pcvar_num(gg_stats_mode);

	if(stats_mode)
	{
		if(stats_mode == 1) len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE3A",wins);
		else len += formatex(menuText[len],511-len,"%L (%i %L)^n",id,"LEVEL_MESSAGE_LINE3B",points,wins,id,"WINS");

		len += formatex(menuText[len],511-len,"\d----------\w^n");
	}

	if(leaderNum > 1) len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE4A",leaderList);
	else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE4B",leaderList);

	if(teamplay)
	{
		if(teamLevel[leader]) formatex(displayWeapon,15,"%s",teamLvlWeapon[leader]);
		else formatex(displayWeapon,15,"%L",id,"NONE");
	}
	else
	{
		if(level[leader]) formatex(displayWeapon,15,"%s",lvlWeapon[leader]);
		else formatex(displayWeapon,15,"%L",id,"NONE");
	}

	len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE5",leaderLevel,displayWeapon);
	len += formatex(menuText[len],511-len,"\d----------\w^n");

	len += formatex(menuText[len],511-len,"%L",id,"PRESS_KEY_TO_CONTINUE");
	show_menu(id,1023,menuText,-1,"level_menu");
}

// show the top10 list menu
show_top10_menu(id)
{
	new totalPlayers = TOP_PLAYERS, playersPerPage = 5, stats_mode = get_pcvar_num(gg_stats_mode);
	new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

	if(page[id] < 1) page[id] = 1;
	if(page[id] > pageTotal) page[id] = pageTotal;

	len = formatex(menuText,511-len,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"TOP_10",page[id],pageTotal);
	//len += formatex(menuText[len],511-len,"\d-----------\w^n");

	static top10listing[81];
	new start = (playersPerPage * (page[id]-1)), i;

	for(i=start;i<start+playersPerPage;i++)
	{
		if(i > totalPlayers) break;

		// blank
		if(!top10[i][0])
		{
			len += formatex(menuText[len],511-len,"#%i \d%L\w^n",i+1,id,"NONE");
			continue;
		}

		// assign it to a new variable so that strtok
		// doesn't tear apart our constant top10 variable
		top10listing = top10[i];

		// get rid of authid
		strtok(top10listing,sfAuthid,1,top10listing,80,'^t');

		// isolate wins
		strtok(top10listing,sfWins,5,top10listing,80,'^t');

		// isolate name
		strtok(top10listing,sfName,31,top10listing,80,'^t');

		// break off timestamp and get points
		strtok(top10listing,sfTimestamp,1,sfPoints,7,'^t');

		if(stats_mode == 1)
			len += formatex(menuText[len],511-len,"#%i %s (%s %L)^n",i+1,sfName,sfWins,id,"WINS");
		else
			len += formatex(menuText[len],511-len,"#%i %s (%i %L, %s %L)^n",i+1,sfName,str_to_num(sfPoints),id,"POINTS",sfWins,id,"WINS");
	}

	len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new keys = MENU_KEY_0;

	if(page[id] > 1)
	{
		len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
		keys |= MENU_KEY_1;
	}
	if(page[id] < pageTotal)
	{
		len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
		keys |= MENU_KEY_2;
	}
	len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");

	show_menu(id,keys,menuText,-1,"top10_menu");
}

// someone pressed a key on the top10 list menu page
public top10_menu_handler(id,key)
{
	new totalPlayers = TOP_PLAYERS, playersPerPage = 5;
	new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_top10_menu(id);

		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_top10_menu(id);

		return;
	}

	// 0. Close
	// do nothing, menu closes automatically
}

// show the weapon list menu
show_weapons_menu(id)
{
	new totalWeapons = get_weapon_num(), wpnsPerPage = 10;
	new pageTotal = floatround(float(totalWeapons) / float(wpnsPerPage),floatround_ceil);

	if(page[id] < 1) page[id] = 1;
	if(page[id] > pageTotal) page[id] = pageTotal;

	len = formatex(menuText,511-len,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"WEAPONS",page[id],pageTotal);
	//len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new start = (wpnsPerPage * (page[id]-1)) + 1, i, wName[24];

	// are there any custom kill requirements?
	get_pcvar_string(gg_weapon_order,weaponOrder,WEAPONORDER_SIZE-1);
	new customKills = (contain(weaponOrder,":") != -1);

	for(i=start;i<start+wpnsPerPage;i++)
	{
		if(i > totalWeapons) break;

		get_weapon_name_by_level(i,wName,23);

		if(customKills)
			len += formatex(menuText[len],511-len,"%L %i: %s (%i)^n",id,"LEVEL",i,wName,get_level_goal(i));
		else
			len += formatex(menuText[len],511-len,"%L %i: %s^n",id,"LEVEL",i,wName);
	}

	len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new keys = MENU_KEY_0;

	if(page[id] > 1)
	{
		len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
		keys |= MENU_KEY_1;
	}
	if(page[id] < pageTotal)
	{
		len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
		keys |= MENU_KEY_2;
	}
	len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");

	show_menu(id,keys,menuText,-1,"weapons_menu");
}

// someone pressed a key on the weapon list menu page
public weapons_menu_handler(id,key)
{
	new totalWeapons = get_weapon_num(), wpnsPerPage = 10;
	new pageTotal = floatround(float(totalWeapons) / float(wpnsPerPage),floatround_ceil);

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_weapons_menu(id);
		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_weapons_menu(id);
		return;
	}

	// 0. Close
	// do nothing, menu closes automatically
}

// show the score list menu
show_scores_menu(id)
{
	new keys;

	if(get_pcvar_num(gg_teamplay))
	{
		if(page[id] != 1) page[id] = 1;

		new leader = teamplay_get_lead_team(), otherTeam = (leader == 1) ? 2 : 1;
		new displayWeapon[24], teamName[32];

		len = formatex(menuText,511,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"SCORES",page[id],1);

		new team;
		for(team=leader;team>0;team=otherTeam)
		{
			if(teamLevel[team] && teamLvlWeapon[team][0]) formatex(displayWeapon,23,"%s",teamLvlWeapon[team]);
			else formatex(displayWeapon,23,"%L",id,"NONE");

			get_team_name(team,teamName,31);
			len += formatex(menuText[len],511-len,"#%i %s %L, %L %i (%s) %i/%i^n",(team == leader) ? 1 : 2,teamName,id,"TEAM",id,"LEVEL",teamLevel[team],displayWeapon,teamScore[team],teamplay_get_team_goal(team));

			// finished
			if(team == otherTeam) break;
		}

		// nice separator!
		len += formatex(menuText[len],511-len,"\d-----------\w^n");

		keys = MENU_KEY_0;
		len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");
	}
	else
	{
		new totalPlayers = get_playersnum(), playersPerPage = 5, stats_mode = get_pcvar_num(gg_stats_mode);
		new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

		if(page[id] < 1) page[id] = 1;
		if(page[id] > pageTotal) page[id] = pageTotal;

		new players[32], num;
		get_players(players,num);

		// order by highest level first
		SortCustom1D(players,num,"score_custom_compare");

		len = formatex(menuText,511,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"SCORES",page[id],pageTotal);
		//len += formatex(menuText[len],511-len,"\d-----------\w^n");

		new start = (playersPerPage * (page[id]-1)), i, name[32], player, authid[24], wins, points;

		// check for stats
		get_pcvar_string(gg_stats_file,sfFile,63);

		new stats_ip = get_pcvar_num(gg_stats_ip), displayWeapon[24];

		for(i=start;i<start+playersPerPage;i++)
		{
			if(i >= totalPlayers) break;

			player = players[i];
			get_user_name(player,name,31);

			if(level[player] && lvlWeapon[player][0]) formatex(displayWeapon,23,"%s",lvlWeapon[player]);
			else formatex(displayWeapon,23,"%L",id,"NONE");

			if(sfFile[0] && stats_mode)
			{
				if(stats_ip) get_user_ip(player,authid,23);
				else get_user_authid(player,authid,23);

				stats_get_data(authid,wins,points,dummy,1,dummy[0]);

				len += formatex(menuText[len],511-len,"#%i %s, %L %i (%s) %i/%i, %i %L^n",i+1,name,id,"LEVEL",level[player],displayWeapon,score[player],get_level_goal(level[player]),(stats_mode == 1) ? wins : points,id,(stats_mode == 1) ? "WINS" : "POINTS");
			}
			else len += formatex(menuText[len],511-len,"#%i %s, %L %i (%s) %i/%i^n",i+1,name,id,"LEVEL",level[player],displayWeapon,score[player],get_level_goal(level[player]));
		}

		len += formatex(menuText[len],511-len,"\d-----------\w^n");

		keys = MENU_KEY_0;

		if(page[id] > 1)
		{
			len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
			keys |= MENU_KEY_1;
		}
		if(page[id] < pageTotal)
		{
			len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
			keys |= MENU_KEY_2;
		}
		len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");
	}

	show_menu(id,keys,menuText,-1,"scores_menu");
}

// sort list of players with their level first
public score_custom_compare(elem1,elem2)
{
	// invalid players
	if(elem1 < 1 || elem1 > 32 || elem2 < 1 || elem2 > 32)
		return 0;

	// tied levels, compare scores
	if(level[elem1] == level[elem2])
	{
		if(score[elem1] > score[elem2]) return -1;
		else if(score[elem1] < score[elem2]) return 1;
		else return 0;
	}

	// compare levels
	else if(level[elem1] > level[elem2]) return -1;
	else if(level[elem1] < level[elem2]) return 1;

	return 0; // equal
}

// someone pressed a key on the score list menu page
public scores_menu_handler(id,key)
{
	new totalPlayers = get_playersnum(), playersPerPage = 5;
	new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_scores_menu(id);
		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_scores_menu(id);
		return;
	}

	// 0. Close
	// do nothing, menu closes automatically
}

/**********************************************************************
* MAIN FUNCTIONS
**********************************************************************/

// toggle the status of gungame
public toggle_gungame(taskid)
{
	new status = taskid-TASK_TOGGLE_GUNGAME, i;

	// clear player tasks and values
	for(i=1;i<=32;i++) clear_values(i);

	clear_team_values(1);
	clear_team_values(2);

	// clear temp saves
	for(i=0;i<TEMP_SAVES;i++) clear_save(TASK_CLEAR_SAVE+i);

	if(status == TOGGLE_FORCE || status == TOGGLE_ENABLE)
	{
		new cfgFile[64];
		get_gg_config_file(cfgFile,63);

		// run the gungame config
		if(cfgFile[0] && file_exists(cfgFile))
		{
			new command[512], file, i;

			file = fopen(cfgFile,"rt");
			while(file && !feof(file))
			{
				fgets(file,command,511);
				new len = strlen(command) - 2;

				// stop at a comment
				for(i=0;i<len;i++)
				{
					// only check config-style (;) comments as first character,
					// since they could be used ie in gg_map_setup to separate
					// commands. also check for coding-style (//) comments
					if((i == 0 && command[i] == ';') || (command[i] == '/' && command[i+1] == '/'))
					{
						copy(command,i,command);
						break;
					}
				}

				// this will effect GunGame's status
				if(containi(command,"gg_enabled") != -1)
				{
					// don't override our setting from amx_gungame
					if(status == TOGGLE_ENABLE) continue;

					new val[8];
					parse(command,dummy,1,val,7);

					// update active status
					ggActive = str_to_num(val);
					fws_gungame_toggled(ggActive);
				}

				trim(command);
				if(command[0]) server_cmd(command);
			}
			if(file) fclose(file);
		}
	}

	// set to what we chose from amx_gungame
	if(status != TOGGLE_FORCE)
	{
		set_pcvar_num(gg_enabled,status);
		ggActive = status;
		fws_gungame_toggled(ggActive);
	}

	// execute all of those cvars that we just set
	server_exec();

	// run appropiate cvars
	map_start_cvars();

	// reset some things
	if(!ggActive)
	{
		// clear HUD message
		if(warmup > 0) ClearSyncHud(0,hudSyncWarmup);

		warmup = -1;
		warmupWeapon[0] = 0;
		voted = 0;
		won = 0;

		remove_task(TASK_WARMUP_CHECK);
		fws_warmup_changed(warmup,warmupWeapon);
	}

	stats_get_top_players(TOP_PLAYERS,top10,80);

	// game_player_equip
	manage_equips();

	// start (or stop) the leader display
	remove_task(TASK_LEADER_DISPLAY);
	show_leader_display();
}

// run cvars that should be run on map start
public map_start_cvars()
{
	new setup[512];

	// gungame is disabled, run endmap_setup
	if(!ggActive)
	{
		get_pcvar_string(gg_endmap_setup,setup,511);
		if(setup[0]) server_cmd(setup);
	}
	else
	{
		// run map setup
		get_pcvar_string(gg_map_setup,setup,511);
		if(setup[0]) server_cmd(setup);

		// random weapon orders
		do_rOrder();

		// random win sounds
		currentWinSound = do_rWinSound();
	}
}

// sift through the config to check for custom sounds
set_sounds_from_config()
{
	new cfgFile[64];
	get_gg_config_file(cfgFile,63);

	// run the gungame config
	if(cfgFile[0] && file_exists(cfgFile))
	{
		new command[WINSOUNDS_SIZE+32], cvar[32], value[WINSOUNDS_SIZE], file, i;

		file = fopen(cfgFile,"rt");
		while(file && !feof(file))
		{
			fgets(file,command,WINSOUNDS_SIZE+31);
			new len = strlen(command) - 2;

			// stop at a comment
			for(i=0;i<len;i++)
			{
				// only check config-style (;) comments as first character,
				// since they could be used ie in gg_map_setup to separate
				// commands. also check for coding-style (//) comments
				if((i == 0 && command[i] == ';') || (command[i] == '/' && command[i+1] == '/'))
				{
					copy(command,i,command);
					break;
				}
			}

			// this is a sound
			if(equal(command,"gg_sound_",9) || equal(command,"gg_lead_sounds"))
			{
				parse(command,cvar,31,value,WINSOUNDS_SIZE-1);
				set_cvar_string(cvar,value);
			}
		}
		if(file) fclose(file);
	}
}

// manage stats pruning
public manage_pruning()
{
	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist/pruning disabled
	if(!sfFile[0] || !file_exists(sfFile) || !get_pcvar_num(gg_stats_prune)) return;

	// get how many plugin ends more until we prune
	new prune_in_str[3], prune_in;
	get_localinfo("gg_prune_in",prune_in_str,2);
	prune_in = str_to_num(prune_in_str);

	// localinfo not set yet
	if(!prune_in)
	{
		set_localinfo("gg_prune_in","9");
		return;
	}

	// time to prune
	if(prune_in == 1)
	{
		// prune and log
		log_amx("%L",LANG_SERVER,"PRUNING",sfFile,stats_prune());

		// reset our prune count
		set_localinfo("gg_prune_in","10");
		return;
	}

	// decrement our count
	num_to_str(prune_in-1,prune_in_str,2);
	set_localinfo("gg_prune_in",prune_in_str);
}

// manage warmup mode
public warmup_check(taskid)
{
	warmup--;
	set_hudmessage(255,255,255,-1.0,0.4,0,6.0,1.0,0.1,0.2);

	if(warmup <= 0)
	{
		warmup = -13;
		warmupWeapon[0] = 0;
		fws_warmup_changed(warmup,warmupWeapon);

		ShowSyncHudMsg(0,hudSyncWarmup,"%L",LANG_PLAYER,"WARMUP_ROUND_OVER");
		fws_restart_round(1);

		return;
	}

	ShowSyncHudMsg(0,hudSyncWarmup,"%L",LANG_PLAYER,"WARMUP_ROUND_DISPLAY",warmup);
	set_task(1.0,"warmup_check",taskid);

	fws_warmup_changed(warmup,warmupWeapon);
}

// show the leader display
public show_leader_display()
{
	 static Float:lastDisplay, lastLeader, lastLevel, leaderName[32];

	 if(!ggActive || !get_pcvar_num(gg_leader_display))
	 {
	 	 remove_task(TASK_LEADER_DISPLAY);
	 	 return 0;
	 }

	 // keep it going
	 if(!task_exists(TASK_LEADER_DISPLAY))
		set_task(LEADER_DISPLAY_RATE,"show_leader_display",TASK_LEADER_DISPLAY,_,_,"b");

	 // don't show during warmup or game over
	 if(warmup > 0 || won) return 0;

	 new leaderLevel, numLeaders, leader, teamplay = get_pcvar_num(gg_teamplay);

	 if(teamplay) leader = teamplay_get_lead_team(leaderLevel,numLeaders);
	 else leader = get_leader(leaderLevel,numLeaders);

	 if(!leader || leaderLevel <= 0) return 0;

	 // we just displayed the same message, don't flood
	 new Float:time = get_gametime();
	 if(lastLevel == leaderLevel &&  lastLeader == leader && lastDisplay == time) return 0;

	 // remember for later
	 lastDisplay = time;
	 lastLeader = leader;
	 lastLevel = leaderLevel;

	 if(teamplay) get_team_name(leader,leaderName,31);
	 else get_user_name(leader,leaderName,31);

	 set_hudmessage(200,200,200,get_pcvar_float(gg_leader_display_x),get_pcvar_float(gg_leader_display_y),_,_,LEADER_DISPLAY_RATE+0.5,0.0,0.0);

	 if(numLeaders > 1)
	 {
	 	if(teamplay)
	 	{
	 		new otherName[32];
	 		get_team_name((leader == 1) ? 2 : 1,otherName,31);

	 		ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s + %s (%i - %s)",LANG_PLAYER,"LEADER",leaderName,otherName,leaderLevel,teamLvlWeapon[leader])
	 	}
	 	else ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s +%i (%i - %s)",LANG_PLAYER,"LEADER",leaderName,numLeaders-1,leaderLevel,lvlWeapon[leader]);
	 }
	 else ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s (%i - %s)",LANG_PLAYER,"LEADER",leaderName,leaderLevel,(teamplay) ? teamLvlWeapon[leader] : lvlWeapon[leader]);

	 return 1;
}

// show the nice HUD progress display
show_progress_display(id)
{
	static statusString[48];

	new teamplay = get_pcvar_num(gg_teamplay);
	if(teamplay)
	{
		new team = get_user_team(id), otherTeam = (team == 1) ? 2 : 1;
		if(team != 1 && team != 2) return;

		new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);

		// tied
		if(numLeaders > 1) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM2");

		// leading
		else if(leader == team) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM1",teamLevel[team]-teamLevel[otherTeam]);

		// losing
		else formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM3",teamLevel[otherTeam]-teamLevel[team]);
	}
	else
	{
		new leaderLevel, numLeaders, runnerUp;
		new leader = get_leader(leaderLevel,numLeaders,runnerUp);

		if(level[id] == leaderLevel)
		{
			if(numLeaders == 1) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY1",leaderLevel-level[runnerUp]);
			else if(numLeaders == 2)
			{
				new otherLeader;
				if(leader != id) otherLeader = leader;
				else
				{
					new player;
					for(player=1;player<=maxPlayers;player++)
					{
						if(is_user_connected(player) && level[player] == leaderLevel && player != id)
						{
							otherLeader = player;
							break;
						}
					}
				}

				static otherName[32];
				get_user_name(otherLeader,otherName,31);

				formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY2",otherName);
			}
			else
			{
				static numWord[16];
				num_to_word(numLeaders-1,numWord,15);
				trim(numWord);
				formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY3",numWord);
			}
		}
		else formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY4",leaderLevel-level[id]);
	}

	gungame_hudmessage(id,5.0,"%L %i (%s)^n%s",id,(teamplay) ? "ON_LEVEL_TEAM" : "ON_LEVEL",level[id],lvlWeapon[id],statusString);
}

// play the taken/tied/lost lead sounds
public play_lead_sounds(id,oldLevel,Float:playDelay)
{
	// id: the player whose level changed
	// oldLevel: his level before it changed
	// playDelay: how long to wait until we play id's sounds

	if(get_pcvar_num(gg_teamplay))
	{
		// redirect to other function
		teamplay_play_lead_sounds(id,oldLevel,Float:playDelay);
		return;
	}

	// warmup or game over, no one cares
	if(warmup > 0 || won) return;

	// no level change
	if(level[id] == oldLevel) return;

	//
	// monitor MY stuff first
	//

	new leaderLevel, numLeaders;
	get_leader(leaderLevel,numLeaders);

	// I'm now on the leader level
	if(level[id] == leaderLevel)
	{
		// someone else here?
		if(numLeaders > 1)
		{
			new params[2];
			params[0] = id;
			params[1] = gg_sound_tiedlead;

			remove_task(TASK_PLAY_LEAD_SOUNDS+id);
			set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);
		}

		// just me, I'm the winner!
		else
		{
			// did I just pass someone?
			if(level[id] > oldLevel && num_players_on_level(oldLevel))
			{
				new params[2];
				params[0] = id;
				params[1] = gg_sound_takenlead;

				remove_task(TASK_PLAY_LEAD_SOUNDS+id);
				set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);
			}
		}
	}

	// WAS I on the leader level?
	else if(oldLevel == leaderLevel)
	{
		new params[2];
		params[0] = id;
		params[1] = gg_sound_lostlead;

		remove_task(TASK_PLAY_LEAD_SOUNDS+id);
		set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);

		//return; // will not effect other players
	}

	// nothing of importance
	else return; // will not effect other players

	//
	// now monitor other players.
	// if we get this far, id is now in the lead level
	//

	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player) || player == id) continue;

		// PLAYER tied with ID
		if(level[player] == level[id])
		{
			// don't tell him if he already got it from another player
			if(num_players_on_level(level[id]) <= 2
			|| (oldLevel > level[id] && leaderLevel == level[id])) // dropped into tied position
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_tiedlead;

				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}

		// PLAYER passed by ID
		else if(level[id] > level[player] && level[player] == oldLevel)
		{
			// don't tell him if he already got it from another player
			if(num_players_on_level(level[id]) <= 1)
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_lostlead;

				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}

		// ID passed by PLAYER
		else if(level[player] > level[id] && leaderLevel == level[player])
		{
			// I stand alone!
			if(num_players_on_level(level[player]) <= 1)
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_takenlead;

				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}
	}
}

// manage game_player_equip and player_weaponstrip entities
public manage_equips()
{
	static classname[20], targetname[24];
	new ent, i, block_equips = get_pcvar_num(gg_block_equips), enabled = ggActive;

	// go through both entities to monitor
	for(i=0;i<4;i++)
	{
		// get classname for current iteration
		switch(i)
		{
			case 0: classname = "game_player_equip";
			case 1: classname = "game_player_equip2";
			case 2: classname = "player_weaponstrip";
			default: classname = "player_weaponstrip2";
		}

		// go through whatever entity
		ent = 0;
		while((ent = fm_find_ent_by_class(ent,classname)))
		{
			// allowed to have this, reverse possible changes
			if(!enabled || !block_equips || (i >= 2 && block_equips < 2)) // player_weaponstrip switch
			{
				pev(ent,pev_targetname,targetname,23);

				// this one was blocked
				if(equal(targetname,"gg_block_equips"))
				{
					pev(ent,TNAME_SAVE,targetname,23);

					set_pev(ent,pev_targetname,targetname);
					set_pev(ent,TNAME_SAVE,"");

					switch(i)
					{
						case 0, 1: set_pev(ent,pev_classname,"game_player_equip");
						default: set_pev(ent,pev_classname,"player_weaponstrip");
					}
				}
			}

			// not allowed to pickup others, make possible changes
			else
			{
				pev(ent,pev_targetname,targetname,23);

				// needs to be blocked, but hasn't been yet
				if(targetname[0] && !equal(targetname,"gg_block_equips"))
				{
					set_pev(ent,TNAME_SAVE,targetname);
					set_pev(ent,pev_targetname,"gg_block_equips");

					// classname change is required sometimes for some reason
					switch(i)
					{
						case 0, 1: set_pev(ent,pev_classname,"game_player_equip2");
						default: set_pev(ent,pev_classname,"player_weaponstrip2");
					}
				}
			}
		}
	}
}

// select a random weapon order
do_rOrder()
{
	new i, maxRandom, cvar[20];
	for(i=1;i<=MAX_WEAPON_ORDERS+1;i++) // +1 so we can detect final
	{
		formatex(cvar,19,"gg_weapon_order%i",i);
		get_cvar_string(cvar,weaponOrder,WEAPONORDER_SIZE-1);
		trim(weaponOrder);

		// found a blank one, stop here
		if(!weaponOrder[0])
		{
			maxRandom = i - 1;
			break;
		}
	}

	// we found some random ones
	if(maxRandom)
	{
		new randomOrder[30], lastOIstr[6], lastOI, orderAmt;
		get_localinfo("gg_rand_order",randomOrder,29);
		get_localinfo("gg_last_oi",lastOIstr,5);
		lastOI = str_to_num(lastOIstr);
		orderAmt = get_rOrder_amount(randomOrder);

		// no random order yet, or amount of random orders changed
		if(!randomOrder[0] || orderAmt != maxRandom)
		{
			shuffle_rOrder(randomOrder,29,maxRandom);
			lastOI = 0;
		}

		// reached the end, reshuffle while avoiding this one
		else if(get_rOrder_index_val(orderAmt,randomOrder) == get_rOrder_index_val(lastOI,randomOrder))
		{
			shuffle_rOrder(randomOrder,29,maxRandom,lastOI);
			lastOI = 0;
		}

		new choice = get_rOrder_index_val(lastOI+1,randomOrder);

		// get its weapon order
		formatex(cvar,19,"gg_weapon_order%i",choice);
		get_cvar_string(cvar,weaponOrder,WEAPONORDER_SIZE-1);

		// set as current
		set_cvar_string("gg_weapon_order",weaponOrder);

		// remember for next time
		num_to_str(lastOI+1,lastOIstr,5);
		set_localinfo("gg_last_oi",lastOIstr);
	}
}

// get the value of an order index in an order string
get_rOrder_index_val(index,randomOrder[])
{
	// only one listed
	if(str_count(randomOrder,',') < 1)
		return str_to_num(randomOrder);

	// find preceding comma
	new search = str_find_num(randomOrder,',',index-1);

	// go until succeeding comma
	new extract[6];
	copyc(extract,5,randomOrder[search+1],',');

	return str_to_num(extract);
}

// gets the amount of orders in an order string
get_rOrder_amount(randomOrder[])
{
	return str_count(randomOrder,',')+1;
}

// shuffle up our random order
stock shuffle_rOrder(randomOrder[],len,maxRandom,avoid=-1)
{
	randomOrder[0] = 0;

	// fill up array with order indexes
	new order[MAX_WEAPON_ORDERS], i;
	for(i=0;i<maxRandom;i++) order[i] = i+1;

	// shuffle it
	SortCustom1D(order,maxRandom,"sort_shuffle");

	// avoid a specific number as the starting number
	while(avoid > 0 && order[0] == avoid)
		SortCustom1D(order,maxRandom,"sort_shuffle");

	// get them into a string
	for(i=0;i<maxRandom;i++)
	{
		format(randomOrder,len,"%s%s%i",randomOrder,(i>0) ? "," : "",order[i]);
		set_localinfo("gg_rand_order",randomOrder);
	}
}

// play a random win sound
do_rWinSound()
{
	// just one, no one cares
	if(numWinSounds <= 1)
	{
		return 0; // 1 minus 1
	}

	new randomOrder[30], lastWSIstr[6], lastWSI, orderAmt;
	get_localinfo("gg_winsound_order",randomOrder,29);
	get_localinfo("gg_last_wsi",lastWSIstr,5);
	lastWSI = str_to_num(lastWSIstr);
	orderAmt = get_rWinSound_amount(randomOrder);

	// no random order yet, or amount of random orders changed
	if(!randomOrder[0] || orderAmt != numWinSounds)
	{
		shuffle_rWinSound(randomOrder,29);
		lastWSI = 0;
	}

	// reached the end, reshuffle while avoiding this one
	else if(get_rWinSound_index_val(orderAmt,randomOrder) == get_rWinSound_index_val(lastWSI,randomOrder))
	{
		shuffle_rWinSound(randomOrder,29,lastWSI);
		lastWSI = 0;
	}

	new choice = get_rWinSound_index_val(lastWSI+1,randomOrder);

	// remember for next time
	num_to_str(lastWSI+1,lastWSIstr,5);
	set_localinfo("gg_last_wsi",lastWSIstr);

	return choice-1;
}

// get the value of an order index in an order string
get_rWinSound_index_val(index,randomOrder[])
{
	// only one listed
	if(str_count(randomOrder,',') < 1)
		return str_to_num(randomOrder);

	// find preceding comma
	new search = str_find_num(randomOrder,',',index-1);

	// go until succeeding comma
	new extract[6];
	copyc(extract,5,randomOrder[search+1],',');

	return str_to_num(extract);
}

// gets the amount of orders in an order string
get_rWinSound_amount(randomOrder[])
{
	return str_count(randomOrder,',')+1;
}

// shuffle up our random order
stock shuffle_rWinSound(randomOrder[],len,avoid=-1)
{
	randomOrder[0] = 0;

	// fill up array with order indexes
	new order[MAX_WINSOUNDS], i;
	for(i=0;i<numWinSounds;i++) order[i] = i+1;

	// shuffle it
	SortCustom1D(order,numWinSounds,"sort_shuffle");

	// avoid a specific number as the starting number
	while(avoid > 0 && order[0] == avoid)
		SortCustom1D(order,numWinSounds,"sort_shuffle");

	// get them into a string
	for(i=0;i<numWinSounds;i++)
	{
		format(randomOrder,len,"%s%s%i",randomOrder,(i>0) ? "," : "",order[i]);
		set_localinfo("gg_winsound_order",randomOrder);
	}
}

// shuffle an array
public sort_shuffle(elem1,elem2)
{
	return random_num(-1,1);
}

// clear all saved values
clear_values(id,ignoreWelcome=0)
{
	level[id] = 0;
	levelsThisRound[id] = 0;
	score[id] = 0;
	lvlWeapon[id][0] = 0;
	star[id] = 0;
	if(!ignoreWelcome) welcomed[id] = 0;
	page[id] = 0;
	lastKilled[id] = 0;

	// let them know to clear their values
	fws_cleared_values(id);

	// update satellite plugins
	fws_level_changed(id,level[id],lvlWeapon[id]);
	fws_score_changed(id,score[id]);

	return 1;
}

// clears a TEAM's values
clear_team_values(team)
{
	 if(team != 1 && team != 2) return;

	 teamLevel[team] = 0;
	 teamLvlWeapon[team][0] = 0;
	 teamScore[team] = 0;
}

// a new round has begun, called from ggn_notify_new_round
new_round()
{
	roundEnded = 0;
	roundsElapsed++;

	if(!autovoted)
	{
		new autovote_rounds = get_pcvar_num(gg_autovote_rounds);

		if(autovote_rounds && gameCommenced && roundsElapsed >= autovote_rounds)
		{
			autovoted = 1;
			set_task(get_pcvar_float(gg_autovote_delay),"autovote_start");
		}
	}

	// game_player_equip
	manage_equips();

	if(!ggActive) return 0;

	// we should probably warmup...
	// don't ask me where I'm getting this from.
	if(shouldWarmup)
	{
		shouldWarmup = 0;
		start_warmup();
	}

	if(warmup <= 0)
	{
		new leader = get_leader();

		if(fws_is_nade(lvlWeapon[leader])) play_sound_by_cvar(0,gg_sound_nade);
		else if(fws_is_melee(lvlWeapon[leader])) play_sound_by_cvar(0,gg_sound_knife);
	}

	// reset leader display
	remove_task(TASK_LEADER_DISPLAY);
	set_task(0.5,"show_leader_display"); // wait to initialize levels

	return 1;
}

// the round ends, called from ggn_notify_round_end
round_end()
{
	roundEnded = 1;
	return 1;
}

// possibly start a warmup round
start_warmup()
{
	new warmup_value = get_pcvar_num(gg_warmup_timer_setting);

	// warmup is set to -13 after its finished if gg_warmup_multi is 0,
	// so this stops multiple warmups for multiple map iterations
	if(warmup_value > 0 && warmup != -13)
	{
		warmup = warmup_value;
		get_pcvar_string(gg_warmup_weapon,warmupWeapon,23);
		set_task(0.1,"warmup_check",TASK_WARMUP_CHECK);
		fws_warmup_changed(warmup,warmupWeapon);

		// now that warmup is in effect, reset player weapons
		new player;
		for(player=1;player<=maxPlayers;player++)
		{
			if(is_user_connected(player))
			{
				// just joined for all intents and purposes
				change_level(player,-MAX_WEAPONS,1,_,1,0,0); // just joined, always score, don't play sounds, don't effect team
			}
		}

		// a single team update instead of for everyone
		if(get_pcvar_num(gg_teamplay))
		{
			teamplay_update_score(1,0);
			teamplay_update_score(2,0);
			teamplay_update_level(1,1);
			teamplay_update_level(2,1);
		}

		// clear leader display for warmup
		if(warmup > 0) ClearSyncHud(0,hudSyncLDisplay);
	}
}

// refresh a player's hegrenade stock
public refresh_nade(taskid)
{
	new id = taskid-TASK_REFRESH_NADE;

	// player left, player died, or GunGame turned off
	if(!is_user_connected(id) || !is_user_alive(id) || !ggActive) return;

	// not on the grenade level, or have one already
	if(!fws_is_nade(lvlWeapon[id]) || user_has_grenade(id))
		return;

	// get weapon name for this level
	static fullName[24];
	formatex(fullName,23,"weapon_%s",lvlWeapon[id]);

	// give another hegrenade
	ham_give_weapon(id,fullName);
}

// refill a player's ammo
stock refill_ammo(id,current=0)
{
	if(!is_user_alive(id)) return 0;

	// weapon-specific warmup
	if(warmup > 0 && warmupWeapon[0])
	{
		// no ammo for knives only
		if(fws_is_melee(warmupWeapon))
		{
			fws_refilled_ammo(id,0);
			return 0;
		}
	}

	// get weapon name and index
	static fullName[24], curWpnName[24];
	new wpnid, curWpnMelee, curweapon = get_user_weapon(id,dummy[0],dummy[0]);

	// re-init start of strings
	fullName[0] = 0;
	curWpnName[0] = 0;

	// we have a valid current weapon (stupid runtime errors)
	if(curweapon)
	{
		get_mod_weaponname(curweapon,curWpnName,23);
		curWpnMelee = fws_is_melee(curWpnName);
	}

	// if we are refilling our current weapon instead of our level weapon,
	// we actually have a current weapon, and this isn't a melee weapon or the
	// other alternative, our level weapon, is a melee weapon
	if(current && curweapon && (!curWpnMelee || fws_is_melee(lvlWeapon[id])))
	{
		// refill our current weapon
		get_mod_weaponname(curweapon,fullName,23);
		wpnid = curweapon;
	}
	else
	{
		// refill our level weapon
		formatex(fullName,23,"weapon_%s",lvlWeapon[id]);
		wpnid = get_mod_weaponid(fullName);

		// so that we know for sure
		current = 0;
	}

	// didn't find anything valid to refill somehow
	if(wpnid < 1 || wpnid > 35 || !fullName[0])
	{
		fws_refilled_ammo(id,0);
		return 0;
	}

	// no reason to refill a melee weapon.
	// make use of our curWpnMelee cache here
	if((current && curWpnMelee) || fws_is_melee(fullName))
	{
		fws_refilled_ammo(id,wpnid);
		return 1;
	}

	new ammo, wEnt;
	ammo = get_pcvar_num(gg_ammo_amount);

	// don't give away hundreds of grenades
	if(!fws_is_nade(fullName))
	{
		// set clip ammo
		wEnt = get_weapon_ent(id,wpnid);
		if(pev_valid(wEnt)) set_weapon_ammo(wEnt,maxClip[wpnid]);

		// set backpack ammo
		if(ammo > 0) set_user_bpammo(id,wpnid,ammo);
		else set_user_bpammo(id,wpnid,maxAmmo[wpnid]);

		// update display if we need to
		if(curweapon == wpnid)
		{
			message_begin(MSG_ONE,gmsgCurWeapon,_,id);
			write_byte(1);
			write_byte(wpnid);
			write_byte(maxClip[wpnid]);
			message_end();
		}
	}

	// now do stupid grenade stuff.
	// NOTE: considerably less stupid since we moved CS nade stuff.
	else
	{
		// we don't have this nade yet
		if(!user_has_weapon(id,wpnid))
		{
			ham_give_weapon(id,fullName);
			remove_task(TASK_REFRESH_NADE+id);
		}
	}

	// keep melee weapon out if we had it out
	if(curweapon && curWpnMelee)
	{
		engclient_cmd(id,curWpnName);
		client_cmd(id,curWpnName);
	}

	fws_refilled_ammo(id,wpnid);

	return 1;
}

// show someone a welcome message
public show_welcome(id)
{
	if(welcomed[id]) return;

	new menuid, keys;
	get_user_menu(id,menuid,keys);

	// another old-school menu opened
	if(menuid > 0)
	{
		// wait and try again
		set_task(3.0,"show_welcome",id);
		return;
	}

	play_sound_by_cvar(id,gg_sound_welcome);

	len = formatex(menuText,511,"\y%L\w^n",id,"WELCOME_MESSAGE_LINE1",GG_VERSION);
	len += formatex(menuText[len],511-len,"\d---------------\w^n");

	new special;
	if(get_pcvar_num(gg_knife_pro))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE2");
		special = 1;
	}
	if(get_pcvar_num(gg_turbo))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE3");
		special = 1;
	}
	if(get_pcvar_num(gg_knife_elite))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE4");
		special = 1;
	}
	if(cstrike && (get_cvar_num("gg_cs_dm") || get_cvar_num("csdm_active")))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE5");
		special = 1;
	}
	if(get_pcvar_num(gg_teamplay))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE6");
		special = 1;
	}

	if(special) len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE7",get_weapon_num());
	len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L",id,"WELCOME_MESSAGE_LINE8");
	len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L",id,"PRESS_KEY_TO_CONTINUE");

	show_menu(id,1023,menuText,-1,"welcome_menu");
}

// show the required kills message
stock show_required_kills(id,always_individual=0)
{
	// weapon-specific warmup, who cares
	if(warmup > 0 && warmupWeapon[0]) return 0;

	if(always_individual || !get_pcvar_num(gg_teamplay))
		return gungame_hudmessage(id,3.0,"%L: %i / %i",id,"REQUIRED_KILLS",score[id],get_level_goal(level[id],id));

	new player, myTeam = get_user_team(id), goal = get_level_goal(teamLevel[myTeam],id);
	for(player=1;player<=maxPlayers;player++)
	{
		if(player == id || (is_user_connected(player) && get_user_team(player) == myTeam))
			gungame_hudmessage(player,3.0,"%L: %i / %i",player,"REQUIRED_KILLS",teamScore[myTeam],goal);
	}

	return 1;
}

// player killed himself
player_suicided(id)
{
	// we still have protection (round ended, new one hasn't started yet)
	// or, suicide level downs are disabled
	if(roundEnded || !get_pcvar_num(gg_suicide_penalty)) return 0;

	static name[32];

	if(!get_pcvar_num(gg_teamplay))
	{
		get_user_name(id,name,31);

		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_LEVEL_DOWN",name);

		// this is going to start a respawn counter HUD message
		if(cstrike && get_cvar_num("gg_cs_dm") && (get_cvar_num("gg_cs_dm_countdown") & 2))
			return change_level(id,-1,_,0,1); // don't show message, always score

		// show with message
		return change_level(id,-1,_,_,1); // always score
	}
	else
	{
		new team = get_user_team(id);
		if(team != 1 && team != 2) return 0;

		new penalty = get_level_goal(teamLevel[team],0);
		if(penalty > 0)
		{
			get_team_name(team,name,31);

			if(teamScore[team] - penalty < 0)
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_LEVEL_DOWN_TEAM",name,(teamLevel[team] > 1) ? teamLevel[team]-1 : teamLevel[team]);
			else
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_SCORE_DOWN_TEAM",name,penalty);

			return change_score(id,-penalty);
		}
	}

	return 0;
}

// player scored or lost a point
stock change_score(id,value,refill=1,effect_team=1)
{
	// don't bother scoring up on weapon-specific warmup
	if(warmup > 0 && warmupWeapon[0] && value > 0)
		return 0;

	if(!can_score(id)) return 0;

	// already won, isn't important
	if(level[id] > get_weapon_num()) return 0;

	new oldScore = score[id], goal = get_level_goal(level[id],id);

	new teamplay = get_pcvar_num(gg_teamplay), team;
	if(teamplay) team = get_user_team(id);

	// if this is going to level us
	if(score[id] + value >= goal)
	{
		new max_lvl = get_pcvar_num(gg_max_lvl);

		// already reached max levels this round
		if(!teamplay && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[id] >= max_lvl)
		{
			// put it as high as we can without leveling
			score[id] = goal - 1;
		}
		else score[id] += value;
	}
	else score[id] += value;

	// check for level up
	if(score[id] >= goal)
	{
		score[id] = 0;

		// no comment WHOOPS
		fws_score_changed(id,score[id]);

		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct

		change_level(id,1);
		return 1;
	}

	// check for level down
	if(score[id] < 0)
	{
		if(value < 0) show_required_kills(id);

		// can't go down below level 1
		if(level[id] <= 1)
		{
			score[id] = 0;

			// what? this one slipped in late
			fws_score_changed(id,score[id]);

			if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
				teamplay_update_score(team,score[id],id,1); // direct

			return 0;
		}
		else
		{
			goal = get_level_goal(level[id] > 1 ? level[id]-1 : 1,id);

			score[id] = (oldScore + value) + goal; // carry over points
			if(score[id] < 0) score[id] = 0;

			// no comment really this time WHOOPS
			fws_score_changed(id,score[id]);

			if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
				teamplay_update_score(team,score[id],id,1); // direct

			change_level(id,-1);
			return -1;
		}
	}

	// refresh menus
	new menu;
	get_user_menu(id,menu,dummy[0]);
	if(menu == level_menu) show_level_menu(id);

	if(refill && get_pcvar_num(gg_refill_on_kill)) refill_ammo(id);

	// alright I really got it this time WHOOPS
	fws_score_changed(id,score[id]);

	if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
		teamplay_update_score(team,score[id],id,1); // direct

	if(value < 0) show_required_kills(id);
	else client_cmd(id,"speak ^"buttons/bell1.wav^"");

	return 0;
}

// player gained or lost a level
stock change_level(id,value,just_joined=0,show_message=1,always_score=0,play_sounds=1,effect_team=1)
{
	// can't score
	if(level[id] > 0 && !always_score && !can_score(id))
		return 0;

	// don't bother leveling up on weapon-specific warmup
	if(level[id] > 0 && warmup > 0 && warmupWeapon[0] && value > 0)
		return 0;

	new oldLevel = level[id], oldValue = value;

	new teamplay = get_pcvar_num(gg_teamplay), team;
	if(teamplay) team = get_user_team(id);

	// teamplay, on a valid team
	if(teamplay && (team == 1 || team == 2))
	{
		// not effecting team, but setting me to something that doesn't match team
		// OR
		// effecting team, and not even starting on same thing as team
		if((!effect_team && level[id] + value != teamLevel[team]) || (effect_team && level[id] != teamLevel[team]))
		{
			log_amx("MISSYNCH -- id: %i, value: %i, just_joined: %i, show_message: %i, always_score: %i, play_sounds: %i, effect_team: %i, team: %i, level: %i, teamlevel: %i, usertime: %i, score: %i, teamscore: %i, lvlweapon: %s, teamlvlweapon: %s",
				id,value,just_joined,show_message,always_score,play_sounds,effect_team,team,level[id],teamLevel[team],get_user_time(id,1),score[id],teamScore[team],lvlWeapon[id],teamLvlWeapon[team]);

			log_message("MISSYNCH -- id: %i, value: %i, just_joined: %i, show_message: %i, always_score: %i, play_sounds: %i, effect_team: %i, team: %i, level: %i, teamlevel: %i, usertime: %i, score: %i, teamscore: %i, lvlweapon: %s, teamlvlweapon: %s",
				id,value,just_joined,show_message,always_score,play_sounds,effect_team,team,level[id],teamLevel[team],get_user_time(id,1),score[id],teamScore[team],lvlWeapon[id],teamLvlWeapon[team]);
		}
	}

	// this will put us below level 1
	if(level[id] + value < 1)
	{
		value = 1 - level[id]; // go down only to level 1

		// bottom out the score
		score[id] = 0;

		fws_score_changed(id,0);

		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
	}

	// going up
	if(value > 0)
	{
		new max_lvl = get_pcvar_num(gg_max_lvl);

		// already reached max levels for this round
		if(!teamplay && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[id] >= max_lvl)
			return 0;
	}

	level[id] += value;
	if(!just_joined)	levelsThisRound[id] += value;

	// win???
	if(level[id] > get_weapon_num())
	{
		// already won, ignore this
		if(won) return 1;

		// cap out score
		score[id] = get_level_goal(level[id],id);

		fws_score_changed(id,score[id]);

		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct

		// let everyone know while we still can, because I just can't believe that
		// we'll be leaving this if statement with our lives! :( I LOVE YOU!!!!!!!
		fws_level_changed(id,level[id],lvlWeapon[id]);

		if(teamplay && effect_team && (team == 1 || team == 2) && teamLevel[team] != level[id])
			teamplay_update_level(team,level[id],id,1); // direct

		// still warming up (wow, this guy is good)
		if(warmup > 0)
		{
			change_level(id,-value,just_joined,0,1); // don't show message, always score

			client_print(id,print_chat,"%L",id,"SLOW_DOWN");
			client_print(id,print_center,"%L",id,"SLOW_DOWN");

			return 1;
		}

		// bot, and not allowed to win
		if(is_user_bot(id) && get_pcvar_num(gg_ignore_bots) == 2 && !only_bots())
		{
			change_level(id,-value,just_joined,_,1); // always score
			return 1;
		}

		// crown the winner
		win(id,lastKilled[id]);

		return 1;
	}

	// set weapon based on it
	get_level_weapon(level[id],lvlWeapon[id],23);

	new is_nade = fws_is_nade(lvlWeapon[id]); // cache

	// I'm a leader!
	if(warmup <= 0 && level[get_leader()] == level[id])
	{
		new sound_cvar;
		if(is_nade) sound_cvar = gg_sound_nade;
		else if(fws_is_melee(lvlWeapon[id])) sound_cvar = gg_sound_knife;

		if(sound_cvar)
		{
			// only play sound if we reached this level first
			if(num_players_on_level(level[id]) == 1) play_sound_by_cvar(0,sound_cvar);
		}
	}

	// NOW play level up sounds, so that they potentially
	// override the global "Player is on X level" sounds

	if(play_sounds)
	{
		// level up!
		if(oldValue >= 0) play_sound_by_cvar(id,gg_sound_levelup);

		// level down :(
		else play_sound_by_cvar(id,gg_sound_leveldown);
	}

	// remember to modify changes
	new oldTeamLevel;
	if(team == 1 || team == 2) oldTeamLevel = teamLevel[team];

	// alert the masses
	fws_level_changed(id,level[id],lvlWeapon[id]);

	if(teamplay && effect_team && (team == 1 || team == 2) && teamLevel[team] != level[id])
		teamplay_update_level(team,level[id],id);

	// refresh menus
	new player, menu;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		get_user_menu(player,menu,dummy[0]);

		if(menu == scores_menu) show_scores_menu(player);
		else if(menu == level_menu) show_level_menu(player);
	}

	// make sure we don't have more than required now
	new goal = get_level_goal(level[id],id);
	if(score[id] >= goal)
	{
		score[id] = goal-1; // 1 under

		// update the others
		fws_score_changed(id,score[id]);

		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
	}

	new turbo = get_pcvar_num(gg_turbo);

	// give weapon right away?
	if((turbo || just_joined) && is_user_alive(id)) give_level_weapon(id);
	else show_progress_display(id); // still show display anyway

	// update the leader display (cvar check done in that function)
	if(!just_joined)
	{
		remove_task(TASK_LEADER_DISPLAY);
		show_leader_display();

		new Float:lead_sounds = get_pcvar_float(gg_lead_sounds);
		if(lead_sounds > 0.0 && (!teamplay || effect_team)) play_lead_sounds(id,oldLevel,lead_sounds);
	}

	new vote_setting = get_pcvar_num(gg_vote_setting), map_iterations = get_pcvar_num(gg_map_iterations);

	// the level to start a map vote on
	if(!voted && warmup <= 0 && vote_setting > 0
	&& level[id] >= get_weapon_num() - (vote_setting - 1)
	&& mapIteration >= map_iterations && map_iterations > 0)
	{
		new mapCycleFile[64];
		get_gg_mapcycle_file(mapCycleFile,63);

		// start map vote?
		if(!mapCycleFile[0] || !file_exists(mapCycleFile))
		{
			voted = 1;

			// check for a custom vote
			new custom[256];
			get_pcvar_string(gg_vote_custom,custom,255);

			if(custom[0]) server_cmd(custom);
			else start_mapvote();
		}
	}

	// grab my name
	static name[32];
	if(!teamplay) get_user_name(id,name,31);

	// only calculate position if we didn't just join
	if(!just_joined && show_message)
	{
		if(teamplay)
		{
			// is the first call for this level change
			if((team == 1 || team == 2) && teamLevel[team] != oldTeamLevel)
			{
				new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);

				// tied
				if(numLeaders > 1) gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_TEAM",leaderLevel,teamLvlWeapon[team]);

				// leading
				else if(leader == team)
				{
					get_team_name(team,name,31);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"LEADING_ON_LEVEL_TEAM",name,leaderLevel,teamLvlWeapon[team]);
				}

				// trailing
				else
				{
					get_team_name(team,name,31);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TRAILING_ON_LEVEL_TEAM",name,teamLevel[team],teamLvlWeapon[team]);
				}
			}
		}
		else
		{
			new leaderLevel, numLeaders, leader = get_leader(leaderLevel,numLeaders);

			// tied
			if(level[id] == leaderLevel && numLeaders > 1 && level[id] > 1)
			{
				if(numLeaders == 2)
				{
					new otherLeader;
					if(leader != id) otherLeader = leader;
					else
					{
						new player;
						for(player=1;player<=maxPlayers;player++)
						{
							if(is_user_connected(player) && level[player] == leaderLevel && player != id)
							{
								otherLeader = player;
								break;
							}
						}
					}

					static otherName[32];
					get_user_name(otherLeader,otherName,31);

					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_ONE",name,leaderLevel,lvlWeapon[id],otherName);
				}
				else
				{
					static numWord[16];
					num_to_word(numLeaders-1,numWord,15);
					trim(numWord);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_MULTI",name,leaderLevel,lvlWeapon[id],numWord);
				}
			}

			// I'M THE BEST!!!!!!!
			else if(leader == id && level[id] > 1)
			{
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"LEADING_ON_LEVEL",name,level[id],lvlWeapon[id]);
			}
		}
	}

	// teamplay, didn't grab name yet
	if(teamplay) get_user_name(id,name,31);

	// triple bonus!
	if(levelsThisRound[id] == 3 && get_pcvar_num(gg_triple_on) && !turbo)
	{
		star[id] = 1;

		new sound[64];
		get_pcvar_string(gg_sound_triple,sound,63);

		fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)*1.5);
		if(sound[0]) emit_sound(id,CHAN_VOICE,sound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		set_pev(id,pev_effects,pev(id,pev_effects) | EF_BRIGHTLIGHT);
		fm_set_rendering(id,kRenderFxGlowShell,255,255,100,kRenderNormal,1);
		fm_set_user_godmode(id,1);

		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(22); // TE_BEAMFOLLOW
		write_short(id); // entity
		write_short(trailSpr); // sprite
		write_byte(20); // life
		write_byte(10); // width
		write_byte(255); // r
		write_byte(255); // g
		write_byte(100); // b
		write_byte(100); // brightness
		message_end();

		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TRIPLE_LEVELED",name);
		set_task(10.0,"end_star",TASK_END_STAR+id);
	}

	// does this mod support friendlyfire?
	if(mp_friendlyfire)
	{
		// we don't bother with pcvars in here because they have some sketchy bugs about them!
		// maybe these are fixed in AMXX 1.8? who knows!

		new ff_auto = get_pcvar_num(gg_ff_auto), ff = get_cvar_num("mp_friendlyfire");

		// turn on FF?
		if(ff_auto && !ff && is_nade)
		{
			server_cmd("mp_friendlyfire 1"); // so console is notified
			set_cvar_num("mp_friendlyfire",1); // so it changes instantly

			gungame_print(0,0,1,"%L",LANG_PLAYER_C,"FRIENDLYFIRE_ON");

			client_cmd(0,"speak ^"gungame/brass_bell_C.wav^"");
		}

		// turn off FF?
		else if(ff_auto && ff)
		{
			new keepFF, player;

			for(player=1;player<=maxPlayers;player++)
			{
				if(fws_is_nade(lvlWeapon[player]) || fws_is_melee(lvlWeapon[player]))
				{
					keepFF = 1;
					break;
				}
			}

			// no one is on nade or knife level anymore
			if(!keepFF)
			{
				server_cmd("mp_friendlyfire 0"); // so console is notified
				set_cvar_num("mp_friendlyfire",0); // so it changes instantly
			}
		}
	}

	return 1;
}

// forces a player to a level, skipping a lot of important stuff.
// it's assumed that this is used as a result of "id" being leveled
// up because his teammate leveled up in teamplay.
stock set_level_noifandsorbuts(id,newLevel,play_sounds=1)
{
	new oldLevel = level[id];

	level[id] = newLevel;
	get_level_weapon(level[id],lvlWeapon[id],23);

	if(play_sounds)
	{
		// level up!
		if(newLevel >= oldLevel) play_sound_by_cvar(id,gg_sound_levelup);

		// level down :(
		else play_sound_by_cvar(id,gg_sound_leveldown);
	}

	// refresh menus
	new player, menu;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		get_user_menu(player,menu,dummy[0]);

		if(menu == scores_menu) show_scores_menu(player);
		else if(menu == level_menu) show_level_menu(player);
	}

	// give weapon right away?
	if(get_pcvar_num(gg_turbo) && is_user_alive(id)) give_level_weapon(id);
	else show_progress_display(id); // still show display anyway

	return 1;
}

// get rid of a player's star
public end_star(taskid)
{
	new id = taskid - TASK_END_STAR;
	if(!star[id]) return;

	star[id] = 0;
	//gungame_print(id,0,1,"Your star has run out!");

	if(is_user_alive(id))
	{
		fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)/1.5);
		emit_sound(id,CHAN_VOICE,"common/null.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM); // stop sound
		set_pev(id,pev_effects,pev(id,pev_effects) & ~EF_BRIGHTLIGHT);
		fm_set_rendering(id);
		fm_set_user_godmode(id,0);

		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(99); // TE_KILLBEAM
		write_short(id); // entity
		message_end();
	}
}

// give a player a weapon based on his level
stock give_level_weapon(id,notify=1,verify=1)
{
	if(!is_user_alive(id) || level[id] <= 0) return 0;

	// stop attacks from bleeding over into the new weapon
	client_cmd(id,"-attack;-attack2");

	new oldWeapon = get_user_weapon(id,dummy[0],dummy[0]);

	static wpnName[24];
	new weapons = pev(id,pev_weapons), wpnid, alright, myCategory, hasMain;

	new ammo = get_pcvar_num(gg_ammo_amount);
	new knife_elite = get_pcvar_num(gg_knife_elite);
	new pickup_others = get_pcvar_num(gg_pickup_others);
	new mainCategory = get_weapon_category(_,lvlWeapon[id]);

	new melee_only = ((warmup > 0 && warmupWeapon[0] && fws_is_melee(warmupWeapon)) || (knife_elite && levelsThisRound[id] > 0));

	// remove stuff first
	for(wpnid=1;wpnid<32;wpnid++)
	{
		if(!(weapons & (1<<wpnid))) continue;

		// ignore C4 and kevlar
		if(cstrike && (wpnid == CSW_C4 || wpnid == 31))
			continue;

		alright = 0;
		get_mod_weaponname(wpnid,wpnName,23);

		// not knives only, check if this is okay. otherwise, it's assumed to be bad
		if(!melee_only)
		{
			// if this weapon COULD BE SCOPED and I HAVE A NON-SCOPED VERSION or
			// I HAVE A SCOPED VERSION, examine closer to check for consistency
			if(dod && (equal(wpnName,"weapon_fg42") || equal(wpnName,"weapon_enfield"))
				 && (equal(wpnName[7],lvlWeapon[id]) || equal(wpnName[7],lvlWeapon[id][6])))
			{
				new wEnt = fm_find_ent_by_owner(maxPlayers,wpnName,id);
				if(pev_valid(wEnt))
				{
					new shouldBeScoped = equal(lvlWeapon[id],"scoped",6);
					new isScoped = get_pdata_int(wEnt,WPN_SCOPED_OFFSET,WPN_LINUX_DIFF);

					// do our scope values match up?
					if(shouldBeScoped == isScoped)
					{
						alright = 1;
						hasMain = 1;
					}
				}
			}
			else
			{
				replace(wpnName,23,"weapon_","");

				// this is our designated weapon
				if(equal(lvlWeapon[id],wpnName))
				{
					alright = 1;
					hasMain = 1;
				}
			}
		}/*if not knives only*/

		// get the tag back on there
		if(!equal(wpnName,"weapon_",7)) format(wpnName,23,"weapon_%s",wpnName);

		// was it alright?
		if(alright)
		{
			// reset ammo
			if(!fws_is_nade(wpnName))
			{
				if(ammo > 0) set_user_bpammo(id,wpnid,ammo);
				else set_user_bpammo(id,wpnid,maxAmmo[wpnid]);
			}
			else set_user_bpammo(id,wpnid,1); // grenades
		}

		// we should probably remove this weapon
		else
		{
			myCategory = get_weapon_category(wpnid);

			// we aren't allowed to have any other weapons,
			// or this is in the way of the weapon that I want.
			if(!pickup_others || myCategory == mainCategory)
			{
				// if this isn't a melee weapon, disregard this. if it is, only strip
				// it if it's really in the way of the weapon that I want.
				if(!fws_is_melee(wpnName) || myCategory == mainCategory)
				{
					// undeploy machineguns first -- VERY IMPORTANT!
					if(dod && dod_is_deployed(id) && (wpnid == DODW_BAR || wpnid == DODW_MG42
					|| wpnid == DODW_30_CAL || wpnid == DODW_MG34 || wpnid == DODW_FG42
					|| wpnid == DODW_BREN))
					{
						new wEnt = fm_find_ent_by_owner(maxPlayers,wpnName,id);
						if(pev_valid(wEnt)) ExecuteHam(Ham_Weapon_SecondaryAttack,wEnt);
					}

					ham_strip_weapon(id,wpnName);
				}
			}
		}/*not alright*/
	}/*wpnid for loop*/

	// not warming up, didn't just win
	if(notify && warmup <= 0 && level[id] > 0 && level[id] <= get_weapon_num())
		show_progress_display(id);

	// don't try to give away weapons that don't exist in DoD
	if(lvlWeapon[id][0] && !hasMain &&
	(!dod || (!equal(lvlWeapon[id],"bayonet") && !equal(lvlWeapon[id],"garandbutt")
		&& !equal(lvlWeapon[id],"enfbayonet") && !equal(lvlWeapon[id],"k43butt"))))
	{
		formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);

		// give a player his weapon
		ham_give_weapon(id,wpnName);

		remove_task(TASK_REFRESH_NADE+id);

		if(!fws_is_nade(lvlWeapon[id]))
		{
			wpnid = get_mod_weaponid(wpnName);

			if(!wpnid) log_amx("INVALID WEAPON ID FOR ^"%s^"",lvlWeapon[id]);
			else
			{
				if(ammo > 0) set_user_bpammo(id,wpnid,ammo);
				else set_user_bpammo(id,wpnid,maxAmmo[wpnid]);
			}
		}
	}

	// switch back to knife if we had it out. also don't do this when called
	// by the verification check, because their old weapon will obviously be
	// a knife and they will want to use their new one.
	if(verify && !notify)
	{
		get_mod_weaponname(oldWeapon,wpnName,23);
		if(wpnName[0] && fws_is_melee(wpnName))
		{
			engclient_cmd(id,wpnName);
			client_cmd(id,wpnName);
		}
		else if(lvlWeapon[id][0])
		{
			formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
			engclient_cmd(id,wpnName);
			client_cmd(id,wpnName);
		}
	}

	// otherwise, switch to our new weapon
	else if(lvlWeapon[id][0])
	{
		formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
		engclient_cmd(id,wpnName);
		client_cmd(id,wpnName);
	}

	// make sure that we get this...
	if(verify)
	{
		remove_task(TASK_VERIFY_WEAPON+id);
		set_task(1.0,"verify_weapon",TASK_VERIFY_WEAPON+id);
	}

	fws_gave_level_weapon(id,melee_only);

	return 1;
}

// verify that we have our stupid weapon
public verify_weapon(taskid)
{
	new id = taskid-TASK_VERIFY_WEAPON;

	if(!is_user_alive(id)) return;

	static wpnName[24];
	formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
	new wpnid = get_mod_weaponid(wpnName);

	if(!wpnid) return;

	// we don't have it, but we want it
	if(!user_has_weapon(id,wpnid)) give_level_weapon(id,0,0);
}

// crown a winner
win(winner,loser)
{
	// we have an invalid winner here
	if(won || !is_user_connected(winner) || !can_score(winner))
		return;

	won = 1;
	roundEnded = 1;

	server_cmd("sv_alltalk 1");
	play_sound(0,winSounds[currentWinSound]);

	new map_iterations = get_pcvar_num(gg_map_iterations), restart;

	// final playthrough, get ready for next map
	if(mapIteration >= map_iterations && map_iterations > 0)
	{
		set_nextmap();
		set_task(15.0,"goto_nextmap");

		// as of GG1.16, we always send a non-emessage intermission, because
		// other map changing plugins (as well as StatsMe) intercepting it
		// was causing problems.

		// as of GG1.20, we no longer do this because it closes the MOTD.

		/*message_begin(MSG_ALL,SVC_INTERMISSION);
		message_end();*/
	}

	// get ready to go again!!
	else restart = 1;

	// freeze and godmode everyone
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;

		set_pev(player,pev_button,0);
		client_cmd(player,"-attack;-attack2");

		set_pev(player,pev_flags,pev(player,pev_flags) | FL_FROZEN);
		fm_set_user_godmode(player,1);
	}

	new teamplay = get_pcvar_num(gg_teamplay), winningTeam;
	if(teamplay) winningTeam = get_user_team(winner);

	new winnerName[32], myName[32], authid[24], team[10], i;
	if(teamplay) get_team_name(winningTeam,winnerName,31);
	else get_user_name(winner,winnerName,31);

	// old-fashioned
	for(i=0;i<5;i++)
	{
		if(teamplay) gungame_print(0,winner,1,"%L!!",LANG_PLAYER_C,"WON_TEAM",winnerName);
		else gungame_print(0,winner,1,"%%n%s%%e %L!",winnerName,LANG_PLAYER_C,"WON");
	}

	get_pcvar_string(gg_stats_file,sfFile,63);

	new stats_mode = get_pcvar_num(gg_stats_mode), ignore_bots = get_pcvar_num(gg_ignore_bots);

	// points system
	if(sfFile[0] && stats_mode == 2)
	{
		new wins, Float:flPoints, iPoints, totalPoints;

		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_connected(player)) continue;

			// calculate points and add
			flPoints = float(level[player]) - 1.0;
			wins = 0;

			// winner gets bonus points plus a win
			if(player == winner || (teamplay && get_user_team(player) == winningTeam))
			{
				flPoints *= get_pcvar_float(gg_stats_winbonus);
				wins = 1;
			}

			// unnecessary
			if(flPoints <= 0.0 && !wins) continue;

			iPoints = floatround(flPoints);

			// it's okay to add to stats
			if(!ignore_bots || !is_user_bot(player))
				stats_add_to_score(player,wins,iPoints,dummy[0],totalPoints);

			get_user_name(player,myName,31);
			get_user_authid(player,authid,23);
			get_user_team(player,team,9);

			// log it
			log_message("^"%s<%i><%s><%s>^" triggered ^"GunGame_Points^" amount ^"%i^"",myName,get_user_userid(player),authid,team,iPoints);

			// display it
			gungame_print(player,0,1,"%L",player,"GAINED_POINTS",iPoints,totalPoints);
		}
	}

	// regular wins, no points
	else if(sfFile[0] && stats_mode)
	{
		// solo-play
		if(!teamplay)
		{
			if(!ignore_bots || !is_user_bot(winner))
				stats_add_to_score(winner,1,0,dummy[0],dummy[0]);

			get_user_authid(winner,authid,23);
			get_user_team(winner,team,9);

			log_message("^"%s<%i><%s><%s>^" triggered ^"Won_GunGame^"",winnerName,get_user_userid(winner),authid,team);
		}

		// team play, give everyone a win
		else if(teamplay)
		{
			for(player=1;player<=maxPlayers;player++)
			{
				if(is_user_connected(player) && get_user_team(player) == winningTeam)
				{
					// it's okay to add to stats
					if(!ignore_bots || !is_user_bot(player))
						stats_add_to_score(player,1,0,dummy[0],dummy[0]);

					get_user_authid(player,authid,23);
					get_user_name(player,winnerName,31);
					get_user_team(player,team,9);

					log_message("^"%s<%i><%s><%s>^" triggered ^"Won_GunGame^"",winnerName,get_user_userid(player),authid,team);
				}
			}
		}
	}

	show_win_screen(winner,loser);

	// we can restart now (do it after calculations because points might get reset)
	if(restart)
	{
		new Float:time = float(fws_restart_round(15)) - 0.1;

		set_task((time < 0.1) ? 0.1 : time,"restart_gungame",czero ? get_cvar_num("bot_stop") : 0);
		set_task(20.0,"stop_win_sound");

		if(czero) server_cmd("bot_stop 1"); // freeze CZ bots
	}
}

// restart gungame, for the next map iteration
public restart_gungame(old_bot_stop_value)
{
	won = 0;
	mapIteration++;

	/*new i;
	for(i=0;i<sizeof teamLevel;i++)
		clear_team_values(i);*/

	// game already commenced, but we are restarting, allow us to warmup again
	if(gameCommenced) shouldWarmup = 1;

	toggle_gungame(TASK_TOGGLE_GUNGAME + TOGGLE_ENABLE); // reset stuff
	do_rOrder(); // pick the next weapon order
	currentWinSound = do_rWinSound(); // pick the next win sound

	// unfreeze and ungodmode everyone
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;

		set_pev(player,pev_flags,pev(player,pev_flags) & ~FL_FROZEN);
		fm_set_user_godmode(player,0);
		welcomed[player] = 1; // also don't show welcome again
	}
	if(czero) server_cmd("bot_stop %i",old_bot_stop_value); // unfreeze CZ bots

	// only have warmup once?
	if(!get_pcvar_num(gg_warmup_multi)) warmup = -13; // -13 is the magical stop number
	else warmup = -1; // -1 isn't magical at all... :(

	warmupWeapon[0] = 0;
	fws_warmup_changed(warmup,warmupWeapon);
}

// stop the winner sound (for multiple map iterations)
public stop_win_sound()
{
	// stop winning sound
	if(containi(winSounds[currentWinSound],".mp3") != -1) client_cmd(0,"mp3 stop");
	else client_cmd(0,"speak null");
}

// calculate the winner screen... huge because of its awesomeness
public show_win_screen(winner,loser)
{
	//
	// FILE READING
	//

	new file = fopen("gungame_winmotd.html","rt");
	if(!file) return 0;

	new motd[2048], len;

	// collect it all
	while(!feof(file)) len += fgets(file,motd[len],2047-len);
	fclose(file);

	//
	// REPLACEMENTS START
	//

	// some advanced replacements... do these first because they may
	// remove unnecessary replacements further down the chain
	new startpos, endpos, goodStart[32], goodEnd[32], bad1Start[32], bad1End[32], bad1EndLen,
	bad2Start[32], bad2End[32], bad2EndLen, stats_mode = get_pcvar_num(gg_stats_mode),
	iterations = get_pcvar_num(gg_map_iterations), rounds = iterations - mapIteration,
	teamplay = get_pcvar_num(gg_teamplay);

	//
	// STATS IF BLOCKS
	//

	// stats enabled
	if(stats_mode)
	{
		if(stats_mode == 1)
		{
			goodStart = "%STATSMODE1|START%";
			goodEnd = "%STATSMODE1|END%";
			bad1Start = "%STATSMODE2|START%";
			bad1End = "%STATSMODE2|END%";
		}
		else
		{
			goodStart = "%STATSMODE2|START%";
			goodEnd = "%STATSMODE2|END%";
			bad1Start = "%STATSMODE1|START%";
			bad1End = "%STATSMODE1|END%";
		}

		bad1EndLen = strlen(bad1End);

		// remove tags that are alright
		replace_all(motd,len,goodStart,"");
		replace_all(motd,len,goodEnd,"");

		// remove data between bad tags
		while((startpos = contain(motd,bad1Start)) != -1)
		{
			endpos = contain(motd,bad1End);
			if(endpos == -1) break;
			endpos += (bad1EndLen-1);
			remove_snippet(motd,len,startpos,endpos);
		}
	}

	// stats disabled, remove all stats-related tags
	else
	{
		while((startpos = contain(motd,"%STATSMODE1|START%")) != -1)
		{
			endpos = contain(motd,"%STATSMODE1|END%");
			if(endpos == -1) break;
			endpos += 15;
			remove_snippet(motd,len,startpos,endpos);
		}
		while((startpos = contain(motd,"%STATSMODE2|START%")) != -1)
		{
			endpos = contain(motd,"%STATSMODE2|END%");
			if(endpos == -1) break;
			endpos += 15;
			remove_snippet(motd,len,startpos,endpos);
		}
	}

	//
	// MAP ITERATIONS IF BLOCKS
	//

	// no rounds left
	if(rounds <= 0)
	{
		goodStart = "%NOROUNDSLEFT|START%";
		goodEnd = "%NOROUNDSLEFT|END%";
		bad1Start = "%ONEROUNDLEFT|START%";
		bad1End = "%ONEROUNDLEFT|END%";
		bad2Start = "%MULTIROUNDSLEFT|START%";
		bad2End = "%MULTIROUNDSLEFT|END%";
	}

	// one round left
	else if(rounds == 1)
	{
		goodStart = "%ONEROUNDLEFT|START%";
		goodEnd = "%ONEROUNDLEFT|END%";
		bad1Start = "%NOROUNDSLEFT|START%";
		bad1End = "%NOROUNDSLEFT|END%";
		bad2Start = "%MULTIROUNDSLEFT|START%";
		bad2End = "%MULTIROUNDSLEFT|END%";
	}

	// multiple rounds left
	else
	{
		goodStart = "%MULTIROUNDSLEFT|START%";
		goodEnd = "%MULTIROUNDSLEFT|END%";
		bad1Start = "%NOROUNDSLEFT|START%";
		bad1End = "%NOROUNDSLEFT|END%";
		bad2Start = "%ONEROUNDLEFT|START%";
		bad2End = "%ONEROUNDLEFT|END%";
	}

	bad1EndLen = strlen(bad1End);
	bad2EndLen = strlen(bad2End);

	// remove tags that are alright
	replace_all(motd,len,goodStart,"");
	replace_all(motd,len,goodEnd,"");

	// remove data between bad tags
	while((startpos = contain(motd,bad1Start)) != -1)
	{
		endpos = contain(motd,bad1End);
		if(endpos == -1) break;
		endpos += (bad1EndLen-1);
		remove_snippet(motd,len,startpos,endpos);
	}
	while((startpos = contain(motd,bad2Start)) != -1)
	{
		endpos = contain(motd,bad2End);
		if(endpos == -1) break;
		endpos += (bad2EndLen-1);
		remove_snippet(motd,len,startpos,endpos);
	}

	//
	// TEAMPLAY IF BLOCKS
	//

	if(teamplay)
	{
		goodStart = "%TEAMPLAY|START%";
		goodEnd = "%TEAMPLAY|END%";
		bad1Start = "%SOLOPLAY|START%";
		bad1End = "%SOLOPLAY|END%";
	}
	else
	{
		goodStart = "%SOLOPLAY|START%";
		goodEnd = "%SOLOPLAY|END%";
		bad1Start = "%TEAMPLAY|START%";
		bad1End = "%TEAMPLAY|END%";
	}

	bad1EndLen = strlen(bad1End);

	// remove tags that are alright
	replace_all(motd,len,goodStart,"");
	replace_all(motd,len,goodEnd,"");

	// remove data between bad tags
	while((startpos = contain(motd,bad1Start)) != -1)
	{
		endpos = contain(motd,bad1End);
		if(endpos == -1) break;
		endpos += (bad1EndLen-1);
		remove_snippet(motd,len,startpos,endpos);
	}

	//
	// WINNER REPLACEMENTS
	//

	new name[32], team[32], color[12], weapon[24], levelStr[8], winStr[8], winSuffix[4], pointsGained[12], pointsTotal[12];
	get_motd_info(winner,name,team,color,weapon,levelStr,winStr,winSuffix,pointsGained,pointsTotal,1);

	replace_all(motd,len,"%WINNERNAME%",name);
	replace_all(motd,len,"%WINNERTEAM%",team);
	replace_all(motd,len,"%WINNERCOLOR%",color);
	replace_all(motd,len,"%WINNERWEAPON%",weapon);
	replace_all(motd,len,"%WINNERLEVEL%",levelStr);
	replace_all(motd,len,"%WINNERWINS%",winStr);
	replace_all(motd,len,"%WINNERWINSUFFIX%",winSuffix);
	replace_all(motd,len,"%WINNERPOINTSGAINED%",pointsGained);
	replace_all(motd,len,"%WINNERPOINTSTOTAL%",pointsTotal);

	//
	// LOSER REPLACEMENTS
	//

	if(is_user_connected(loser))
	{
		get_motd_info(loser,name,team,color,weapon,levelStr,winStr,winSuffix,pointsGained,pointsTotal);
	}
	else
	{
		name = "no one";
		formatex(team,31,"%L",LANG_SERVER,"NONE");
		color = "gray";
		formatex(weapon,23,"%L",LANG_SERVER,"NONE");
		levelStr = "0";
		winStr = "0";
		winSuffix = "th";
		pointsGained = "0";
		pointsTotal = "0";
	}


	replace_all(motd,len,"%LOSERNAME%",name);
	replace_all(motd,len,"%LOSERTEAM%",team);
	replace_all(motd,len,"%LOSERCOLOR%",color);
	replace_all(motd,len,"%LOSERWEAPON%",weapon);
	replace_all(motd,len,"%LOSERLEVEL%",levelStr);
	replace_all(motd,len,"%LOSERWINS%",winStr);
	replace_all(motd,len,"%LOSERWINSUFFIX%",winSuffix);
	replace_all(motd,len,"%LOSERPOINTSGAINED%",pointsGained);
	replace_all(motd,len,"%LOSERPOINTSTOTAL%",pointsTotal);

	//
	// NEXT MAP REPLACEMENTS
	//

	// find nextmap
	new nextmap[32];
	get_cvar_string("amx_nextmap",nextmap,31);

	replace_all(motd,len,"%NEXTMAP%",nextmap);

	//
	// ROUNDS LEFT REPLACEMENTS
	//

	// rounds left
	new roundsLeft[8];
	num_to_str(iterations-mapIteration,roundsLeft,7);

	replace_all(motd,len,"%ROUNDSLEFT%",roundsLeft);

	//
	// PLAYER REPLACEMENTS
	//

	// track player-specific replacements
	new pName = (containi(motd,"%PLAYERNAME%") != -1);
	new pTeam = (containi(motd,"%PLAYERTEAM%") != -1);
	new pColor = (containi(motd,"%PLAYERCOLOR%") != -1);
	new pWeapon = (containi(motd,"%PLAYERWEAPON%") != -1);
	new pLevel = (containi(motd,"%PLAYERLEVEL%") != -1);
	new pWins = (containi(motd,"%PLAYERWINS%") != -1);
	new pWinSuffix = (containi(motd,"%PLAYERWINSUFFIX%") != -1);
	new pPointsGained = (containi(motd,"%PLAYERPOINTSGAINED%") != -1);
	new pPointsTotal = (containi(motd,"%PLAYERPOINTSTOTAL%") != -1);

	// calculate MOTD header (Avalanche won!)
	new player, header[32];
	get_user_name(winner,name,31);
	formatex(header,31,"%s %L!",name,LANG_SERVER,"WON");

	// we have some crazy stuff going on in here
	if(pName || pTeam || pColor || pWeapon || pLevel || pWins || pWinSuffix || pPointsGained || pPointsTotal)
	{
		new temp[9][32];

		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_connected(player)) continue;

			get_motd_info(player,name,team,color,weapon,levelStr,winStr,winSuffix,pointsGained,pointsTotal,(player==winner));

			if(pName) // name
			{
				formatex(temp[0],31,"<!--PNA-->%s<!--PNA-->",name);
				replace_all(motd,len,"%PLAYERNAME%",temp[0]);
			}
			if(pTeam) // team
			{
				formatex(temp[1],31,"<!--PTE-->%s<!--PTE-->",team);
				replace_all(motd,len,"%PLAYERNAME%",temp[1]);
			}
			if(pColor) // team color
			{
				formatex(temp[2],31,"<!--PCO-->%s<!--PCO-->",color);
				replace_all(motd,len,"%PLAYERCOLOR%",temp[2]);
			}
			if(pWeapon) // weapon
			{
				formatex(temp[3],31,"<!--PWE-->%s<!--PWE-->",weapon);
				replace_all(motd,len,"%PLAYERWEAPON%",temp[3]);
			}
			if(pLevel) // level
			{
				formatex(temp[4],31,"<!--PLE-->%s<!--PLE-->",levelStr);
				replace_all(motd,len,"%PLAYERLEVEL%",temp[4]);
			}
			if(pWins) // total wins
			{
				formatex(temp[5],31,"<!--PWI-->%s<!--PWI-->",winStr);
				replace_all(motd,len,"%PLAYERWINS%",temp[5]);
			}
			if(pWinSuffix) // total win suffix
			{
				formatex(temp[6],31,"<!--PSU-->%s<!--PSU-->",winSuffix);
				replace_all(motd,len,"%PLAYERWINSUFFIX%",temp[6]);
			}
			if(pPointsGained) // points gained this round
			{
				formatex(temp[7],31,"<!--PPG-->%s<!--PPG-->",pointsGained);
				replace_all(motd,len,"%PLAYERPOINTSGAINED%",temp[7]);
			}
			if(pPointsTotal) // total points
			{
				formatex(temp[8],31,"<!--PPT-->%s<!--PPT-->",pointsTotal);
				replace_all(motd,len,"%PLAYERPOINTSTOTAL%",temp[8]);
			}

			// show it all
			show_motd(player,motd,header);

			// put it back where we found it for the next guy
			if(pName) replace_all(motd,len,temp[0],"%PLAYERNAME%");
			if(pTeam) replace_all(motd,len,temp[1],"%PLAYERTEAM%");
			if(pColor) replace_all(motd,len,temp[2],"%PLAYERCOLOR%");
			if(pWeapon) replace_all(motd,len,temp[3],"%PLAYERWEAPON%");
			if(pLevel) replace_all(motd,len,temp[4],"%PLAYERLEVEL%");
			if(pWins) replace_all(motd,len,temp[5],"%PLAYERWINS%");
			if(pWinSuffix) replace_all(motd,len,temp[6],"%PLAYERWINSUFFIX%");
			if(pPointsGained) replace_all(motd,len,temp[7],"%PLAYERPOINTSGAINED%");
			if(pPointsTotal) replace_all(motd,len,temp[8],"%PLAYERPOINTSTOTAL%");
		}
	}

	// this is easy
	else show_motd(0,motd,header);

	/*

	// did it reference the player listing?
	if(containi(motd,"gungame_scoremotd.html") != -1)
		create_score_motd(motd); // better make it then!

	*/

	return 1;
}

// gets a user's MOTD information
stock get_motd_info(id,name[32],team[32],color[12],weapon[24],levelStr[8],winStr[8],winSuffix[4],pointsGained[12],pointsTotal[12],winner=0)
{
	new wnum = get_weapon_num(), authid[24], wins, points, Float:flPoints;

	// name, team, and color
	get_user_name(id,name,31);
	get_team_name(get_user_team(id),team,31);
	get_team_color(get_user_team(id),color,11);

	// get winner's weapon, don't go over the bounds
	if(level[id] > wnum) get_level_weapon(wnum,weapon,23);
	else get_level_weapon(level[id],weapon,23);

	// his level in string format
	num_to_str(level[id],levelStr,7);

	// get stats info first
	get_user_authid(id,authid,23);
	stats_get_data(authid,wins,points,dummy,1,dummy[0]);

	// calculate points earned now
	flPoints = float(level[id]) - 1.0;

	// winner or on winning team
	if(winner || (get_pcvar_num(gg_teamplay) && get_user_team(winner) == get_user_team(id)))
		flPoints *= get_pcvar_float(gg_stats_winbonus);

	if(flPoints < 0.0) flPoints = 0.0;
	num_to_str(floatround(flPoints),pointsGained,11);

	// store wins and total points
	num_to_str(wins,winStr,7);
	num_to_str(points,pointsTotal,11);

	// now get a 'st, 'nd, 'rd, 'th number
	new len = strlen(winStr);

	if(wins >= 10 && winStr[len-2] == '1') // second to last digit
		winSuffix = "th"; // 10-19 end in 'th
	else
	{
		switch(winStr[len-1]) // last digit
		{
			case '1': winSuffix = "st";
			case '2': winSuffix = "nd";
			case '3': winSuffix = "rd";
			default: winSuffix = "th";
		}
	}
}

// create the player score listing motd
/*public create_score_motd(motd[2048])
{
	 // the passed variable is used for sharing to prevent stack errors

	 new len = 0;
	 len += formatex(motd[len],2047-len,"<style>*.a{color:black;background-color:#EFEFEF;text-align:center;font-family:Georgia;padding:2px;}*.b{color:black;background-color:#DEE3E7;text-align:center;font-family:Georgia;padding:2px;}</style>");
	 len += formatex(motd[len],2047-len,"<body bgcolor=black><center><table width=100%% cellspacing=1 style=^"border:1px solid white;^">");
	 len += formatex(motd[len],2047-len,"<tr class=b style=^"font-weight:bold;letter-spacing:2px;^"><td width=5%%>#</td><td width=25%%>%L</td><td width=20%%>%L</td><td width=15%%>%L</td><td width=20%%>%L</td><td width=15%%>K/D</td></tr>",LANG_SERVER,"NAME_CAPS",LANG_SERVER,"LEVEL_CAPS",LANG_SERVER,"SCORE_CAPS",LANG_SERVER,"TEAM_CAPS");

	 new players[32], num, i, player;
	 get_players(players,num);
	 SortCustom1D(players,num,"sort_scoremotd");

	 new name[32], displayWeapon[24], temp[256], tempLen, team[16], td[2], Float:kd, deaths;
	 new wnum = get_weapon_num();

	 for(i=0;i<num;i++)
	 {
	 	 if(i % 2) td = "b";
	 	 else td = "a";

	 	 player = players[i];
	 	 get_user_name(player,name,31);
	 	 get_user_team(player,team,15);

	 	 if(level[player] < 1) formatex(displayWeapon,23,"%L",LANG_SERVER,"NONE");
	 	 else if(level[player] > wnum) formatex(displayWeapon,23,"%L",LANG_SERVER,"WON");
	 	 else displayWeapon = lvlWeapon[player];

	 	 deaths = get_mod_user_deaths(player);

	 	 // no divison by zero
	 	 if(!deaths) kd = float(get_user_frags(player));
	 	 else kd = float(get_user_frags(player)) / float(deaths);

	 	 tempLen = formatex(temp,255,"<tr class=%s><td>%i</td><td>%s</td><td>%i - %s</td><td>%i / %i</td><td>%s</td><td>%.2f</td></tr>",td,i+1,name,level[player],displayWeapon,score[player],get_level_goal(level[player],player),team,kd);
		 if(2047 - len - 8 < tempLen) break; // space left is less than what we are trying to add (reserve 8 for table end tag)

	 	 len += formatex(motd[len],2047-len,"%s",temp);
	 }

	 len += formatex(motd[len],2047-len,"</table>");

	 // save it to a file
	 new file = fopen("gungame_scoremotd.html","wt");
	 fputs(file,motd);
	 fclose(file);
}

// sort the list of players on the MOTD
public sort_scoremotd(elem1,elem2)
{
	 if(level[elem1] == level[elem2])
	 {
	 	 if(score[elem1] == score[elem2])
	 	 {
	 	 	 new Float:deaths = float(get_mod_user_deaths(elem1));
	 	 	 if(deaths == 0.0) deaths = 1.0; // no division by zero
	 	 	 new Float:kd1 = float(get_user_frags(elem1)) / deaths;

	 	 	 deaths = float(get_mod_user_deaths(elem2));
	 	 	 if(deaths == 0.0) deaths = 1.0; // no division by zero
	 	 	 new Float:kd2 = float(get_user_frags(elem2)) / deaths;

	 	 	 if(kd1 > kd2) return -1;
	 	 	 else if(kd2 > kd1) return 1;

	 	 	 // player id priority
	 	 	 return elem2 - elem1;
	 	 }

	 	 return score[elem2] - score[elem1];
	 }

	 return level[elem2] - level[elem1];
}*/

/**********************************************************************
* TEAMPLAY FUNCTIONS
**********************************************************************/

// change the score of a team
stock teamplay_update_score(team,newScore,exclude=0,direct=0)
{
	 if(team != 1 && team != 2) return;

	 teamScore[team] = newScore;

	 new player;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && player != exclude && get_user_team(player) == team)
	 	 {
	 	 	 if(direct) score[player] = newScore;
	 	 	 else change_score(player,newScore-score[player],0); // don't refill
	 	 }
	 }
}

// change the level of a team
stock teamplay_update_level(team,newLevel,exclude=0,direct=1)
{
	 if(team != 1 && team != 2) return;

	 teamLevel[team] = newLevel;
	 get_level_weapon(teamLevel[team],teamLvlWeapon[team],23);

	 new player;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && player != exclude && get_user_team(player) == team)
	 	 {
	 	 	//if(direct) level[player] = newLevel;
	 	 	if(direct) set_level_noifandsorbuts(player,newLevel);
			else change_level(player,newLevel-level[player],_,_,1); // always score
		 }
	 }
}

// play the taken/tied/lost lead sounds
public teamplay_play_lead_sounds(id,oldLevel,Float:playDelay)
{
	// both teams not initialized yet
	if(!teamLevel[1] || !teamLevel[2]) return;

	// id: the player whose level changed
	// oldLevel: his level before it changed
	// playDelay: how long to wait until we play id's sounds

	// warmup or game over, no one cares
	if(warmup > 0 || won) return;

	// no level change
	if(level[id] == oldLevel) return;

	new team = get_user_team(id), otherTeam = (team == 1) ? 2 : 1, thisTeam, player, params[2];
	if(team != 1 && team != 2) return;

	new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);

	// this team is leading
	if(leader == team)
	{
		// the other team here?
		if(numLeaders > 1)
		{
			params[1] = gg_sound_tiedlead;

			// play to both teams
			for(player=1;player<=maxPlayers;player++)
			{
				if(!is_user_connected(player)) continue;

				thisTeam = get_user_team(player);
				if(thisTeam == team || thisTeam == otherTeam)
				{
					params[0] = player;
					remove_task(TASK_PLAY_LEAD_SOUNDS+player);
					set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
				}
			}
		}

		// just us, we are the winners!
		else
		{
			// did we just pass the other team?
			if(level[id] > oldLevel && teamLevel[otherTeam] == oldLevel)
			{
				// play to both teams (conditional)
				for(player=1;player<=maxPlayers;player++)
				{
					if(!is_user_connected(player)) continue;

					thisTeam = get_user_team(player);

					if(thisTeam == team) params[1] = gg_sound_takenlead;
					else if(thisTeam == otherTeam) params[1] = gg_sound_lostlead;
					else continue;

					params[0] = player;
					remove_task(TASK_PLAY_LEAD_SOUNDS+player);
					set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
				}
			}
		}
	}

	// WAS this team on the leader level?
	else if(oldLevel == leaderLevel)
	{
		// play to entire team
		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_connected(player)) continue;

			thisTeam = get_user_team(player);

			if(thisTeam == team) params[1] = gg_sound_lostlead;
			else if(thisTeam == otherTeam) params[1] = gg_sound_takenlead;
			else continue;

			params[0] = player;
			remove_task(TASK_PLAY_LEAD_SOUNDS+player);
			set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
		}
	}
}

// find the highest level team and such
stock teamplay_get_lead_team(&retLevel=0,&retNumLeaders=0,&retRunnerUp=0)
{
	new leader, numLeaders, runnerUp;

	if(teamLevel[1] >= teamLevel[2]) leader = 1;
	else leader = 2;

	if(teamLevel[1] == teamLevel[2]) numLeaders = 2;
	else
	{
		numLeaders = 1;
		runnerUp = (leader == 1) ? 2 : 1;
	}

	retLevel = teamLevel[leader];
	retNumLeaders = numLeaders;
	retRunnerUp = runnerUp;

	return leader;
}

// gets the team's level goal without a player passed
teamplay_get_team_goal(team)
{
	 if(team != 1 && team != 2) return 0;

	 new player;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && get_user_team(player) == team)
	 	 	 return get_level_goal(teamLevel[team],player);
	 }

	 return 0;
}

/**********************************************************************
* AUTOVOTE FUNCTIONS
**********************************************************************/

// start the autovote
public autovote_start()
{
	// vote in progress
	if(autovotes[0] || autovotes[1]) return;

	new Float:autovote_time = get_pcvar_float(gg_autovote_time);

	format(menuText,511,"\y%L^n^n\w1. %L^n2. %L^n^n0. %L",LANG_PLAYER,"PLAY_GUNGAME",LANG_PLAYER,"YES",LANG_PLAYER,"NO",LANG_PLAYER,"CANCEL");

	show_menu(0,MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,menuText,floatround(autovote_time),"autovote_menu");
	set_task(autovote_time,"autovote_result");
}

// take in votes
public autovote_menu_handler(id,key)
{
	switch(key)
	{
		case 0: autovotes[1]++;
		case 1: autovotes[0]++;
		//case 9: let menu close
	}

	return PLUGIN_HANDLED;
}

// calculate end of vote
public autovote_result()
{
	new enable, enabled = ggActive;

	if(autovotes[0] || autovotes[1])
	{
		if(float(autovotes[1]) / float(autovotes[0] + autovotes[1]) >= get_pcvar_float(gg_autovote_ratio))
			enable = 1;
	}

	gungame_print(0,0,1,"%L (%L: %i, %L: %i)",LANG_PLAYER_C,(enable) ? "VOTING_SUCCESS" : "VOTING_FAILED",LANG_PLAYER_C,"YES",autovotes[1],LANG_PLAYER_C,"NO",autovotes[0]);

	if(enable && !enabled)
	{
		new Float:time = float(fws_restart_round(5)) - 0.2;
		set_task((time < 0.1) ? 0.1 : time,"toggle_gungame",TASK_TOGGLE_GUNGAME+TOGGLE_ENABLE);
	}
	else if(!enable && enabled)
	{
		new Float:time = float(fws_restart_round(5)) - 0.2;
		set_task((time < 0.1) ? 0.1 : time,"toggle_gungame",TASK_TOGGLE_GUNGAME+TOGGLE_DISABLE);

		set_pcvar_num(gg_enabled,0);
		ggActive = 0;
		fws_gungame_toggled(ggActive);
	}

	// reset votes
	autovotes[0] = 0;
	autovotes[1] = 0;
}

/**********************************************************************
* STAT FUNCTIONS
**********************************************************************/

// add to a player's wins
stats_add_to_score(id,wins,points,&newWins,&newPoints)
{
	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return 0;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled
	if(!sfFile[0]) return 0;

	// get data
	new authid[24], name[32];

	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	get_user_name(id,name,31);

	// clean up the name
	trim(name);
	replace_all(name,31,"^t"," ");

	// replace it with new data
	new oldWins, oldPoints, line;
	line = stats_get_data(authid,oldWins,oldPoints,dummy,1,dummy[0]);

	newWins = oldWins+wins;
	newPoints = oldPoints+points;

	return stats_set_data(authid,oldWins+wins,oldPoints+points,name,get_systime(),line);
}

// get a player's last used name and wins from save file
stock stats_get_data(authid[],&wins,&points,lastName[],nameLen,&timestamp,knownLine=-1)
{
	wins = 0;
	points = 0;
	timestamp = 0;

	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return -1;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return -1;

	// storage format:
	// AUTHID	WINS	LAST_USED_NAME	TIMESTAMP	POINTS

	// reset
	sfLineData[0] = 0;

	// open 'er up, boys!
	new line, found, file = fopen(sfFile,"rt");
	if(!file) return -1;

	// go through it
	while(!feof(file))
	{
		fgets(file,sfLineData,80);
		line++;

		// go to the line we know
		if(knownLine > -1)
		{
			if(line-1 == knownLine)
			{
				found = 1;
				break;
			}
			else continue;
		}

		// isolate authid
		strtok(sfLineData,sfAuthid,23,dummy,1,'^t');

		// this is it, stop now because our
		// data is already stored in sfLineData
		if(equal(authid,sfAuthid))
		{
			found = 1;
			break;
		}
	}

	// close 'er up, boys! (hmm....)
	fclose(file);

	// couldn't find
	if(!found) return -1;

	// isolate authid
	strtok(sfLineData,sfAuthid,23,sfLineData,80,'^t');

	// isolate wins
	strtok(sfLineData,sfWins,5,sfLineData,80,'^t');
	wins = str_to_num(sfWins);

	// isolate name
	strtok(sfLineData,lastName,nameLen,sfLineData,80,'^t');

	// isolate timestamp
	strtok(sfLineData,sfTimestamp,11,sfPoints,7,'^t');
	timestamp = str_to_num(sfTimestamp);

	// isolate points (only thing left)
	points = str_to_num(sfPoints);

	// return the line we got it on
	if(knownLine > -1) return knownLine;

	return line - 1;
}

// set a player's last used name and wins from save file
stock stats_set_data(authid[],wins,points,lastName[],timestamp,knownLine=-1)
{
	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return 0;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled
	if(!sfFile[0]) return 0;

	// storage format:
	// AUTHID	WINS	LAST_USED_NAME	TIMESTAMP	POINTS

	new tempFileName[65], sfFile_rename[64], newFile_rename[65], file;
	formatex(tempFileName,64,"%s2",sfFile); // our temp file, append 2

	// rename_file backwards compatibility (thanks Mordekay)
	formatex(sfFile_rename,63,"%s/%s",modName,sfFile);
	formatex(newFile_rename,64,"%s/%s",modName,tempFileName);

	// create stats file if it doesn't exist
	if(!file_exists(sfFile))
	{
		file = fopen(sfFile,"wt");
		fclose(file);
	}

	// copy over current stat file
	rename_file(sfFile_rename,newFile_rename);

	// rename failed?
	if(!file_exists(tempFileName)) return 0;

	new tempFile = fopen(tempFileName,"rt");
	new line, goal;
	file = fopen(sfFile,"wt");

	// go through our old copy and rewrite entries
	while(tempFile && file && !feof(tempFile))
	{
		fgets(tempFile,sfLineData,80);

		if(!sfLineData[0])
		{
			line++;
			continue;
		}

		// see if this is the line we are trying to overwrite
		if(!goal)
		{
			if(knownLine > -1)
			{
				if(line == knownLine) goal = 1;
			}
			else
			{
				// isolate authid
				strtok(sfLineData,sfAuthid,23,dummy,1,'^t');

				// this is what we are looking for
				if(equal(authid,sfAuthid)) goal = 1;
			}
		}

		// overwrite with new values
		if(goal == 1)
		{
			goal = -1;
			fprintf(file,"%s^t%i^t%s^t%i^t%i",authid,wins,lastName,timestamp,points);
			fputc(file,'^n');
		}

		// otherwise just copy it over as it was (newline is already included)
		else fprintf(file,"%s",sfLineData);

		line++;
	}

	// never found an existing entry, make a new one
	if(!goal)
	{
		fprintf(file,"%s^t%i^t%s^t%i^t%i",authid,wins,lastName,timestamp,points);
		fputc(file,'^n');
	}

	if(tempFile) fclose(tempFile);
	if(file) fclose(file);

	// remove our copy
	delete_file(tempFileName);

	return 1;
}

// update a user's timestamp
stats_refresh_timestamp(authid[])
{
	new wins, points, lastName[32], timestamp;
	new line = stats_get_data(authid,wins,points,lastName,31,timestamp);

	if(line > -1) stats_set_data(authid,wins,points,lastName,get_systime(),line);
}

// gets the top X amount of players into an array
// of the format: storage[amount][storageLen]
stats_get_top_players(amount,storage[][],storageLen)
{
	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return 0;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return 0;

	// storage format:
	// AUTHID	WINS	LAST_USED_NAME	TIMESTAMP	POINTS

	// not so much OMG OMG OMG OMG as of 1.16
	static tempList[TOP_PLAYERS+1][82], tempLineData[81];

	new count, stats_mode = get_pcvar_num(gg_stats_mode), score[10];

	// open sesame
	new file = fopen(sfFile,"rt");
	if(!file) return 0;

	// reading, reading, reading...
	while(!feof(file))
	{
		fgets(file,sfLineData,80);

		// empty line
		if(!sfLineData[0]) continue;

		// assign it to a new variable so that strtok
		// doesn't tear apart our constant sfLineData variable
		tempLineData = sfLineData;

		// get rid of authid
		strtok(tempLineData,dummy,1,tempLineData,80,'^t');

		// sort by wins
		if(stats_mode == 1)
		{
			strtok(tempLineData,score,9,tempLineData,1,'^t');
		}

		// sort by points
		else
		{
			// break off wins
			strtok(tempLineData,dummy,1,tempLineData,80,'^t');

			// break off name
			strtok(tempLineData,dummy,1,tempLineData,80,'^t');

			// break off timestamp and get points
			strtok(tempLineData,dummy,1,score,9,'^t');
		}

		// don't store more than 11
		if(count >= amount) count = amount;

		tempList[count][0] = str_to_num(score);
		formatex(tempList[count][1],81,"%s",sfLineData);
		count++;

		// filled list with 11, sort
		if(count > amount) SortCustom2D(tempList,count,"stats_custom_compare");
	}

	// nolisting
	if(!count)
	{
		fclose(file);
		return 0;
	}

	// not yet sorted (didn't reach 11 entries)
	else if(count <= amount)
		SortCustom2D(tempList,count,"stats_custom_compare");

	new i;

	// now that it's sorted, return it
	for(i=0;i<amount&&i<count;i++)
		formatex(storage[i],storageLen,"%s",tempList[i][1]);


	// close
	fclose(file);

	return 1;
}

// our custom sorting function (check first dimension for score)
public stats_custom_compare(elem1[],elem2[])
{
	// optimization by sawce
	return elem2[0] - elem1[0];
}

// prune old entries
stock stats_prune(max_time=-1)
{
	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return 0;

	// -1 = use value from cvar
	if(max_time == -1) max_time = get_pcvar_num(gg_stats_prune);

	// 0 = no pruning
	if(max_time == 0) return 0;

	new tempFileName[65], sfFile_rename[64], newFile_rename[65];
	formatex(tempFileName,64,"%s2",sfFile); // our temp file, append 2

	// rename_file backwards compatibility (thanks Mordekay)
	formatex(sfFile_rename,63,"%s/%s",modName,sfFile);
	formatex(newFile_rename,64,"%s/%s",modName,tempFileName);

	// copy over current stat file
	rename_file(sfFile_rename,newFile_rename);

	// rename failed?
	if(!file_exists(tempFileName)) return 0;

	new tempFile = fopen(tempFileName,"rt");
	new file = fopen(sfFile,"wt");

	// go through our old copy and rewrite valid entries into the new copy
	new current_time = get_systime(), original[81], removed;
	while(tempFile && file && !feof(tempFile))
	{
		fgets(tempFile,sfLineData,80);

		if(!sfLineData[0]) continue;

		// save original
		original = sfLineData;

		// break off authid
		strtok(sfLineData,sfAuthid,1,sfLineData,80,'^t');

		// break off wins
		strtok(sfLineData,sfWins,1,sfLineData,80,'^t');

		// break off name, and thus get timestamp
		strtok(sfLineData,sfName,1,sfTimestamp,11,'^t');
		copyc(sfTimestamp,11,sfTimestamp,'^t'); // cut off points

		// not too old, write it to our new file
		if(current_time - str_to_num(sfTimestamp) <= max_time)
			fprintf(file,"%s",original); // newline is already included
		else
			removed++;
	}

	if(tempFile) fclose(tempFile);
	if(file) fclose(file);

	// remove our copy
	delete_file(tempFileName);
	return removed;
}

/**********************************************************************
* SUPPORT FUNCTIONS
**********************************************************************/

// gets the goal for a level, taking into account default and custom values
stock get_level_goal(level,id=0)
{
	get_pcvar_string(gg_weapon_order,weaponOrder,WEAPONORDER_SIZE-1);
	new wnum = str_count(weaponOrder,',') + 1;
	if(level > wnum) level = wnum;

	new comma = str_find_num(weaponOrder,',',level-1)+1;

	static crop[32];
	copyc(crop,31,weaponOrder[comma],',');

	new colon = contain(crop,":");

	// no custom goal
	if(colon == -1)
	{
		new Float:result, isNade, isMelee;

		if(fws_is_nade(crop))
		{
			result = 1.0;
			isNade = 1;
		}
		else if(fws_is_melee(crop))
		{
			result = 1.0;
			isMelee = 1;
		}
		else result = get_pcvar_float(gg_kills_per_lvl);

		// teamplay exception
		if(id && get_pcvar_num(gg_teamplay))
		{
			// one of this for every player on team
			result *= float(team_player_count(get_user_team(id)));

			// modifiers for nade and knife levels
			if(isNade) result *= get_pcvar_float(gg_teamplay_nade_mod);
			else if(isMelee) result *= get_pcvar_float(gg_teamplay_melee_mod);
		}

		if(result <= 0.0) result = 1.0;
		return floatround(result,floatround_ceil);
	}

	static goal[8];
	copyc(goal,7,crop[colon+1],',');

	// teamplay exception
	if(id && get_pcvar_num(gg_teamplay))
	{
		// one of this for every player on team
		new Float:result = floatstr(goal) * float(team_player_count(get_user_team(id)));

		// modifiers for nade and knife levels
		if(fws_is_nade(crop)) result *= get_pcvar_float(gg_teamplay_nade_mod);
		else if(fws_is_melee(crop)) result *= get_pcvar_float(gg_teamplay_melee_mod);

		if(result <= 0.0) result = 1.0;
		return floatround(result,floatround_ceil);
	}

	new Float:result = floatstr(goal);

	if(result <= 0.0) result = 1.0;
	return floatround(result,floatround_ceil);
}

// gets the level a player should use for his level
stock get_level_weapon(theLevel,var[],varLen,includeGoal=0)
{
	if(warmup > 0 && warmupWeapon[0])
		formatex(var,varLen,"%s",warmupWeapon);
	else
		get_weapon_name_by_level(theLevel,var,varLen,includeGoal);
}

// get the name of a weapon by level
stock get_weapon_name_by_level(theLevel,var[],varLen,includeGoal=0)
{
	// under bounds
	if(theLevel <= 0) theLevel = 1;
	else
	{
		// over bounds
		new wnum = get_weapon_num();
		if(theLevel > MAX_WEAPONS || theLevel > wnum) theLevel = wnum;
	}

	static weapons[MAX_WEAPONS][24];
	get_weapon_order(weapons);

	if(!includeGoal && contain(weapons[theLevel-1],":")) // strip off goal if we don't want it
		copyc(var,varLen,weapons[theLevel-1],':');
	else
		formatex(var,varLen,"%s",weapons[theLevel-1]);

	strtolower(var);
}

// get the weapons, in order
stock get_weapon_order(weapons[MAX_WEAPONS][24])
{
	get_pcvar_string(gg_weapon_order,weaponOrder,WEAPONORDER_SIZE-1);

	new i;
	for(i=0;i<MAX_WEAPONS;i++)
	{
		// out of stuff
		if(strlen(weaponOrder) <= 1) break;

		// we still have a comma, go up to it
		if(contain(weaponOrder,",") != -1)
		{
			strtok(weaponOrder,weapons[i],23,weaponOrder,WEAPONORDER_SIZE-1,',');
			trim(weapons[i]);
		}

		// otherwise, finish up
		else
		{
			formatex(weapons[i],23,"%s",weaponOrder);
			trim(weapons[i]);
			break;
		}
	}
}

// get the number of weapons to go through
stock get_weapon_num()
{
	get_pcvar_string(gg_weapon_order,weaponOrder,WEAPONORDER_SIZE-1);
	return str_count(weaponOrder,',') + 1;
}

// easy function to precache sound via cvar
stock precache_sound_by_cvar(pcvar)
{
	 new value[64];
	 get_pcvar_string(pcvar,value,63);
	 precache_generic(value);
}

// figure out which gungame.cfg file to use
stock get_gg_config_file(filename[],len)
{
	formatex(filename,len,"%s/gungame.cfg",cfgDir);

	if(!file_exists(filename))
	{
		formatex(filename,len,"gungame.cfg");
		if(!file_exists(filename)) filename[0] = 0;
	}
}

// figure out which gungame_mapcycle file to use
stock get_gg_mapcycle_file(filename[],len)
{
	static testFile[64];

	// cstrike/addons/amxmodx/configs/gungame_mapcycle.cfg
	formatex(testFile,63,"%s/gungame_mapcycle.cfg",cfgDir);
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/addons/amxmodx/configs/gungame_mapcycle.txt
	formatex(testFile,63,"%s/gungame_mapcycle.txt",cfgDir);
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/gungame_mapcycle.cfg
	testFile = "gungame_mapcycle.cfg";
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/gungame_mapcycle.txt
	testFile = "gungame_mapcycle.txt";
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	return 0;
}

// another easy function to play sound via cvar
stock play_sound_by_cvar(id,cvar)
{
	static value[64];
	get_pcvar_string(cvar,value,63);

	if(!value[0]) return;

	if(containi(value,".mp3") != -1) client_cmd(id,"mp3 play ^"%s^"",value);
	else client_cmd(id,"speak ^"%s^"",value);
}

// a taskable play_sound_by_cvar
public play_sound_by_cvar_task(params[2])
{
	play_sound_by_cvar(params[0],params[1]);
}

// this functions take a filepath, but manages speak/mp3 play
stock play_sound(id,value[])
{
	if(!value[0]) return;

	if(containi(value,".mp3") != -1) client_cmd(id,"mp3 play ^"%s^"",value);
	else
	{
		if(equali(value,"sound/",6)) client_cmd(id,"speak ^"%s^"",value[6]);
		else client_cmd(id,"speak ^"%s^"",value);
	}
}

// find the highest level player and his level
stock get_leader(&retLevel=0,&retNumLeaders=0,&retRunnerUp=0)
{
	new player, leader, numLeaders, runnerUp;

	// locate highest player
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;

		if(leader == 0 || level[player] > level[leader])
		{
			// about to dethrown leader, monitor runnerup
			if(leader && (runnerUp == 0 || level[leader] > level[runnerUp]))
				runnerUp = leader;

			leader = player;
			numLeaders = 1; // reset tied count
		}
		else if(level[player] == level[leader])
			numLeaders++;
		else
		{
			// monitor runnerup
			if(runnerUp == 0 || level[player] > level[runnerUp])
				runnerUp = player;
		}
	}

	retLevel = level[leader];
	retNumLeaders = numLeaders;
	retRunnerUp = runnerUp;

	return leader;
}

// gets the number of players on a particular level
stock num_players_on_level(checkLvl)
{
	 new player, result;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && level[player] == checkLvl)
	 	 	 result++;
	 }
	 return result;
}

// a butchered version of teame06's CS Color Chat Function
public gungame_print(id,custom,tag,msg[],{Float,Sql,Result,_}:...)
{
	new changeCount, num, i, j, argnum = numargs(), player;
	static newMsg[191], message[191], changed[5], players[32];

	if(id)
	{
		players[0] = id;
		num = 1;
	}
	else get_players(players,num);

	new colored_messages = get_pcvar_num(gg_colored_messages);

	for(i=0;i<num;i++)
	{
		player = players[i];
		changeCount = 0;

		// we have to change LANG_PLAYER into
		// a player-specific argument, because
		// ML doesn't work well with SayText
		for(j=4;j<argnum;j++)
		{
			if(getarg(j) == LANG_PLAYER_C)
			{
				setarg(j,0,player);
				changed[changeCount++] = j;
			}
		}

		// do user formatting
		vformat(newMsg,190,msg,5);

		// and now we have to change what we changed
		// back into LANG_PLAYER, so that the next
		// player will be able to have it in his language
		for(j=0;j<changeCount;j++)
		{
			setarg(changed[j],0,LANG_PLAYER_C);
		}

		// optimized color swapping
		if(cstrike && colored_messages)
		{
			replace_all(newMsg,190,"%n","^x03"); // %n = team color
			replace_all(newMsg,190,"%g","^x04"); // %g = green
			replace_all(newMsg,190,"%e","^x01"); // %e = regular
		}
		else
		{
			replace_all(newMsg,190,"%n","");
			replace_all(newMsg,190,"%g","");
			replace_all(newMsg,190,"%e","");
		}

		// now do our formatting (I used two variables because sharing one caused glitches)

		if(tag) formatex(message,190,"^x04[%L]^x01 %s",player,"GUNGAME",newMsg);
		else formatex(message,190,"^x01%s",newMsg);

		message_begin(MSG_ONE,gmsgSayText,_,player);
		write_byte((custom > 0) ? custom : player);
		write_string(message);
		message_end();
	}

	return 1;
}

// show a HUD message to a user
public gungame_hudmessage(id,Float:holdTime,msg[],{Float,Sql,Result,_}:...)
{
	// user formatting
	static newMsg[191];
	vformat(newMsg,190,msg,4);

	// show it
	set_hudmessage(255,255,255,-1.0,0.8,0,6.0,holdTime,0.1,0.5);
	return ShowSyncHudMsg(id,hudSyncReqKills,newMsg);
}

// start a map vote
stock start_mapvote()
{
	new dmmName[24];

	// AMXX Nextmap Chooser
	if(find_plugin_byfile("mapchooser.amxx") != INVALID_PLUGIN_ID)
	{
		log_amx("Starting a map vote from mapchooser.amxx");

		new oldWinLimit = get_cvar_num("mp_winlimit"), oldMaxRounds = get_cvar_num("mp_maxrounds");
		set_cvar_num("mp_winlimit",0); // skip winlimit check
		set_cvar_num("mp_maxrounds",-1); // trick plugin to think game is almost over

		// call the vote
		if(callfunc_begin("voteNextmap","mapchooser.amxx") == 1)
			callfunc_end();

		// set maxrounds back
		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_num("mp_maxrounds",oldMaxRounds);
	}

	// Deagles' Map Management 2.30b
	else if(find_plugin_byfile("deagsmapmanage230b.amxx") != INVALID_PLUGIN_ID)
	{
		dmmName = "deagsmapmanage230b.amxx";
	}

	// Deagles' Map Management 2.40
	else if(find_plugin_byfile("deagsmapmanager.amxx") != INVALID_PLUGIN_ID)
	{
		dmmName = "deagsmapmanager.amxx";
	}

	//  Mapchooser4
	else if(find_plugin_byfile("mapchooser4.amxx") != INVALID_PLUGIN_ID)
	{
		log_amx("Starting a map vote from mapchooser4.amxx");

		new oldWinLimit = get_cvar_num("mp_winlimit"), oldMaxRounds = get_cvar_num("mp_maxrounds");
		set_cvar_num("mp_winlimit",0); // skip winlimit check
		set_cvar_num("mp_maxrounds",1); // trick plugin to think game is almost over

		// deactivate g_buyingtime variable
		if(callfunc_begin("buyFinished","mapchooser4.amxx") == 1)
			callfunc_end();

		// call the vote
		if(callfunc_begin("voteNextmap","mapchooser4.amxx") == 1)
		{
			callfunc_push_str("",false);
			callfunc_end();
		}

		// set maxrounds back
		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_num("mp_maxrounds",oldMaxRounds);
	}

	// NOTHING?
	else log_amx("Using gg_vote_setting without mapchooser.amxx, mapchooser4.amxx, deagsmapmanage230b.amxx, or deagsmapmanager.amxx: could not start a vote!");

	// do DMM stuff
	if(dmmName[0])
	{
		log_amx("Starting a map vote from %s",dmmName);

		// allow voting
		/*if(callfunc_begin("dmapvotemode",dmmName) == 1)
					{
			callfunc_push_int(0); // server
			callfunc_end();
		}*/

		new oldWinLimit = get_cvar_num("mp_winlimit"), Float:oldTimeLimit = get_cvar_float("mp_timelimit");
		set_cvar_num("mp_winlimit",99999); // don't allow extending
		set_cvar_float("mp_timelimit",0.0); // don't wait for buying
		set_cvar_num("enforce_timelimit",1); // don't change map after vote

		// call the vote
		if(callfunc_begin("startthevote",dmmName) == 1)
			callfunc_end();

		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_float("mp_timelimit",oldTimeLimit);

		// disallow further voting
		/*if(callfunc_begin("dmapcyclemode",dmmName) == 1)
		{
			callfunc_push_int(0); // server
			callfunc_end();
		}*/
	}
}

// set amx_nextmap to the next map
stock set_nextmap()
{
	new mapCycleFile[64];
	get_gg_mapcycle_file(mapCycleFile,63);

	// no mapcycle, leave amx_nextmap alone
	if(!mapCycleFile[0] || !file_exists(mapCycleFile))
	{
		set_localinfo("gg_cycle_num","0");
		return;
	}

	new strVal[10];

	// have not gotten cycleNum yet (only get it once, because
	// set_nextmap is generally called at least twice per map, and we
	// don't want to change it twice)
	if(cycleNum == -1)
	{
		get_localinfo("gg_cycle_num",strVal,9);
		cycleNum = str_to_num(strVal);
	}

	new firstMap[32], currentMap[32], lineData[32], i, line, foundMap;
	get_mapname(currentMap,31);

	new file = fopen(mapCycleFile,"rt");
	while(file && !feof(file))
	{
		fgets(file,lineData,31);

		trim(lineData);
		replace(lineData,31,".bsp",""); // remove extension
		new len = strlen(lineData) - 2;

		// stop at a comment
		for(i=0;i<len;i++)
		{
			// supports config-style (;) and coding-style (//)
			if(lineData[i] == ';' || (lineData[i] == '/' && lineData[i+1] == '/'))
			{
				copy(lineData,i,lineData);
				break;
			}
		}

		trim(lineData);
		if(!lineData[0]) continue;

		// save first map
		if(!firstMap[0]) formatex(firstMap,31,"%s",lineData);

		// we reached the line after our current map's line
		if(line == cycleNum+1)
		{
			// remember so
			foundMap = 1;

			// get ready to change to it
			set_cvar_string("amx_nextmap",lineData);

			// remember this map's line for next time
			num_to_str(line,strVal,9);
			set_localinfo("gg_cycle_num",strVal);

			break;
		}

		line++;
	}
	if(file) fclose(file);

	// we didn't find next map
	if(!foundMap)
	{
		// reset line number to first (it's zero-based)
		set_localinfo("gg_cycle_num","0");

		// no maps listed, go to current
		if(!firstMap[0]) set_cvar_string("amx_nextmap",currentMap);

		// go to first map listed
		else set_cvar_string("amx_nextmap",firstMap);
	}
}

// go to amx_nextmap
public goto_nextmap()
{
	set_nextmap(); // for good measure

	new mapCycleFile[64];
	get_gg_mapcycle_file(mapCycleFile,63);

	// no gungame mapcycle
	if(!mapCycleFile[0] || !file_exists(mapCycleFile))
	{
		new custom[256];
		get_pcvar_string(gg_changelevel_custom,custom,255);

		// try custom changelevel command
		if(custom[0])
		{
			server_cmd(custom);
			return;
		}
	}

	// otherwise, go to amx_nextmap
	new nextMap[32];
	get_cvar_string("amx_nextmap",nextMap,31);

	server_cmd("changelevel %s",nextMap);
}

// find a player's weapon entity
stock get_weapon_ent(id,wpnid=0,wpnName[]="")
{
	// who knows what wpnName will be
	static newName[24];

	// need to find the name
	if(wpnid) get_mod_weaponname(wpnid,newName,23);

	// go with what we were told
	else formatex(newName,23,"%s",wpnName);

	// prefix it if we need to
	if(!equal(newName,"weapon_",7))
		format(newName,23,"weapon_%s",newName);

	return fm_find_ent_by_owner(maxPlayers,newName,id);
}

// counts number of chars in a string, by (probably) Twilight Suzuka
stock str_count(str[],searchchar)
{
	new i = 0;
	new maxlen = strlen(str);
	new count = 0;

	for(i=0;i<=maxlen;i++)
	{
		if(str[i] == searchchar)
			count++;
	}
	return count;
}

// find the nth occurance of a character in a string, based on str_count
stock str_find_num(str[],searchchar,number)
{
	new i;
	new maxlen = strlen(str);
	new found = 0;

	for(i=0;i<=maxlen;i++)
	{
		if(str[i] == searchchar)
		{
			if(++found == number)
				return i;
		}
	}
	return -1;
}

// cuts a snippet out of a string
stock remove_snippet(string[],strLen,start,end)
{
	 new i, newpos;
	 for(i=start;i<strLen;i++)
	 {
	 	 if(!string[i]) break;
	 	 newpos = i + end - start + 1;

	 	 if(newpos >= strLen) string[i] = 0;
	 	 else string[i] = string[newpos];
	 }

	 return 1;
}

// gets a player id that triggered certain logevents, by VEN
stock get_loguser_index()
{
	static loguser[80], name[32];
	read_logargv(0,loguser,79);
	parse_loguser(loguser,name,31);

	return get_user_index(name);
}

// checks if a space is vacant, by VEN
stock bool:is_hull_vacant(const Float:origin[3],hull)
{
	new tr = 0;
	engfunc(EngFunc_TraceHull,origin,origin,0,hull,0,tr);

	if(!get_tr2(tr,TR_StartSolid) && !get_tr2(tr,TR_AllSolid) && get_tr2(tr,TR_InOpen))
		return true;

	return false;
}

// gets a weapon's category, just a shortcut to the weaponSlots table basically
stock get_weapon_category(id=0,name[]="")
{
	if(name[0])
	{
		if(equal(name,"weapon_",7)) id = get_mod_weaponid(name);
		else
		{
			static newName[24];
			formatex(newName,23,"weapon_%s",name);
			id = get_mod_weaponid(newName);
		}
	}

	if(!id) return -1;
	return weaponSlots[id];
}

// if a player is allowed to score (at least 1 player on opposite team)
stock can_score(id)
{
	if(!is_user_connected(id)) return 0;

	// If debug endabled, allow scoring with single player
	if( get_pcvar_num(gg_debugmode) )
	{
		return 1;
	}

	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		// this player is in a position to play and is on the other team than me
		if(player != id && is_user_connected(player) && fws_on_valid_team(player) && !fws_same_team(id,player))
			return 1;
	}

	return 0;
}

// returns 1 if there are only bots in the server, 0 if not
stock only_bots()
{
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && !is_user_bot(player))
			return 0;
	}

	// didn't find any humans
	return 1;
}

// gives a player a weapon efficiently
stock ham_give_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;

	new scoped;
	if(dod)
	{
		if(equal(weapon,"weapon_scopedfg42"))
		{
			scoped = 1;
			formatex(weapon,11,"weapon_fg42");
		}
		else if(equal(weapon,"weapon_scopedenfield"))
		{
			scoped = 1;
			formatex(weapon,14,"weapon_enfield");
		}
	}

	new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon));
	if(!pev_valid(wEnt)) return 0;

	if(scoped) set_pdata_int(wEnt,WPN_SCOPED_OFFSET,1,WPN_LINUX_DIFF);

	set_pev(wEnt,pev_spawnflags,SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn,wEnt);

	if(!ExecuteHamB(Ham_AddPlayerItem,id,any:wEnt) || !ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,any:id))
	{
		if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) & FL_KILLME);
		return 0;
	}

	return 1;
}

// takes a weapon from a player efficiently
stock ham_strip_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;

	new wId = get_mod_weaponid(weapon);
	if(!wId) return 0;

	new wEnt = fm_find_ent_by_owner(maxPlayers,weapon,id);
	if(!wEnt) return 0;

	new dummy, weapon = get_user_weapon(id,dummy,dummy);
	if(weapon == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);

	if(!ExecuteHamB(Ham_RemovePlayerItem,id,any:wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill,wEnt);

	set_pev(id,pev_weapons,pev(id,pev_weapons) & ~(1<<wId));

	// CS
	if(cstrike && (wId == CSW_C4 || wId == CSW_SMOKEGRENADE || wId == CSW_FLASHBANG || wId == CSW_HEGRENADE))
		cs_set_user_bpammo(id,wId,0);

	// DOD
	else if(dod && (wId == DODW_HANDGRENADE || wId == DODW_STICKGRENADE || wId == DODW_MILLS_BOMB))
		dod_set_user_ammo(id,wId,0);

	return 1;
}

// checks if a player has a grenade on him
stock user_has_grenade(id)
{
	new weapons = pev(id,pev_weapons), wpnid, name[32];
	for(wpnid=1;wpnid<32;wpnid++)
	{
		if(!(weapons & (1<<wpnid))) continue;

		get_mod_weaponname(wpnid,name,31);
		if(fws_is_nade(name)) return 1;
	}

	return 0;
}

// gets the weapon that a killer used, just like CHalfLifeMultiplay::DeathNotice
stock get_killer_weapon(killer,inflictor,retVar[],retLen)
{
	static killer_weapon_name[32];
	killer_weapon_name = "world"; // by default, the player is killed by the world

	if(pev_valid(killer) && (pev(killer,pev_flags) & FL_CLIENT))
	{
		if(pev_valid(inflictor))
		{
			if(inflictor == killer)
			{
				// if the inflictor is the killer, then it must be their current weapon doing the damage
				new weapon = get_user_weapon(killer,dummy[0],dummy[0]);
				get_mod_weaponname(weapon,killer_weapon_name,31);
			}
			else pev(inflictor,pev_classname,killer_weapon_name,31); // it's just that easy
		}
	}
	else
	{
		if(pev_valid(killer)) pev(inflictor,pev_classname,killer_weapon_name,31);
		else if(killer == 0) killer_weapon_name = "worldspawn";
	}

	// strip the monster_* or weapon_* from the inflictor's classname
	if(equal(killer_weapon_name,"weapon_",7))
		format(killer_weapon_name,31,"%s",killer_weapon_name[7]);
	else if(equal(killer_weapon_name,"monster_",8))
		format(killer_weapon_name,31,"%s",killer_weapon_name[8]);
	else if(equal(killer_weapon_name,"func_",5))
		format(killer_weapon_name,31,"%s",killer_weapon_name[5]);

	// output
	formatex(retVar,retLen,"%s",killer_weapon_name);
}

// get a list of which weapons go in which slots
stock calculate_weapon_slots()
{
	new i, ent, wname[24];
	for(i=1;i<32;i++)
	{
		get_mod_weaponname(i,wname,23);
		if(!wname[0]) continue;

		ent = fm_create_entity(wname);
		if(!pev_valid(ent)) continue;

		set_pev(ent,pev_spawnflags,SF_NORESPAWN);
		weaponSlots[i] = ExecuteHam(Ham_Item_ItemSlot,ent);
		fm_remove_entity(ent);
	}
}

// set up some quick-reference variables
stock set_mod_shortcuts()
{
	get_modname(modName,11);
	if(equal(modName,"cstrike")) cstrike = 1;
	else if(equal(modName,"czero"))
	{
		cstrike = 1;
		czero = 1;
	}
	else if(equal(modName,"dod")) dod = 1;
}

// set important weapon information per-mod
stock set_mod_weapon_information()
{
	 if(cstrike)
	 {
		maxClip = { -1, 13, -1, 10, 1, 7, 1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20,
			10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50, -1, -1, -1, -1, -1 };

		maxAmmo = { -1, 52, -1, 90, -1, 32, -1, 100, 90, -1, 120, 100, 100, 90, 90, 90, 100, 100,
			30, 120, 200, 32, 90, 120, 60, -1, 35, 90, 90, -1, 100, -1, -1, -1, -1, -1 };

		calculate_weapon_slots();
	 }
	 else if(dod)
	 {
		maxClip = { -1, -1, -1, 7, 8, 8, 5, 30, 30, 5, 5, 20, 30, -1, -1, -1, -1, 250, 150, -1,
			15, 75, 30, 20, 10, 10, 30, 30, 6, 1, 1, 1, 20, 15, -1, 10 };

		maxAmmo = { -1, -1, -1, 21, 24, 88, 65, 210, 210, 55, 65, 260, 210, 3, 3, 1, 1, 500, 300, -1,
			165, 450, 210, 180, 80, 60, 210, 180, 18, 5, 5, 5, 180, 165, -1, 60 };

		calculate_weapon_slots();
	 }
	 else
	 {
	 	 fws_request_weapon_info(maxClip,maxAmmo,weaponSlots);
	 }
}

// sets clip ammo, offset thanks to Wilson [29th ID]
stock dod_set_weapon_ammo(index,newammo)
{
	return set_pdata_int(index,108,newammo,WPN_LINUX_DIFF);
}

// per-mod backpack ammo update
stock set_user_bpammo(id,weapon,ammo)
{
	 if(cstrike)
	 {
	 	if(weapon == CSW_KNIFE) return 0;
	 	return cs_set_user_bpammo(id,weapon,ammo);
	 }
	 else if(dod) return dod_set_user_ammo(id,weapon,ammo);

	 return fws_set_user_bpammo(id,weapon,ammo);
}

// per-mod weapon clip update
stock set_weapon_ammo(weapon,ammo)
{
	 if(cstrike) return cs_set_weapon_ammo(weapon,ammo);
	 else if(dod) return dod_set_weapon_ammo(weapon,ammo);

	 return fws_set_weapon_ammo(weapon,ammo);
}

// DoD exception for get_weaponname
stock get_mod_weaponname(weapon,ret[],retLen)
{
	 ret[0] = 0;
	 if(dod) return dod_get_weaponname(weapon,ret,retLen);
	 return get_weaponname(weapon,ret,retLen);
}

// DoD exception for get_weaponid
stock get_mod_weaponid(weapon[])
{
	if(dod) return dod_get_weaponid(weapon);
	return get_weaponid(weapon);
}

// mod exceptiosn for get_user_deaths
stock get_mod_user_deaths(id)
{
	 if(cstrike) return cs_get_user_deaths(id);
	 else if(dod) return dod_get_pl_deaths(id);

	 return get_user_deaths(id);
}

// DoD has fancy weapon names. we just need the facts!
stock dod_get_weaponname(weapon,ret[],retLen)
{
	 if(weapon < 1 || weapon > 41)
	 	 return 0;

	 static logName[24];
	 xmod_get_wpnlogname(weapon,logName,23);

	 if(equal(logName,"grenade")) logName = "handgrenade";
	 else if(equal(logName,"grenade2")) logName = "stickgrenade";
	 else if(equal(logName,"scoped_fg42")) logName = "fg42";
	 else if(equal(logName,"fcarbine")) logName = "m1carbine";
	 else if(equal(logName,"scoped_enfield")) logName = "enfield";
	 else if(equal(logName,"brit_knife")) logName = "amerknife";

	 return formatex(ret,retLen,"weapon_%s",logName);
}

// DoD has fancy weapon names. we just need the facts!
stock dod_get_weaponid(weapon[])
{
	 static names[32][] =
	 {
	 	 "",
	 	 "weapon_amerknife",
	 	 "weapon_gerknife",
	 	 "weapon_colt",
	 	 "weapon_luger",
	 	 "weapon_garand",
	 	 "weapon_scopedkar",
	 	 "weapon_thompson",
	 	 "weapon_mp44",
	 	 "weapon_spring",
	 	 "weapon_kar",
	 	 "weapon_bar",
	 	 "weapon_mp40",
	 	 "weapon_handgrenade",
	 	 "weapon_stickgrenade",
	 	 "weapon_stickgrenade_ex",
	 	 "weapon_handgrenade_ex",
	 	 "weapon_mg42",
	 	 "weapon_30cal",
	 	 "weapon_spade",
	 	 "weapon_m1carbine",
	 	 "weapon_mg34",
	 	 "weapon_greasegun",
	 	 "weapon_fg42",
	 	 "weapon_k43",
	 	 "weapon_enfield",
	 	 "weapon_sten",
	 	 "weapon_bren",
	 	 "weapon_webley",
	 	 "weapon_bazooka",
	 	 "weapon_pschreck",
	 	 "weapon_piat"
	 };

	 // awkward exceptions
	 if(equal(weapon,"weapon_scopedfg42")) return DODW_FG42;
	 else if(equal(weapon,"weapon_fcarbine")) return DODW_M1_CARBINE;
	 else if(equal(weapon,"weapon_scopedenfield")) return DODW_ENFIELD;
	 else if(equal(weapon,"weapon_britknife")) return DODW_AMERKNIFE;

	 new i;
	 for(i=1;i<=31;i++) if(equal(weapon,names[i])) return i;

	 return 0;
}

// gets a team's color
stock get_team_color(team,ret[],retLen)
{
	switch(team)
	{
		case 1: // terrorist, allies
		{
			if(cstrike) formatex(ret,retLen,"#FF3F3F");
			else if(dod) formatex(ret,retLen,"#4C664C");
		}
		case 2: // counter-terrorist, axis
		{
			if(cstrike) formatex(ret,retLen,"#99CCFF");
			else if(dod) formatex(ret,retLen,"#FF3F3F");
		}
	}
}

// gets the name of a team
stock get_team_name(team,ret[],retLen)
{
	 // fast lookups
	 if(cstrike)
	 {
	 	 switch(team)
	 	 {
	 	 	 case 1: return formatex(ret,retLen,"TERRORIST");
	 	 	 case 2: return formatex(ret,retLen,"CT");
	 	 	 case 3: return formatex(ret,retLen,"SPECTATOR");
	 	 	 default: return formatex(ret,retLen,"UNASSIGNED");
	 	 }
	 }
	 else if(dod)
	 {
	 	 switch(team)
	 	 {
	 	 	 case 1: return formatex(ret,retLen,"Allies");
	 	 	 case 2: return formatex(ret,retLen,"Axis");
	 	 	 default: return formatex(ret,retLen,"Spectator");
	 	 }
	 }

	 // otherwise, do it the hard way
	 new player;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && get_user_team(player) == team)
	 	 	 return get_user_team(player,ret,retLen);
	 }

	 return formatex(ret,retLen,"");
}

// gets the amount of players on a team
stock team_player_count(team)
{
	 new player, count;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	 if(is_user_connected(player) && get_user_team(player) == team)
	 	 	 count++;
	 }

	 return count;
}
