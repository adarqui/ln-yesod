module LN.All.TeamMember (
  -- Handler
  getTeamMembersR,
  postTeamMemberR0,
  getTeamMemberR,
  putTeamMemberR,
  deleteTeamMemberR,
  getTeamMembersCountR,

  -- Model/Function
  teamMemberRequestToTeamMember,
  teamMemberToResponse,
  teamMembersToResponses,

  -- Model/Internal
  getTeamMembersM,
  getTeamMembers_ByTeamIdM,
  getTeamMemberM,
  insertTeamMemberM,
  insertTeamMember_InternalM,
  insertTeamMember_BypassM,
  updateTeamMemberM,
  deleteTeamMemberM,
) where



import           LN.All.Prelude
import           LN.T.Membership



--
-- Handler
--

getTeamMembersR :: Handler Value
getTeamMembersR = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON teamMembersToResponses $ getTeamMembersM (pure sp) user_id



postTeamMemberR0 :: Handler Value
postTeamMemberR0 = run $ do
  user_id             <- _requireAuthId
  team_member_request <- requireJsonBody :: HandlerEff TeamMemberRequest
  sp                  <- lookupStandardParams
  errorOrJSON teamMemberToResponse $ insertTeamMemberM (pure sp) user_id team_member_request



getTeamMemberR :: TeamMemberId -> Handler Value
getTeamMemberR team_member_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON teamMemberToResponse $ getTeamMemberM user_id team_member_id



putTeamMemberR :: TeamMemberId -> Handler Value
putTeamMemberR team_member_id = run $ do
  user_id             <- _requireAuthId
  team_member_request <- requireJsonBody
  errorOrJSON teamMemberToResponse $ updateTeamMemberM user_id team_member_id team_member_request



deleteTeamMemberR :: TeamMemberId -> Handler Value
deleteTeamMemberR team_member_id = run $ do
  user_id <- _requireAuthId
  errorOrJSON id $ deleteTeamMemberM user_id team_member_id



getTeamMembersCountR :: Handler Value
getTeamMembersCountR = run $ do
  user_id <- _requireAuthId
  sp      <- lookupStandardParams
  errorOrJSON id $ countTeamMembersM (pure sp) user_id







--
-- Model/Function
--

teamMemberRequestToTeamMember :: UserId -> OrganizationId -> TeamId -> TeamMemberRequest -> TeamMember
teamMemberRequestToTeamMember user_id org_id team_id TeamMemberRequest{..} = TeamMember {
  teamMemberUserId      = user_id,
  teamMemberOrgId       = org_id,
  teamMemberTeamId      = team_id,
  teamMemberIsAccepted  = False,
  teamMemberAcceptedAt  = Nothing,
  teamMemberIsBlocked   = False,
  teamMemberBlockedAt   = Nothing,
  teamMemberActive      = True,
  teamMemberGuard       = teamMemberRequestGuard,
  teamMemberCreatedAt   = Nothing,
  teamMemberModifiedBy  = Nothing,
  teamMemberModifiedAt  = Nothing,
  teamMemberActivityAt  = Nothing
}



teamMemberToResponse :: Entity TeamMember -> TeamMemberResponse
teamMemberToResponse (Entity team_member_id TeamMember{..}) = TeamMemberResponse {
  teamMemberResponseId          = keyToInt64 team_member_id,
  teamMemberResponseUserId      = keyToInt64 teamMemberUserId,
  teamMemberResponseOrgId       = keyToInt64 teamMemberOrgId,
  teamMemberResponseTeamId      = keyToInt64 teamMemberTeamId,
  teamMemberResponseIsAccepted  = teamMemberIsAccepted,
  teamMemberResponseAcceptedAt  = teamMemberAcceptedAt,
  teamMemberResponseIsBlocked   = teamMemberIsBlocked,
  teamMemberResponseBlockedAt   = teamMemberBlockedAt,
  teamMemberResponseActive      = teamMemberActive,
  teamMemberResponseGuard       = teamMemberGuard,
  teamMemberResponseCreatedAt   = teamMemberCreatedAt,
  teamMemberResponseModifiedBy  = fmap keyToInt64 teamMemberModifiedBy,
  teamMemberResponseModifiedAt  = teamMemberModifiedAt,
  teamMemberResponseActivityAt  = teamMemberActivityAt
}



