{-# LANGUAGE BangPatterns   #-}
{-# LANGUAGE ExplicitForAll #-}

module LN.Cache (
  Cache (..),
  CacheEntry (..),
  defaultCache,
  emptyCache
--  cacheRun
) where



import qualified Data.Map                as M
import           LN.Import



data CacheEntry a
  = CacheEntry a
  | CacheMissing



type CacheMap a b = M.Map a (CacheEntry b)



data Cache = Cache {
  cacheMe                :: !(Maybe User),
  cacheOrganizations     :: !(CacheMap OrganizationId (Entity Organization)),
  cacheUsers             :: !(CacheMap UserId (Entity User)),
  cacheTeams             :: !(CacheMap TeamId (Entity Team)),
  cacheTeamsByOrg        :: !(CacheMap OrganizationId [Entity Team]),
  cacheTeamMembersByTeam :: !(CacheMap (TeamId, UserId) (Entity TeamMember)),
  cacheForums            :: !(CacheMap ForumId (Entity Forum)),
  cacheBoards            :: !(CacheMap BoardId (Entity Board)),
  cacheThreads           :: !(CacheMap ThreadId (Entity Thread)),
  cacheThreadPosts       :: !(CacheMap ThreadPostId (Entity ThreadPost))
}



emptyCache :: forall a b. CacheMap a b
emptyCache = M.empty



defaultCache :: Cache
defaultCache = Cache {
  cacheMe                = Nothing,
  cacheOrganizations     = emptyCache,
  cacheUsers             = emptyCache,
  cacheTeams             = emptyCache,
  cacheTeamsByOrg        = emptyCache,
  cacheTeamMembersByTeam = emptyCache,
  cacheForums            = emptyCache,
  cacheBoards            = emptyCache,
  cacheThreads           = emptyCache,
  cacheThreadPosts       = emptyCache
}



-- cacheRun :: CacheEntry a -> a -> (a -> a) -> a -> a
-- cacheRun entry go1 go2 go3 =
--   case entry of
--     CacheEmpty   -> go1
--     CacheEntry a -> go2 a
--     CacheMissing -> go3
