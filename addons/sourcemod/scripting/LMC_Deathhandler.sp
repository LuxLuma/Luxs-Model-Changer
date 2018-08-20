#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <L4D2ModelChanger>
#pragma newdecls required

#define PLUGIN_NAME "LMC_Deathhandler"
#define PLUGIN_VERSION "1.0"


static bool bIsIncapped[MAXPLAYERS+1] = {false, ...};
static bool bHideDeathModel = false;

static int g_iHideDeathModel = 2;
static Handle hCvar_HideDeathModel = INVALID_HANDLE;


Handle g_hOnClientDeathModelCreated = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("LMC_Deathhandler");
	g_hOnClientDeathModelCreated  = CreateGlobalForward("LMC_OnClientDeathModelCreated", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "LMC_Deathhandler",
	author = "Lux",
	description = "Manages deaths regarding lmc, overlay deathmodels and ragdolls, and fixes clonesurvivors deathmodels teleporting around, module required to handle (witch & common deaths)",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("LMC_Core"))
		SetFailState("[LMC]LMC_Core notloaded, load LMC_Core and reload %s.", PLUGIN_NAME);
	if(!LibraryExists("LMC_L4D2_SetTransmit"))
		SetFailState("[LMC]LMC_L4D2_SetTransmit notloaded, load LMC_L4D2_SetTransmit and reload %s.", PLUGIN_NAME);
}

public void OnPluginStart()
{
	CreateConVar("lmc_deathhandler_version", PLUGIN_VERSION, "LMC_Deathhandler_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_HideDeathModel = CreateConVar("lmc_hide_defib_model", "2", "(-1 to do nothing at all)(0 = create Deathmodels) (1 = custom model death model) (2 = Custom model ragdoll and hide death model)", FCVAR_NOTIFY, true, -1.0, true, 2.0);
	HookConVarChange(hCvar_HideDeathModel, eConvarChanged);
	CvarsChanged();
	AutoExecConfig(true, "LMC_Deathhandler");
	
	HookEvent("player_death", ePlayerDeath, EventHookMode_Pre);
	HookEvent("witch_killed", eWitchKilled, EventHookMode_Pre);
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i))
			OnClientPutInServer(i);
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_iHideDeathModel = GetConVarInt(hCvar_HideDeathModel);
}

