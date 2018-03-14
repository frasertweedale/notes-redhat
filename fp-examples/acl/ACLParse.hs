{-# LANGUAGE OverloadedStrings #-}

module ACLParse
  (
    acl
  , expression
  , parseUserAccessEvaluator
  , parseGroupAccessEvaluator
  , parseIpaddressAccessEvaluator
  )
where

import Control.Applicative ((<$), (<|>))
import Data.Char (isAlpha, isAlphaNum)
import Data.Foldable (asum)

import Data.Attoparsec.Text as A
import Data.Text (Text)

import ACL

parseACLRuleType :: Parser ACLRuleType
parseACLRuleType =
  Allow <$ string "allow"
  <|> Deny <$ string "deny"


-- | Parse an equality operator (@"="@ or @"!="@)
--
eqOp :: Parser EqCondition
eqOp =
  Equal <$ char '='
  <|> NotEqual <$ string "!="

-- Returns the value between quotes.  Doesn't handle escaped quotes.
quotedString :: Parser Text
quotedString = char '"' *> A.takeWhile (/= '"') <* char '"'

-- Sequence of alpha-numeric characters
unquotedString :: Parser Text
unquotedString = A.takeWhile isAlphaNum

accessEvaluatorValue :: Parser Text
accessEvaluatorValue = quotedString <|> unquotedString

parseUserAccessEvaluator :: Parser AccessEvaluator
parseUserAccessEvaluator =
  userAccessEvaluator <$> (string "user" *> eqOp) <*> accessEvaluatorValue

parseGroupAccessEvaluator :: Parser AccessEvaluator
parseGroupAccessEvaluator =
  groupAccessEvaluator <$> (string "group" *> eqOp) <*> accessEvaluatorValue

parseIpaddressAccessEvaluator :: Parser AccessEvaluator
parseIpaddressAccessEvaluator =
  groupAccessEvaluator <$> (string "ipaddress" *> eqOp) <*> accessEvaluatorValue

-- | Allow optional whitespace before and after a parser.
--
spaced :: Parser a -> Parser a
spaced p = skipSpace *> p <* skipSpace

expression :: [Parser AccessEvaluator] -> Parser ACLExpression
expression ps =
  orExpr
  <|> andExpr
  <|> End <$> accessExpr
  where
    opExpr op con =
      con
      <$> accessExpr <* spaced (string op)
      <*> expression ps
    orExpr = opExpr "||" Or
    andExpr = opExpr "&&" And
    accessExpr = asum ps

permission :: Parser Text
permission = takeWhile1 isAlpha

rule :: [Parser AccessEvaluator] -> Parser ACLRule
rule ps =
  ACLRule
  <$> parseACLRuleType
  <*> spaced (char '(' *> (permission `sepBy1` char ',') <* char ')')
  <*> expression ps

-- | Parser for an ACL
--
-- Takes a list of parsers for AccessEvaluators.  These will be
-- tried in order when parsing each fragment of an ACL expression.
--
-- Example usage:
--
-- @
-- parseACL :: Text -> Either String ACL
-- parseACL = parseOnly (acl evaluators)
--   where
--   evaluators = [userAccessEvaluator, groupAccessEvaluator]
-- @
--
acl :: [Parser AccessEvaluator] -> Parser ACL
acl ps =
  ACL
  <$> takeWhile1 (/= ':') <* char ':'
  <*> permission `sepBy1` char ',' <* char ':'
  <*> rule ps `sepBy1` spaced (char ';') <* char ':'
  <*> takeText
