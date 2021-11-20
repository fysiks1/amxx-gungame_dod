
// Blah blah blah. Note that there is quite a bit of
// DoD-specific code in gungame_base.amxx because
// DoD is so wonky (mostly, the shared weapons).
//
// In this script, I define a lot of things. Okay?

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <dodfun>
#include <dodx>
#include <hamsandwich>
#include <gungame>

// defines
new const GG_VERSION[] =	"2.00B4.0"
#define LANG_PLAYER_C		-76 // for gungame_print (arbitrary number)
#define MAX_SPAWNS		128 // for gg_dod_spawn_random

// tasks
#define TASK_DOMAPFLAGS	100

// ammo indexes from Wilson
#define AMMO_SMG		1 // thompson, greasegun, sten, mp40
#define AMMO_ALTRIFLE	2 // carbine, k43, mg34
#define AMMO_RIFLE	3 // garand, enfield, scoped enfield, k98, scoped k98
#define AMMO_PISTOL	4 // colt, webley, luger
#define AMMO_SPRING	5 // springfield
#define AMMO_HEAVY	6 // bar, bren, stg44, fg42, scoped fg42
#define AMMO_MG42	7 // mg42
#define AMMO_30CAL	8 // 30cal
#define AMMO_HANDNADE	9 // american/british grenade
#define AMMO_STICKNADE	11 // stick grenade
#define AMMO_ROCKET	13 // bazooka, piat, panzerschreck

// weapon pdata offest
#define WPN_SCOPED_OFFSET	115
#define WPN_LINUX_DIFF		4

// for gg_dod_mapflags
#define MFL_REMOVE_FLAGS		(1<<0) // a
#define MFL_REMOVE_OBJECTS		(1<<1) // b
#define MFL_REMOVE_SPAWNGUNS		(1<<2) // c
#define MFL_REMOVE_TEAMHURTS		(1<<3) // d
#define MFL_UNLOCK_OBJECTS		(1<<4) // e
#define MFL_UNLOCK_MISCCAPAREAS	(1<<5) // f
#define MFL_UNLOCK_TEAMDOORS		(1<<6) // g
#define MFL_UNLOCK_TEAMBUTTONS	(1<<7) // h
#define MFL_UNLOCK_TEAMBREAKABLES	(1<<8) // i
#define MFL_ONLY_WITH_CSDM		(1<<25) // z

// for gg_dod_mapflags
#define SAVEFIELD_INT1		pev_iuser3
#define SAVEFIELD_INT2		pev_iuser4
#define SAVEFIELD_VEC1		pev_vuser3
#define SAVEFIELD_VEC2		pev_vuser4
#define SAVEFIELD_STR1		pev_netname
#define SAVEFIELD_STR2		pev_message
#define SAVEFIELD_STR3		pev_noise
#define SAVEFIELD_STR4		pev_noise1
#define SAVEFIELD_STR5		pev_noise2
#define SAVEFIELD_STR6		pev_noise3

// for func_tank
#define TANK_CLASS_ALLIES	14
#define TANK_CLASS_AXIS	15

// for trigger_hurt
#define HURT_SF_NOTALLIES	64
#define HURT_SF_NOTAXIS	128

// for trigger_teleport
#define TELEPORT_SF_NOALLIES	8
#define TELEPORT_SF_NOAXIS	16

// for func_button
#define BUTTON_SF_NOALLIES	2
#define BUTTON_SF_NOAXIS	4

// for func_breakable
#define BREAKABLE_SF_ALLIESONLY	16
#define BREAKABLE_SF_AXISONLY	32

/**********************************************************************
* VARIABLE DEFINITIONS
**********************************************************************/

// pcvar holders
new gg_weapon_order, gg_kills_per_lvl, gg_ammo_amount, gg_pickup_others,
gg_dod_flagcap_bonus, gg_dod_object_get_bonus, gg_dod_object_kill_bonus,
gg_dod_sniper_oneshot, gg_dod_bayostock_steal, gg_dod_spawn_random, gg_dod_start_random,
gg_dod_mapflags, gg_dod_roundwin_bonus, gg_dod_allow_changeteam, gg_teamplay;

// misc
new weaponOrder[416], gameCommenced, roundEnded, maxPlayers, britMap, cfgDir[32],
Float:spawns[MAX_SPAWNS][9], spawnCount, weaponSlots[36], ggActive, fwKeyValue, mflInEffect;

// event ids
new gmsgCurWeapon, gmsgAmmoX, gmsgAmmoShort;

// player variables
new hasObject[33], gotObject[33], killedObject[33], blockSounds[33], switchOkay[33];

// shared variables from the base plugin
new level[33], score[33], lvlWeapon[33][24];

/**********************************************************************
* INITIATION FUNCTIONS
**********************************************************************/

public plugin_init()
{
	register_plugin("GunGame AMXX - DOD",GG_VERSION,"Avalanche");

	// does this need to be here?
	register_dictionary("gungame.txt");

	// event ids
	gmsgCurWeapon = get_user_msgid("CurWeapon");
	gmsgAmmoX = get_user_msgid("AmmoX");
	gmsgAmmoShort = get_user_msgid("AmmoShort");

	// events
	RegisterHam(Ham_Spawn,"player","ham_player_spawn",1);
	register_event("CurWeapon","event_curweapon","be","1=1");
	register_event("RoundState","event_roundstate","a");
	register_event("PStatus","event_pstatus","abe");

	// log events
	register_logevent("logevent_flag_capture",5,"1=triggered a","2=dod_capture_area","2=dod_control_point");
	register_logevent("logevent_team_join",3,"1=joined team");

	// forwards
	register_forward(FM_EmitSound,"fw_emitsound");
	unregister_forward(FM_KeyValue,fwKeyValue,1);

	// ham goes here
	RegisterHam(Ham_Touch,"weaponbox","ham_weapon_touch",0);
	RegisterHam(Ham_Killed,"player","ham_player_killed",0);
	RegisterHam(Ham_DOD_RoundRespawn,"dod_control_point","ham_control_point_reset",1);
	RegisterHam(Ham_DOD_RoundRespawn,"dod_capture_area","ham_control_point_reset",1);
	RegisterHam(Ham_DOD_RoundRespawn,"dod_object","ham_object_reset",1);
	RegisterHam(Ham_DOD_RoundRespawn,"trigger_hurt","ham_hurt_reset",1);
	RegisterHam(Ham_DOD_RoundRespawn,"func_button","ham_button_reset",1);
	RegisterHam(Ham_DOD_RoundRespawn,"func_breakable","ham_breakable_reset",1);

	// dod cvars
	gg_dod_allow_changeteam = register_cvar("gg_dod_allow_changeteam","2");
	gg_dod_flagcap_bonus = register_cvar("gg_dod_flagcap_bonus","1");
	gg_dod_object_get_bonus = register_cvar("gg_dod_object_get_bonus","0");
	gg_dod_object_kill_bonus = register_cvar("gg_dod_object_kill_bonus","0");
	gg_dod_roundwin_bonus = register_cvar("gg_dod_roundwin_bonus","1");
	gg_dod_sniper_oneshot = register_cvar("gg_dod_sniper_oneshot","1");
	gg_dod_bayostock_steal = register_cvar("gg_dod_bayostock_steal","1");
	gg_dod_mapflags = register_cvar("gg_dod_mapflags","acdefghiz");
	gg_dod_spawn_random = register_cvar("gg_dod_spawn_random","1");
	gg_dod_start_random = register_cvar("gg_dod_start_random","1");

	// remember such
	maxPlayers = get_maxplayers();
	britMap = (dod_get_map_info(MI_ALLIES_TEAM) == 1);

	// calculate!!
	calculate_weapon_slots();

	// grab CSDM file
	new mapName[32], csdmFile[64], lineData[64];
	get_configsdir(cfgDir,31);
	get_mapname(mapName,31);
	formatex(csdmFile,63,"%s/csdm/%s.spawns.cfg",cfgDir,mapName);

	// collect CSDM spawns
	if(file_exists(csdmFile))
	{
		new csdmData[10][6];

		new file = fopen(csdmFile,"rt");
		while(file && !feof(file))
		{
			fgets(file,lineData,63);

			// invalid spawn
			if(!lineData[0] || str_count(lineData,' ') < 2)
				continue;

			// BREAK IT UP!
			parse(lineData,csdmData[0],5,csdmData[1],5,csdmData[2],5,csdmData[3],5,csdmData[4],5,csdmData[5],5,csdmData[6],5,csdmData[7],5,csdmData[8],5,csdmData[9],5);

			// origin
			spawns[spawnCount][0] = floatstr(csdmData[0]);
			spawns[spawnCount][1] = floatstr(csdmData[1]);
			spawns[spawnCount][2] = floatstr(csdmData[2]);

			// angles
			spawns[spawnCount][3] = floatstr(csdmData[3]);
			spawns[spawnCount][4] = floatstr(csdmData[4]);
			spawns[spawnCount][5] = floatstr(csdmData[5]);

			// team, csdmData[6], unused

			// vangles
			spawns[spawnCount][6] = floatstr(csdmData[7]);
			spawns[spawnCount][7] = floatstr(csdmData[8]);
			spawns[spawnCount][8] = floatstr(csdmData[9]);

			spawnCount++;
			if(spawnCount >= MAX_SPAWNS) break;
		}
		if(file) fclose(file);
	}
}

