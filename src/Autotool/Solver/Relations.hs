module Autotool.Solver.Relations (solve, solveP) where

import Data.List (sortOn)
import Data.Function (on)
import Data.Set ( Set )
import Autotool.Data.LazyTree ( Tree, Op, findTreeLim )
import Autotool.Data.Parallel.LazyTree (searchTreeLimP)

type Rel a = Set (a,a)
type RelOp a = Op () (Rel a)

solve :: (Num a, Eq a, Show a) =>
    [RelOp a]      -- ^ operators and constants
    -> Rel a       -- ^ result set
    -> Tree (RelOp a)
solve ops t = case findTreeLim lim ops () t of
    (Just result) -> result
    _ -> error $ "No matching tree found within first " ++ show lim ++ " candidates"
    where
        lim = 300000

solveP :: (Num a, Eq a, Show a) =>
    [RelOp a]      -- ^ operators and constants
    -> Rel a       -- ^ result set
    -> Tree (RelOp a)
solveP ops t = case searchTreeLimP lim ops () (==t) of
    (Just result) -> result
    _ -> error $ "No matching tree found within first " ++ show lim ++ " candidates"
    where
        lim = 300000