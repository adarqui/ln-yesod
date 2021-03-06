{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards     #-}

module LN.All.Board (
  -- Handler
  getBoardsR,
  postBoardR0,
  getBoardR,
  getBoardH,
  putBoardR,
  deleteBoardR,
  getBoardStatsR,
  getBoardStatR,

  -- Model/Function
  boardRequestToBoard,
  boardToResponse,
  boardsToResponses,

  -- Model/Internal
  getBoardsM,
  getBoards_ByOrganizationIdM,
  getBoards_ByForumIdM,
  getBoards_ByForumId_KeysM,
  getBoards_ByBoardParentIdM,
  getBoardMH,
  getWithBoardM,
  insertBoardM,
  updateBoardM,
  deleteBoardM,
  getBoardStatsM,
  getBoardStatM,
) where




import           LN.All.Internal
import           LN.All.Prelude
import           LN.All.Forum



--
-- Handler
--

getBoardsR :: Handler Value
getBoardsR = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON boardsToResponses $ getBoardsM (pure sp) user_id



postBoardR0 :: Handler Value
postBoardR0 = run $ do
  user_id       <- _requireAuthId
  board_request <- requireJsonBody :: HandlerEff BoardRequest
  sp            <- lookupStandardParams
  errorOrJSON boardToResponse $ insertBoardM (pure sp) user_id board_request



getBoardR :: BoardId -> Handler Value
getBoardR board_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON boardToResponse $ getBoardM user_id board_id



getBoardH :: Text -> Handler Value
getBoardH board_name = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON boardToResponse $ getBoardMH (pure sp) user_id board_name



putBoardR :: BoardId -> Handler Value
putBoardR board_id = run $ do
  user_id       <- _requireAuthId
  board_request <- requireJsonBody
  errorOrJSON boardToResponse $ updateBoardM user_id board_id board_request



deleteBoardR :: BoardId -> Handler Value
deleteBoardR board_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON id $ deleteBoardM user_id board_id



getBoardStatsR :: Handler Value
getBoardStatsR = notFound



getBoardStatR :: BoardId -> Handler Value
getBoardStatR board_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON id $ getBoardStatM user_id board_id








--
-- Model/Function
--

boardRequestToBoard :: UserId -> OrganizationId -> ForumId -> Maybe BoardId -> BoardRequest -> Board
boardRequestToBoard user_id org_id forum_id m_board_id BoardRequest{..} = Board {
  boardUserId             = user_id,
  boardOrgId              = org_id,
  boardForumId            = forum_id,
  boardParentId           = m_board_id,
  boardName               = toSafeUrl boardRequestDisplayName,
  boardDisplayName        = boardRequestDisplayName,
  boardDescription        = boardRequestDescription,
  boardIsAnonymous        = boardRequestIsAnonymous,
  boardCanCreateSubBoards = boardRequestCanCreateSubBoards,
  boardCanCreateThreads   = boardRequestCanCreateThreads,
  boardSuggestedTags      = boardRequestSuggestedTags,
  boardIcon               = boardRequestIcon,
  boardTags               = boardRequestTags,
  boardActive             = True,
  boardGuard              = boardRequestGuard,
  boardCreatedAt          = Nothing,
  boardModifiedBy         = Nothing,
  boardModifiedAt         = Nothing,
  boardActivityAt         = Nothing
}



boardToResponse :: Entity Board -> BoardResponse
boardToResponse (Entity board_id Board{..}) = BoardResponse {
  boardResponseId                 = keyToInt64 board_id,
  boardResponseUserId             = keyToInt64 boardUserId,
  boardResponseOrgId              = keyToInt64 boardOrgId,
  boardResponseForumId            =  keyToInt64 boardForumId,
  boardResponseParentId           = fmap keyToInt64 boardParentId,
  boardResponseName               = boardName,
  boardResponseDisplayName        = boardDisplayName,
  boardResponseDescription        = boardDescription,
  boardResponseIsAnonymous        = boardIsAnonymous,
  boardResponseCanCreateSubBoards = boardCanCreateSubBoards,
  boardResponseCanCreateThreads   = boardCanCreateThreads,
  boardResponseSuggestedTags      = boardSuggestedTags,
  boardResponseIcon               = boardIcon,
  boardResponseTags               = boardTags,
  boardResponseActive             = boardActive,
  boardResponseGuard              = boardGuard,
  boardResponseCreatedAt          = boardCreatedAt,
  boardResponseModifiedBy         = fmap keyToInt64 boardModifiedBy,
  boardResponseModifiedAt         = boardModifiedAt,
  boardResponseActivityAt         = boardActivityAt
}



boardsToResponses :: [Entity Board] -> BoardResponses
boardsToResponses boards = BoardResponses {
  boardResponses = map boardToResponse boards
}





--
-- Model/Internal
--

getBoardsM :: Maybe StandardParams -> UserId -> HandlerErrorEff [Entity Board]
getBoardsM m_sp user_id = do

  case (lookupSpMay m_sp spOrganizationId, lookupSpMay m_sp spForumId, lookupSpMay m_sp spParentId) of

    (Just org_id, Nothing, Nothing)          -> getBoards_ByOrganizationIdM m_sp user_id org_id
    (Nothing, Just forum_id, Nothing)        -> getBoards_ByForumIdM m_sp user_id forum_id
    (Nothing, Nothing, Just board_parent_id) -> getBoards_ByBoardParentIdM m_sp user_id (int64ToKey' board_parent_id)
    _                                        -> leftA $ Error_InvalidArguments "org_id, forum_id, parent_id"




getBoards_ByOrganizationIdM :: Maybe StandardParams -> UserId -> OrganizationId -> HandlerErrorEff [Entity Board]
getBoards_ByOrganizationIdM m_sp user_id org_id = do

  -- TODO FIXME: move this to esqueleto
   e_forums <- getForums_ByOrganizationIdM m_sp user_id org_id
   rehtie e_forums leftA $ \forums -> do
     boards <- rights <$> mapM (\(Entity forum_id _) -> getBoards_ByForumIdM m_sp user_id forum_id) forums
     rightA $ concat boards



getBoards_ByForumIdM :: Maybe StandardParams -> UserId -> ForumId -> HandlerErrorEff [Entity Board]
getBoards_ByForumIdM m_sp _ forum_id = do

  selectListDbE m_sp [BoardForumId ==. forum_id, BoardActive ==. True] [] BoardId



getBoards_ByForumId_KeysM :: Maybe StandardParams -> UserId -> ForumId -> HandlerErrorEff [Key Board]
getBoards_ByForumId_KeysM m_sp _ forum_id = do

  selectKeysListDbE m_sp [BoardForumId ==. forum_id, BoardActive ==. True] [] BoardId



getBoards_ByBoardParentIdM :: Maybe StandardParams -> UserId -> BoardId -> HandlerErrorEff [Entity Board]
getBoards_ByBoardParentIdM m_sp _ board_parent_id = do

  selectListDbE m_sp [BoardParentId ==. Just board_parent_id, BoardActive ==. True] [] BoardId



getBoardMH :: Maybe StandardParams -> UserId -> Text -> HandlerErrorEff (Entity Board)
getBoardMH m_sp _ board_name = do

  case (lookupSpMay m_sp spForumId) of

    Just forum_id -> do
      selectFirstDbE [BoardName ==. board_name, BoardForumId ==. forum_id, BoardActive ==. True] []

    _             -> leftA $ Error_InvalidArguments "forum_id"



getWithBoardM :: Bool -> UserId -> BoardId -> HandlerErrorEff (Maybe (Entity Board))
getWithBoardM False _ _             = rightA Nothing
getWithBoardM True user_id board_id = fmap Just <$> getBoardM user_id board_id



insertBoardM :: Maybe StandardParams -> UserId -> BoardRequest -> HandlerErrorEff (Entity Board)
insertBoardM m_sp user_id board_request = do

  case (lookupSpMay m_sp spForumId, lookupSpMay m_sp spBoardId) of
    (Just forum_id, _) -> insertBoard_ByForumId user_id forum_id board_request
    (_, Just board_id) -> insertBoard_ByBoardId user_id board_id board_request
    _                  -> leftA $ Error_InvalidArguments "forum_id, board_id"



insertBoard_ByForumId :: UserId -> ForumId -> BoardRequest -> HandlerErrorEff (Entity Board)
insertBoard_ByForumId user_id forum_id board_request = do

  runEitherT $ do
    mustT $ mustBe_OwnerOf_ForumIdM user_id forum_id
    sanitized_board_request <- mustT $ isValidAppM $ validateBoardRequest board_request
    ts                      <- lift timestampH'
    (Entity _ Forum{..})    <- mustT $ selectFirstDbE [ForumId ==. forum_id, ForumActive ==. True] []
    mustT $ insertEntityDbE $ (boardRequestToBoard user_id forumOrgId forum_id Nothing sanitized_board_request) { boardCreatedAt = Just ts }



insertBoard_ByBoardId :: UserId -> BoardId -> BoardRequest -> HandlerErrorEff (Entity Board)
insertBoard_ByBoardId user_id board_id board_request = do

  runEitherT $ do
    mustT $ mustBe_OwnerOf_BoardIdM user_id board_id
    sanitized_board_request <- mustT $ isValidAppM $ validateBoardRequest board_request
    ts                      <- lift timestampH'
    (Entity _ Board{..})    <- mustT $ selectFirstDbE [BoardId ==. board_id, BoardActive ==. True] []
    mustT $ insertEntityDbE $ (boardRequestToBoard user_id boardOrgId boardForumId (Just board_id) sanitized_board_request) { boardCreatedAt = Just ts }



updateBoardM :: UserId -> BoardId -> BoardRequest -> HandlerErrorEff (Entity Board)
updateBoardM user_id board_id board_request = do

  runEitherT $ do

    mustT $ mustBe_OwnerOf_BoardIdM user_id board_id
    sanitized_board_request <- mustT $ isValidAppM $ validateBoardRequest board_request
    ts                      <- lift timestampH'

    let
      Board{..} = (boardRequestToBoard user_id dummyId dummyId Nothing sanitized_board_request) { boardModifiedAt = Just ts }

    mustT $ updateWhereDbE
      [BoardId ==. board_id, BoardActive ==. True]
      [BoardModifiedAt         =. boardModifiedAt
      ,BoardActivityAt         =. Just ts
      ,BoardName               =. boardName
      ,BoardDisplayName        =. boardDisplayName
      ,BoardDescription        =. boardDescription
      ,BoardIsAnonymous        =. boardIsAnonymous
      ,BoardCanCreateSubBoards =. boardCanCreateSubBoards
      ,BoardCanCreateThreads   =. boardCanCreateThreads
      ,BoardSuggestedTags      =. boardSuggestedTags
      ,BoardIcon               =. boardIcon
      ,BoardTags               =. boardTags
      ,BoardGuard             +=. 1
      ]

    mustT $ selectFirstDbE [BoardUserId ==. user_id, BoardId ==. board_id, BoardActive ==. True] []



deleteBoardM :: UserId -> BoardId -> HandlerErrorEff ()
deleteBoardM user_id board_id = do
  runEitherT $ do
    mustT $ mustBe_OwnerOf_BoardIdM user_id board_id
    mustT $ deleteWhereDbE [BoardId ==. board_id, BoardActive ==. True]





getBoardStatsM :: Maybe StandardParams -> UserId -> HandlerErrorEff Value
getBoardStatsM _ _ = leftA Error_NotImplemented



getBoardStatM :: UserId -> BoardId -> HandlerErrorEff BoardStatResponse
getBoardStatM _ board_id = do

  num_threads      <- countDb [ThreadBoardId ==. board_id, ThreadActive ==. True]
  num_thread_posts <- countDb [ThreadPostBoardId ==. board_id, ThreadPostActive ==. True]

  rightA $ BoardStatResponse {
    boardStatResponseBoardId     = keyToInt64 board_id,
    boardStatResponseThreads     = fromIntegral num_threads,
    boardStatResponseThreadPosts = fromIntegral num_thread_posts,
    boardStatResponseViews       = 0
  }