// world spawned
public plugin_precache()
{
	 fwKeyValue = register_forward(FM_KeyValue,"fw_keyvalue",1);
}

// catch all cvar pointers from gungame_base.amxx
public plugin_cfg()
{
	// gameplay cvars
	gg_weapon_order = get_cvar_pointer("gg_weapon_order");
	gg_kills_per_lvl = get_cvar_pointer("gg_kills_per_lvl");
	gg_pickup_others = get_cvar_pointer("gg_pickup_others");
	gg_ammo_amount = get_cvar_pointer("gg_ammo_amount");
	gg_teamplay = get_cvar_pointer("gg_teamplay");
}

/**********************************************************************
* EVENT HOOKS
**********************************************************************/

// a player respawned... probably
public ham_player_spawn(id)
{
	if(!is_user_alive(id)) return;
	if(!ggActive || !ggfw_on_valid_team(id)) return;

	switchOkay[id] = 0;
	blockSounds[id] = 0;

	ggn_notify_player_spawn(id);

	if(spawnCount)
	{
		new Float:maxspeed;
		pev(id,pev_maxspeed,maxspeed);

		// maxspeed is 1.0 on round start
		if((maxspeed > 1.0 && get_pcvar_num(gg_dod_spawn_random))
		|| (maxspeed == 1.0 && get_pcvar_num(gg_dod_start_random)))
			do_random_spawn(id);
	}
}

// player changes weapon
public event_curweapon(id)
{
	 if(!ggActive) return;

	 new weapon = read_data(2);

	 // model fix for brits and certain melee weapons
	 if(britMap && get_user_team(id) == ALLIES)
	 {
	 	 switch(weapon)
	 	 {
	 	 	case DODW_GERKNIFE:
	 	 	{
	 	 		set_pev(id,pev_viewmodel2,"models/v_paraknife.mdl");
	 	 		set_pev(id,pev_weaponmodel2,"models/p_paraknife.mdl");
	 	 		return;
	 	 	}
	 	 	case DODW_SPADE:
	 	 	{
	 	 		set_pev(id,pev_viewmodel2,"models/v_spade.mdl");
	 	 		set_pev(id,pev_weaponmodel2,"models/p_spade.mdl");
	 	 		return;
	 	 	}
	 	 }
	 }

	 // have more than one bullet in a sniper clip
	 if(get_pcvar_num(gg_dod_sniper_oneshot) && (weapon == DODW_SCOPED_KAR
	 	|| weapon == DODW_SPRINGFIELD || weapon == DODW_ENFIELD) && read_data(3) > 1)
	 {
	 	static wName[32];
	 	dod_get_weaponname(weapon,wName,31);

		new wEnt = fm_find_ent_by_owner(maxPlayers,wName,id);
		if(pev_valid(wEnt))
		{
			// not the scoped enfield
			if(weapon == DODW_ENFIELD && !get_pdata_int(wEnt,WPN_SCOPED_OFFSET,WPN_LINUX_DIFF))
				return

			dod_set_weapon_ammo(wEnt,1);
		}

		message_begin(MSG_ONE,gmsgCurWeapon,_,id);
		write_byte(1); // current?
		write_byte(weapon); // weapon
		write_byte(1); // clip
		message_end();
	}
}

// the state of the round changes
public event_roundstate()
{
	 // re-entrancy fix
	 static Float:lastThis;
	 new Float:now = get_gametime();
	 if(now == lastThis) return;
	 lastThis = now;

	 new status = read_data(1);

	 // clear information
	 new i;
	 for(i=1;i<=maxPlayers;i++)
	 {
	 	 hasObject[i] = 0;
	 	 gotObject[i] = 0;
	 	 killedObject[i] = 0;
	 }

	 // round start
	 if(status == 1)
	 {
	 	 // log game commenced on first round start
	 	 if(!gameCommenced)
	 	 {
	 	 	 ggn_notify_game_commenced();
	 	 	 gameCommenced = 1;

	 	 	 // for check below
	 	 	 roundEnded = 1;
	 	 }

	 	 if(roundEnded)
	 	 {
	 	 	ggn_notify_new_round();
	 	 	roundEnded = 0;
	 	 }
	 }

	 // round end slash team win
	 else if(status == 0 || status == 3 || status == 4 || status == 5)
	 {
	 	 switch(status)
	 	 {
	 	 	 case 3: team_won(ALLIES);
	 	 	 case 4: team_won(AXIS);
	 	 }

	 	 if(!roundEnded)
	 	 {
	 	 	roundEnded = 1;
	 	 	ggn_notify_round_end();
	 	 }
	 }

	 do_mapflags(); // gg_dod_mapflags
}

// player's status changes
public event_pstatus()
{
	 if(!ggActive) return;

	 new id = read_data(1);
	 new status = read_data(2);

	 // re-entrancy fix
	 static Float:lastThis[33][2];
	 new Float:now = get_gametime();
	 if(now == lastThis[id][0] && float(status) == lastThis[id][1]) return;
	 lastThis[id][0] = now;
	 lastThis[id][1] = float(status);

	 if(status == 5) // OBJECT
	 {
	 	hasObject[id] = 1;

	 	if(!gotObject[id])
	 	{
	 		gotObject[id] = 1;

	 		if(get_pcvar_num(gg_teamplay))
	 		{
	 			new team = get_user_team(id), i;
	 			for(i=1;i<=maxPlayers;i++)
	 			{
	 				// one per team
	 				if(is_user_connected(i) && get_user_team(i) == team)
	 					gotObject[i] = 1;
	 			}
	 		}

	 		new bonus = get_pcvar_num(gg_dod_object_get_bonus);
	 		if(!bonus) return;

			if((!ggfw_is_nade(lvlWeapon[id]) && !ggfw_is_melee(lvlWeapon[id]) && level[id] < get_weapon_num())
				|| score[id] + bonus < get_level_goal(level[id]))
			{
				// didn't level off of it
				if(!ggn_change_score(id,bonus)) ggn_show_required_kills(id);
			}
			else ggn_refill_ammo(id);
	 	}
	 }
	 else hasObject[id] = 0;
}

/**********************************************************************
* LOG EVENT HOOKS
**********************************************************************/

// someone captures a flag
public logevent_flag_capture()
{
	static Float:lastCap, name[32];

	if(!ggActive) return;

	new bonus = get_pcvar_num(gg_dod_flagcap_bonus);
	if(!bonus) return;
	new absBonus = abs(bonus);

	new id = get_loguser_index();

	new teamplay = get_pcvar_num(gg_teamplay);
	if(teamplay)
	{
		new Float:time = get_gametime();
		if(lastCap == time) return; // only accept one log per flag capture
		lastCap = time;

		switch(get_user_team(id))
		{
			case ALLIES: name = "Allies";
			case AXIS: name = "Axis";
		}
	}
	else get_user_name(id,name,31);

	if((!ggfw_is_nade(lvlWeapon[id]) && !ggfw_is_melee(lvlWeapon[id]) && level[id] < get_weapon_num())
		|| score[id] + absBonus < get_level_goal(level[id]))
	{
		// didn't level off of it
		if(!ggn_change_score(id,absBonus))
		{
			if(bonus > 0) ggn_gungame_print(0,0,1,"%L",/*pattern*/"issi",/*args*/LANG_PLAYER_C,(teamplay) ? "DOD_FLAG_SCORE_UP_TEAM" : "DOD_FLAG_SCORE_UP",name,bonus);
			ggn_show_required_kills(id);
		}
		else if(bonus > 0) ggn_gungame_print(0,0,1,"%L",/*pattern*/"issi",/*args*/LANG_PLAYER_C,(teamplay) ? "DOD_FLAG_LEVEL_UP_TEAM" : "DOD_FLAG_LEVEL_UP",name,level[id]);
	}
	else ggn_refill_ammo(id);
}

