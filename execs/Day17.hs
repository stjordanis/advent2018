{-|
Module      : Main
Description : Day 17 solution
Copyright   : (c) Eric Mertens, 2018
License     : ISC
Maintainer  : emertens@gmail.com

<https://adventofcode.com/2018/day/17>
-}
{-# Language OverloadedStrings #-}
module Main (main) where

import           Advent
import           Advent.Coord
import           Control.Applicative
import qualified Data.Set as Set
import           Data.Set (Set)
import qualified Data.Map as Map
import           Data.Map (Map)
import           Data.Foldable (foldl')
import           Data.Array.Unboxed as A
import           Codec.Picture

-- | Print the answers to day 17
main :: IO ()
main =
  do input <- getParsedLines 17 parseLine
     let walls = toArray (concat input)
         frames = solver walls
         (walls', water) = last frames

     writePng "output.png" (draw walls walls' water)
     -- sequence_ $ writeGifAnimation "output.gif"
     --    10 LoopingForever
     --     [ draw walls walls' water | (walls', water) <- frames ]

     let flowingN  = Set.size water
         standingN = count id (zipWith (/=) (A.elems walls) (A.elems walls'))

     print (flowingN + standingN)
     print standingN

-- clay walls and standing water representation ------------------------

type Walls = A.UArray Coord Bool

isWall :: Walls -> Coord -> Bool
isWall walls c = inArray walls c && walls A.! c

-- water flow logic ----------------------------------------------------

-- | Given some initial clay walls, generate the sequence of updated
-- walls (including standing water) and flowing water coordinates.
solver :: Walls -> [(Walls, Set Coord)]
solver walls
  | null fills = [(walls, Map.keysSet water)]
  | otherwise  = (walls, Map.keysSet water) : solver (walls A.// fills)
  where
    water = waterflow walls

    fills = [(C ly x, True)
               | c@(C ly lx) <- Map.keys water
               , isWall walls (below c)
               , isWall walls (left  c)
               , rightWall <- isContained c
               , x <- [lx .. coordCol rightWall - 1]
               ]

    -- search to the right to see that the bottom extends out to a wall
    isContained c
      | walls A.! c       = [c]
      | walls A.! below c = isContained (right c)
      | otherwise         = []

-- water flow logic ----------------------------------------------------

data Mode = LookLeft | LookRight | LookDown
  deriving (Eq, Ord, Show)

waterflow :: Walls -> Map Coord Mode
waterflow walls = reachable (waterStep walls) (C startY 500, LookDown)
  where
    startY = coordRow (fst (A.bounds walls))

-- | Given the current walls (including standing water), a water
-- coordinate, and the direction the water is flowing, generate
-- the neighboring water flows.
waterStep :: Walls -> (Coord, Mode) -> [(Coord, Mode)]
waterStep walls (c, mode)
  | not (inArray walls (below c)) = []
  | not (walls A.! below c) = [ (below c, LookDown) ]
  | otherwise = filter (not . isWall walls . fst)
              $ [ (left  c, LookLeft ) | mode /= LookRight ]
             ++ [ (right c, LookRight) | mode /= LookLeft  ]

-- input format --------------------------------------------------------

asHoriz, asVert :: Int -> Int -> Int -> [Coord]
asHoriz y xlo xhi = [ C y x | x <- [xlo..xhi] ]
asVert  x ylo yhi = [ C y x | y <- [ylo..yhi] ]

parseLine :: Parser [Coord]
parseLine =
  asHoriz <$ "y=" <*> number <* ", x=" <*> number <* ".." <*> number <|>
  asVert  <$ "x=" <*> number <* ", y=" <*> number <* ".." <*> number

-- rendering -----------------------------------------------------------

draw :: Walls -> Walls -> Set Coord -> Image PixelRGB8
draw walls walls' water =
  generateImage toPixel (hicol-locol+1) (hirow-lorow+1)
  where
    standing = PixelRGB8 0 0 255
    flowing  = PixelRGB8 0 200 255
    sand     = PixelRGB8 170 121 66
    clay     = PixelRGB8 100 71 39

    (C lorow locol, C hirow hicol) = A.bounds walls

    toPixel col row =
        if Set.member (C (lorow+row) (locol+col)) water then flowing  else
        if walls A.!  (C (lorow+row) (locol+col))       then clay     else
        if walls' A.! (C (lorow+row) (locol+col))       then standing else
        sand

-- searching -----------------------------------------------------------

reachable :: Ord a => ((a,b) -> [(a,b)]) -> (a,b) -> Map a b
reachable next = aux Map.empty
  where
    aux seen (k,v)
      | Map.member k seen = seen
      | otherwise         = foldl' aux (Map.insert k v seen) (next (k,v))

-- array helpers -------------------------------------------------------

inArray :: (Ix i, IArray a e) => a i e -> i -> Bool
inArray a c = A.inRange (A.bounds a) c

toArray :: [Coord] -> A.UArray Coord Bool
toArray xs = A.accumArray (\_ e -> e) False (C miny minx, C maxy maxx)
                        [ (xy, True) | xy <- xs ]
  where
    miny = minimum (map coordRow xs)
    maxy = maximum (map coordRow xs)
    minx = minimum (map coordCol xs) - 1
    maxx = maximum (map coordCol xs) + 1
