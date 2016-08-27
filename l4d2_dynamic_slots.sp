#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>

public Plugin:myinfo =
{
	name = "[L4D2] Dynamic Slots",
	author = "Антиквар",
	description = "Set slots and tanks health on players count.",
	version = PLUGIN_VERSION,
	url = "zo-zo.org"
}

#define L4D_TEAM_SURVIVORS 2
#define L4D_TEAM_INFECTED 3
#define L4D_ZOMBIE_TANK 8

#define TANK_HEALTH_DEFAULT 8000 // от 0 до 14 игроков
#define TANK_HEALTH_MIDDLE 10000 // от 14 до 20 игроков
#define TANK_HEALTH_MAX 15000 // от 20 и более игроков

#define CVAR_TANK_HEALTH "z_tank_health"
#define CVAR_SURVIVOR_LIMIT "survivor_limit"
#define CVAR_INFECTED_LIMIT "z_max_player_zombies"
#define CVAR_SUPERVERSUS_SURVIVOR_LIMIT "l4d_survivor_limit"
#define CVAR_SUPERVERSUS_INFECTED_LIMIT "l4d_infected_limit"

static Handle:g_hTankHealth;
static Handle:g_hSurvivorLimit;
static Handle:g_hInfectedLimit;
static Handle:g_hSuperVersusSurvivorLimit;
static Handle:g_hSuperVersusInfectedLimit;

static bool:g_bSuperVersusReady;
static bool:g_bEnableTeamPlacement;

static g_iTeamMax;
static g_iSurvivorsMax;
static g_iInfectedMax;
static g_iTankHealth;

public OnPluginStart()
{
	CreateConVar(
		"l4d2_dynamic_slots_version", PLUGIN_VERSION,
		"Dynamic Slots plugin version", FCVAR_PLUGIN | FCVAR_SPONLY  | FCVAR_NOTIFY | FCVAR_DONTRECORD
	);

	g_hTankHealth = FindConVar( CVAR_TANK_HEALTH );
	g_hSurvivorLimit = FindConVar( CVAR_SURVIVOR_LIMIT );
	g_hInfectedLimit = FindConVar( CVAR_INFECTED_LIMIT );

	SetConVarBounds( g_hSurvivorLimit, ConVarBound_Upper, true, 32.0 );
	SetConVarBounds( g_hInfectedLimit, ConVarBound_Upper, true, 32.0 );

	HookEvent( "tank_spawn", Event_TankSpawn );
	HookEvent( "player_disconnect", Event_PlayerDisconnect );
}

public OnAllPluginsLoaded()
{
	g_hSuperVersusSurvivorLimit = FindConVar( CVAR_SUPERVERSUS_SURVIVOR_LIMIT );
	g_hSuperVersusInfectedLimit = FindConVar( CVAR_SUPERVERSUS_INFECTED_LIMIT );

	if(
		g_hSuperVersusSurvivorLimit != INVALID_HANDLE &&
		g_hSuperVersusInfectedLimit != INVALID_HANDLE
	)
	{
		g_bSuperVersusReady = true;
		SetConVarBounds( g_hSuperVersusSurvivorLimit, ConVarBound_Upper, true, 32.0 );
		SetConVarBounds( g_hSuperVersusInfectedLimit, ConVarBound_Upper, true, 32.0 );
	}

	ExecuteUpdate();
}

public OnPluginEnd()
{
	if( g_bSuperVersusReady )
	{
		ResetConVar( g_hSuperVersusSurvivorLimit );
		ResetConVar( g_hSuperVersusInfectedLimit );
	}

	ResetConVar( g_hSurvivorLimit );
	ResetConVar( g_hInfectedLimit );
}

public OnMapEnd()
{
	g_bEnableTeamPlacement = false;
}

public OnMapStart()
{
	CreateTimer( 120.0, Timer_EnableTeamPlacement, _, TIMER_FLAG_NO_MAPCHANGE );
}

public Action:Timer_EnableTeamPlacement( Handle:timer, any:client )
{
	g_bEnableTeamPlacement = true;
}

public OnClientConnected( client )
{
	if( !IsFakeClient( client ) )
	{
		CreateTimer( 0.5, Timer_ExecuteUpdate );
	}
}

public OnClientPostAdminCheck( client )
{
	if( !g_bEnableTeamPlacement ) return;
	if( IsFakeClient( client ) ) return;

	ChooseTeam( client );
}