public void ePlayerDeath(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int iEntity;
	
	if(iVictim > 0 && iVictim <= MaxClients && IsClientInGame(iVictim))
	{
		int iTeam = GetClientTeam(iVictim);
		iEntity = LMC_GetClientOverlayModel(iVictim);
		
		if(iTeam == 3 && IsValidEntity(iEntity))
		{
			AcceptEntityInput(iEntity, "ClearParent");
			SetEntProp(iEntity, Prop_Send, "m_bClientSideRagdoll", 1, 1);
			SetVariantString("OnUser1 !self:Kill::0.1:1");
			AcceptEntityInput(iEntity, "AddOutput");
			AcceptEntityInput(iEntity, "FireUser1");
			return;
		}
		
		if(g_iHideDeathModel == -1)
		{
			if(IsValidEntity(iEntity))
				AcceptEntityInput(iEntity, "Kill");
			return;
		}
		
		int iEnt;
		if(iTeam == 2)
		{
			bHideDeathModel = true;
			iEnt = CreateEntityByName("survivor_death_model");
			bHideDeathModel = false;
			if(iEnt < 0)
				return;
			
			
			DispatchSpawn(iEnt);
			ActivateEntity(iEnt);
			
			SetEntProp(iEnt, Prop_Data, "m_nModelIndex", GetEntProp(iVictim, Prop_Data, "m_nModelIndex"));
			SetEntProp(iEnt, Prop_Send, "m_nCharacterType", GetEntProp(iVictim, Prop_Send, "m_survivorCharacter"));
			
			char sModel[31];
			GetEntPropString(iVictim, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
			
			switch(sModel[29])
			{
				case 'b'://nick
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 679, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 678, 2);
				}
				case 'd'://rochelle
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 686, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 685, 2);
				}
				case 'c'://coach
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 668, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 667, 2);
				}
				case 'h'://ellis
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 683, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 682, 2);
				}
				case 'v'://bill
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 771, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 770, 2);
				}
				case 'n'://zoey
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 808, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 807, 2);
				}
				case 'e'://francis
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 774, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 773, 2);
				}
				case 'a'://louis
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 771, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 770, 2);
				}
				case 'w'://adawong
				{
					if(bIsIncapped[iVictim])
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 686, 2);
					else
						SetEntProp(iEnt, Prop_Send, "m_nSequence", 687, 2);
				}
			}
			
			SetEntPropFloat(iEnt, Prop_Send, "m_flPlaybackRate", 1.0);
			SetEntProp(iEnt, Prop_Send, "m_bClientSideAnimation", 1, 1);
			
			float fPos[3];
			float fAng[3];
			
			GetClientAbsOrigin(iVictim, fPos);
			GetClientAbsAngles(iVictim, fAng);
			
			fPos[2]++;
			Handle trace;
			trace = TR_TraceRayFilterEx(fPos, view_as<float>({90.0, 0.0, 0.0}), MASK_SHOT, RayType_Infinite, _TraceFilter);
			
			float fEnd[3];
			TR_GetEndPosition(fEnd, trace); // retrieve our trace endpoint
			CloseHandle(trace);
			
			fAng[0] = 0.0;
			
			if(150 > GetVectorDistance(fPos, fEnd))//traceray is from the center not from the 4 corners of the collision box should help with deathmodels teleporting down a ledge or though a prop.
				TeleportEntity(iEnt, fEnd, fAng, NULL_VECTOR);
			else
			{
				fPos[2]--;
				TeleportEntity(iEnt, fPos, fAng, NULL_VECTOR);
			}
			
			
			int iWeapon = GetPlayerWeaponSlot(iVictim, 1);
			if(iWeapon > MaxClients && iWeapon <= 2048 && IsValidEntity(iWeapon))
				SDKHooks_DropWeapon(iVictim, iWeapon);
			
			Call_StartForward(g_hOnClientDeathModelCreated);
			Call_PushCell(iVictim);
			Call_PushCell(iEnt);
			
			if(g_iHideDeathModel == 1 && IsValidEntity(iEntity))
				Call_PushCell(iEntity);
			else
				Call_PushCell(-1);
			Call_Finish();
			
			
			if(g_iHideDeathModel < 1 && IsValidEntity(iEntity))
			{
				AcceptEntityInput(iEntity, "Kill");
				return;
			}
		}
		
		if(!IsValidEntity(iEntity))
			return;
		
		
		SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(iEntity, Prop_Send, "m_iGlowType", 0);
		SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", 0);
		SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 0);
		
		LMC_L4D2_SetTransmit(iVictim, iEntity, false);
		
		if(iTeam != 2)
			return;
		
		AcceptEntityInput(iEntity, "ClearParent");
		SetEntProp(iEnt, Prop_Send, "m_nMinGPULevel", 1);
		SetEntProp(iEnt, Prop_Send, "m_nMaxGPULevel", 1);
		
		if(g_iHideDeathModel == 1)
		{
			AcceptEntityInput(iEntity, "Detach");
			
			SetVariantString("!activator");
			AcceptEntityInput(iEntity, "SetParent", iEnt);
			
			SetVariantString("!activator");
			AcceptEntityInput(iEntity, "SetAttached", iEnt);
			
			SetEntityRenderMode(iEnt, RENDER_NONE);
			
			return;
		}
		
		SetEntProp(iEntity, Prop_Send, "m_bClientSideRagdoll", 1, 1);
		SetVariantString("OnUser1 !self:Kill::0.1:1");
		AcceptEntityInput(iEntity, "AddOutput");
		AcceptEntityInput(iEntity, "FireUser1");
		
		SetEntityRenderMode(iEnt, RENDER_NONE);
	}
	else
	{
		iVictim = GetEventInt(hEvent, "entityid");
		if(iVictim < MaxClients+1 || iVictim > 2048 || !IsValidEntity(iVictim))
			return;
		
		char sClassname[7];
		GetEntityClassname(iVictim, sClassname, 7);
		if(StrEqual(sClassname, "witch", false))// called before witch death event
			return;
		
		if((iEntity = LMC_GetEntityOverlayModel(iVictim)) < 1)
			return;
		
		NextBotRagdollHandler(iVictim, iEntity);
	}
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
	SetEntProp(iPreRagdoll, Prop_Send, "m_nGlowRange", 0);
	SetEntProp(iPreRagdoll, Prop_Send, "m_iGlowType", 0);
	SetEntProp(iPreRagdoll, Prop_Send, "m_glowColorOverride", 0);
	SetEntProp(iPreRagdoll, Prop_Send, "m_nGlowRangeMin", 0);
	
	SetEntProp(iPreRagdoll, Prop_Send, "m_bClientSideRagdoll", 1, 1);
	SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 999.0);
	
	AcceptEntityInput(iPreRagdoll, "ClearParent");
	SetVariantString("OnUser1 !self:Kill::0.1:1");
	AcceptEntityInput(iPreRagdoll, "AddOutput");
	AcceptEntityInput(iPreRagdoll, "FireUser1");
}

public bool _TraceFilter(int iEntity, int contentsMask)
{
	static char sClassName[32];
	GetEntityClassname(iEntity, sClassName, sizeof(sClassName));
	if(sClassName[0] != 'i' || !StrEqual(sClassName, "infected", false))
		return false;
	else if(sClassName[0] != 'w' || !StrEqual(sClassName, "witch", false))
		return false;
	else if(StrContains(sClassName, "weapon_", false) == 0)
		return false;
	else if(iEntity > 0 && iEntity <= MaxClients)
		return false;
	return true;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamageAlivePost, eOnTakeDamageAlivePost);
}

public void eOnTakeDamageAlivePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamagetype)
{
	if(!IsClientInGame(iVictim) || GetClientTeam(iVictim) != 2)
		return;
	
	bIsIncapped[iVictim] = view_as<bool>(GetEntProp(iVictim, Prop_Send, "m_isIncapacitated", 1));
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(g_iHideDeathModel == -1 || bHideDeathModel || !IsServerProcessing())
		return;
	
	if(sClassname[0] != 's' || !StrEqual(sClassname, "survivor_death_model", false))
		return;
	
	SDKHook(iEntity, SDKHook_SpawnPost, SpawnPost);
}

public void SpawnPost(int iEntity)
{
	SDKUnhook(iEntity, SDKHook_SpawnPost, SpawnPost);
	if(!IsValidEntity(iEntity))
		return;
	
	AcceptEntityInput(iEntity, "Kill");
}