#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required


#define PLUGIN_VERSION "3.0"

enum ZOMBIECLASS
{
	ZOMBIECLASS_SMOKER = 1,
	ZOMBIECLASS_BOOMER,
	ZOMBIECLASS_HUNTER,
	ZOMBIECLASS_SPITTER,
	ZOMBIECLASS_JOCKEY,
	ZOMBIECLASS_CHARGER,
	ZOMBIECLASS_UNKNOWN,
	ZOMBIECLASS_TANK,
}


static int iHiddenEntity[2048+1] = {0, ...};
static int iHiddenEntityRef[2048+1];
static int iHiddenIndex[MAXPLAYERS+1] = {0, ...};
static int iHiddenOwner[2048+1] = {0, ...};
static Handle hCvar_AggressiveChecks = INVALID_HANDLE;
static bool g_bAggressiveChecks = false;

Handle g_hOnClientModelApplied = INVALID_HANDLE;
Handle g_hOnClientModelChanged = INVALID_HANDLE;
Handle g_hOnClientModelDestroyed = INVALID_HANDLE;

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
	
	RegPluginLibrary("L4D2ModelChanger");// for compatibility with older plugins
	RegPluginLibrary("LMCCore");
	CreateNative("LMC_GetClientOverlayModel", GetOverlayModel);
	CreateNative("LMC_SetClientOverlayModel", SetOverlayModel);
	CreateNative("LMC_SetEntityOverlayModel", SetEntityOverlayModel);
	CreateNative("LMC_GetEntityOverlayModel", GetEntityOverlayModel);
	CreateNative("LMC_HideClientOverlayModel", HideOverlayModel);
	CreateNative("LMC_ResetRenderMode", ResetRenderMode);
	
	g_hOnClientModelApplied = CreateGlobalForward("LMC_OnClientModelApplied", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hOnClientModelChanged  = CreateGlobalForward("LMC_OnClientModelChanged", ET_Event, Param_Cell, Param_Cell, Param_String);
	g_hOnClientModelDestroyed  = CreateGlobalForward("LMC_OnClientModelDestroyed", ET_Event, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "LMCCore",
	author = "Lux",
	description = "Core of LMC, manages overlay models",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};


public void OnPluginStart()
{
	CreateConVar("lmccore_version", PLUGIN_VERSION, "LMCCore_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_AggressiveChecks = CreateConVar("lmc_aggressive_model_checks", "0", "1 = (When client has no lmc model (enforce aggressive model showing base model render mode)) 0 = (compatibility mode (should help with plugins like incap crawling) Depends on the plugin)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(hCvar_AggressiveChecks, eConvarChanged);
	CvarsChanged();
	AutoExecConfig(true, "LMCCore");
	
	HookEvent("player_team", eTeamChange);
	HookEvent("player_incapacitated", eSetColour);
	HookEvent("revive_end", eSetColour);
	HookEvent("player_spawn", ePlayerSpawn, EventHookMode_Pre);
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_bAggressiveChecks = GetConVarInt(hCvar_AggressiveChecks) > 0;
}

public void ePlayerSpawn(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(IsValidEntRef(iHiddenIndex[iClient]))
	{
		AcceptEntityInput(iHiddenIndex[iClient], "kill");
		iHiddenIndex[iClient] = -1;
	}
	
	SetEntProp(iClient, Prop_Send, "m_nMinGPULevel", 0);
	SetEntProp(iClient, Prop_Send, "m_nMaxGPULevel", 0);
}

int BeWitched(int iClient, const char[] sModel, const bool bBaseReattach)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return -1;
	
	CheckForSameModel(iClient, sModel);
	
	int iEntity = EntRefToEntIndex(iHiddenIndex[iClient]);
	if(IsValidEntRef(iHiddenIndex[iClient]) && !bBaseReattach)
	{
		SetEntityModel(iEntity, sModel);
		Call_StartForward(g_hOnClientModelChanged);
		Call_PushCell(iClient);
		Call_PushCell(iEntity);
		Call_PushString(sModel);
		Call_Finish();
		return iEntity;
	}
	else if(bBaseReattach)
		AcceptEntityInput(iEntity, "Kill");
	
	
	iEntity = CreateEntityByName("prop_dynamic_ornament");
	if(iEntity < 0)
		return -1;
	
	DispatchKeyValue(iEntity, "model", sModel);
	
	DispatchSpawn(iEntity);
	ActivateEntity(iEntity);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iClient);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetAttached", iClient);
	AcceptEntityInput(iEntity, "TurnOn");
	
	SetEntityRenderMode(iClient, RENDER_NONE);
	
	iHiddenIndex[iClient] = EntIndexToEntRef(iEntity);
	iHiddenOwner[iEntity] = GetClientUserId(iClient);
	
	SetEntProp(iClient, Prop_Send, "m_nMinGPULevel", 1);
	SetEntProp(iClient, Prop_Send, "m_nMaxGPULevel", 1);
	
	Call_StartForward(g_hOnClientModelApplied);
	Call_PushCell(iClient);
	Call_PushCell(iEntity);
	Call_PushString(sModel);
	Call_PushCell(bBaseReattach);
	Call_Finish();
	
	return iEntity;
}