// someone joins a team
public logevent_team_join()
{
	if(!ggActive) return;

	new id = get_loguser_index();
	if(!is_user_connected(id)) return;

	static arg2[7];
	read_logargv(2,arg2,6);

	new newTeam;

	// get the new team
	if(equal(arg2,"Allies")) newTeam = ALLIES;
	else if(equal(arg2,"Axis")) newTeam = AXIS;
	else newTeam = 0;

	// it shall be known!
	ggn_notify_player_teamchange(id,newTeam);

	// always allow switching in teamplay
	if(get_pcvar_num(gg_teamplay))
	{
		switchOkay[id] = 1;
		return;
	}

	// team change not allowed, don't bother with below stuff
	new allow_changeteam = get_pcvar_num(gg_dod_allow_changeteam);
	if(!allow_changeteam) return;

	new oldTeam = get_user_team(id);
	if(oldTeam != ALLIES && oldTeam != AXIS) return;

	// didn't switch teams, too bad for you (suicide)
	if(!newTeam || oldTeam == newTeam) return;

	// check to see if the team change was beneficial
	if(allow_changeteam == 2)
	{
		new teamCount[2], i;
		for(i=1;i<=maxPlayers;i++)
		{
			if(!is_user_connected(i)) continue;

			if(i == id) teamCount[newTeam-1]++;
			else
			{
				switch(get_user_team(i))
				{
					case ALLIES: teamCount[0]++;
					case AXIS: teamCount[1]++;
				}
			}
		}

		if(teamCount[newTeam-1] <= teamCount[oldTeam-1])
			switchOkay[id] = 1;
	}
	else switchOkay[id] = 1;
}

/**********************************************************************
* FORWARD HOOKS
**********************************************************************/

// an entity is getting a keyvalue assigned to it
public fw_keyvalue(ent,kvd_handle)
{
	 if(!pev_valid(ent)) return HAM_IGNORED;

	 new classname[18], keyname[22];
	 get_kvd(kvd_handle,KV_ClassName,classname,17);
	 get_kvd(kvd_handle,KV_KeyName,keyname,21);

	 // save important information
	 if((equal(classname,"func_tank") && equal(keyname,"m_iClass"))
	 	 || (equal(classname,"trigger_hurt") && equal(keyname,"spawnflags"))
	 	 || (equal(classname,"trigger_teleport") && equal(keyname,"spawnflags"))
	 	 || (equal(classname,"func_door",9) && equal(keyname,"TeamDoors"))
	 	 || (equal(classname,"func_button") && equal(keyname,"spawnflags"))
	 	 || (equal(classname,"func_breakable") && equal(keyname,"spawnflags"))
	 	 || (equal(classname,"dod_object") && equal(keyname,"object_owner")))
	 {
	 	new keyvalue[8];
	 	get_kvd(kvd_handle,KV_Value,keyvalue,7);
	 	set_pev(ent,SAVEFIELD_INT1,str_to_num(keyvalue));
	 }

	 if(equal(classname,"dod_capture_area"))
	 {
	 	 if(equal(keyname,"area_allies_cancap"))
	 	 {
	 	 	new keyvalue[8];
			get_kvd(kvd_handle,KV_Value,keyvalue,7);
			set_pev(ent,SAVEFIELD_INT1,str_to_num(keyvalue));
		 }
	 	 else if(equal(keyname,"area_axis_cancap"))
	 	 {
	 	 	new keyvalue[8];
			get_kvd(kvd_handle,KV_Value,keyvalue,7);
			set_pev(ent,SAVEFIELD_INT2,str_to_num(keyvalue));
	 	 }
	 	 else if(equal(keyname,"area_allies_startcap"))
	 	 {
			new keyvalue[32];
			get_kvd(kvd_handle,KV_Value,keyvalue,31);
			set_pev(ent,SAVEFIELD_STR1,keyvalue);
	 	 }
	 	 else if(equal(keyname,"area_allies_breakcap"))
	 	 {
			new keyvalue[32];
	 	 	get_kvd(kvd_handle,KV_Value,keyvalue,31);
	 	 	set_pev(ent,SAVEFIELD_STR2,keyvalue);
	 	 }
	 	 else if(equal(keyname,"area_allies_endcap"))
	 	 {
			new keyvalue[32];
	 	 	get_kvd(kvd_handle,KV_Value,keyvalue,31);
	 	 	set_pev(ent,SAVEFIELD_STR3,keyvalue);
	 	 }
	 	 else if(equal(keyname,"area_axis_startcap"))
	 	 {
			new keyvalue[32];
	 	 	get_kvd(kvd_handle,KV_Value,keyvalue,31);
	 	 	set_pev(ent,SAVEFIELD_STR4,keyvalue);
	 	 }
	 	 else if(equal(keyname,"area_axis_breakcap"))
	 	 {
			new keyvalue[32];
	 	 	get_kvd(kvd_handle,KV_Value,keyvalue,31);
	 	 	set_pev(ent,SAVEFIELD_STR5,keyvalue);
	 	 }
	 	 else if(equal(keyname,"area_axis_endcap"))
	 	 {
			new keyvalue[32];
	 	 	get_kvd(kvd_handle,KV_Value,keyvalue,31);
	 	 	set_pev(ent,SAVEFIELD_STR6,keyvalue);
	 	 }
	 }

	 return HAM_IGNORED;
}

// HHHHHHHHHHHHHHHHHHHHEEEEEEEEEEEEEEEELLO
public fw_emitsound(ent,channel,sample[],Float:volume,Float:atten,flags,pitch)
{
	if(!ggActive || !is_user_connected(ent) || !blockSounds[ent])
		return FMRES_IGNORED;

	return FMRES_SUPERCEDE;
}

/**********************************************************************
* HAM HOOKS
**********************************************************************/

// a player is touching a weaponbox or armoury_entity, possibly disallow
public ham_weapon_touch(weapon,other)
{
	// gungame off, non-player or dead-player, or allowed to pick up others
	if(!ggActive || !is_user_alive(other) || get_pcvar_num(gg_pickup_others))
		return HAM_IGNORED;

	static model[24];
	pev(weapon,pev_model,model,23);

	// strips off models/w_ and .mdl
	copyc(model,23,model[contain(model,"_")+1],'.');

	// weaponbox model is no good
	// checks for weaponbox
	if(model[8] == 'x') return HAM_IGNORED;

	// convert inconsistent names
	switch(model[0])
	{
		case 'g':
		{
			if(model[3] == 'n') model = "handgrenade"; // grenade
		}
		case 'm':
		{
			if(model[1] == 'i') model = "handgrenade"; // mills
		}
		case '9': model = "kar"; // 98k
		case 'f':
		{
			if(model[1] == 'c') model = "m1carbine"; // fcarbine
			else if(model[4] == 's') model = "scopedfg42"; // fg42s
		}
		case 'e':
		{
			if(model[7] == '_') model = "scopedenfield"; // enfield_scoped
		}
		case 's':
		{
			if(model[2] == 'i') model = "stickgrenade"; // stick
			else if(model[6] == '9') model = "scopedkar"; // scoped98k
		}
		case 't': model = "thompson"; // tommy
	}
	if(model[1] == '1') model = "m1carbine"; // m1carb

	// this is our weapon, don't mess with it
	if(equal(lvlWeapon[other],model)) return HAM_IGNORED;

	// a few more exceptions
	if(
		(equal(model,"kar") && equal(lvlWeapon[other],"bayonet"))
		|| (equal(model,"garand") && equal(lvlWeapon[other],"garandbutt"))
		|| (equal(model,"enfield") && equal(lvlWeapon[other],"enfbayonet"))
		|| (equal(model,"k43") && equal(lvlWeapon[other],"k43butt"))
	)
		return HAM_IGNORED;


	return HAM_SUPERCEDE;
}

