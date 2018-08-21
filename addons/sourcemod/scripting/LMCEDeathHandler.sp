#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define REQUIRE_PLUGIN
#include <LMCCore>
#undef REQUIRE_PLUGIN

#pragma newdecls required


#define PLUGIN_NAME "LMCEDeathHandler"
#define PLUGIN_VERSION "1.0"


static bool bL4D2 = false;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion == Engine_Left4Dead2)
		bL4D2 = true;
	else if(iEngineVersion == Engine_Left4Dead)
		bL4D2 = false;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1/2");
		return APLRes_SilentFailure;
	}
	RegPluginLibrary("LMCEDeathHandler");
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Lux",
	description = "Manages deaths regarding lmc for entities ragdolls, module required to handle (witch & common deaths)",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};

public void OnPluginStart()
{
	CreateConVar("lmcedeathhandler_version", PLUGIN_VERSION, "LMCL4D2EDeathHandler_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
}

public void OnAllPluginsLoaded()// makesure my hook is last if it can
{
	HookEvent("player_death", ePlayerDeath);
	HookEvent("witch_killed", eWitchKilled);
}


public void ePlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iVictim = GetEventInt(hEvent, "entityid");
	if(iVictim < MaxClients+1 || iVictim > 2048 || !IsValidEntity(iVictim))
		return;
	
	char sNetclass[7];
	GetEntityNetClass(iVictim, sNetclass, 7);
	if(StrEqual(sNetclass, "Witch", false))// called before witch death event
		return;
	
	int iEntity = LMC_GetEntityOverlayModel(iVictim);
	if(iEntity < 1)
		return;
	
	NextBotRagdollHandler(iVictim, iEntity);

}

public void eWitchKilled(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iWitch = GetEventInt(hEvent, "witchid");
	if(iWitch < MaxClients+1 || iWitch > 2048 || !IsValidEntity(iWitch))
		return;
	
	int iEntity = LMC_GetEntityOverlayModel(iWitch);
	if(iEntity < 1)
		return;
	
	NextBotRagdollHandler(iWitch, iEntity);
}

void NextBotRagdollHandler(int iEntity, int iPreRagdoll)
{
	if(bL4D2)
	{
		SetEntProp(iPreRagdoll, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(iPreRagdoll, Prop_Send, "m_iGlowType", 0);
		SetEntProp(iPreRagdoll, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(iPreRagdoll, Prop_Send, "m_nGlowRangeMin", 0);
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 999.0);// failsafe incase BecomeRagdoll is invoked on the entity L4d1 does not have this tho
	}
	
	SetEntityRenderFx(iEntity, RENDERFX_HOLOGRAM);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);
	
	AcceptEntityInput(iPreRagdoll, "BecomeRagdoll");
}

