module All.GlobalGroup (
  -- Handler
  getGlobalGroupsR,
  postGlobalGroupR0,
  getGlobalGroupR,
  getGlobalGroupH,
  putGlobalGroupR,
  deleteGlobalGroupR,
  getCountGlobalGroupsR,
  getGlobalGroupStatsR,
  getGlobalGroupStatR,

  -- Model/Functions
  globalGroupRequestToGlobalGroup,
  globalGroupToResponse,
  globalGroupsToResponses,

  -- Model/internal
  getGlobalGroupsM,
  getGlobalGroups_ByUserIdM,
  getGlobalGroups_ByEverythingM,
  getGlobalGroupM,
  getGlobalGroupMH,
  getGlobalGroupMH',
  insertGlobalGroupM,
  updateGlobalGroupM,
  deleteGlobalGroupM,
  getGlobalGroupStatsM,
  getGlobalGroupStatM
) where



import           Handler.Prelude
import           Model.Prelude



getGlobalGroupsR :: HandlerEff Value
getGlobalGroupsR = do
  user_id <- requireAuthId
  (toJSON . globalGroupsToResponses) <$> getGlobalGroupsM user_id



postGlobalGroupR0 :: HandlerEff Value
postGlobalGroupR0 = do

  user_id <- requireAuthId

  global_group_request <- requireJsonBody :: HandlerEff GlobalGroupRequest
  (toJSON . globalGroupToResponse) <$> insertGlobalGroupM user_id global_group_request



getGlobalGroupR :: GlobalGroupId -> HandlerEff Value
getGlobalGroupR global_group_id = do
  user_id <- requireAuthId
  (toJSON . globalGroupToResponse) <$> getGlobalGroupM user_id global_group_id



getGlobalGroupH :: Text -> HandlerEff Value
getGlobalGroupH group_name = do
  user_id <- requireAuthId
  (toJSON . globalGroupToResponse) <$> getGlobalGroupMH user_id group_name



putGlobalGroupR :: GlobalGroupId -> HandlerEff Value
putGlobalGroupR global_group_id = do
  user_id <- requireAuthId
  global_group_request <- requireJsonBody
  (toJSON . globalGroupToResponse) <$> updateGlobalGroupM user_id global_group_id global_group_request



deleteGlobalGroupR :: GlobalGroupId -> HandlerEff Value
deleteGlobalGroupR global_group_id = do
  user_id <- requireAuthId
  void $ deleteGlobalGroupM user_id global_group_id
  sendResponseStatus status200 ("DELETED" :: Text)



getCountGlobalGroupsR :: HandlerEff Value
getCountGlobalGroupsR = do
  user_id <- requireAuthId
  toJSON <$> countGlobalGroupsM user_id



getGlobalGroupStatsR :: HandlerEff Value
getGlobalGroupStatsR = do
  user_id <- requireAuthId
  toJSON <$> getGlobalGroupStatsM user_id



getGlobalGroupStatR :: GlobalGroupId -> HandlerEff Value
getGlobalGroupStatR global_group_id = do
  user_id <- requireAuthId
  toJSON <$> getGlobalGroupStatM user_id global_group_id







-- Model/Function

globalGroupRequestToGlobalGroup :: UserId -> GlobalGroupRequest -> GlobalGroup
globalGroupRequestToGlobalGroup user_id GlobalGroupRequest{..} = GlobalGroup {
  globalGroupUserId      = user_id,
  globalGroupName        = toPrettyUrl globalGroupRequestDisplayName,
  globalGroupDisplayName = globalGroupRequestDisplayName,
  globalGroupDescription = globalGroupRequestDescription,
  globalGroupMembership  = globalGroupRequestMembership,
  globalGroupIcon        = globalGroupRequestIcon,
  globalGroupTags        = globalGroupRequestTags,
  globalGroupVisibility  = globalGroupRequestVisibility,
  globalGroupActive      = True,
  globalGroupGuard       = globalGroupRequestGuard,
  globalGroupCreatedAt   = Nothing,
  globalGroupModifiedBy  = Nothing,
  globalGroupModifiedAt  = Nothing,
  globalGroupActivityAt  = Nothing
}



globalGroupToResponse :: Entity GlobalGroup -> GlobalGroupResponse
globalGroupToResponse (Entity global_groupid GlobalGroup{..}) = GlobalGroupResponse {
  globalGroupResponseId          = keyToInt64 global_groupid,
  globalGroupResponseUserId      = keyToInt64 globalGroupUserId,
  globalGroupResponseName        = globalGroupName,
  globalGroupResponseDisplayName = globalGroupDisplayName,
  globalGroupResponseDescription = globalGroupDescription,
  globalGroupResponseMembership  = globalGroupMembership,
  globalGroupResponseIcon        = globalGroupIcon,
  globalGroupResponseTags        = globalGroupTags,
  globalGroupResponseVisibility  = globalGroupVisibility,
  globalGroupResponseActive      = globalGroupActive,
  globalGroupResponseGuard       = globalGroupGuard,
  globalGroupResponseCreatedAt   = globalGroupCreatedAt,
  globalGroupResponseModifiedBy  = fmap keyToInt64 globalGroupModifiedBy,
  globalGroupResponseModifiedAt  = globalGroupModifiedAt,
  globalGroupResponseActivityAt  = globalGroupActivityAt
}