// what do you think happened here?
public ham_player_killed(victim,killer,gib)
{
	if(!ggActive || !is_user_connected(victim)) return HAM_IGNORED;

	// don't play weapon grab sounds
	if(spawnCount && get_pcvar_num(gg_dod_spawn_random))
		blockSounds[victim] = 1; // don't play false respawn noises

	// some sort of death that we don't want to count
	if(killer == victim || !is_user_connected(killer) || get_user_team(killer) == get_user_team(victim))
	{
		hasObject[victim] = 0;
		return HAM_IGNORED;
	}

	if(!hasObject[victim]) return HAM_IGNORED;

	if(!killedObject[killer])
	{
		killedObject[killer] = 1;

		if(get_pcvar_num(gg_teamplay))
		{
			new team = get_user_team(killer), i;
			for(i=1;i<=maxPlayers;i++)
			{
				// one per team
				if(is_user_connected(i) && get_user_team(i) == team)
					killedObject[i] = 1;
			}
		}

	 	new bonus = get_pcvar_num(gg_dod_object_kill_bonus);
	 	if(!bonus) return HAM_IGNORED;

		if((!ggfw_is_nade(lvlWeapon[killer]) && !ggfw_is_melee(lvlWeapon[killer]) && level[killer] < get_weapon_num())
			|| score[killer] + bonus < get_level_goal(level[killer]))
		{
			// didn't level off of it
			if(!ggn_change_score(killer,bonus)) ggn_show_required_kills(killer);
		}
		else ggn_refill_ammo(killer);
	 }

	return HAM_IGNORED;
}

// some things are being reset, monitor for gg_dod_mapflags

public ham_control_point_reset(ent)
{
	 mflInEffect &= ~MFL_REMOVE_FLAGS & ~MFL_UNLOCK_MISCCAPAREAS;
	 if(!task_exists(TASK_DOMAPFLAGS)) set_task(0.1,"do_mapflags",TASK_DOMAPFLAGS);
}

public ham_object_reset(ent)
{
	 mflInEffect &= ~MFL_REMOVE_OBJECTS & ~MFL_UNLOCK_OBJECTS;
	 if(!task_exists(TASK_DOMAPFLAGS)) set_task(0.1,"do_mapflags",TASK_DOMAPFLAGS);
}

public ham_hurt_reset(ent)
{
	 mflInEffect &= ~MFL_REMOVE_TEAMHURTS;
	 if(!task_exists(TASK_DOMAPFLAGS)) set_task(0.1,"do_mapflags",TASK_DOMAPFLAGS);
}

public ham_button_reset(ent)
{
	 mflInEffect &= ~MFL_UNLOCK_TEAMBUTTONS;
	 if(!task_exists(TASK_DOMAPFLAGS)) set_task(0.1,"do_mapflags",TASK_DOMAPFLAGS);
}

public ham_breakable_reset(ent)
{
	 mflInEffect &= ~MFL_UNLOCK_TEAMBREAKABLES;
	 if(!task_exists(TASK_DOMAPFLAGS)) set_task(0.1,"do_mapflags",TASK_DOMAPFLAGS);
}

/**********************************************************************
* RESPAWN FUNCTIONS
**********************************************************************/

// place a user at a random spawn
do_random_spawn(id)
{
	// not even alive or no spawns
	if(!is_user_alive(id) || spawnCount <= 0)
		return;

	static Float:vecHolder[3];
	new sp_index = random_num(0,spawnCount-1);

	// get origin for comparisons
	vecHolder[0] = spawns[sp_index][0];
	vecHolder[1] = spawns[sp_index][1];
	vecHolder[2] = spawns[sp_index][2];

	// this one is taken
	if(!is_hull_vacant(vecHolder,HULL_HUMAN) && spawnCount > 1)
	{
		new i;
		for(i=sp_index+1;i!=sp_index;i++)
		{
			// start over when we reach the end
			if(i >= spawnCount) i = 0;

			vecHolder[0] = spawns[i][0];
			vecHolder[1] = spawns[i][1];
			vecHolder[2] = spawns[i][2];

			// free space! office space!
			if(is_hull_vacant(vecHolder,HULL_HUMAN))
			{
				sp_index = i;
				break;
			}
		}
	}

	// origin
	vecHolder[0] = spawns[sp_index][0];
	vecHolder[1] = spawns[sp_index][1];
	vecHolder[2] = spawns[sp_index][2];
	engfunc(EngFunc_SetOrigin,id,vecHolder);

	// angles
	vecHolder[0] = spawns[sp_index][3];
	vecHolder[1] = spawns[sp_index][4];
	vecHolder[2] = spawns[sp_index][5];
	set_pev(id,pev_angles,vecHolder);

	// vangles
	vecHolder[0] = spawns[sp_index][6];
	vecHolder[1] = spawns[sp_index][7];
	vecHolder[2] = spawns[sp_index][8];
	set_pev(id,pev_v_angle,vecHolder);

	set_pev(id,pev_fixangle,1);

	// to be fair, play a spawn noise at new location
	engfunc(EngFunc_EmitSound,id,CHAN_ITEM,"items/weaponpickup.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
}

// what do you think??
public randomly_place_everyone()
{
	// count number of legitimate players
	new player, validNum;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && ggfw_on_valid_team(player))
			validNum++;
	}

	// not enough CSDM spawns for everyone
	if(validNum > spawnCount)
		return;

	// now randomly place them
	for(player=1;player<=maxPlayers;player++)
	{
		// not spectator or unassigned
		if(is_user_connected(player) && ggfw_on_valid_team(player))
			do_random_spawn(player);
	}
}

/**********************************************************************
* MISCELLAENOUS STUFF
**********************************************************************/

// someone won!
team_won(team)
{
	new teamName[8];
	switch(team)
	{
	 	case ALLIES: teamName = "Allies";
	 	case AXIS: teamName = "Axis";
	 	default: return;
	}

	new bonus = get_pcvar_num(gg_dod_roundwin_bonus);
	if(!bonus) return;

	if(bonus > 0) ggn_gungame_print(0,0,1,"%L",/*pattern*/"issi",/*args*/LANG_PLAYER_C,"DOD_ROUNDWIN_LEVELS",teamName,bonus);

	new player, i, nextWeapon[24], absBonus = abs(bonus),
	wnum = get_weapon_num(), teamplay = get_pcvar_num(gg_teamplay);

	for(player=1;player<=maxPlayers;player++)
	{
	 	if(!is_user_connected(player) || get_user_team(player) != team)
	 		 continue;

	 	// don't skip important levels
		for(i=0;i<=absBonus;i++)
		{
			if(i >= wnum)
			{
				i++;
				break;
			}
			get_weapon_name_by_level(level[player]+i,nextWeapon,23);
			if(ggfw_is_nade(nextWeapon) || ggfw_is_melee(nextWeapon))
			{
				i++;
				break;
			}
		}

		if(i-1 > 0)
		{
			ggn_change_level(player,i-1);
			if(teamplay) break; // this will effect entire team in teamplay, so stop after the first
		}
	}
}

