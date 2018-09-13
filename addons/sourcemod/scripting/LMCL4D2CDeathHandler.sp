#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define REQUIRE_PLUGIN
#include <LMCCore>
#include <LMCL4D2SetTransmit>
#undef REQUIRE_PLUGIN

#pragma newdecls required


#define PLUGIN_NAME "LMCL4D2CDeathHandler"
#define PLUGIN_VERSION "1.1.1"



static int iDeathModelRef = INVALID_ENT_REFERENCE;
static bool bIgnore = false;

Handle g_hOnClientDeathModelCreated = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("LMCL4D2CDeathHandler");
	g_hOnClientDeathModelCreated  = CreateGlobalForward("LMC_OnClientDeathModelCreated", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Lux",
	description = "Manages deaths regarding lmc, overlay deathmodels and ragdolls, and fixes clonesurvivors deathmodels teleporting around.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};


public void OnPluginStart()
{
	CreateConVar("lmcl4d2cdeathhandler_version", PLUGIN_VERSION, "LMCL4D2CDeathHandler_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	HookEvent("player_death", ePlayerDeath);
}

public void ePlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iVictim < 1 || iVictim > MaxClients || !IsClientInGame(iVictim))
		return;
	
	int iTeam = GetClientTeam(iVictim);
	int iEntity = LMC_GetClientOverlayModel(iVictim);
	
	if(iTeam == 3 && IsValidEntity(iEntity))
	{
		LMC_L4D2_SetTransmit(iVictim, iEntity, false);
		AcceptEntityInput(iEntity, "ClearParent");
		SetEntProp(iEntity, Prop_Send, "m_bClientSideRagdoll", 1, 1);
		SetVariantString("OnUser1 !self:Kill::0.1:1");
		AcceptEntityInput(iEntity, "AddOutput");
		AcceptEntityInput(iEntity, "FireUser1");
		return;
	}
	
	if(iTeam == 2 && IsValidEntRef(iDeathModelRef))
	{
		float fPos[3];
		GetClientAbsOrigin(iVictim, fPos);
		int iEnt = EntRefToEntIndex(iDeathModelRef);
		iDeathModelRef = INVALID_ENT_REFERENCE;
		TeleportEntity(iEnt, fPos, NULL_VECTOR, NULL_VECTOR);// fix valve issue with teleporting clones
		
		Call_StartForward(g_hOnClientDeathModelCreated);
		Call_PushCell(iVictim);
		Call_PushCell(iEnt);
		
		if(iEntity > MaxClients && IsValidEntity(iEntity))
		{
			char sModel[PLATFORM_MAX_PATH];
			GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
			AcceptEntityInput(iEntity, "Kill");
			
			if(sModel[0] == '\0')
			{
				Call_PushCell(-1);
				Call_Finish();
				return;
			}
				
			iEntity = LMC_SetEntityOverlayModel(iEnt, sModel);
			SetEntityRenderMode(iEnt, RENDER_NONE);
			SetEntProp(iEnt, Prop_Send, "m_nMinGPULevel", 1);
			SetEntProp(iEnt, Prop_Send, "m_nMaxGPULevel", 1);
			
			Call_PushCell(iEntity);
			Call_Finish();
			return;
		}
		Call_PushCell(-1);
		Call_Finish();
		return;
	}
	
	if(!IsValidEntity(iEntity))
		return;
	
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 0);
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 0);
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 0);
	
	LMC_L4D2_SetTransmit(iVictim, iEntity, false);
	
	AcceptEntityInput(iEntity, "ClearParent");
	SetEntProp(iEntity, Prop_Send, "m_bClientSideRagdoll", 1, 1);
	SetVariantString("OnUser1 !self:Kill::0.1:1");
	AcceptEntityInput(iEntity, "AddOutput");
	AcceptEntityInput(iEntity, "FireUser1");
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(sClassname[0] != 's' || !StrEqual(sClassname, "survivor_death_model", false))
		return;
	
	SDKHook(iEntity, SDKHook_SpawnPost, SpawnPost);
}

public void SpawnPost(int iEntity)
{
	SDKUnhook(iEntity, SDKHook_SpawnPost, SpawnPost);
	if(!IsValidEntity(iEntity))
		return;
	
	iDeathModelRef = EntIndexToEntRef(iEntity);
	
	if(bIgnore)
		return;
	
	bIgnore = true;
	RequestFrame(ClearVar);
}

public void ClearVar(any nothing)
{
	iDeathModelRef = INVALID_ENT_REFERENCE;
	bIgnore = false;
}

static bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}