int BeWitchOther(int iEntity, const char[] sModel)// dont pass refs
{
	if(iEntity < 1 || iEntity > 2048)
		return -1;
	
	CheckForSameModel(iEntity, sModel);
	
	if(IsValidEntRef(iHiddenEntity[iEntity]))
	{
		SetEntityModel(iHiddenEntity[iEntity], sModel);
		return EntRefToEntIndex(iHiddenEntity[iEntity]);
	}
	
	int iEnt = CreateEntityByName("prop_dynamic_ornament");
	if(iEnt < 0)
		return -1;
	
	DispatchKeyValue(iEnt, "model", sModel);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", iEntity);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetAttached", iEntity);
	AcceptEntityInput(iEnt, "TurnOn");
	
	iHiddenEntity[iEntity] = EntIndexToEntRef(iEnt);
	iHiddenEntityRef[iEntity] = EntIndexToEntRef(iEntity);
	
	SetEntityRenderFx(iEntity, RENDERFX_HOLOGRAM);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);
	
	SetEntProp(iEntity, Prop_Send, "m_nMinGPULevel", 1);
	SetEntProp(iEntity, Prop_Send, "m_nMaxGPULevel", 1);
	return iEnt;
}

void CheckForSameModel(int iEntity, const char[] sPendingModel)// justincase 
{
	char sModel[PLATFORM_MAX_PATH];
	char sNetClass[64];
	if(!GetEntityNetClass(iEntity, sNetClass, sizeof(sNetClass)))
		return;
	
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	if(!StrEqual(sModel, sPendingModel, false))
		return;
	
	PrintToServer("[LMC][%i]%s(NetClass) overlay_model is the same as base model! \"%s\"", iEntity, sNetClass, sModel);// used netclass because classname can be changed!
}

