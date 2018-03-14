{-# LANGUAGE OverloadedStrings #-}

module ACL where

import Data.Maybe (fromMaybe)
import Data.Monoid (First(First, getFirst))
import Data.Semigroup ((<>))

import Data.Text (Text, unpack)

-- | An authentication token (simple placeholder for this POC).
--
data AuthenticationToken = AuthenticationToken
  { tokenUsername :: Username
  , tokenGroups :: [Group]
  , tokenIPAddress :: String -- FIXME better type
  }

type Username = Text
type Group = Text


-- | An AccessEvaluator
data AccessEvaluator = AccessEvaluator
  { evaluateAccess :: AuthenticationToken -> Bool
  , printAccessEvaluator :: Text -- ^ string representation
  }

instance Show AccessEvaluator where
  show = unpack . printAccessEvaluator

-- | An ACL expression is left-associative with no operator
-- precedence.  In other words:
--
-- @
-- a || b && c || d == (((a || b) && c) || d)
-- @
--
-- This can give different results from the "usual" precedence
-- of AND and OR.  The old Java implementation has this semantics.
--
-- Note that the construction is right-associative to make parsing
-- easy, but 'evaluateExpression' evaluates the structure
-- left-associatively.
--
data ACLExpression
  = End AccessEvaluator
  | And AccessEvaluator ACLExpression
  | Or AccessEvaluator ACLExpression
  deriving (Show)

-- | Evaluate expression left-associatively.
-- (The implementation is a bit convoluted for this reason)
--
evaluateExpression :: AuthenticationToken -> ACLExpression -> Bool
evaluateExpression tok = go id{-use the first fragment as-is-}
  where
  go f (End l) = f (evaluateAccess l tok)
  go f (Or l r) = go (f (evaluateAccess l tok) ||) r
  go f (And l r) = go (f (evaluateAccess l tok) &&) r


type Permission = Text

data ACLRuleType = Allow | Deny
  deriving (Eq, Show)

data ACLRule = ACLRule
  { aclRuleType :: ACLRuleType
  , aclRulePermissions :: [Permission]
  , aclRuleExpression :: ACLExpression
  }
  deriving (Show)

-- | Evaluate a rule.  An @Allow@ rule will evaluate to
-- @Just Allowed@ if its expression evaluate to @True@s, else
-- @Nothing@.  Similarly, a @Deny@ rule will evaluate to
-- @Just Denied@ or @Nothing@.
--
evaluateRule :: AuthenticationToken -> ACLRule -> Maybe ACLResult
evaluateRule tok (ACLRule ruleType _ expr) =
  if evaluateExpression tok expr then Just (result ruleType) else Nothing
  where
    result Deny = Denied
    result Allow = Allowed


-- | Specifies whether "allow" or "deny" rules will be processed first
data ACLRuleOrder = AllowDeny | DenyAllow

-- | Result of evaluating an ACL
data ACLResult = Allowed | Denied


data ACL = ACL
  { aclName :: Text
  , aclPermissions :: [Permission]
  -- ^ the union of the permissions of each acl entry (hypothetically)
  , aclRules :: [ACLRule]
  , aclDescription :: Text
  }
  deriving (Show)

-- | Evaluate an ACL for the given 'Permission'.  The 'ACLRuleOrder'
-- controls whether 'Deny' rules will be processed before 'Allow'
-- rules or vice-versa.  The first matching rule covering the given
-- 'Permission' wins.  If no rule matches for the given permission,
-- access is 'Denied'.
--
evaluateACL
  :: ACLRuleOrder
  -> AuthenticationToken
  -> Permission
  -> ACL
  -> ACLResult
evaluateACL order tok perm (ACL _ _ rules _ ) =
  fromMaybe Denied result -- deny if no rules matched
  where
    -- rules for the given permissions
    permRules = filter (elem perm . aclRulePermissions) rules

    -- order rules by allow/deny according to ACLRuleOrder
    orderedRules = case order of
      DenyAllow -> denyRules <> allowRules
      AllowDeny -> allowRules <> denyRules
    denyRules = filter ((== Deny) . aclRuleType) permRules
    allowRules = filter ((== Allow) . aclRuleType) permRules

    -- the first matching rule wins
    result = getFirst (foldMap (First . evaluateRule tok) orderedRules)


data EqCondition = Equal | NotEqual
  deriving (Eq)

eq :: (Eq a) => EqCondition -> (a -> a -> Bool)
eq Equal = (==)
eq NotEqual = (/=)

printEq :: EqCondition -> Text
printEq Equal = "="
printEq NotEqual = "!="

-- | Constract a user access evaluator
--
userAccessEvaluator :: EqCondition -> Text -> AccessEvaluator
userAccessEvaluator eqCond s = AccessEvaluator f repr
  where
  f | eqCond == Equal && (s `elem` ["anybody", "everybody"]) = const True
    | otherwise = eq eqCond s . tokenUsername
  repr = "user" <> printEq eqCond <> "\"" <> s <> "\""

groupAccessEvaluator :: EqCondition -> Text -> AccessEvaluator
groupAccessEvaluator eqCond s = AccessEvaluator f repr
  where
  f = any (eq eqCond s) . tokenGroups
  repr = "group" <> printEq eqCond <> "\"" <> s <> "\""

-- | extract IP address from auth token and perform regex match
ipaddressAccessEvaluator :: EqCondition -> Text -> AccessEvaluator
ipaddressAccessEvaluator eqCond pat = AccessEvaluator f repr
  where
  op = case eqCond of Equal -> id ; NotEqual -> not
  regexMatch = undefined pat -- TODO
  f tok = op (regexMatch (tokenIPAddress tok))
  repr = "ipaddress" <> printEq eqCond <> "\"" <> pat <> "\""
