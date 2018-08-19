#if defined _L4D2ModelChanger_included
	#endinput
#endif
#define _L4D2ModelChanger_included

enum LMCModelType
{
	LMCModelType_NoModel = 1,
	LMCModelType_WitchNormal,
	LMCModelType_WitchBride,
	LMCModelType_InfectedBoomer,
	LMCModelType_InfectedBoomette,
	LMCModelType_InfectedHunter,
	LMCModelType_InfectedSmoker,
	LMCModelType_InfectedRiotcop,
	LMCModelType_InfectedMudman,
	LMCModelType_NPCPilot,
	LMCModelType_InfectedCeda,
	LMCModelType_InfectedClown,
	LMCModelType_InfectedJimmyGibs,
	LMCModelType_InfectedFallenSurvivor,
	LMCModelType_InfectedRandomCommon,
	LMCModelType_SurvivorNick,
	LMCModelType_SurvivorRochelle,
	LMCModelType_SurvivorCoach,
	LMCModelType_SurvivorEllis,
	LMCModelType_SurvivorBill,
	LMCModelType_SurvivorZoey,
	LMCModelType_SurvivorFrancis,
	LMCModelType_SurvivorLouis,
	LMCModelType_InfectedTank,
	LMCModelType_InfectedTankDLC3,
}


/**
*   Show and Hide Client overlay models.
*   Note@If client changes model with menu that could effect the hidden toggle.
*
*   @param  iClient     Client Index
*   @param  bHide       true = hide \ false = unhide (toggle effect)
*   @return true        If action was successful false othewise.
*/
native bool LMC_HideClientOverlayModel(int iEntity, bool bHide);

/**
*   @note Entity Overlays have different array from Client overlays
*
*   @param  iEntity     Entity Index Gets entity model overlay
*   @return             Entity Index, -1 on invalid.
*/
native int LMC_GetEntityOverlayModel(int iEntity);

/**
*   @note Don't use this on Clients because it would not hide the model in Firstperson and is less securty for Clients if used.
*   @note if used on entities that don't have m_nGlowRange entprop could throw errors(i'm not sure).
*
*   @param  iEntity     Entity Index.
*   @param  sModel      Model Path of the model you wish to apply.
*   @return             Overlay Model index, -1 on unable create.
*/
native int LMC_SetEntityOverlayModel(int iEntity, char sModel[PLATFORM_MAX_PATH]);

/**
*   @param  iClient     Client Index.
*   @return             Entity Index, -1 on invalid.
*/
native int LMC_GetClientOverlayModel(int iClient);

/**
*   @note LMC_OnClientModelAppliedPre/LMC_OnClientModelSelected will be Skipped.
*
*   This cannot be blocked by plugin (unless LMC is modified)
*
*   @param  iClient     Client Index.
*   @param  sModel      Model Path of the model you wish to apply.
*   @return             Overlay Model index, -1 on unable create.
*/
native int LMC_SetClientOverlayModel(int iClient, char sModel[PLATFORM_MAX_PATH]);


/**
*   @note this is called instead of LMC_OnClientModelApplied if the overlay model already exists.
*
*   @param  iClient     Client Index.
*   @param  iEntity     Entity Reference, of OverlayModel
*   @param  sModel      Model Path Of Entity.
*   @no return;
*/
forward void LMC_OnClientModelChanged(int iClient, int iEntity, const char sModel[PLATFORM_MAX_PATH]);

/**
*   After Overlay model Applied
@   @Note This can be called twice On When a client is put in server.
*   @Note This is Called Instead of LMC_OnClientModelChanged if overlaymodel entity does not exist.
*   @Note This will be called if the base model is change(Client model) to stop messed up bones clientside, if you don't wan't this to be called Prevent the model from changing.
*
*   @param  iClient         Client Index.
*   @param  iEntity         Entity Index, of OverlayModel
*   @param  sModel          Model Path Of Entity.
*   @param  bBaseReattach   Was model reattach true if so, false otherwise(When the basemodel is changed to remove any clientside errors of missplaced bones)
*   @no return;
*/
forward void LMC_OnClientModelApplied(int iClient, int iEntity, const char sModel[PLATFORM_MAX_PATH], bool bBaseReattach);

/**
*   Before LMC_OnClientModelApplied but after LMC_OnModelSelected
*   @note Cookie will have already besaved and won't effect and model won't be saved for next respawn.
*   You can only Set models  that are already defined in l4d2modelchanger use LMC_OnModelSelected
*   to use other models.
*
*   @note this will obey cvars set in l4d2modelchanger use LMC_OnModelSelected to change to any model
*
*   @param  iClient     Client Index.
*   @param  iModelType  ModelIndex  Refer to LMCModelType enum
*   @return Plugin_Handled/Plugin_Stop to block, Plugin_Changed to change model Index
*/
forward Action LMC_OnClientModelAppliedPre(int iClient, LMCModelType &iModel);

/**
*   before Cookie saving and cvar checks
*   @note block this will not save the model the client has selected and cookie wont be updated.
*   @note LMC_OnClientModelAppliedPre wont be called if changing model here.
*   @note LMC_OnClientModelApplied will be called using this forward.
*
*   This Can not be blocked by plugin (unless LMC is modified)
*
*   @param  iClient     Client Index.
*   @param  sModel      return Plugin_Changed Model Path to change model
*   @return Plugin_Handled/Plugin_Stop to block, Plugin_Changed to change model to sModel
*/
forward Action LMC_OnClientModelSelected(int iClient, char sModel[PLATFORM_MAX_PATH]);

/**
*   @note This is Only called for Client models not for entity models
*
*   @param  iClient     Client Index who had the model.
*   @param  iEntity     Entity Index of OverlayModel
*   @no return
*/
forward void LMC_OnClientModelDestroyed(int iClient, int iEntity);

/**
*	This is called when lmc_hide_defib_model > -1 cvar
*
*	@param 	iClient		Client Index who died.
*	@param 	iEntity		Entity Index of Deathmodel for client who died
*	@param	iOverlayModel 	Entity Index of Deathmodel overlaymodel -1 if don't exist
*	@no return
*/
forward void LMC_OnClientDeathModelCreated(int iClient, int iDeathModel, int iOverlayModel);