public void OnGameFrame()
{
	if(!IsServerProcessing())
		return;
	
	static int iClient = 1;
	if(iClient > MaxClients || iClient < 1)
		iClient = 1;
	
	
	if(IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		if(IsValidEntRef(iHiddenIndex[iClient]))
		{
			SetEntityRenderMode(iClient, RENDER_NONE);
			static int iEnt;
			iEnt = EntRefToEntIndex(iHiddenIndex[iClient]);
			
			if(bL4D2)
			{
				if((GetEntProp(iClient, Prop_Send, "m_nGlowRange") > 0 && GetEntProp(iEnt, Prop_Send, "m_nGlowRange") == 0)
						&& (GetEntProp(iClient, Prop_Send, "m_iGlowType") > 0 && GetEntProp(iEnt, Prop_Send, "m_iGlowType") == 0)
						&& (GetEntProp(iClient, Prop_Send, "m_glowColorOverride") > 0 && GetEntProp(iEnt, Prop_Send, "m_glowColorOverride") == 0)
						&& (GetEntProp(iClient, Prop_Send, "m_nGlowRangeMin") > 0 && GetEntProp(iEnt, Prop_Send, "m_nGlowRangeMin") == 0))
				{
					SetEntProp(iEnt, Prop_Send, "m_nGlowRange", GetEntProp(iClient, Prop_Send, "m_nGlowRange"));
					SetEntProp(iEnt, Prop_Send, "m_iGlowType", GetEntProp(iClient, Prop_Send, "m_iGlowType"));
					SetEntProp(iEnt, Prop_Send, "m_glowColorOverride", GetEntProp(iClient, Prop_Send, "m_glowColorOverride"));
					SetEntProp(iEnt, Prop_Send, "m_nGlowRangeMin", GetEntProp(iClient, Prop_Send, "m_nGlowRangeMin"));
				}
			}
		}
		else if(g_bAggressiveChecks && !IsValidEntRef(iHiddenEntityRef[iClient]))
			SetEntityRenderMode(iClient, RENDER_NORMAL);
		
		static int iModelIndex[MAXPLAYERS+1] = {-1, ...};
		if(iModelIndex[iClient] != GetEntProp(iClient, Prop_Data, "m_nModelIndex", 2))
		{
			iModelIndex[iClient] = GetEntProp(iClient, Prop_Data, "m_nModelIndex", 2);
			if(IsValidEntRef(iHiddenIndex[iClient]))
			{
				static char sModel[PLATFORM_MAX_PATH];
				GetEntPropString(iHiddenIndex[iClient], Prop_Data, "m_ModelName", sModel, sizeof(sModel));
				BeWitched(iClient, sModel, true);
			}
		}
	}
	iClient++;
	
	
	static int iEntity;
	if(iEntity <= MaxClients || iEntity > 2048)
		iEntity = MaxClients+1;
	
	if(IsValidEntRef(iHiddenEntity[iEntity] && IsValidEntRef(iHiddenEntityRef[iEntity])))
	{
		static int iEnt;
		iEnt = EntRefToEntIndex(iHiddenEntity[iEntity]);
		SetEntityRenderFx(iEntity, RENDERFX_HOLOGRAM);
		SetEntityRenderColor(iEntity, 0, 0, 0, 0);
		
		if(bL4D2)
		{
			if((GetEntProp(iEntity, Prop_Send, "m_nGlowRange") > 0 && GetEntProp(iEnt, Prop_Send, "m_nGlowRange") == 0)
					&& (GetEntProp(iEntity, Prop_Send, "m_iGlowType") > 0 && GetEntProp(iEnt, Prop_Send, "m_iGlowType") == 0)
					&& (GetEntProp(iEntity, Prop_Send, "m_glowColorOverride") > 0 && GetEntProp(iEnt, Prop_Send, "m_glowColorOverride") == 0)
					&& (GetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin") > 0 && GetEntProp(iEnt, Prop_Send, "m_nGlowRangeMin") == 0))
			{
				SetEntProp(iEnt, Prop_Send, "m_nGlowRange", GetEntProp(iEntity, Prop_Send, "m_nGlowRange"));
				SetEntProp(iEnt, Prop_Send, "m_iGlowType", GetEntProp(iEntity, Prop_Send, "m_iGlowType"));
				SetEntProp(iEnt, Prop_Send, "m_glowColorOverride", GetEntProp(iEntity, Prop_Send, "m_glowColorOverride"));
				SetEntProp(iEnt, Prop_Send, "m_nGlowRangeMin", GetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin"));
			}
		}
	}
	iEntity++;
}


public int GetOverlayModel(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_PARAM, "Client index out of bounds %i", iClient);
	
	if(!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iClient);
	
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return -1;
	
	return EntRefToEntIndex(iHiddenIndex[iClient]);
}

public int SetOverlayModel(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_PARAM, "Client index out of bounds %i", iClient);
	
	if(!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iClient);
	
	char sModel[PLATFORM_MAX_PATH];
	GetNativeString(2, sModel, sizeof(sModel));
	
	if(sModel[0] == '\0')
		ThrowNativeError(SP_ERROR_PARAM, "Error Empty String");
	
	
	return BeWitched(iClient, sModel, false);
}

public int SetEntityOverlayModel(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iEntity = GetNativeCell(1);
	if(iEntity < 1 || iEntity > 2048)
		ThrowNativeError(SP_ERROR_PARAM, "Entity index out of bounds %i", iEntity);
		
	if(!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_ABORTED, "Entity Invalid %i", iEntity);
	
	if(iEntity <= MaxClients)
		if(!IsClientInGame(iEntity))
			ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iEntity);
	
	char sModel[PLATFORM_MAX_PATH];
	GetNativeString(2, sModel, sizeof(sModel));
	
	if(sModel[0] == '\0')
		ThrowNativeError(SP_ERROR_PARAM, "Error Empty String");
	
	return BeWitchOther(iEntity, sModel);
}

