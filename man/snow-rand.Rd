\name{snow-rand}
\title{Uniform Random Number Generation in SNOW Clusters}
\alias{clusterSetupSPRNG}
\usage{
clusterSetupSPRNG (cl, seed = round(2^32 * runif(1)),
                   prngkind = "default", para = 0) 

}
\arguments{
  \item{cl}{cluster object}
  \item{seed}{integer seed for SPRNG}
  \item{prngkind}{character string naming generator type}
  \item{para}{additional parameters for the generator}
}
\description{
  Initialize independent uniform random number streams on the nodes in a
  SNOW cluster.
}
\details{
  \code{clusterSetupSPRNG} loads the \code{rsprng} package and initializes
  separate streams  on each node. For further details see the documentation
  of \code{init.sprng}.  The generator on the master is not affected.

  For more details see
  \url{http://www.stat.uiowa.edu/~luke/R/cluster/cluster.html}.
}
\examples{
  \dontrun{
clusterSetupSPRNG(cl)
clusterSetupSPRNG(cl, seed=1234)
  }
}
\keyword{internal}