ChooseTeam( client )
{
	new team = GetClientTeam( client );

	if( g_iSurvivorsMax <= g_iInfectedMax )
	{
		if( team == L4D_TEAM_SURVIVORS ) return;
		ChangeClientTeam( client, L4D_TEAM_SURVIVORS );
	}
	else
	{
		if( team == L4D_TEAM_INFECTED ) return;
		ChangeClientTeam( client, L4D_TEAM_INFECTED );
	}
}

public Action:Event_PlayerDisconnect( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if( client > 0 && IsClientInGame( client ) && !IsFakeClient( client ) )
	{
		CreateTimer( 1.0, Timer_ExecuteUpdate );
	}
}

public Action:Timer_ExecuteUpdate( Handle:timer )
{
	ExecuteUpdate();
}

public Action:Event_TankSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );

	if( client > 0 && IsClientInGame( client ) )
	{
		if( GetEntProp( client, Prop_Send, "m_iHealth" ) != g_iTankHealth )
		{
			CreateTimer( 0.3, Timer_SetTankHealth, client );
		}
	}
}

public Action:Timer_SetTankHealth( Handle:timer, any:client )
{
	if( IsClientInGame( client ) && IsPlayerTank( client ) )
	{
		SetEntProp( client, Prop_Send, "m_iHealth", g_iTankHealth );
	}
}

ExecuteUpdate()
{
	UpdatePlayersCount();
	UpdateTanksHealth();
	SetSlotsAmount();
}

UpdatePlayersCount()
{
	new iTotal, iTeamHalf;
	g_iTeamMax = g_iSurvivorsMax = g_iInfectedMax = 0;

	for( new team, i = 1; i <= MaxClients; i++ )
	{
		if( IsClientConnected( i ) && !IsFakeClient( i ) )
		{
			iTotal++;

			if( IsClientInGame( i ) )
			{
				team = GetClientTeam( i );
				if( team == L4D_TEAM_SURVIVORS ) g_iSurvivorsMax++;
				else if( team == L4D_TEAM_INFECTED ) g_iInfectedMax++;
			}
		}
	}

	iTeamHalf = RoundToCeil( float( iTotal ) / 2 );
	g_iTeamMax = g_iSurvivorsMax > g_iInfectedMax ? g_iSurvivorsMax : g_iInfectedMax;
	g_iTeamMax = g_iTeamMax > iTeamHalf ? g_iTeamMax : iTeamHalf;
	g_iTeamMax = g_iTeamMax < 4 ? 4 : g_iTeamMax;

	PrintToServer(
		"[DynSlots] UpdatePlayersCount > Total: %d, Half: %d, Surv: %d, Inf: %d, TeamMax: %d",
		iTotal, iTeamHalf, g_iSurvivorsMax, g_iInfectedMax, g_iTeamMax
	);
}

UpdateTanksHealth()
{
	if( g_iTeamMax >= 10 )
	{
		g_iTankHealth = TANK_HEALTH_MAX;
	}
	else if( g_iTeamMax >= 7 )
	{
		g_iTankHealth = TANK_HEALTH_MIDDLE;
	}
	else
	{
		g_iTankHealth = TANK_HEALTH_DEFAULT;
	}

	new iCvarHealth = RoundToCeil( float( g_iTankHealth ) / 1.5 );
	SetConVarInt( g_hTankHealth, iCvarHealth );

	PrintToServer(
		"[DynSlots] UpdateTanksHealth > Real Health: %d, Cvar Health: %d",
		g_iTankHealth, iCvarHealth
	);
}

SetSlotsAmount()
{
	if( g_bSuperVersusReady )
	{
		SetConVarInt( g_hSuperVersusSurvivorLimit, g_iTeamMax );
		SetConVarInt( g_hSuperVersusInfectedLimit, g_iTeamMax );
	}

	SetConVarInt( g_hSurvivorLimit, g_iTeamMax );
	SetConVarInt( g_hInfectedLimit, g_iTeamMax );
}

bool:IsPlayerTank( client )
{
	return (
		GetClientTeam( client ) == L4D_TEAM_INFECTED &&
		GetEntProp( client, Prop_Send, "m_zombieClass" ) == L4D_ZOMBIE_TANK
	);
}
