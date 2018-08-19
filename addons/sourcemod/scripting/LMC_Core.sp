#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required

#define PLUGIN_VERSION "cakebuildA"

static int iHiddenOwner[2048+1] = {0, ...};
static int iHiddenEntity[2048+1] = {0, ...};
static int iHiddenEntityRef[2048+1];
static int iHiddenIndex[MAXPLAYERS+1] = {0, ...};
static bool bThirdPerson[MAXPLAYERS+1] = {false, ...};



Handle g_hOnClientModelApplied = INVALID_HANDLE;
Handle g_hOnClientModelAppliedPre = INVALID_HANDLE;
Handle g_hOnClientModelBlocked = INVALID_HANDLE;
Handle g_hOnClientModelChanged = INVALID_HANDLE;
Handle g_hOnClientModelDestroyed = INVALID_HANDLE;
Handle g_hOnClientDeathModelCreated = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("L4D2ModelChanger");
	CreateNative("LMC_GetClientOverlayModel", GetOverlayModel);
	CreateNative("LMC_SetClientOverlayModel", SetOverlayModel);
	CreateNative("LMC_SetEntityOverlayModel", SetEntityOverlayModel);
	CreateNative("LMC_GetEntityOverlayModel", GetEntityOverlayModel);
	CreateNative("LMC_HideClientOverlayModel", HideOverlayModel);
	
	g_hOnClientModelApplied = CreateGlobalForward("LMC_OnClientModelApplied", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	g_hOnClientModelAppliedPre = CreateGlobalForward("LMC_OnClientModelAppliedPre", ET_Event, Param_Cell, Param_CellByRef);
	g_hOnClientModelBlocked  = CreateGlobalForward("LMC_OnClientModelSelected", ET_Event, Param_Cell, Param_String);
	g_hOnClientModelChanged  = CreateGlobalForward("LMC_OnClientModelChanged", ET_Event, Param_Cell, Param_Cell, Param_String);
	g_hOnClientModelDestroyed  = CreateGlobalForward("LMC_OnClientModelDestroyed", ET_Event, Param_Cell, Param_Cell);
	g_hOnClientDeathModelCreated  = CreateGlobalForward("LMC_OnClientDeathModelCreated", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}


public OnPluginStart()
{
	CreateConVar("lmc_core_version", PLUGIN_VERSION, "LMC_Core_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
}



bool BeWitched(int iClient, const char[] sModel, const bool bBaseReattach)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	int iEntity = iHiddenIndex[iClient];
	if(IsValidEntRef(iEntity) && !bBaseReattach)
	{
		SetEntityModel(iEntity, sModel);
		Call_StartForward(g_hOnClientModelChanged);
		Call_PushCell(iClient);
		Call_PushCell(EntRefToEntIndex(iEntity));
		Call_PushString(sModel);
		Call_Finish();
		return;
	}
	else if(bBaseReattach)
		AcceptEntityInput(iEntity, "Kill");
	
	
	iEntity = CreateEntityByName("prop_dynamic_ornament");
	if(iEntity < 0)
		return;
	
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
	
	BeWitched(iClient, sModel, false);
	return EntRefToEntIndex(iHiddenIndex[iClient]);
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
	
	BeWitchOther(iEntity, sModel);
	return EntRefToEntIndex(iHiddenEntityRef[iEntity]);
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


public void OnEntityDestroyed(int iEntity)
{
	if(!IsServerProcessing() || iEntity < MaxClients+1 || iEntity > 2048)
		return;
	
	static char sClassname[64];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	if(sClassname[0] != 'p' || !StrEqual(sClassname, "prop_dynamic_ornament", false))
		return;
	
	static int iClient;
	iClient = GetClientOfUserId(iHiddenOwner[iEntity]);
	
	if(iClient < 1)
		return;
	
	iHiddenOwner[iEntity] = -1;
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	Call_StartForward(g_hOnClientModelDestroyed);
	Call_PushCell(iClient);
	Call_PushCell(EntRefToEntIndex(iHiddenIndex[iClient]));//now returns entity index 
	Call_Finish();
}

bool BeWitchOther(int iEntity, const char[] sModel)
{
	if(iEntity < 1 || iEntity > 2048)
		return false;
	
	if(IsValidEntRef(iHiddenEntity[iEntity]))
	{
		SetEntityModel(iHiddenEntity[iEntity], sModel);
		return true;
	}
	
	int iEnt = CreateEntityByName("prop_dynamic_ornament");
	if(iEnt < 0)
		return false;
	
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
	return true;
}

void ResetDefaultModel(int iClient)
{
	SetEntityRenderMode(iClient, RENDER_NORMAL);
	SetEntProp(iClient, Prop_Send, "m_nMinGPULevel", 0);
	SetEntProp(iClient, Prop_Send, "m_nMaxGPULevel", 0);
	
	if(!IsValidEntRef(iHiddenIndex[iClient]))
		return;
	
	AcceptEntityInput(EntRefToEntIndex(iHiddenIndex[iClient]), "kill");
	iHiddenIndex[iClient] = -1;
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
	ThrowNativeError(SP_ERROR_NOT_FOUND, "Deprecated function not longer included in LMC since ADD_VERSION.");//add version
}