public int GetEntityOverlayModel(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iEntity = GetNativeCell(1);
	if(iEntity < MaxClients+1 || iEntity > 2048+1)
		ThrowNativeError(SP_ERROR_PARAM, "Entity index out of bounds %i", iEntity);
	
	if(!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_ABORTED, "Entity Invalid %i", iEntity);
	
	if(iEntity <= MaxClients)
		if(!IsClientInGame(iEntity))
			ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iEntity);
	
	if(!IsValidEntRef(iHiddenEntityRef[iEntity]))
		return -1;
	
	if(!IsValidEntRef(iHiddenEntity[iEntity]))
		return -1;
	
	return EntRefToEntIndex(iHiddenEntity[iEntity]);
}

public int ResetRenderMode(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iEntity = GetNativeCell(1);
	if(iEntity < 1 || iEntity > 2048+1)
		ThrowNativeError(SP_ERROR_PARAM, "Entity index out of bounds %i", iEntity);
	
	if(!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_ABORTED, "Entity Invalid %i", iEntity);
	
	if(iEntity <= MaxClients)
		if(!IsClientInGame(iEntity))
			ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iEntity);
	
	ResetRender(iEntity);
}


public void OnEntityDestroyed(int iEntity)
{
	if(!IsServerProcessing() || iEntity < MaxClients+1 || iEntity > 2048)
		return;
	
	static char sClassname[64];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	if(sClassname[0] != 'p' || !StrEqual(sClassname, "prop_dynamic_ornament", false))
		return;
	
	int iClient = GetClientOfUserId(iHiddenOwner[iEntity]);
	if(iClient < 1)
		return;
	
	iHiddenOwner[iEntity] = -1;
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	Call_StartForward(g_hOnClientModelDestroyed);
	Call_PushCell(iClient);
	Call_PushCell(EntRefToEntIndex(iHiddenIndex[iClient]));
	Call_Finish();
}

void ResetRender(int iEntity)
{
	if(iEntity < MaxClients+1)
	{
		SetEntityRenderMode(iEntity, RENDER_NORMAL);
		SetEntProp(iEntity, Prop_Send, "m_nMinGPULevel", 0);
		SetEntProp(iEntity, Prop_Send, "m_nMaxGPULevel", 0);
	}
	else
	{
		SetEntityRenderFx(iEntity, RENDERFX_NONE);
		SetEntityRenderColor(iEntity, 255, 255, 255, 255);
	}
}

public void OnClientDisconnect(int iClient)
{
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	AcceptEntityInput(iHiddenIndex[iClient], "kill");
	iHiddenIndex[iClient] = -1;
}

public void eSetColour(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return;
	
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	SetEntityRenderMode(iClient, RENDER_NONE);
}

public void eTeamChange(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient))
		return;
	
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	AcceptEntityInput(iHiddenIndex[iClient], "kill");
	iHiddenIndex[iClient] = -1;
}

static bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}


//deprecated stuff
public int HideOverlayModel(Handle plugin, int numParams)
{
	ThrowNativeError(SP_ERROR_NOT_RUNNABLE, "Deprecated function not longer included in LMC since \"ADD_VERSION\" use older build if you want to use this function.");//add version
}