teamMembersToResponses :: [Entity TeamMember] -> TeamMemberResponses
teamMembersToResponses teamMembers = TeamMemberResponses {
  teamMemberResponses = map teamMemberToResponse teamMembers
}







--
-- Model/Internal
--

getTeamMembersM :: Maybe StandardParams -> UserId -> HandlerErrorEff [Entity TeamMember]
getTeamMembersM m_sp user_id = do

  case (lookupSpMay m_sp spTeamId) of
    Just team_id -> getTeamMembers_ByTeamIdM m_sp user_id team_id
    _            -> leftA $ Error_InvalidArguments "team_id"



getTeamMembers_ByTeamIdM :: Maybe StandardParams -> UserId -> TeamId -> HandlerErrorEff [Entity TeamMember]
getTeamMembers_ByTeamIdM m_sp _ team_id = do
  -- TODO ACCESS:
  selectListDbE m_sp [TeamMemberTeamId ==. team_id, TeamMemberActive ==. True] [] TeamMemberId



getTeamMemberM :: UserId -> TeamMemberId -> HandlerErrorEff (Entity TeamMember)
getTeamMemberM _ team_member_id = do
  selectFirstDbE [TeamMemberId ==. team_member_id, TeamMemberActive ==. True] []




insertTeamMemberM :: Maybe StandardParams -> UserId -> TeamMemberRequest -> HandlerErrorEff (Entity TeamMember)
insertTeamMemberM m_sp user_id team_member_request = do

  case (lookupSpMay m_sp spOrganizationId, lookupSpMay m_sp spTeamId) of
    (Just org_id, _)   -> insertTeamMember_JoinM user_id org_id team_member_request
    -- TODO FIXME
    -- (_, Just team_id)  -> insertTeamMember_InternalM user_id team_id team_member_request
    _                  -> leftA $ Error_InvalidArguments "org_id, team_id"



-- | Simple JOIN
-- Find Team_Members and insert this user into that team
--
insertTeamMember_JoinM :: UserId -> OrganizationId -> TeamMemberRequest -> HandlerErrorEff (Entity TeamMember)
insertTeamMember_JoinM user_id org_id team_member_request = do

  ts <- timestampH'

  e_team <- selectFirstDbE [TeamOrgId ==. org_id, TeamSystem ==. Team_Members, TeamActive ==. True] []
  rehtie e_team leftA $ \(Entity team_id _) -> do

    let
      team_member = (teamMemberRequestToTeamMember user_id org_id team_id team_member_request) { teamMemberCreatedAt = Just ts }

    e_team' <- selectFirstDbE [TeamId ==. team_id] []

    rehtie e_team' leftA $ \(Entity _ Team{..}) -> do
    -- TODO FIXME: PROPER MEMBERSHIP RESTRICTIONS
      case teamMembership of
        Membership_Join -> insertEntityDbE team_member
        _               -> leftA $ Error_PermissionDenied



-- | TODO ACCESS RESTRICTIONS
-- 1. Can only add to owners, by an owner
-- 2. Restrictions based on Membership
--
insertTeamMember_InternalM :: UserId -> OrganizationId -> TeamId -> TeamMemberRequest -> HandlerErrorEff (Entity TeamMember)
insertTeamMember_InternalM user_id org_id team_id team_member_request = do

  ts <- timestampH'

  let
    team_member = (teamMemberRequestToTeamMember user_id org_id team_id team_member_request) { teamMemberCreatedAt = Just ts }

  e_team <- selectFirstDbE [TeamId ==. team_id] []

  rehtie e_team leftA $ \(Entity _ Team{..}) -> do
    -- TODO FIXME: PROPER MEMBERSHIP RESTRICTIONS
    case teamMembership of
      Membership_Join -> insertEntityDbE team_member
      _               -> leftA $ Error_PermissionDenied