// manage crazy stuff from gg_dod_mapflags
public do_mapflags()
{
	 // ignore ham hooks on start of map
	 if(get_gametime() < 1.0) return;

	 new flags;

	 // GunGame disabled, reset everything
	 if(!ggActive) flags = 0;

	 // otherwise, check from cvar
	 else
	 {
	 	new mapflags[27];
	 	get_pcvar_string(gg_dod_mapflags,mapflags,26);
	 	flags = read_flags(mapflags);
	 }

	 // z:	only with CSDM spawns		MFL_ONLY_WITH_CSDM
	 if((flags & MFL_ONLY_WITH_CSDM) && !spawnCount) return;

	 new ent, sf, str[8], Float:vec1[3], Float:vec2[3];
	 static target[32], classname[18];

	 //
	 // a:	remove flags			MFL_REMOVE_FLAGS
	 //

	 if((flags & MFL_REMOVE_FLAGS) && !(mflInEffect & MFL_REMOVE_FLAGS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_control_point")))
	 	{
	 		pev(ent,pev_origin,vec1);
	 		if(vec1[0] == 4096.0 && vec1[1] == 4096.0 && vec1[2] == 4096.0) continue;
	 		set_pev(ent,SAVEFIELD_VEC1,vec1);

			engfunc(EngFunc_SetOrigin,ent,Float:{4096.0,4096.0,4096.0});
	 	}

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_capture_area")))
	 	{
	 		// is not tied to a flag, ignore
	 		pev(ent,pev_target,target,31);
	 		sf = fm_find_ent_by_tname(maxPlayers,target);
	 		if(!pev_valid(sf)) continue;
	 		pev(sf,pev_classname,classname,17);
	 		if(!equal(classname,"dod_control_point")) continue;

	 		pev(ent,pev_mins,vec1);
	 		pev(ent,pev_maxs,vec2);
	 		if(vec1[0] == 0.0 && vec2[0] == 0.0) continue;
	 		set_pev(ent,SAVEFIELD_VEC1,vec1);
	 		set_pev(ent,SAVEFIELD_VEC2,vec2);

			engfunc(EngFunc_SetSize,ent,Float:{0.0,0.0,0.0},Float:{0.0,0.0,0.0});
	 	}

	 	mflInEffect |= MFL_REMOVE_FLAGS;
	 }
	 else if(!(flags & MFL_REMOVE_FLAGS) && (mflInEffect & MFL_REMOVE_FLAGS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_control_point")))
	 	{
	 		pev(ent,SAVEFIELD_VEC1,vec1);
			engfunc(EngFunc_SetOrigin,ent,vec1);
	 	}

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_capture_area")))
	 	{
	 		pev(ent,SAVEFIELD_VEC1,vec1);
	 		pev(ent,SAVEFIELD_VEC2,vec2);
	 		if(!vec1[0] && !vec2[0]) continue; // not saved
			engfunc(EngFunc_SetSize,ent,vec1,vec2);
	 	}

	 	mflInEffect &= ~MFL_REMOVE_FLAGS;
	 }

	 //
	 // b:	remove objects			MFL_REMOVE_OBJECTS
	 //

	 if(flags & MFL_REMOVE_OBJECTS && !(mflInEffect & MFL_REMOVE_OBJECTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_object")))
	 	{
	 		set_pev(ent,pev_solid,SOLID_NOT);
	 		fm_set_entity_visibility(ent,0);
	 	}

	 	mflInEffect |= MFL_REMOVE_OBJECTS;
	 }
	 else if(!(flags & MFL_REMOVE_OBJECTS) && (mflInEffect & MFL_REMOVE_OBJECTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_object")))
	 	{
	 		set_pev(ent,pev_solid,SOLID_TRIGGER);
	 		fm_set_entity_visibility(ent,1);
	 	}

	 	mflInEffect &= ~MFL_REMOVE_OBJECTS;
	 }

	 //
	 // c:	remove spawn guns			MFL_REMOVE_SPAWNGUNS
	 //

	 if((flags & MFL_REMOVE_SPAWNGUNS) && !(mflInEffect & MFL_REMOVE_SPAWNGUNS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_tank")))
	 	{
	 		// does not belong to a team
	 		if(!pev(ent,SAVEFIELD_INT1)) continue;

	 		pev(ent,pev_origin,vec1);
	 		if(vec1[0] == 4096.0 && vec1[1] == 4096.0 && vec1[2] == 4096.0) continue;
	 		set_pev(ent,SAVEFIELD_VEC1,vec1);

			engfunc(EngFunc_SetOrigin,ent,Float:{4096.0,4096.0,4096.0});
	 	}

	 	mflInEffect |= MFL_REMOVE_SPAWNGUNS;
	 }
	 else if(!(flags & MFL_REMOVE_SPAWNGUNS) && (mflInEffect & MFL_REMOVE_SPAWNGUNS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_tank")))
	 	{
	 		// does not belong to a team
	 		if(!pev(ent,SAVEFIELD_INT1)) continue;

	 		pev(ent,SAVEFIELD_VEC1,vec1);
			engfunc(EngFunc_SetOrigin,ent,vec1);
	 	}

	 	mflInEffect &= ~MFL_REMOVE_SPAWNGUNS;
	 }

	 //
	 // d:	remove team hurts			MFL_REMOVE_TEAMHURTS
	 //

	 if((flags & MFL_REMOVE_TEAMHURTS) && !(mflInEffect & MFL_REMOVE_TEAMHURTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"trigger_hurt")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & HURT_SF_NOTALLIES) && !(sf & HURT_SF_NOTAXIS)) continue;

	 		sf |= HURT_SF_NOTALLIES | HURT_SF_NOTAXIS; // hurt no one
	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"trigger_hurt");
	 	}

	 	mflInEffect |= MFL_REMOVE_TEAMHURTS;
	 }
	 else if(!(flags & MFL_REMOVE_TEAMHURTS) && (mflInEffect & MFL_REMOVE_TEAMHURTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"trigger_hurt")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & HURT_SF_NOTALLIES) && !(sf & HURT_SF_NOTAXIS)) continue;

	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"trigger_hurt");
	 	}

	 	mflInEffect &= ~MFL_REMOVE_TEAMHURTS;
	 }

	 //
	 // e:	unlock team objects		MFL_UNLOCK_OBJECTS
	 //

	 if((flags & MFL_UNLOCK_OBJECTS) && !(mflInEffect & MFL_UNLOCK_OBJECTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_object")))
	 	{
			fm_set_kvd(ent,"object_owner","0","dod_object");
		}

		mflInEffect |= MFL_UNLOCK_OBJECTS;
	 }
	 else if(!(flags & MFL_UNLOCK_OBJECTS) && (mflInEffect & MFL_UNLOCK_OBJECTS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_object")))
	 	{
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		num_to_str(sf,str,7);
			fm_set_kvd(ent,"object_owner",str,"dod_object");
		}

		mflInEffect &= ~MFL_UNLOCK_OBJECTS;
	 }

	 //
	 // f:	unlock misc cap areas		MFL_UNLOCK_MISCCAPAREAS
	 //

	 if((flags & MFL_UNLOCK_MISCCAPAREAS) && !(mflInEffect & MFL_UNLOCK_MISCCAPAREAS))
	 {
	 	new strLong[32];

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_capture_area")))
		{
		 	// not tied to a specific team
		 	new allies = pev(ent,SAVEFIELD_INT1), axis = pev(ent,SAVEFIELD_INT2);
		 	if(allies == axis) continue;

	 		// tied to a flag, ignore
	 		pev(ent,pev_target,target,31);
	 		sf = fm_find_ent_by_tname(maxPlayers,target);
	 		if(pev_valid(sf))
	 		{
	 			pev(sf,pev_classname,classname,17);
	 			if(equal(classname,"dod_control_point")) continue;
	 		}

	 		if(allies)
	 		{
	 			pev(ent,SAVEFIELD_STR1,strLong,31);
	 			fm_set_kvd(ent,"area_axis_startcap",strLong,"dod_capture_area");

	 			pev(ent,SAVEFIELD_STR2,strLong,31);
	 			fm_set_kvd(ent,"area_axis_breakcap",strLong,"dod_capture_area");

	 			pev(ent,SAVEFIELD_STR3,strLong,31);
	 			fm_set_kvd(ent,"area_axis_endcap",strLong,"dod_capture_area");

	 			fm_set_kvd(ent,"area_axis_cancap","1","dod_capture_area");
	 		}
	 		else // axis
	 		{
	 			pev(ent,SAVEFIELD_STR4,strLong,31);
	 			fm_set_kvd(ent,"area_allies_startcap",strLong,"dod_capture_area");

	 			pev(ent,SAVEFIELD_STR5,strLong,31);
	 			fm_set_kvd(ent,"area_allies_breakcap",strLong,"dod_capture_area");

	 			pev(ent,SAVEFIELD_STR6,strLong,31);
	 			fm_set_kvd(ent,"area_allies_endcap",strLong,"dod_capture_area");

	 			fm_set_kvd(ent,"area_allies_cancap","1","dod_capture_area");
	 		}
	 	}

		mflInEffect |= MFL_UNLOCK_MISCCAPAREAS;
	 }
	 else if(!(flags & MFL_UNLOCK_MISCCAPAREAS) && (mflInEffect & MFL_UNLOCK_MISCCAPAREAS))
	 {
	 	new strLong[32];

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"dod_capture_area")))
		{
		 	// not tied to a specific team
		 	new allies = pev(ent,SAVEFIELD_INT1), axis = pev(ent,SAVEFIELD_INT2);
		 	if(allies == axis) continue;

	 		// tied to a flag, ignore
	 		pev(ent,pev_target,target,31);
	 		sf = fm_find_ent_by_tname(maxPlayers,target);
	 		if(pev_valid(sf))
	 		{
	 			pev(sf,pev_classname,classname,17);
	 			if(equal(classname,"dod_control_point")) continue;
	 		}

	 		pev(ent,SAVEFIELD_STR1,strLong,31);
	 		fm_set_kvd(ent,"area_allies_startcap",strLong,"dod_capture_area");

	 		pev(ent,SAVEFIELD_STR2,strLong,31);
	 		fm_set_kvd(ent,"area_allies_breakcap",strLong,"dod_capture_area");

	 		pev(ent,SAVEFIELD_STR3,strLong,31);
	 		fm_set_kvd(ent,"area_allies_endcap",strLong,"dod_capture_area");

			pev(ent,SAVEFIELD_STR4,strLong,31);
			fm_set_kvd(ent,"area_axis_startcap",strLong,"dod_capture_area");

			pev(ent,SAVEFIELD_STR5,strLong,31);
			fm_set_kvd(ent,"area_axis_breakcap",strLong,"dod_capture_area");

			pev(ent,SAVEFIELD_STR6,strLong,31);
			fm_set_kvd(ent,"area_axis_endcap",strLong,"dod_capture_area");

			num_to_str(allies,str,7);
			fm_set_kvd(ent,"area_allies_cancap",str,"dod_capture_area");

			num_to_str(axis,str,7);
			fm_set_kvd(ent,"area_axis_cancap",str,"dod_capture_area");
	 	}

		mflInEffect &= ~MFL_UNLOCK_MISCCAPAREAS;
	 }

	 //
	 // g:	unlock team doors			MFL_UNLOCK_TEAMDOORS
	 //

	 if((flags & MFL_UNLOCK_TEAMDOORS) && !(mflInEffect & MFL_UNLOCK_TEAMDOORS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_door")))
	 	{
	 		// does not belong to a team
	 		if(!pev(ent,SAVEFIELD_INT1)) continue;

	 		fm_set_kvd(ent,"TeamDoors","0","func_door");
	 	}

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_door_rotating")))
	 	{
	 		// does not belong to a team
	 		if(!pev(ent,SAVEFIELD_INT1)) continue;

	 		fm_set_kvd(ent,"TeamDoors","0","func_door_rotating");
	 	}

	 	mflInEffect |= MFL_UNLOCK_TEAMDOORS;
	 }
	 else if(!(flags & MFL_UNLOCK_TEAMDOORS) && (mflInEffect & MFL_UNLOCK_TEAMDOORS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_door")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!sf) continue;

	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"TeamDoors",str,"func_door");
	 	}

	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_door_rotating")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!sf) continue;

	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"TeamDoors",str,"func_door_rotating");
	 	}

	 	mflInEffect &= ~MFL_UNLOCK_TEAMDOORS;
	 }

	 //
	 // h:	unlock team buttons		MFL_UNLOCK_TEAMBUTTONS
	 //

	 if((flags & MFL_UNLOCK_TEAMBUTTONS) && !(mflInEffect & MFL_UNLOCK_TEAMBUTTONS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_button")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & BUTTON_SF_NOALLIES) && !(sf & BUTTON_SF_NOAXIS)) continue;

	 		sf &= ~BUTTON_SF_NOALLIES & ~BUTTON_SF_NOAXIS; // restrict no one
	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"func_button");
	 	}

	 	mflInEffect |= MFL_UNLOCK_TEAMBUTTONS;
	 }
	 else if(!(flags & MFL_UNLOCK_TEAMBUTTONS) && (mflInEffect & MFL_UNLOCK_TEAMBUTTONS))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_button")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & BUTTON_SF_NOALLIES) && !(sf & BUTTON_SF_NOAXIS)) continue;

	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"func_button");
	 	}

	 	mflInEffect &= ~MFL_UNLOCK_TEAMBUTTONS;
	 }

	 //
	 // i:	unlock team breakables		MFL_UNLOCK_TEAMBREAKABLES
	 //

	 if((flags & MFL_UNLOCK_TEAMBREAKABLES) && !(mflInEffect & MFL_UNLOCK_TEAMBREAKABLES))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_breakable")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & BREAKABLE_SF_ALLIESONLY) && !(sf & BREAKABLE_SF_AXISONLY)) continue;

	 		sf &= ~BREAKABLE_SF_ALLIESONLY & ~BREAKABLE_SF_AXISONLY; // restrict no one
	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"func_breakable");
	 	}

	 	mflInEffect |= MFL_UNLOCK_TEAMBREAKABLES;
	 }
	 else if(!(flags & MFL_UNLOCK_TEAMBREAKABLES) && (mflInEffect & MFL_UNLOCK_TEAMBREAKABLES))
	 {
	 	ent = maxPlayers;
	 	while((ent = fm_find_ent_by_class(ent,"func_breakable")))
	 	{
	 		// does not belong to a team
	 		sf = pev(ent,SAVEFIELD_INT1);
	 		if(!(sf & BREAKABLE_SF_ALLIESONLY) && !(sf & BREAKABLE_SF_AXISONLY)) continue;

	 		num_to_str(sf,str,7);
	 		fm_set_kvd(ent,"spawnflags",str,"func_breakable");
	 	}

	 	mflInEffect &= ~MFL_UNLOCK_TEAMBREAKABLES;
	 }
}

