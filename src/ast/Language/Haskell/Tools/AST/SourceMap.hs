module Language.Haskell.Tools.AST.SourceMap where

import ApiAnnotation
import Data.Map as Map
import Data.List as List
import Safe

import SrcLoc as GHC
import FastString as GHC

-- We store tokens in the source map so it is not a problem that they cannot overlap
type SourceMap = Map AnnKeywordId (Map SrcLoc SrcLoc)

-- | Returns the first occurrence of the keyword in the whole source file
getKeywordAnywhere :: AnnKeywordId -> SourceMap -> Maybe SrcSpan
getKeywordAnywhere keyw srcmap = return . uncurry mkSrcSpan =<< headMay . assocs =<< (Map.lookup keyw srcmap)

-- | Get the source location of a token restricted to a certain source span
getKeywordInside :: AnnKeywordId -> SrcSpan -> SourceMap -> Maybe SrcSpan
getKeywordInside keyw sr srcmap = getSourceElementInside sr =<< Map.lookup keyw srcmap

getSourceElementInside :: SrcSpan -> Map SrcLoc SrcLoc -> Maybe SrcSpan
getSourceElementInside sr srcmap = 
  case lookupGE (srcSpanStart sr) srcmap of
    Just (k, v) -> if k <= srcSpanEnd sr then Just (mkSrcSpan k v)
                                         else Nothing
    Nothing -> Nothing
    
-- | Converts GHC Annotations into a convenient format for looking up tokens
annotationsToSrcMap :: Map ApiAnnKey [SrcSpan] -> Map AnnKeywordId (Map SrcLoc SrcLoc)
annotationsToSrcMap anns = Map.map (List.foldr addToSrcRanges Map.empty) $ mapKeysWith (++) snd anns
  where 
    addToSrcRanges :: SrcSpan -> Map SrcLoc SrcLoc -> Map SrcLoc SrcLoc
    addToSrcRanges span srcmap = Map.insert (srcSpanStart span) (srcSpanEnd span) srcmap
    
    
                