insertTeamMember_BypassM :: UserId -> OrganizationId -> TeamId -> TeamMemberRequest -> HandlerErrorEff (Entity TeamMember)
insertTeamMember_BypassM user_id org_id team_id team_member_request = do

  ts <- timestampH'

  let
    team_member = (teamMemberRequestToTeamMember user_id org_id team_id team_member_request) { teamMemberCreatedAt = Just ts }

  e_team <- selectFirstDbE [TeamId ==. team_id] []
  rehtie e_team leftA $ \(Entity _ Team{..}) -> do
    -- TODO FIXME: PROPER MEMBERSHIP RESTRICTIONS
    case teamMembership of
      _ -> insertEntityDbE team_member




updateTeamMemberM :: UserId -> TeamMemberId -> TeamMemberRequest -> HandlerErrorEff (Entity TeamMember)
updateTeamMemberM user_id team_member_id team_member_request = do

  ts <- timestampH'

  let
    TeamMember{..} = (teamMemberRequestToTeamMember user_id dummyId dummyId team_member_request) { teamMemberModifiedAt = Just ts }

  updateWhereDb
    [TeamMemberUserId ==. user_id, TeamMemberId ==. team_member_id, TeamMemberActive ==. True]
    [ TeamMemberModifiedAt  =. teamMemberModifiedAt
    , TeamMemberGuard      +=. teamMemberGuard
    ]

  selectFirstDbE [TeamMemberUserId ==. user_id, TeamMemberId ==. team_member_id, TeamMemberActive ==. True] []



-- | A user can delete a team_member from an organization if:
-- 1. A user is an owner and a team_member is not an owner
-- 2. A user owns the organization completely, and this is not the user as the team_member
-- 3. A user is not an owner, and the user is the same as the team_member
--
deleteTeamMemberM :: UserId -> TeamMemberId -> HandlerErrorEff ()
deleteTeamMemberM user_id team_member_id = do
  lr <- runEitherT $ do
    (Entity _ TeamMember{..})         <- mustT $ selectFirstDbE [TeamMemberId ==. team_member_id, TeamMemberActive ==. True] []
    (Entity org_id Organization{..})  <- mustT $ selectFirstDbE [OrganizationId ==. teamMemberOrgId, OrganizationActive ==. True] []
    is_owner                          <- lift $ isOwnerOf_OrganizationIdM user_id org_id
    is_team_member_owner              <- lift $ isOwnerOf_OrganizationIdM teamMemberUserId org_id
    liftIO $ print (organizationUserId == user_id, is_owner, is_team_member_owner, user_id == teamMemberUserId)
    case (organizationUserId == user_id, is_owner, is_team_member_owner, user_id == teamMemberUserId) of
      (True, _,    _,     False) -> mustT $ del
      (_,   True,  False, _)     -> mustT $ del
      (_,   False, False, True)  -> mustT $ del
      _                          -> leftT Error_PermissionDenied
    pure ()

  rehtie lr leftA (const $ rightA ())
  where
  del = deleteWhereDbE [TeamMemberId ==. team_member_id, TeamMemberActive ==. True]



countTeamMembersM :: Maybe StandardParams -> UserId -> HandlerErrorEff CountResponses
countTeamMembersM m_sp _ = do

  case (lookupSpMay m_sp spUserId) of

    Just lookup_user_id -> do
      n <- countDb [TeamMemberUserId ==. lookup_user_id, TeamMemberActive ==. True]
      rightA $ CountResponses [CountResponse (keyToInt64 lookup_user_id) (fromIntegral n)]

    _                   -> leftA $ Error_InvalidArguments "user_id"
