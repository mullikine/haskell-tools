-- | Utility functions for transforming the GHC AST representation into our own.
module Language.Haskell.Tools.AST.FromGHC.Utils where

import Control.Monad.Reader
import Data.Maybe
import Language.Haskell.Tools.AST.Ann
import Language.Haskell.Tools.AST.FromGHC.Monad
import Language.Haskell.Tools.AST.SourceMap
import ApiAnnotation
import SrcLoc
import HsSyn

-- | RangeInfo (RI) is an alias for SrcSpan
type RI = SrcSpan

-- | Transform a located part of the AST by automatically transforming the location.
-- Sets the source range for transforming children.
trfLoc :: (a -> Trf (b RI)) -> Located a -> Trf (Ann b RI)
trfLoc f (L l e) = Ann l <$> local (\s -> s { contRange = l }) (f e) 

-- | Transform a located part of the AST by automatically transforming the location
-- with correction by applying the given function. Sets the source range for transforming children.
trfLocCorrect :: (RI -> Trf RI) -> (a -> Trf (b RI)) -> Located a -> Trf (Ann b RI)
trfLocCorrect locF f (L l e) = do loc <- locF l
                                  Ann loc <$> local (\s -> s { contRange = loc }) (f e)

-- | Transform a located part of the AST by automatically transforming the location.
-- Sets the source range for transforming children.
trfMaybeLoc :: (a -> Trf (Maybe (b RI))) -> Located a -> Trf (Maybe (Ann b RI))
trfMaybeLoc f (L l e) = fmap (Ann l) <$> local (\s -> s { contRange = l }) (f e)  

-- | Transform a located part of the AST by automatically transforming the location.
-- Sets the source range for transforming children.
trfListLoc :: (a -> Trf [b RI]) -> Located a -> Trf [Ann b RI]
trfListLoc f (L l e) = fmap (Ann l) <$> local (\s -> s { contRange = l }) (f e)  

-- | Searches for a token inside the parent element and retrieves its location
tokenLoc :: AnnKeywordId -> Trf RI
tokenLoc keyw = fromMaybe noSrcSpan <$> (getKeywordInside keyw <$> asks contRange <*> asks srcMap)

-- | Searches for tokens inside the parent element and returns their combined location
tokensLoc :: [AnnKeywordId] -> Trf RI
tokensLoc keys = asks contRange >>= tokensLoc' keys
  where tokensLoc' :: [AnnKeywordId] -> RI -> Trf RI
        tokensLoc' (keyw:rest) r 
          = do spanFirst <- fromMaybe noSrcSpan <$> getKeywordInside keyw r <$> asks srcMap
               spanRest <- tokensLoc' rest (mkSrcSpan (srcSpanEnd spanFirst) (srcSpanEnd r))
               return (combineSrcSpans spanFirst spanRest)                   
        tokensLoc' [] r = pure noSrcSpan
        
-- | Searches for a token and retrieves its location anywhere
uniqueTokenAnywhere :: AnnKeywordId -> Trf RI
uniqueTokenAnywhere keyw = fromMaybe noSrcSpan <$> (getKeywordAnywhere keyw <$> asks srcMap)
        
-- | No annotation for a part of the AST
noAnn = Ann noSrcSpan