#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <L4D2ModelChanger>
#pragma newdecls required

#define PLUGIN_VERSION "cakeChocoA"

#define HUMAN_MODEL_PATH_SIZE 11
#define SPECIAL_MODEL_PATH_SIZE 8
#define UNCOMMON_MODEL_PATH_SIZE 6
#define COMMON_MODEL_PATH_SIZE 34

native int LMC_GetClientOverlayModel(int iClient);
native int LMC_SetClientOverlayModel(int iClient, char sModel[PLATFORM_MAX_PATH]);
native int LMC_GetEntityOverlayModel(int iEntity);
native int LMC_SetEntityOverlayModel(int iEntity, char sModel[PLATFORM_MAX_PATH]);

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

enum LMCModelSectionType
{
	LMCModelSectionType_Human = 0,
	LMCModelSectionType_Special,
	LMCModelSectionType_UnCommon,
	LMCModelSectionType_Common
};

static const char sHumanPaths[HUMAN_MODEL_PATH_SIZE][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_teenangst_light.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_biker_light.mdl",
	"models/survivors/survivor_manager.mdl",
	"models/npcs/rescue_pilot_01.mdl"
};

enum LMCHumanModelType
{
	LMCHumanModelType_Nick = 0,
	LMCHumanModelType_Rochelle,
	LMCHumanModelType_Coach,
	LMCHumanModelType_Ellis,
	LMCHumanModelType_Bill,
	LMCHumanModelType_Zoey,
	LMCHumanModelType_ZoeyLight,
	LMCHumanModelType_Francis,
	LMCHumanModelType_FrancisLight,
	LMCHumanModelType_Louis,
	LMCHumanModelType_Pilot
};

static char sSpecialPaths[SPECIAL_MODEL_PATH_SIZE][] =
{
	"models/infected/witch.mdl",
	"models/infected/witch_bride.mdl",
	"models/infected/boomer.mdl",
	"models/infected/boomette.mdl",
	"models/infected/hunter.mdl",
	"models/infected/smoker.mdl",
	"models/infected/hulk.mdl",
	"models/infected/hulk_dlc3.mdl"
};

enum LMCSpecialModelType
{
	LMCSpecialModelType_Witch = 0,
	LMCSpecialModelType_WitchBride,
	LMCSpecialModelType_Boomer,
	LMCSpecialModelType_Boomette,
	LMCSpecialModelType_Hunter,
	LMCSpecialModelType_Smoker,
	LMCSpecialModelType_Tank,
	LMCSpecialModelType_TankDLC3
};

static const char sUnCommonPaths[UNCOMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_riot.mdl",
	"models/infected/common_male_mud.mdl",
	"models/infected/common_male_ceda.mdl",
	"models/infected/common_male_clown.mdl",
	"models/infected/common_male_jimmy.mdl",
	"models/infected/common_male_fallen_survivor.mdl"
};

enum LMCUnCommonModelType
{
	LMCUnCommonModelType_RiotCop = 0,
	LMCUnCommonModelType_MudMan,
	LMCUnCommonModelType_Ceda,
	LMCUnCommonModelType_Clown,
	LMCUnCommonModelType_Jimmy,
	LMCUnCommonModelType_Fallen
};

static const char sCommonPaths[COMMON_MODEL_PATH_SIZE][] =
{
	"models/infected/common_male_tshirt_cargos.mdl",
	"models/infected/common_male_tankTop_jeans.mdl",
	"models/infected/common_male_dressShirt_jeans.mdl",
	"models/infected/common_female_tankTop_jeans.mdl",
	"models/infected/common_female_tshirt_skirt.mdl",
	"models/infected/common_male_roadcrew.mdl",
	"models/infected/common_male_tankTop_overalls.mdl",
	"models/infected/common_male_tankTop_jeans_rain.mdl",
	"models/infected/common_female_tankTop_jeans_rain.mdl",
	"models/infected/common_male_roadcrew_rain.mdl",
	"models/infected/common_male_tshirt_cargos_swamp.mdl",
	"models/infected/common_male_tankTop_overalls_swamp.mdl",
	"models/infected/common_female_tshirt_skirt_swamp.mdl",
	"models/infected/common_male_formal.mdl",
	"models/infected/common_female_formal.mdl",
	"models/infected/common_military_male01.mdl",
	"models/infected/common_police_male01.mdl",
	"models/infected/common_male_baggagehandler_01.mdl",
	"models/infected/common_tsaagent_male01.mdl",
	"models/infected/common_shadertest.mdl",
	"models/infected/common_female_nurse01.mdl",
	"models/infected/common_surgeon_male01.mdl",
	"models/infected/common_worker_male01.mdl",
	"models/infected/common_morph_test.mdl",
	"models/infected/common_male_biker.mdl",
	"models/infected/common_female01.mdl",
	"models/infected/common_male01.mdl",
	"models/infected/common_male_suit.mdl",
	"models/infected/common_patient_male01_l4d2.mdl",
	"models/infected/common_male_polo_jeans.mdl",
	"models/infected/common_female_rural01.mdl",
	"models/infected/common_male_rural01.mdl",
	"models/infected/common_male_pilot.mdl",
	"models/infected/common_test.mdl"
};


