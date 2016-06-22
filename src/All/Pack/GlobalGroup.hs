{-# LANGUAGE RecordWildCards #-}

module All.Pack.GlobalGroup (
  -- Handler
  getGlobalGroupPacksR,
  getGlobalGroupPackR,
  getGlobalGroupPackH,

  -- Model

) where



import           All.GlobalGroup
import           All.Prelude
import           All.User



--
-- Handler
--

getGlobalGroupPacksR :: HandlerEff Value
getGlobalGroupPacksR = run $ do
  user_id <- _requireAuthId
  toJSON <$> getGlobalGroupPacksM user_id



getGlobalGroupPackR :: GlobalGroupId -> HandlerEff Value
getGlobalGroupPackR global_group_id = do
  user_id <- _requireAuthId
  toJSON <$> getGlobalGroupPackM user_id global_group_id



getGlobalGroupPackH :: Text -> HandlerEff Value
getGlobalGroupPackH global_group_name = do
  user_id <- _requireAuthId
  toJSON <$> getGlobalGroupPackMH user_id global_group_name







-- Model

getGlobalGroupPacksM :: UserId -> HandlerEff GlobalGroupPackResponses
getGlobalGroupPacksM user_id = do

  sp@StandardParams{..} <- lookupStandardParams

  case spUserId of

    Just lookup_user_id -> getGlobalGroupPacks_ByUserIdM user_id lookup_user_id sp
    _                   -> getGlobalGroupPacks_ByEverythingM user_id sp



getGlobalGroupPackM :: UserId -> GlobalGroupId -> HandlerEff GlobalGroupPackResponse
getGlobalGroupPackM user_id global_group_id = do

  globalGroup         <- getGlobalGroupM user_id global_group_id
  getGlobalGroupPack_ByGlobalGroupM user_id globalGroup



getGlobalGroupPackMH :: UserId -> Text -> HandlerEff GlobalGroupPackResponse
getGlobalGroupPackMH user_id global_group_name = do

  globalGroup         <- getGlobalGroupMH user_id global_group_name
  getGlobalGroupPack_ByGlobalGroupM user_id globalGroup



getGlobalGroupPacks_ByEverythingM :: UserId -> StandardParams -> HandlerEff GlobalGroupPackResponses
getGlobalGroupPacks_ByEverythingM user_id sp = do
  globalGroups       <- getGlobalGroups_ByEverythingM user_id sp
  globalGroups_packs <- mapM (\globalGroup -> getGlobalGroupPack_ByGlobalGroupM user_id globalGroup) globalGroups
  return $ GlobalGroupPackResponses {
    globalGroupPackResponses = globalGroups_packs
  }



getGlobalGroupPacks_ByUserIdM :: UserId -> UserId -> StandardParams -> HandlerEff GlobalGroupPackResponses
getGlobalGroupPacks_ByUserIdM user_id lookup_user_id sp = do

  globalGroups       <- getGlobalGroups_ByUserIdM user_id lookup_user_id sp
  globalGroups_packs <- mapM (\globalGroup -> getGlobalGroupPack_ByGlobalGroupM user_id globalGroup) globalGroups
  return $ GlobalGroupPackResponses {
    globalGroupPackResponses = globalGroups_packs
  }



getGlobalGroupPack_ByGlobalGroupM :: UserId -> Entity GlobalGroup -> HandlerEff GlobalGroupPackResponse
getGlobalGroupPack_ByGlobalGroupM user_id global_group@(Entity global_group_id GlobalGroup{..}) = do

  -- let sp = defaultStandardParams {
  --     spSortOrder = Just SortOrderBy_Dsc,
  --     spOrder     = Just OrderBy_ActivityAt,
  --     spLimit     = Just 1
  --   }

  global_group_user    <- getUserM user_id globalGroupUserId
  global_group_stats   <- getGlobalGroupStatM user_id (entityKey global_group)

  return $ GlobalGroupPackResponse {
    globalGroupPackResponseUser          = userToSanitizedResponse global_group_user,
    globalGroupPackResponseUserId        = entityKeyToInt64 global_group_user,
    globalGroupPackResponseGlobalGroup   = globalGroupToResponse global_group,
    globalGroupPackResponseGlobalGroupId = keyToInt64 global_group_id,
    globalGroupPackResponseStat          = global_group_stats,
    globalGroupPackResponsePermissions   = emptyPermissions
  }