// update my ammox amount
public update_ammox(id)
{
	if(!lvlWeapon[id][0]) return;

	static fullName[32];
	formatex(fullName,31,"weapon_%s",lvlWeapon[id]);

	new aId = dod_get_ammo_index(fullName);
	if(aId)
	{
		new ammo = dod_get_user_ammo(id,dod_get_weaponid(fullName));

		if(ammo <= 255)
		{
			message_begin(MSG_ONE,gmsgAmmoX,_,id);
			write_byte(aId);
			write_byte(ammo);
			message_end();
		}
		else
		{
			message_begin(MSG_ONE,gmsgAmmoShort,_,id);
			write_byte(aId);
			write_short(ammo);
			message_end();
		}
	}
}

// unfreeze players after a round restart allowing them to move
public reset_players()
{
	 // fake round end
	 ggn_notify_round_end();

	 new player;
	 for(player=1;player<=maxPlayers;player++)
	 {
	 	if(!is_user_connected(player)) continue;

	 	ggn_clear_values(player,1);

	 	if(is_user_alive(player))
	 	{
	 		user_silentkill(player);
	 		dod_set_pl_deaths(player,dod_get_pl_deaths(player)-1);
	 	}
	 }

	 // fake new round
	 ggn_notify_new_round();
}

/**********************************************************************
* GUNGAME FORWARD HANDLERS
**********************************************************************/

// GunGame just turned on or off. Pay attention!
public ggfw_gungame_toggled(newStatus)
{
	ggActive = newStatus;

	// for gg_dod_mapflags
	set_task(1.0,"do_mapflags");
}

// GunGame called change_level on a player, so copy the values to our plugin.
// NOTE: this player may not actually be connected.
public ggfw_level_changed(id,newLevel,newWeapon[])
{
	level[id] = newLevel;
	formatex(lvlWeapon[id],23,"%s",newWeapon);
}

// GunGame called change_score on a player, so copy the values to our plugin.
// NOTE: this player may not actually be connected.
public ggfw_score_changed(id,newScore)
{
	score[id] = newScore;
}