#define CvarIndexes 8
static const char sSharedCvarNames[CvarIndexes][] =
{
	"lmc_allowtank",
	"lmc_allowhunter",
	"lmc_allowsmoker",
	"lmc_allowboomer",
	"lmc_allowSurvivors",
	"lmc_ai_model_survivor",
	"lmc_ai_model_infected",
	"lmc_allow_tank_model_use"
};
static Handle hCvar_ArrayIndex[CvarIndexes] = {INVALID_HANDLE, ...};

static bool g_bAllowTank = false;
static bool g_bAllowHunter = true;
static bool g_bAllowSmoker = true;
static bool g_bAllowBoomer = true;
static bool g_bAllowSurvivors = true;
static int g_iChanceSurvivor = 10;
static int g_iChanceInfected = 20;
static bool g_bTankModel = false;

static Handle hCvar_RNGHumans = INVALID_HANDLE;
static bool g_bRNGHumans = false; 

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("L4D2ModelChanger"))
		SetFailState("[LMC]LMC_Core notloaded, load LMC_Core and reload plugin.");
	
	HookCvars();
}

public void OnPluginStart()
{
	CreateConVar("lmc_randomaispawns_version", PLUGIN_VERSION, "LMC_RandomAiSpawns_Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	hCvar_RNGHumans = CreateConVar("lmc_rng_humans", "0", "Allow humans to be considered by rng, menu selection will overwrite this in LMC_Menu_Choosing", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(hCvar_RNGHumans, eConvarChanged);
	AutoExecConfig(true, "LMC_RandomSpawns");
	CvarsChanged();
	
	HookEvent("player_spawn", ePlayerSpawn);
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	if(hCvar_ArrayIndex[0] != INVALID_HANDLE)
		g_bAllowTank = GetConVarInt(hCvar_ArrayIndex[0]) > 0;
	if(hCvar_ArrayIndex[1] != INVALID_HANDLE)
		g_bAllowHunter = GetConVarInt(hCvar_ArrayIndex[1]) > 0;
	if(hCvar_ArrayIndex[2] != INVALID_HANDLE)
		g_bAllowSmoker = GetConVarInt(hCvar_ArrayIndex[2]) > 0;
	if(hCvar_ArrayIndex[3] != INVALID_HANDLE)
		g_bAllowBoomer = GetConVarInt(hCvar_ArrayIndex[3]) > 0;
	if(hCvar_ArrayIndex[4] != INVALID_HANDLE)
		g_bAllowSurvivors = GetConVarInt(hCvar_ArrayIndex[4]) > 0;
	if(hCvar_ArrayIndex[5] != INVALID_HANDLE)
		g_iChanceSurvivor = GetConVarInt(hCvar_ArrayIndex[5]);
	if(hCvar_ArrayIndex[6] != INVALID_HANDLE)
		g_iChanceInfected = GetConVarInt(hCvar_ArrayIndex[6]);
	if(hCvar_ArrayIndex[7] != INVALID_HANDLE)
		g_bTankModel = GetConVarInt(hCvar_ArrayIndex[7]) > 0;
	
	g_bRNGHumans = GetConVarInt(hCvar_RNGHumans) > 0;
}

void HookCvars()
{
	for(int i = 0; i <= CvarIndexes; i++)
	{
		if(hCvar_ArrayIndex[i] != INVALID_HANDLE)
			continue;
		
		if((hCvar_ArrayIndex[i] = FindConVar(sSharedCvarNames[i])) == INVALID_HANDLE)
		{
			PrintToServer("[LMC]Unable to find shared cvar \"%s\" using fallback value.", sSharedCvarNames[i]);
			continue;
		}
		HookConVarChange(hCvar_ArrayIndex[i], eConvarChanged);
	}
}

public void OnMapStart()
{
	int i;
	for(i = 0; i < HUMAN_MODEL_PATH_SIZE; i++)
		PrecacheModel(sHumanPaths[i], true);
	
	for(i = 0; i < SPECIAL_MODEL_PATH_SIZE; i++)
		PrecacheModel(sSpecialPaths[i], true);
	
	for(i = 0; i < UNCOMMON_MODEL_PATH_SIZE; i++)
		PrecacheModel(sUnCommonPaths[i], true);
	
	for(i = 0; i < COMMON_MODEL_PATH_SIZE; i++)
		PrecacheModel(sCommonPaths[i], true);
	
	HookCvars();
	CvarsChanged();
}

public void ePlayerSpawn(Handle hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iUserID = GetEventInt(hEvent, "userid");
	int iClient = GetClientOfUserId(iUserID);
	if(iClient < 1 || iClient > MaxClients)
		return;
	
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || (!IsFakeClient(iClient) && !g_bRNGHumans))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_nMinGPULevel", 0);
	SetEntProp(iClient, Prop_Send, "m_nMaxGPULevel", 0);
	
	switch(GetClientTeam(iClient))
	{
		case 3:
		{
			switch(GetEntProp(iClient, Prop_Send, "m_zombieClass"))//1.4
			{
				case ZOMBIECLASS_SMOKER:
				{
					if(!g_bAllowSmoker)
						return;
				}
				case ZOMBIECLASS_BOOMER:
				{
					if(!g_bAllowBoomer)
						return;
				}
				case ZOMBIECLASS_HUNTER:
				{
					if(!g_bAllowHunter)
						return;
				}
				case ZOMBIECLASS_CHARGER, ZOMBIECLASS_JOCKEY, ZOMBIECLASS_SPITTER, ZOMBIECLASS_UNKNOWN:
				{
					return;
				}
				case ZOMBIECLASS_TANK:
				{
					if(!g_bAllowTank)
						return;
				}
				default:
				{
					return;
				}
			}
		}
		case 2:
		{
			if(!g_bAllowSurvivors)
				return;
		}
		default:
		{
			return;
		}
	}
	
	RequestFrame(NextFrame, iUserID);
}

