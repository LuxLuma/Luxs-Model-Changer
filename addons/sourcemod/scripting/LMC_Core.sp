#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required

#define PLUGIN_VERSION "cakebuildD"

static int iHiddenOwner[2048+1] = {0, ...};
static int iHiddenEntity[2048+1] = {0, ...};
static int iHiddenEntityRef[2048+1];
static int iHiddenIndex[MAXPLAYERS+1] = {0, ...};
static bool bThirdPerson[MAXPLAYERS+1] = {false, ...};

static Handle hCvar_AggressiveChecks = INVALID_HANDLE;
static bool g_bAggressiveChecks = false;

Handle g_hOnClientModelApplied = INVALID_HANDLE;
Handle g_hOnClientModelChanged = INVALID_HANDLE;
Handle g_hOnClientModelDestroyed = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("L4D2ModelChanger");
	CreateNative("LMC_GetClientOverlayModel", GetOverlayModel);
	CreateNative("LMC_SetClientOverlayModel", SetOverlayModel);
	CreateNative("LMC_SetEntityOverlayModel", SetEntityOverlayModel);
	CreateNative("LMC_GetEntityOverlayModel", GetEntityOverlayModel);
	CreateNative("LMC_HideClientOverlayModel", HideOverlayModel);
	CreateNative("LMC_SetTransmit", SetTransmit);
	CreateNative("LMC_ResetRenderMode", ResetRenderMode);
	
	g_hOnClientModelApplied = CreateGlobalForward("LMC_OnClientModelApplied", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hOnClientModelChanged  = CreateGlobalForward("LMC_OnClientModelChanged", ET_Event, Param_Cell, Param_Cell, Param_String);
	g_hOnClientModelDestroyed  = CreateGlobalForward("LMC_OnClientModelDestroyed", ET_Event, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}


public void OnPluginStart()
{
	CreateConVar("lmc_core_version", PLUGIN_VERSION, "LMC_Core_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_AggressiveChecks = CreateConVar("lmc_aggressive_model_checks", "0", "1 = (When client has no lmc model (enforce aggressive model showing base model render mode)) 0 = (compatibility mode (should help with plugins like incap crawling) Depends on the plugin)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(hCvar_AggressiveChecks, eConvarChanged);
	CvarsChanged();
	AutoExecConfig(true, "lmc_core");
	
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
	
	SDKHook(iEntity, SDKHook_SetTransmit, HideModel);
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
	
	PrintToServer("[LMC][%i]%s(NetClass) overlay_model is the same as base model! \"%s\"", iEntity, sNetClass, sModel);
}

public Action HideModel(int iEntity, int iClient)
{
	if(IsFakeClient(iClient))
		return Plugin_Continue;
	
	if(!IsPlayerAlive(iClient))
		if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 4)
			if(GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget") == GetClientOfUserId(iHiddenOwner[iEntity]))
				return Plugin_Handled;
	
	static int iOwner;
	iOwner = GetClientOfUserId(iHiddenOwner[iEntity]);
	
	if(iOwner < 1 || !IsClientInGame(iOwner))
		return Plugin_Continue;
	
	switch(GetClientTeam(iOwner)) 
	{
		case 2: 
		{
			if(iOwner != iClient)
				return Plugin_Continue;
			
			if(!IsSurvivorThirdPerson(iClient))
				return Plugin_Handled;
		}
		case 3: 
		{
			static bool bIsGhost;
			bIsGhost = GetEntProp(iOwner, Prop_Send, "m_isGhost", 1) > 0;
			
			if(iOwner != iClient) 
			{
				//Hide model for everyone else when is ghost mode exapt me
				if(bIsGhost)
					return Plugin_Handled;
			}
			else 
			{
				// Hide my model when not in thirdperson
				if(bIsGhost)
					SetEntityRenderMode(iOwner, RENDER_NONE);
				
				if(!IsInfectedThirdPerson(iOwner))
					return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
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
	iEntity++;
}



public int SetTransmit(Handle plugin, int numParams)
{
	if(numParams < 2)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_PARAM, "Client index out of bounds %i", iClient);
	
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return false;
	
	bool bType = view_as<bool>(GetNativeCell(2));
	
	if(bType)
	{
		SDKHook(iHiddenIndex[iClient], SDKHook_SetTransmit, HideModel);
		return true;
	}
	SDKUnhook(iHiddenIndex[iClient], SDKHook_SetTransmit, HideModel);
	return true;
}

public int GetOverlayModel(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_PARAM, "Client index out of bounds %i", iClient);
	
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
	
	static char sModel[PLATFORM_MAX_PATH];
	
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
	
	static char sModel[PLATFORM_MAX_PATH];
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
	if(iClient > 0)
		return;
	
	iHiddenOwner[iEntity] = -1;
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	Call_StartForward(g_hOnClientModelDestroyed);
	Call_PushCell(iClient);
	Call_PushCell(EntRefToEntIndex(iHiddenIndex[iClient]));//now returns entity index 
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

public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson)
{
	bThirdPerson[iClient] = bIsThirdPerson;
}

static bool IsValidEntRef(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}
static bool IsSurvivorThirdPerson(int iClient)
{
	if(bThirdPerson[iClient])
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime())
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true;
	switch(GetEntProp(iClient, Prop_Send, "m_iCurrentUseAction"))
	{
		case 1:
		{
			static int iTarget;
			iTarget = GetEntPropEnt(iClient, Prop_Send, "m_useActionTarget");
			
			if(iTarget == GetEntPropEnt(iClient, Prop_Send, "m_useActionOwner"))
				return true;
			else if(iTarget != iClient)
				return true;
		}
		case 4, 5, 6, 7, 8, 9, 10:
		return true;
	}
	
	static char sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 626, 625, 624, 623, 622, 621, 661, 662, 664, 665, 666, 667, 668, 670, 671, 672, 673, 674, 620, 680, 616:
				return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625, 616:
				return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 656, 622, 623, 624, 625, 626, 663, 662, 661, 660, 659, 658, 657, 654, 653, 652, 651, 621, 620, 669, 615:
				return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 625, 675, 626, 627, 628, 629, 630, 631, 678, 677, 676, 575, 674, 673, 672, 671, 670, 669, 668, 667, 666, 665, 684, 621:
				return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 528, 759, 763, 764, 529, 530, 531, 532, 533, 534, 753, 676, 675, 761, 758, 757, 756, 755, 754, 527, 772, 762, 522:
				return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 537, 819, 823, 824, 538, 539, 540, 541, 542, 543, 813, 828, 825, 822, 821, 820, 818, 817, 816, 815, 814, 536, 809, 572:
				return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 532, 533, 534, 535, 536, 537, 769, 768, 767, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 531, 530, 775, 525:
				return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 529, 530, 531, 532, 533, 534, 766, 765, 764, 763, 762, 761, 760, 759, 758, 757, 756, 755, 754, 753, 527, 772, 528, 522:
				return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 674, 678, 679, 630, 631, 632, 633, 634, 668, 677, 681, 680, 676, 675, 673, 672, 671, 670, 687, 629, 625, 616:
				return true;
			}
		}
	}
	return false;
}
static bool IsInfectedThirdPerson(int iClient)
{
	if(bThirdPerson[iClient])
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_TimeForceExternalView") > GetGameTime())
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > -1.0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	
	switch(GetEntProp(iClient, Prop_Send, "m_zombieClass"))
	{
		case 1://smoker
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 30, 31, 32, 36, 37, 38, 39:
				return true;
			}
		}
		case 3://hunter
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 38, 39, 40, 41, 42, 43, 45, 46, 47, 48, 49:
				return true;
			}
		}
		case 4://spitter
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 17, 18, 19, 20:
				return true;
			}
		}
		case 5://jockey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 8 , 15, 16, 17, 18:
				return true;
			}
		}
		case 6://charger
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 5, 27, 28, 29, 31, 32, 33, 34, 35, 39, 40, 41, 42:
				return true;
			}
		}
		case 8://tank
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 28, 29, 30, 31, 49, 50, 51, 73, 74, 75, 76 ,77:
				return true;
			}
		}
	}
	
	return false;
}






//deprecated stuff
public int HideOverlayModel(Handle plugin, int numParams)
{
	ThrowNativeError(SP_ERROR_NONE, "Deprecated function not longer included in LMC since ADD_VERSION.");//add version
}