#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma newdecls required


#define PLUGIN_NAME "LMCL4D1SetTransmit"
#define PLUGIN_VERSION "1.0"

enum ZOMBIECLASS
{
	ZOMBIECLASS_SMOKER = 1,
	ZOMBIECLASS_BOOMER,
	ZOMBIECLASS_HUNTER,
	ZOMBIECLASS_UNKNOWN,
	ZOMBIECLASS_TANK,
}

static int iHiddenOwner[2048+1] = {0, ...};
static bool bThirdPerson[MAXPLAYERS+1] = {false, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead");
		return APLRes_SilentFailure;
	}
	RegPluginLibrary("LMCL4D1SetTransmit");
	CreateNative("LMC_L4D1_SetTransmit", SetTransmit);
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Lux",
	description = "Manages transmitting models to clients in L4D1",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2607394"
};

public void OnPluginStart()
{
	CreateConVar("lmcl4d1settransmit_version", PLUGIN_VERSION, "LMCL4D1SetTransmit_version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
}


public Action HideModel(int iEntity, int iClient)
{
	if(IsFakeClient(iClient))
		return Plugin_Continue;
	
	static int iOwner;
	iOwner = GetClientOfUserId(iHiddenOwner[iEntity]);
	if(!IsPlayerAlive(iClient))
	{
		if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 4)
		{
			if(GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget") == iOwner)
			{
				switch(GetClientTeam(iOwner))
				{
					case 2:
					{
						if(IsSurvivorThirdPerson(iOwner, true))
							return Plugin_Continue;
					}
					case 3:
					{
						if(IsInfectedThirdPerson(iOwner, true))
							return Plugin_Continue;
					}
				}
				return Plugin_Handled;
			}
		}
	}
	
	
	if(iOwner < 1 || !IsClientInGame(iOwner))
		return Plugin_Continue;
	
	switch(GetClientTeam(iOwner)) 
	{
		case 2: 
		{
			if(iOwner != iClient)
				return Plugin_Continue;
			
			if(!IsSurvivorThirdPerson(iClient, false))
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
				
				if(!IsInfectedThirdPerson(iOwner, false))
					return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}


static bool IsSurvivorThirdPerson(int iClient, bool bSpecCheck)
{
	if(!bSpecCheck)
	{
		if(bThirdPerson[iClient])
			return true;
		
		if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == 1)
			return true;
	}
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_healTarget") > 0)
		return true;
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > GetGameTime())
		return true;
	
	static char sModel[31];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	switch(sModel[29])
	{
		case 'v'://bill
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 535, 537, 539, 540, 541, 542:
				return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 517, 519, 521, 522, 523, 524:
				return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 536, 538, 540, 541, 542, 543:
				return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
			{
				case 535, 537, 539, 540, 541, 542:
				return true;
			}
		}
	}
	return false;
}

static bool IsInfectedThirdPerson(int iClient, bool bSpecCheck)
{
	if(!bSpecCheck)
	{
		if(bThirdPerson[iClient])
			return true;
	}
	if(GetEntPropFloat(iClient, Prop_Send, "m_staggerTimer", 1) > GetGameTime())
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_hViewEntity") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_tongueVictim") > 0)
		return true;
	if(GetEntPropEnt(iClient, Prop_Send, "m_pounceVictim") > 0)
		return true;
	/*
	There is still a bug in l4d1 xbox where infected can revive survivors that are down this seems to be fixed on pc.
	if(GetEntPropEnt(iClient, Prop_Send, "m_reviveTarget") > 0)
		return true;
	*/
	if(view_as<ZOMBIECLASS>(GetEntProp(iClient, Prop_Send, "m_zombieClass")) == ZOMBIECLASS_TANK)
	{
		switch(GetEntProp(iClient, Prop_Send, "m_nSequence"))
		{
			case 47, 48, 49, 71, 72, 73, 74, 75:
			return true;
		}
	}
	
	return false;
}

public void TP_OnThirdPersonChanged(int iClient, bool bIsThirdPerson)
{
	bThirdPerson[iClient] = bIsThirdPerson;
}

public int SetTransmit(Handle plugin, int numParams)
{
	if(numParams < 3)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	int iClient = GetNativeCell(1);
	if(iClient < 1 || iClient > MaxClients)
		ThrowNativeError(SP_ERROR_PARAM, "Client index out of bounds %i", iClient);
	
	if(!IsClientInGame(iClient))
		ThrowNativeError(SP_ERROR_ABORTED, "Client is not ingame %i", iClient);
	
	int iEntity = GetNativeCell(2);
	if(iEntity < MaxClients+1 || iEntity > 2048)
		ThrowNativeError(SP_ERROR_PARAM, "Entity index out of bounds %i", iEntity);
	
	if(!IsValidEntity(iEntity))
		ThrowNativeError(SP_ERROR_ABORTED, "Entity is Invalid %i", iEntity);
	
	if(GetNativeCell(3))
	{
		iHiddenOwner[iEntity] = GetClientUserId(iClient);
		SDKHookEx(iEntity, SDKHook_SetTransmit, HideModel);
		return;
	}
	SDKUnhook(iEntity, SDKHook_SetTransmit, HideModel);
}
