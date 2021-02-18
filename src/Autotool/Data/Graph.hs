{-# LANGUAGE TupleSections #-}

module Autotool.Data.Graph
    ( Graph
    , mkGraph
    , mkI
    , mkK
    , mkP
    , mkC
    , kante
    , vertices
    , edges
    , insertEdge
    , containsEdge
    , deleteVertex
    , similiar
    , neighbours
    , disconnectedSubgraphs
    , complement
    , join
    , add
    , normalize
    , subgraph
    , isCircle
    , connected
    , degree
    , degrees
    , Isomorphism
    , runIsomorphism
    , findIsomorphism
    , isIsomorphTo
    , GraphConstraint(..)
    , satisfiesConstraint
    , breaksConstraint
    , Color(..)
) where

import qualified Data.Map as M
import qualified Data.IntMap as IM
import Data.Set (fromList, Set, toList, notMember)
import qualified Data.Set as S
import Data.Maybe (mapMaybe)
import Data.List (find, permutations)

type Graph a = (Set a, Set (a,a))

-- constructors

mkGraph :: (Ord a) => [a] -> [(a,a)] -> Graph a
mkGraph vs es = (fromList vs, fromList es)

kante :: (Ord a) => a -> a -> (a,a)
kante = (,)

mkI :: Int -> Graph Int
mkI n = mkGraph [1..n] []

mkK :: Int -> Graph Int
mkK n = let vs = [1..n] in mkGraph vs (allEdges vs)

mkP :: Int -> Graph Int
mkP n = let vs = [1..n] in mkGraph vs (zip vs $ drop 1 vs)

mkC :: Int -> Graph Int
mkC n = let vs = [1..n] in mkGraph vs ((n,1):zip vs (drop 1 vs))

-- operations

vertices :: Graph a -> Set a
vertices (vs,_) = vs

edges :: Graph a -> Set (a,a)
edges (_,es) = es

insertEdge :: (Ord a) => Graph a -> (a,a) -> Graph a
insertEdge (vs,es) e = (vs, S.insert e es)

-- | Removes a vertex and alle edges from / to it
-- >>> deleteVertex (S.fromList [1,2,3], S.fromList [(1,2), (2,3), (3,1)]) 2
-- (fromList [1,3],fromList [(3,1)])
deleteVertex :: (Ord a) => Graph a -> a -> Graph a
deleteVertex (vs,es) e = (S.delete e vs, S.filter (\(a,b) -> a /= e && b /= e) es)

-- | > containsEdge g (a,b) := (a,b) ∈ edges_G ∨ (b,a) ∈ edges_G
containsEdge :: (Eq a) => Graph a -> (a,a) -> Bool
containsEdge (_,es) (a,b) = (a,b) `elem` es || (b,a) `elem` es

neighbours :: (Eq a) => Graph a -> a -> [a]
neighbours (vs, es) v = mapMaybe f (toList es) where
    f (a,b)
        | a == v = Just b
        | b == v = Just a
        | otherwise = Nothing

complement :: (Ord a) => Graph a -> Graph a
complement (vs, es) = let esAll = fromList $ allEdges (toList vs) in (vs, diff esAll es)
    where diff ea eb = S.filter (\(a,b) -> (a,b) `notMember` eb && (b,a) `notMember` eb) ea

-- TODO: make join take a rename function
join :: (Ord a, Num a) => Graph a -> Graph a -> Graph a
join g@(vs, es) h@(hs,_) = (S.union vs vs', edges) where
    (vs', es') = rename renameF h
    edges = S.unions [es, es', fromList $ concatMap (\v -> map (,v) (toList vs')) (toList vs) ]
    maxV = S.findMax vs
    minV' = S.findMin hs
    renameF = if maxV >= minV' then (+maxV) else id

add :: (Ord a, Num a) => Graph a -> Graph a -> Graph a
add (vs, es) h@(hs,_) = (S.union vs vs', S.union es es') where
    (vs', es') = rename renameF h
    maxV = S.findMax vs
    minV' = S.findMin hs
    renameF = if maxV >= minV' then (+maxV) else id

subgraph :: (Ord a) => Graph a -> [a] -> Graph a
subgraph (vs, es) vs' = (fromList vs', es') where
    es' = S.filter (\(a,b) -> a `elem` vs' && b `elem` vs') es

-- | Deconstructs a tree in its disconnected subtrees
disconnectedSubgraphs :: (Ord a) => Graph a -> [Graph a]
disconnectedSubgraphs g = map (subgraph g) bipartitNodes
    where
        vs = S.toList (vertices g)
        foldNode v [] = [[v]]
        foldNode v xs =
            let target = concat (filter (any (connected g v)) xs)
                rest = filter (not . any (connected g v)) xs
            in (v:target):rest
        bipartitNodes = foldr foldNode [] vs

-- | Renames a tree so that its vertices starts at `base`
normalize :: (Integral a)
          => a                                  -- ^ the lowest number to start labeling vertices
          -> Graph a                            -- ^ the graph to rename
          -> (Graph a, Graph a -> Graph a)      -- ^ (the renamed graph, a function that reverts the renaming)
