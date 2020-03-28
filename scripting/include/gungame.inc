
#if defined _gungame_included
	#endinput
#endif
#define _gungame_included

#pragma reqlib "gungame"

// use this to get a player's level (Only valid on 2.00B4 and greater)
native ggn_get_level(id);

// use this to get the amount of warmup time left ("warmup" var from gungame_base.amxx)
native ggn_get_warmup_time();

// use this to see if a round is over according to GunGame ("roundEnded" var from gungame_base.amxx)
native ggn_is_round_over();

// use this to change a player's score. it calls change_score in gungame_base.amxx
native ggn_change_score(id,value,refill=1,effect_team=1);

// use this to change a player's level. it calls change_level in gungame_base.amxx
native ggn_change_level(id,value,/*just_joined=0,*/show_message=1,always_score=0,play_sounds=1,effect_team=1);

// use this to give a player his level's weapon. it calls give_level_weapon from gungame_base.amxx
native ggn_give_level_weapon(id,notify=1);

// use this to refill a player's ammo. it calls refill_ammo from gungame_base.amxx
native ggn_refill_ammo(id);

// use this to tell GunGame that this player has killed himself. it calls player_suicided from gungame_base.amxx
native ggn_player_suicided(id);

// use this to clear all of a player's values. it calls clear_values from gungame_base.amxx
native ggn_clear_values(id,ignoreWelcome=0);

// use this to print a GunGame-formatted messsage to a player.
// pattern should be a character list of the variables types you use as extra arguments.
// example: ggn_gungame_print(id,0,1,"INT: %i, FLOAT: %f, STR: %s","ifs",22,22.0,"22");
native ggn_gungame_print(id,custom,tag,msg[],pattern[]="",{Float,Sql,Result,_}:...);

// use this to print a GunGame-style HUD message to a player.
// pattern should be a character list of the variables types you use as extra arguments.
// example: ggn_gungame_hudmessage(id,5.0,"INT: %i, FLOAT: %f, STR: %s","ifs",22,22.0,"22");
native ggn_gungame_hudmessage(id,Float:holdTime,msg[],pattern[]="",{Float,Sql,Result,_}:...);

// use this to show a player his required kills. it calls show_required_kills from gungame_base.amxx
native ggn_show_required_kills(id);

// use this to notify GunGame that the initial game has commenced.
// *** necessary to call at least once a map, and preferably no more ***
native ggn_notify_game_commenced();

// use this to notify GunGame that a new round has begun.
native ggn_notify_new_round();

// use this to notify GunGame that a round has ended.
native ggn_notify_round_end();

// use this to notify GunGame that a player has spawned.
// *** necessary to call every time, GunGame doesn't know otherwise ***
native ggn_notify_player_spawn(id,skipDelay=0);

// tell GunGame that a player switched teams. important for teamplay mode.
native ggn_notify_player_teamchange(id,newTeam);
