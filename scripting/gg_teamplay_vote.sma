#include <amxmodx>
#include <amxmisc>

new gVoteMenu;
new gVotes[2];
new gVoting;

public plugin_init()
{
	register_plugin("GG TeamPlay Vote", "0.1", "Fysiks");
	register_concmd("amx_gungame_teamplay_vote", "cmdTeamPlayVote", ADMIN_MAP);
}

public cmdTeamPlayVote(id, level, cid)
{
	if( !cmd_access(id, level, cid, 1) )
	{
		return PLUGIN_HANDLED;
	}

	if( gVoting )
	{
		client_print(id, print_chat, "Vote is currently running.");
		return PLUGIN_HANDLED;
	}

	gVotes[0] = gVotes[1] = 0;

	gVoteMenu = menu_create("TeamPlay Vote", "menuTeamPlayVote");

	menu_additem(gVoteMenu, "Team Play", "", 0);
	menu_additem(gVoteMenu, "Individual Play", "", 0);

	new players[32], pnum, tempid;

	get_players(players, pnum);

	for( new i; i < pnum; i++ )
	{
		tempid = players[i];
		menu_display(tempid, gVoteMenu, 0);
		gVoting++;
	}

	set_task(10.0, "EndVote");

	return PLUGIN_HANDLED;
}
public menuTeamPlayVote(id, menu, item)
{
	if( item == MENU_EXIT || !gVoting )
	{
		return PLUGIN_HANDLED;
	}

	gVotes[item]++;

	return PLUGIN_HANDLED;
}

public EndVote()
{
	if( gVotes[0] > gVotes[1] )
	{
		client_print(0, print_chat, "Team play has been chosen.");
		server_cmd("amx_gungame_teamplay 1");
	}
	else if( gVotes[0] < gVotes[1] )
	{
		client_print(0, print_chat, "Individual play has been chosen.");
		server_cmd("amx_gungame_teamplay 0");
	}
	else
	{
		client_print(0, print_chat, "The vote was tied, individual play is default.");
		server_cmd("amx_gungame_teamplay 0");
	}

	menu_destroy(gVoteMenu);

	gVoting = 0;
}