normalize base g = (rename (mapping M.!) g, rename (remapping M.!))
    where
        min = base -- S.findMin (vertices g) - base
        mapping = M.fromList $ zip (S.toList $ vertices g) [min..]
        remapping = M.fromList $ zip [min..] (S.toList $ vertices g)

isCircle :: (Eq a) => Graph a -> Bool
isCircle g@(vs, es) = length vs == length es && all ((==2) . degree g) (toList vs)

-- | Returns if two vertices are connected
connected :: (Ord a) => Graph a -> a -> a -> Bool
connected (_,es) a b = (a,b) `S.member` es || (b,a) `S.member` es

degree :: (Eq a) => Graph a -> a -> Int
degree (_, es) v = length $ S.filter (\(a,b) -> a == v || b == v) es

-- | Returns the map of degrees of a graph
degrees :: (Eq a) => Graph a -> IM.IntMap Int
degrees g@(vs,_) = foldr f IM.empty vs
    where
        f v m  = IM.alter alter (degree g v) m
        alter (Just i) = Just $ i + 1
        alter _ = Just 1

clique :: (Eq a, Ord a) => Graph a -> a -> [a]
clique g@(vs,es) v = clique
    where
        ns = neighbours g v
        inClique v = all (\vn -> vn == v || connected g vn v) ns
        clique = filter inClique ns

cliques :: (Eq a, Ord a) => Graph a -> [[a]]
cliques g@(vs,_) = map (clique g) (S.toList vs)

-- | Returns true if two graphs are similiar
--
-- prop> (vG,eG) ~ (vH,eH) := vG = vH ∧ ∀(x,y) ∈ eG: (x,y) ∈ eH ∨ (y,x) ∈ eH
similiar :: (Eq a) => Graph a -> Graph a -> Bool
similiar g h = vsEq && esEq
    where
        vsEq = vertices g == vertices h
        esG = edges g
        esH = edges h
        esEq = length esG == length esH && length esG == length (S.filter (containsEdge h) esG)

-- utility functions

allEdges :: [a] -> [(a,a)]
allEdges [a,b] = [(a,b)]
allEdges (v:vs) = allEdges vs ++ concatMap (allEdges . (:[v])) vs
allEdges _ = []

rename :: (Ord a, Ord b) => (a -> b) -> Graph a -> Graph b
rename f (vs, es) = (vs', es') where
    vs' = S.map f vs
    es' = S.map f' es
    f' (a,b) = (f a, f b)


-- Isomorphisms

type Isomorphism a b = M.Map a b

mkIsomorphism :: (Ord a, Ord b) => [(a,b)] -> Isomorphism a b
mkIsomorphism = M.fromList

runIsomorphism :: (Ord a, Ord b) => M.Map a b -> Graph a -> Graph b
runIsomorphism m = rename (m M.!)

findIsomorphism :: (Ord a, Ord b) => Graph a -> Graph b -> Maybe (Isomorphism a b)
findIsomorphism g h = find (similiar h . (`runIsomorphism` g)) isomorphisms
    where
        vs = S.toList (vertices g)
        vs' = S.toList (vertices h)
        isomorphisms = map (M.fromList . zip vs) (permutations vs')

isIsomorphTo :: (Ord a, Ord b) => Graph a -> Graph b -> Bool
isIsomorphTo g h = areCongruent && isoExists
    where
        areCongruent = degrees g == degrees h
        isoExists = case findIsomorphism g h of
                (Just _) -> True
                _ -> False

-- Constraints

data GraphConstraint a
    = Vertices Int
    | Edges Int
    | MaxDegree Int
    | MaxClique Int
    | Edge a a
    | Degree a Int
    | Not (GraphConstraint a)
    deriving (Show)

satisfiesConstraint :: (Eq a, Ord a) => GraphConstraint a -> Graph a -> Bool
satisfiesConstraint (Vertices n) (vs,_) = n == S.size vs
satisfiesConstraint (Edges n) (_, es) = n == S.size es
satisfiesConstraint (MaxDegree n) g = n >= maximum (IM.keys $ degrees g)
satisfiesConstraint (MaxClique n) g = n >= maximum (map length (cliques g))
satisfiesConstraint (Edge a b) g = connected g a b
satisfiesConstraint (Degree a n) g = n == degree g a
satisfiesConstraint (Not c) g = not $ satisfiesConstraint c g

breaksConstraint :: (Eq a, Ord a) => GraphConstraint a -> Graph a -> Bool
breaksConstraint (Vertices n) (vs,_) = n < S.size vs
breaksConstraint (Edges n) (_, es) = n < S.size es
breaksConstraint (MaxDegree n) g = n < maximum (IM.keys $ degrees g)
breaksConstraint (MaxClique n) g = n < maximum (map length (cliques g))
breaksConstraint (Edge _ _) _ = False
breaksConstraint (Degree a n) g = n < degree g a
breaksConstraint (Not c) g = satisfiesConstraint c g

-- Colors

data Color = A | B | C | D | E | F deriving (Eq, Ord, Enum, Show)