// GunGame changed the warmup time left, so copy the values to our plugin.
public ggfw_warmup_changed(newValue,newWeapon[])
{
	//warmup = newValue;
	//formatex(warmupWeapon,23,"%s",newWeapon);
}

// GunGame is giving a player his weapon, so here's your chance to contribute!
// melee_only means that this player should only be using a melee weapon. so,
// it's a knife only warmup, or he leveled up with knife elite mode.
public ggfw_gave_level_weapon(id,melee_only)
{
	// possible extras for bayonet/stock levels
	if(!melee_only)
	{
		new bayonet, garandbutt, enfbayonet, k43butt, mySlot;

		if(equal(lvlWeapon[id],"bayonet"))
		{
			bayonet = 1;
			mySlot = weaponSlots[DODW_KAR];
		}
		else if(equal(lvlWeapon[id],"garandbutt"))
		{
			garandbutt = 1;
			mySlot = weaponSlots[DODW_GARAND];
		}
		else if(equal(lvlWeapon[id],"enfbayonet"))
		{
			enfbayonet = 1;
			mySlot = weaponSlots[DODW_ENFIELD];
		}
		else if(equal(lvlWeapon[id],"k43butt"))
		{
			k43butt = 1;
			mySlot = weaponSlots[DODW_K43];
		}

		if(mySlot)
		{
			new hasMain, ammo = get_pcvar_num(gg_ammo_amount);

			new weapons = pev(id,pev_weapons), wpnid, alright;

			for(wpnid=1;wpnid<32;wpnid++)
			{
				if(!(weapons & (1<<wpnid))) continue;

				alright = 0;

				// these are simple
				if((wpnid == DODW_KAR && bayonet)
				|| (wpnid == DODW_GARAND && garandbutt)
				|| (wpnid == DODW_K43 && k43butt))
				{
					alright = 1;
					hasMain = 1;
				}

				// enfield has a scoped exception
				else if(wpnid == DODW_ENFIELD && enfbayonet)
				{
					new wEnt = fm_find_ent_by_owner(maxPlayers,"weapon_enfield",id);
					if(pev_valid(wEnt) && !get_pdata_int(wEnt,WPN_SCOPED_OFFSET,WPN_LINUX_DIFF))
					{
						alright = 1;
						hasMain = 1;
					}
				}

				// it's fine
				if(alright)
				{
					if(ammo > 0) dod_set_user_ammo(id,wpnid,ammo);
					else
					{
						new maxAmmo;
						switch(wpnid)
						{
							case DODW_GARAND: maxAmmo = 88;
							case DODW_KAR: maxAmmo = 65;
							case DODW_K43: maxAmmo = 80;
							case DODW_ENFIELD: maxAmmo = 60;
						}
						dod_set_user_ammo(id,wpnid,maxAmmo);
					}
				}

				// something in our way, GET IT OUTTA HERE!
				else if(weaponSlots[wpnid] == mySlot)
				{
					static wpnName[24];
					dod_get_weaponname(wpnid,wpnName,23);
					ham_strip_weapon(id,wpnName);
				}
			}/*weapons for loop*/

			// missing our weapon which has our bayonet or stock
			if(!hasMain)
			{
				if(bayonet) ham_give_weapon(id,"weapon_kar");
				else if(garandbutt) ham_give_weapon(id,"weapon_garand");
				else if(enfbayonet) ham_give_weapon(id,"weapon_enfield");
				else if(k43butt) ham_give_weapon(id,"weapon_k43");
			}
		}/*if mySlot*/
	}/*warmup checks*/

	// stop extra grenades
	if(dod_get_user_ammo(id,DODW_HANDGRENADE) > 1) dod_set_user_ammo(id,DODW_HANDGRENADE,1);
	if(dod_get_user_ammo(id,DODW_STICKGRENADE) > 1) dod_set_user_ammo(id,DODW_STICKGRENADE,1);

	// fix dod ammo display
	update_ammox(id);
}

// GunGame is refilling this player's ammo, so is there anything that we should refill?
// wpnid is the weapon index of the particular weapon that we were trying to refill (could be 0).
public ggfw_refilled_ammo(id,wpnid)
{
	// stop extra grenades
	if(dod_get_user_ammo(id,DODW_HANDGRENADE) > 1) dod_set_user_ammo(id,DODW_HANDGRENADE,1);
	if(dod_get_user_ammo(id,DODW_STICKGRENADE) > 1) dod_set_user_ammo(id,DODW_STICKGRENADE,1);

	// fix dod ammo display
	update_ammox(id);
}

// GunGame is clearing its data for this player, so it's a good time to clear yours.
public ggfw_cleared_values(id)
{
	level[id] = 0;
	score[id] = 0;
	lvlWeapon[id][0] = 0;

	hasObject[id] = 0;
	gotObject[id] = 0;
	killedObject[id] = 0;
	blockSounds[id] = 0;
	switchOkay[id] = 0;
}

// GunGame wants to know if this player is on a team where they could actually play the game.
public ggfw_on_valid_team(id)
{
	new team = get_user_team(id);
	return (team == ALLIES || team == AXIS);
}

// GunGame wants to know if this is the weapon name of a grenade-type weapon.
// It may or may not include the weapon_ prefix.
public ggfw_is_nade(name[])
{
	new pos = contain(name,"_");
	return (equal(name[pos+1],"handgrenade") || equal(name[pos+1],"stickgrenade"));
}

// GunGame wants to know if this is the weapon name (excluding weapon_) of a melee-type weapon.
// It may or may not include the weapon_ prefix.
public ggfw_is_melee(name[])
{
	new pos = contain(name,"_") + 1;
	return (equal(name[pos],"amerknife") || equal(name[pos],"gerknife") || equal(name[pos],"spade")
		|| equal(name[pos],"bayonet") || equal(name[pos],"garandbutt") || equal(name[pos],"enfbayonet")
		|| equal(name[pos],"k43butt"));
}

// GunGame wants to know if this is the ammo type of a grenade-type weapon. How picky!
public ggfw_is_nade_ammo(ammo)
{
	 return (ammo == 9 || ammo == 11);
}

// GunGame wants to know if these players are on the same team.
public ggfw_same_team(p1,p2)
{
	 return (get_user_team(p1) == get_user_team(p2));
}

// GunGame wants to restart the round in "time" amount of seconds.
// Should return the estimated time (round up) for the restart to take effect.
// This should also clear everyone's values (GunGame is too lazy I guess).
public ggfw_restart_round(time)
{
	 client_print(0,print_center,"%L",LANG_PLAYER,"DOD_PLAYERS_RESET",time);
	 set_task(float(time),"reset_players");

	 return time;
}