public void NextFrame(int iUserID)
{
	int iClient = GetClientOfUserId(iClient);
	if(iClient < 1 || !IsPlayerAlive(iClient))
		return;
	
	if(LMC_GetClientOverlayModel(iClient) > 0)
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	
	int iTeam = GetClientTeam(iClient);
	if(iTeam == 2)
	{
		if(GetRandomInt(1, 100) <= g_iChanceSurvivor)
			if(!ChooseRNGModel(sModel))
				return;
	}
	else if(iTeam == 3)
	{
		if(GetRandomInt(1, 100) <= g_iChanceInfected)
			if(!ChooseRNGModel(sModel))
				return;
	}
	if(!SameModel(iClient, sModel))
		LMC_SetClientOverlayModel(iClient, sModel);
}

bool ChooseRNGModel(char sModel[PLATFORM_MAX_PATH])
{
	switch(GetRandomInt(0, 3))
	{
		case LMCModelSectionType_Human:
			strcopy(sModel, sizeof(sModel), sHumanPaths[GetRandomInt(0, HUMAN_MODEL_PATH_SIZE)]);
		case LMCModelSectionType_Special:
		{
			int iRNG = GetRandomInt(0, SPECIAL_MODEL_PATH_SIZE);
			if(!g_bTankModel && (iRNG == view_as<int>(LMCSpecialModelType_Tank) || view_as<int>(LMCSpecialModelType_TankDLC3)))
				return false;
			
			strcopy(sModel, sizeof(sModel), sSpecialPaths[iRNG]);
		}
		case LMCModelSectionType_UnCommon:
			strcopy(sModel, sizeof(sModel), sUnCommonPaths[GetRandomInt(0, UNCOMMON_MODEL_PATH_SIZE)]);
		case LMCModelSectionType_Common:
			strcopy(sModel, sizeof(sModel), sCommonPaths[GetRandomInt(0, COMMON_MODEL_PATH_SIZE)]);
	}
	return true;
}

bool SameModel(int iClient, const char[] sPendingModel)
{
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(iClient, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	return StrEqual(sModel, sPendingModel, false);
}