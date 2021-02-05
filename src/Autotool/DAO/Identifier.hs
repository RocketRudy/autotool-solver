{-# LANGUAGE ScopedTypeVariables #-}

module Autotool.DAO.Identifier (Identifier, mkId, fromId) where

import Text.ParserCombinators.ReadP (satisfy, readP_to_S)
import Autotool.Readable (Readable(..), spaces)

newtype Identifier = Id Char deriving (Ord,Eq)

mkId :: Char -> Identifier
mkId = Id

fromId :: Identifier -> Char
fromId (Id c) = c

instance Show Identifier where
    show (Id a) = [a]

instance Readable Identifier where
    readP = Id <$> (spaces *> char <* spaces)
        where
            char = satisfy isChar
            isChar c = c `elem` ['A'..'Z'] || c `elem` ['a'..'z']

instance Read Identifier where
    readsPrec n = readP_to_S readP