// GunGame wants to know if we have any objections to rewarding this death.
// This is called before suicide and friendlyfire checks are done.
// weapon is copyback, and weaponSize is size of weapon variable.
// -1 = Don't allow killer to score, but refill his ammo.
//  0 = Don't allow killer to score.
//  1 = Allow the killer to score (potentially).
public ggfw_verify_death(killer,victim,weapon[],weaponSize)
{
	// killed self with WORLDSPAWN DUH
	if(!killer && equal(weapon,"worldspawn"))
	{
		// this is a valid team switch
		if(!roundEnded && switchOkay[victim])
			return 0; // don't let GunGame penalize the suicide

		// otherwise, let GunGame catch as suicide
		return 1;
	}

	// a secondary attack that could be relevant (all bayonets/stocks are
	// their own weapon, or I'm specifically on a bayonet/stock level)
	if(is_user_connected(killer) && (pev(killer,pev_button)&IN_ATTACK2) &&
		(get_pcvar_num(gg_dod_bayostock_steal) || equal(lvlWeapon[killer],"bayonet")
		|| equal(lvlWeapon[killer],"garandbutt") || equal(lvlWeapon[killer],"enfbayonet")
		|| equal(lvlWeapon[killer],"k43butt")))
	{
		if(equal(weapon,"kar"))
		{
			formatex(weapon,weaponSize-1,"bayonet");
			return 1;
		}
		else if(equal(weapon,"garand"))
		{
			formatex(weapon,weaponSize-1,"garandbutt");
			return 1;
		}
		else if(equal(weapon,"enfield"))
		{
			// don't count the scoped version
			new wEnt = fm_find_ent_by_owner(maxPlayers,"weapon_enfield",killer);
			if(pev_valid(wEnt) && get_pdata_int(wEnt,WPN_SCOPED_OFFSET,WPN_LINUX_DIFF))
				return 1;

			formatex(weapon,weaponSize-1,"enfbayonet");
			return 1;
		}
		else if(equal(weapon,"k43"))
		{
			formatex(weapon,weaponSize-1,"k43butt");
			return 1;
		}
	}

	new inflictor = pev(victim,pev_dmg_inflictor);
	if(pev_valid(inflictor))
	{
		// grenade -> handgrenade, grenade2 -> stickgrenade
		if(equal(weapon,"grenade",7))
		{
			switch(weapon[7])
			{
				case '2': formatex(weapon,weaponSize-1,"stickgrenade");
				default: formatex(weapon,weaponSize-1,"handgrenade");
			}
		}

		// shell_bazooka -> bazooka, shell_piat -> piat, shell_pschreck -> pschreck
		else if(equal(weapon,"shell",5)) format(weapon,weaponSize-1,"%s",weapon[6]);

		// if appropiate... fg42 -> scopedfg42, enfield -> scopedenfield
		else
		{
			new wEnt;

			if(equal(weapon,"fg42")) wEnt = fm_find_ent_by_owner(maxPlayers,"weapon_fg42",killer);
			else if(equal(weapon,"enfield")) wEnt = fm_find_ent_by_owner(maxPlayers,"weapon_enfield",killer);

			if(!pev_valid(wEnt)) return 1;

			if(get_pdata_int(wEnt,WPN_SCOPED_OFFSET,WPN_LINUX_DIFF))
				format(weapon,weaponSize-1,"scoped%s",weapon);
		}
	}

	return 1;
}

// GunGame needs to get some information about the weapons in your mod.
// This should only be called for mods that aren't cstrike, czero, or dod.
public ggfw_request_weapon_info(maxClip[36],maxAmmo[36],weaponSlots[36])
{
	 // dummy
}

// GunGame wants to change a player's backpack ammo.
// This should only be called for mods that aren't cstrike, czero, or dod.
public ggfw_set_user_bpammo(id,weapon,ammo)
{
	 // dummy
}

// GunGame wants to change a weapon's clip ammo.
// This should only be called for mods that aren't cstrike, czero, or dod.
public ggfw_set_weapon_ammo(weapon,ammo)
{
	 // dummy
}

/**********************************************************************
* SUPPORT FUNCTIONS
**********************************************************************/

// gets the goal for a level, taking into account default and custom values
stock get_level_goal(level)
{
	get_pcvar_string(gg_weapon_order,weaponOrder,415);

	new comma = str_find_num(weaponOrder,',',level-1)+1;

	static crop[32];
	copyc(crop,31,weaponOrder[comma],',');

	new colon = contain(crop,":");

	// no custom goal
	if(colon == -1)
	{
		if(ggfw_is_nade(crop) || ggfw_is_melee(crop))
			return 1;
		else
			return get_pcvar_num(gg_kills_per_lvl);
	}

	static goal[4];
	copyc(goal,3,crop[colon+1],',');

	return str_to_num(goal);
}

// get the name of a weapon by level
stock get_weapon_name_by_level(theLevel,var[],varLen,includeGoal=0)
{
	// invalid level
	if(theLevel <= 0 || theLevel > 32 || theLevel > get_weapon_num())
	{
		// return first level
		get_pcvar_string(gg_weapon_order,weaponOrder,415);
		copyc(var,varLen,weaponOrder,',');

		return;
	}

	static weapons[32][24];
	get_weapon_order(weapons);

	if(!includeGoal && contain(weapons[theLevel-1],":")) // strip off goal if we don't want it
		copyc(var,varLen,weapons[theLevel-1],':');

	else
		formatex(var,varLen,"%s",weapons[theLevel-1]);

	strtolower(var);
}

// get the weapons, in order
stock get_weapon_order(weapons[32][24])
{
	get_pcvar_string(gg_weapon_order,weaponOrder,415);

	new i;
	for(i=0;i<32;i++)
	{
		// out of stuff
		if(strlen(weaponOrder) <= 1) break;

		// we still have a comma, go up to it
		if(contain(weaponOrder,",") != -1)
		{
			strtok(weaponOrder,weapons[i],23,weaponOrder,415,',');
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
	get_pcvar_string(gg_weapon_order,weaponOrder,415);
	return str_count(weaponOrder,',') + 1;
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

// gives a player a weapon efficiently
stock ham_give_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;

	new scoped;
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

	new wId = dod_get_weaponid(weapon);
	if(!wId) return 0;

	new wEnt = fm_find_ent_by_owner(maxPlayers,weapon,id);
	if(!wEnt) return 0;

	new dummy, weapon = get_user_weapon(id,dummy,dummy);
	if(weapon == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);

	if(!ExecuteHamB(Ham_RemovePlayerItem,id,any:wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill,wEnt);

	set_pev(id,pev_weapons,pev(id,pev_weapons) & ~(1<<wId));

	// DOD
	if(wId == DODW_HANDGRENADE || wId == DODW_STICKGRENADE || wId == DODW_MILLS_BOMB)
		dod_set_user_ammo(id,wId,0);

	return 1;
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

// gets a player id that triggered certain logevents, by VEN
stock get_loguser_index()
{
	static loguser[80], name[32];
	read_logargv(0,loguser,79);
	parse_loguser(loguser,name,31);

	return get_user_index(name);
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

// gets a weapon's ammo index
stock dod_get_ammo_index(weapon[])
{
	 if(equal(weapon,"weapon_thompson") || equal(weapon,"weapon_greasegun")
	 || equal(weapon,"weapon_sten") || equal(weapon,"weapon_mp40"))
	 	 return AMMO_SMG;

	 if(equal(weapon,"weapon_m1carbine") || equal(weapon,"weapon_k43")
	 || equal(weapon,"weapon_mg34"))
	 	 return AMMO_ALTRIFLE;

	 if(equal(weapon,"weapon_garand") || equal(weapon,"weapon_enfield")
	 || equal(weapon,"weapon_scopedenfield") || equal(weapon,"weapon_kar")
	 || equal(weapon,"weapon_scopedkar"))
	 	 return AMMO_RIFLE;

	 if(equal(weapon,"weapon_colt") || equal(weapon,"weapon_webley")
	 || equal(weapon,"weapon_luger"))
	 	 return AMMO_PISTOL;

	 if(equal(weapon,"weapon_spring"))
	 	 return AMMO_SPRING;

	 if(equal(weapon,"weapon_bar") || equal(weapon,"weapon_bren")
	 || equal(weapon,"weapon_mp44") || equal(weapon,"weapon_fg42")
	 || equal(weapon,"weapon_scopedfg42"))
	 	 return AMMO_HEAVY;

	 if(equal(weapon,"weapon_mg42"))
	 	 return AMMO_MG42;

	 if(equal(weapon,"weapon_30cal"))
	 	 return AMMO_30CAL;

	 if(equal(weapon,"weapon_handgrenade"))
	 	 return AMMO_HANDNADE;

	 if(equal(weapon,"weapon_stickgrenade"))
	 	 return AMMO_STICKNADE;

	 if(equal(weapon,"weapon_bazooka") || equal(weapon,"weapon_pschreck")
	 || equal(weapon,"weapon_piat"))
	 	 return AMMO_ROCKET;

	 return 0;
}

// sets clip ammo, offset thanks to Wilson [29th ID]
stock dod_set_weapon_ammo(index,newammo)
{
	return set_pdata_int(index,108,newammo,WPN_LINUX_DIFF);
}

// get a list of which weapons go in which slots
stock calculate_weapon_slots()
{
	new i, ent, wname[32];
	for(i=1;i<32;i++)
	{
		dod_get_weaponname(i,wname,31);
		if(!wname[0]) continue;

		ent = fm_create_entity(wname);
		if(!pev_valid(ent)) continue;

		set_pev(ent,pev_spawnflags,SF_NORESPAWN);
		weaponSlots[i] = ExecuteHam(Ham_Item_ItemSlot,ent);
		fm_remove_entity(ent);
	}
}