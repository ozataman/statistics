{-# LANGUAGE DeriveDataTypeable, DeriveGeneric #-}
-- |
-- Module    : Statistics.Distribution.Gamma
-- Copyright : (c) 2009, 2011 Bryan O'Sullivan
-- License   : BSD3
--
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : portable
--
-- The gamma distribution.  This is a continuous probability
-- distribution with two parameters, /k/ and &#977;. If /k/ is
-- integral, the distribution represents the sum of /k/ independent
-- exponentially distributed random variables, each of which has a
-- mean of &#977;.

module Statistics.Distribution.Gamma
    (
      GammaDistribution
    -- * Constructors
    , gammaDistr
    , improperGammaDistr
    -- * Accessors
    , gdShape
    , gdScale
    ) where

import Data.Aeson (FromJSON, ToJSON)
import Control.Applicative ((<$>), (<*>))
import Data.Binary (Binary)
import Data.Binary (put, get)
import Data.Data (Data, Typeable)
import GHC.Generics (Generic)
import Numeric.MathFunctions.Constants (m_pos_inf, m_NaN, m_neg_inf)
import Numeric.SpecFunctions (incompleteGamma, invIncompleteGamma, logGamma, digamma)
import Statistics.Distribution.Poisson.Internal as Poisson
import qualified Statistics.Distribution as D
import qualified System.Random.MWC.Distributions as MWC

-- | The gamma distribution.
data GammaDistribution = GD {
      gdShape :: {-# UNPACK #-} !Double -- ^ Shape parameter, /k/.
    , gdScale :: {-# UNPACK #-} !Double -- ^ Scale parameter, &#977;.
    } deriving (Eq, Read, Show, Typeable, Data, Generic)

instance FromJSON GammaDistribution
instance ToJSON GammaDistribution

instance Binary GammaDistribution where
    put (GD x y) = put x >> put y
    get = GD <$> get <*> get

-- | Create gamma distribution. Both shape and scale parameters must
-- be positive.
gammaDistr :: Double            -- ^ Shape parameter. /k/
           -> Double            -- ^ Scale parameter, &#977;.
           -> GammaDistribution
gammaDistr k theta
  | k     <= 0 = error $ msg ++ "shape must be positive. Got " ++ show k
  | theta <= 0 = error $ msg ++ "scale must be positive. Got " ++ show theta
  | otherwise  = improperGammaDistr k theta
    where msg = "Statistics.Distribution.Gamma.gammaDistr: "

-- | Create gamma distribution. This constructor do not check whether
--   parameters are valid
improperGammaDistr :: Double            -- ^ Shape parameter. /k/
                   -> Double            -- ^ Scale parameter, &#977;.
                   -> GammaDistribution
improperGammaDistr = GD

instance D.Distribution GammaDistribution where
    cumulative = cumulative

instance D.ContDistr GammaDistribution where
    density    = density
    logDensity (GD k theta) x
      | x <= 0    = m_neg_inf
      | otherwise = log x * (k - 1) - (x / theta) - logGamma k - log theta * k
    quantile   = quantile

instance D.Variance GammaDistribution where
    variance (GD a l) = a * l * l

instance D.Mean GammaDistribution where
    mean (GD a l) = a * l

instance D.MaybeMean GammaDistribution where
    maybeMean = Just . D.mean

instance D.MaybeVariance GammaDistribution where
    maybeStdDev   = Just . D.stdDev
    maybeVariance = Just . D.variance

instance D.MaybeEntropy GammaDistribution where
  maybeEntropy (GD a l)
    | a > 0 && l > 0 =
      Just $
      a
      + log l
      + logGamma a
      + (1-a) * digamma a
    | otherwise = Nothing

instance D.ContGen GammaDistribution where
    genContVar (GD a l) = MWC.gamma a l


density :: GammaDistribution -> Double -> Double
density (GD a l) x
  | a < 0 || l <= 0   = m_NaN
  | x <= 0            = 0
  | a == 0            = if x == 0 then m_pos_inf else 0
  | x == 0            = if a < 1 then m_pos_inf else if a > 1 then 0 else 1/l
  | a < 1             = Poisson.probability (x/l) a * a / x
  | otherwise         = Poisson.probability (x/l) (a-1) / l

cumulative :: GammaDistribution -> Double -> Double
cumulative (GD k l) x
  | x <= 0    = 0
  | otherwise = incompleteGamma k (x/l)

quantile :: GammaDistribution -> Double -> Double
quantile (GD k l) p
  | p == 0         = 0
  | p == 1         = 1/0
  | p > 0 && p < 1 = l * invIncompleteGamma k p
  | otherwise      =
    error $ "Statistics.Distribution.Gamma.quantile: p must be in [0,1] range. Got: "++show p
