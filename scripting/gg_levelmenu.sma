/* GunGame Menu


*/
#include <amxmodx>
#include <amxmisc>
#include <gungame>

new g_menuPosition[33]
new g_coloredMenus = 1
new g_menuPlayers[33][32]
new g_menuPlayersNum[33]
new g_targetid[33]
new g_force_levels[4] = {1,2,3,4}

new cvar_gg_force_levels

public plugin_init()
{
	register_plugin("GunGame Menu", "1.3", "Fysiks")

	register_dictionary("common.txt")

	register_clcmd("gg_levelmenu","cmdLevelMenu", ADMIN_SLAY, "- displays a GunGame Level Menu")
	register_clcmd("gg_levelmenu_1","cmdLevelMenuOne", ADMIN_SLAY, "<name> - Menu to change <name>'s level.")
	register_menucmd(register_menuid("All Level Menu"), 1023, "actionAllPlayerLvlMenu")
	register_menucmd(register_menuid("Individual Level Menu"), 1023, "actionIndivLvlMenu")

	cvar_gg_force_levels = register_cvar("gg_menu_levels","1,10,20,26")		// "Jump-to" levels in individual player level menu (max 4)
}

public plugin_cfg()
{
	new tempstring[20]
	new num[8],leftover[20]
	get_pcvar_string(cvar_gg_force_levels, tempstring, 19)
	replace_all(tempstring,19," ","")
	for(new i=0; i<4; i++)
	{
		trim(tempstring)
		strtok(tempstring,num,7,leftover,19,',',1)
		// server_print("--|%s|--|%s|--|%s|--",tempstring,num,leftover)
		if(is_str_num(num))
			g_force_levels[i] = str_to_num(num)
		else
			g_force_levels[i] = 1
		tempstring = leftover
	}
}

public cmdLevelMenu(id, level, cid)
{ // plmenu.sma 370
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	displayAllPlMenu(id, g_menuPosition[id] = 0)
	return PLUGIN_HANDLED
}

public cmdLevelMenuOne(id,level,cid)
{
	if(!cmd_access(id,level,cid,2))
		return PLUGIN_HANDLED

	new arg[32]
	read_argv(1, arg, 31)
	new player = cmd_target(id, arg, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF)

	if (!player)
		return PLUGIN_HANDLED

	g_targetid[id] = player
	g_menuPosition[id] = 0 // Set menu position for when you "go back" to the all players menu
	show_IndivLvlMenu(id)

	return PLUGIN_HANDLED
}

displayAllPlMenu(id, pos)
{ // plmenu.sma 308

	if (pos < 0)
		return

	get_players(g_menuPlayers[id],g_menuPlayersNum[id])

	new menuBody[512]
	new b = 0
	new i
	new name[32]
	new level
	new start = pos * 7

	if (start >= g_menuPlayersNum[id])
		start = pos = g_menuPosition[id] = 0

	new len = format(menuBody, 511, g_coloredMenus ? "\yGG +/- Level Menu\R%d/%d^n\w^n" : "GG +/- Level Menu %d/%d^n^n", pos + 1, (g_menuPlayersNum[id] / 7 + ((g_menuPlayersNum[id] % 7) ? 1 : 0 )))

	new end = start + 7
	new keys = MENU_KEY_0|MENU_KEY_8

	if (end > g_menuPlayersNum[id])
		end = g_menuPlayersNum[id]

	for (new a = start; a < end; ++a) {
		i = g_menuPlayers[id][a]
		get_user_name(i,name,31)
		level = ggn_get_level(i)
		if ( access(i, ADMIN_IMMUNITY) && i != id )  // This is essentially CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF
		{
			++b

			if (g_coloredMenus)
				len += format(menuBody[len], 511-len, "\d%d. %s \R%d^n\w", b, name, level)
			else
				len += format(menuBody[len], 511-len, "#. %s  %d^n", name, level)
		} else {
			keys |= (1<<b)

			if (is_user_admin(i))
				len += format(menuBody[len], 511-len, g_coloredMenus ? "%d. %s \r*\w\R%d^n\w" : "%d. %s *^n", ++b, name, level)
			else
				len += format(menuBody[len], 511-len, g_coloredMenus ? "%d. %s\R%d^n\w" : "%d. %s^n", ++b, name, level)
		}
	}

	if (end != g_menuPlayersNum[id]) {
		format(menuBody[len], 511-len, "^n9. %L...^n0. %L", id, "MORE", id, pos ? "BACK" : "EXIT")
		keys |= MENU_KEY_9
	}
	else
		format(menuBody[len], 511-len, "^n0. %L", id, pos ? "BACK" : "EXIT")

	show_menu(id, keys, menuBody, -1, "All Level Menu")
}

public actionAllPlayerLvlMenu(id, key)
{ // plmenu.sma 247
	switch(key)
	{
		case 8: displayAllPlMenu(id,++g_menuPosition[id])
		case 9: displayAllPlMenu(id,--g_menuPosition[id])
		default:
		{
			g_targetid[id] = g_menuPlayers[id][g_menuPosition[id] * 7 + key]
			show_IndivLvlMenu(id)
		}
	}
}

show_IndivLvlMenu(id)
{
	new menuBody[512]
	new name[32]
	new level
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_9|MENU_KEY_0

	get_user_name(g_targetid[id],name,31)
	level = ggn_get_level(g_targetid[id])

	new len = format(menuBody, 511, g_coloredMenus ? "\yChange Level for: %s (%d)^n\w^n" : "Change Level for: %s^n^n",name, level)

	len += format(menuBody[len], 511-len, g_coloredMenus ? "1. Level Up^n\w" : "1. Level Up^n")
	len += format(menuBody[len], 511-len, g_coloredMenus ? "2. Level Down^n\w" : "2. Level Down^n")
	len += format(menuBody[len], 511-len, g_coloredMenus ? "3. Level %d^n\w" : "3. Level %d^n", g_force_levels[0])
	len += format(menuBody[len], 511-len, g_coloredMenus ? "4. Level %d^n\w" : "4. Level %d^n", g_force_levels[1])
	len += format(menuBody[len], 511-len, g_coloredMenus ? "5. Level %d^n\w" : "5. Level %d^n", g_force_levels[2])
	len += format(menuBody[len], 511-len, g_coloredMenus ? "6. Level %d^n\w" : "6. Level %d^n", g_force_levels[3])
	len += format(menuBody[len], 511-len, "^n9. %L^n0. %L", id, "BACK", id, "EXIT")

	// MENU_KEY_1 => up
	// MENU_KEY_2 => down
	// MENU_KEY_9 => back
	// MENU_KEY_0 => exit

	show_menu(id, keys, menuBody, -1, "Individual Level Menu")
}

public actionIndivLvlMenu(id, key)
{
	// new userid = get_user_userid(g_targetid[id])
	new level = ggn_get_level(g_targetid[id])

	switch(key) {
		case 9: return
		case 8: displayAllPlMenu(id, g_menuPosition[id])
		case 0:
		{
			ggn_change_level(g_targetid[id],1,_,_,0)
			show_IndivLvlMenu(id)
		}
		case 1:
		{
			ggn_change_level(g_targetid[id],-1,_,_,0)
			show_IndivLvlMenu(id)
		}
		case 2,3,4,5:
		{
			ggn_change_level(g_targetid[id],g_force_levels[key-2]-level,_,_,0)
			show_IndivLvlMenu(id)
		}
		default:
		{
			client_print(id, print_chat, "Something didn't work!")
			return
		}
	}
}