globalGroupsToResponses :: [Entity GlobalGroup] -> GlobalGroupResponses
globalGroupsToResponses globalGroups = GlobalGroupResponses {
  globalGroupResponses = map globalGroupToResponse globalGroups
}








-- Model/Internal

getGlobalGroupsM :: UserId -> HandlerEff [Entity GlobalGroup]
getGlobalGroupsM user_id = do

  sp@StandardParams{..} <- lookupStandardParams

  case spUserId of
    Just lookup_user_id -> getGlobalGroups_ByUserIdM user_id lookup_user_id sp
    _                   -> notFound



getGlobalGroups_ByUserIdM :: UserId -> UserId -> StandardParams -> HandlerEff [Entity GlobalGroup]
getGlobalGroups_ByUserIdM _ lookup_user_id sp = do
  selectListDb sp [GlobalGroupUserId ==. lookup_user_id] [] GlobalGroupId



getGlobalGroups_ByEverythingM :: UserId -> StandardParams -> HandlerEff [Entity GlobalGroup]
getGlobalGroups_ByEverythingM _ sp = do
  selectListDb sp [] [] GlobalGroupId



getGlobalGroupM :: UserId -> GlobalGroupId -> HandlerEff (Entity GlobalGroup)
getGlobalGroupM _ global_groupid = do
  notFoundMaybe =<< selectFirstDb [ GlobalGroupId ==. global_groupid ] []



getGlobalGroupMH :: UserId -> Text -> HandlerEff (Entity GlobalGroup)
getGlobalGroupMH user_id global_group_name = do

  sp@StandardParams{..} <- lookupStandardParams

  case spUserId of

    Just lookup_user_id -> getGlobalGroup_ByUserIdMH user_id global_group_name user_id sp
    _                   -> getGlobalGroupMH' user_id global_group_name sp



getGlobalGroup_ByUserIdMH :: UserId -> Text -> UserId -> StandardParams -> HandlerEff (Entity GlobalGroup)
getGlobalGroup_ByUserIdMH user_id global_group_name lookup_user_id _ = notFound



getGlobalGroupMH' :: UserId -> Text -> StandardParams -> HandlerEff (Entity GlobalGroup)
getGlobalGroupMH' user_id global_group_name _ = notFound



insertGlobalGroupM :: UserId -> GlobalGroupRequest -> HandlerEff (Entity GlobalGroup)
insertGlobalGroupM user_id global_group_request = do

--  sp <- lookupStandardParams

  ts <- timestampH'

  let
    globalGroup = (globalGroupRequestToGlobalGroup user_id global_group_request) { globalGroupCreatedAt = Just ts }

  insertEntityDb globalGroup



updateGlobalGroupM :: UserId -> GlobalGroupId -> GlobalGroupRequest -> HandlerEff (Entity GlobalGroup)
updateGlobalGroupM user_id global_groupid global_group_request = do

  ts <- timestampH'

  let
    GlobalGroup{..} = (globalGroupRequestToGlobalGroup user_id global_group_request) { globalGroupModifiedAt = Just ts }

  updateWhereDb
    [ GlobalGroupUserId ==. user_id, GlobalGroupId ==. global_groupid ]
    [ GlobalGroupModifiedAt  =. globalGroupModifiedAt
    , GlobalGroupName        =. globalGroupName
    , GlobalGroupDisplayName =. globalGroupDisplayName
    , GlobalGroupDescription =. globalGroupDescription
    , GlobalGroupMembership  =. globalGroupMembership
    , GlobalGroupIcon        =. globalGroupIcon
    , GlobalGroupTags        =. globalGroupTags
    , GlobalGroupVisibility  =. globalGroupVisibility
    , GlobalGroupGuard      +=. globalGroupGuard
    ]

  notFoundMaybe =<< selectFirstDb [ GlobalGroupUserId ==. user_id, GlobalGroupId ==. global_groupid ] []



deleteGlobalGroupM :: UserId -> GlobalGroupId -> HandlerEff ()
deleteGlobalGroupM user_id global_groupid = do
  deleteWhereDb [ GlobalGroupUserId ==. user_id, GlobalGroupId ==. global_groupid ]



countGlobalGroupsM :: UserId -> HandlerEff CountResponses
countGlobalGroupsM _ = do

  StandardParams{..} <- lookupStandardParams

  case spUserId of

    Nothing             -> do
      notFound
--      n <- countDb [ GlobalGroupId /=. 0 ]
--      return $ CountResponses [CountResponse (fromIntegral 0) (fromIntegral n)]

    Just lookup_user_id -> do
      n <- countDb [ GlobalGroupUserId ==. lookup_user_id ]
      return $ CountResponses [CountResponse (keyToInt64 lookup_user_id) (fromIntegral n)]



getGlobalGroupStatsM :: UserId -> HandlerEff GlobalGroupStatResponses
getGlobalGroupStatsM _ = do

  StandardParams{..} <- lookupStandardParams

  case spBoardId of

    Just _  -> notFound
    Nothing -> notFound



getGlobalGroupStatM :: UserId -> GlobalGroupId -> HandlerEff GlobalGroupStatResponse
getGlobalGroupStatM _ global_group_id = do

  return $ GlobalGroupStatResponse {
    globalGroupStatResponseGroups = 0 -- TODO FIXME
  }
