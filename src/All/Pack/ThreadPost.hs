{-# LANGUAGE RecordWildCards #-}

module All.Pack.ThreadPost (
  -- Handler
  getThreadPostPacksR,
  getThreadPostPackR,

  -- Model
  getThreadPostPacksM,
  getThreadPostPackM
) where



import           All.Like
import           All.Prelude
import           All.Star
import           All.ThreadPost
import           All.User



--
-- Handler
--

getThreadPostPacksR :: Handler Value
getThreadPostPacksR = do
  user_id <- requireAuthId
  toJSON <$> getThreadPostPacksM user_id



getThreadPostPackR :: ThreadPostId -> Handler Value
getThreadPostPackR thread_post_id = do
  user_id <- requireAuthId
  toJSON <$> getThreadPostPackM user_id thread_post_id






--
-- Model
--
getThreadPostPacksM :: UserId -> Handler ThreadPostPackResponses
getThreadPostPacksM user_id = do

  sp <- lookupStandardParams

  thread_posts <- getThreadPostsM user_id
  thread_post_packs <- mapM (\thread_post -> getThreadPostPack_ByThreadPostM user_id thread_post sp) thread_posts

  return $ ThreadPostPackResponses {
    threadPostPackResponses = thread_post_packs
  }



getThreadPostPackM :: UserId -> ThreadPostId -> Handler ThreadPostPackResponse
getThreadPostPackM user_id thread_post_id = do

  sp <- lookupStandardParams

  thread_post <- getThreadPostM user_id thread_post_id
  getThreadPostPack_ByThreadPostM user_id thread_post (sp { spLimit = Just 1 })



getThreadPostPack_ByThreadPostM :: UserId -> Entity ThreadPost -> StandardParams -> Handler ThreadPostPackResponse
getThreadPostPack_ByThreadPostM user_id thread_post@(Entity thread_post_id ThreadPost{..}) StandardParams{..} = do

  thread_post_user <- getUserM user_id threadPostUserId
  thread_post_stat <- getThreadPostStatM user_id thread_post_id
  thread_post_like <- getLike_ByThreadPostIdM user_id thread_post_id

--  thread_post_star <- getThreadPostStar_ByThreadPostM user_id thread_post

  -- TODO FIXME: this needs to be a function argument
  org <- (if spWithOrganization
             then pure Nothing
             else pure Nothing)

  return $ ThreadPostPackResponse {
    threadPostPackResponseThreadPost       = threadPostToResponse thread_post,
    threadPostPackResponseThreadPostId     = keyToInt64 thread_post_id,
    threadPostPackResponseUser             = userToSanitizedResponse thread_post_user,
    threadPostPackResponseUserId           = entityKeyToInt64 thread_post_user,
    threadPostPackResponseStat             = thread_post_stat,
    threadPostPackResponseLike             = fmap likeToResponse thread_post_like,
    threadPostPackResponseStar             = Nothing,
    threadPostPackResponseWithOrganization = org,
    threadPostPackResponseWithForum        = Nothing,
    threadPostPackResponseWithBoard        = Nothing,
    threadPostPackResponseWithThread       = Nothing,
    threadPostPackResponsePermissions      = emptyPermissions
  }
