\name{snow-cluster}
\title{Cluster-Level SNOW Functions}
\alias{clusterSplit}
\alias{clusterCall}
\alias{clusterApply}
\alias{clusterApplyLB}
\alias{clusterEvalQ}
\alias{clusterExport}
\usage{
clusterSplit(cl, seq)
clusterCall(cl, fun, ...)
clusterApply(cl, x, fun, ...)
clusterApplyLB(cl, x, fun, ...)
clusterEvalQ(cl, expr)
clusterExport(cl, list)
}
\arguments{
  \item{cl}{cluster object}
  \item{fun}{function or character string naming a function}
  \item{expr}{expression to evaluate}
  \item{seq}{vector to split}
  \item{list}{character vector of variables to export}
  \item{x}{array}
  \item{...}{additional arguments to pass to standard function}
}
\description{
  Functions for computing on a SNOW cluster.
}
\details{
  These are the basic functions for computing on a cluster.  All
  evaluations on the slave nodes are done using \code{try}.  Currently
  the result lists returned by the cluster computing functions can a
  combination of proper results and \code{try} error objects.  More
  sophisticated approaches will be considered in the future.

  \code{clusterCall} calls a function \code{fun} with identical arguments 
  \code{...} on each node in the cluster \code{cl} and returns a list
  of the results.

  \code{clusterEvalQ} evaluates a literal expression on each cluster node.
  It a cluster version of \code{evalq}, and is a convenience function
  defined in terms of \code{clusterCall}.

  \code{clusterApply} calls \code{fun} on the first cluster node 
  with arguments \code{seq[[1]]} and \code{...}, on the second node with
  \code{seq[[2]]} and \code{...}, and so on.  The length of \code{seq}
  must be less than or equal to the number of nodes in the cluster.
  A list of the results is returned; the length of the result list
  will equal the length of \code{seq}.

  \code{clusterApplyLB} is a load balancing version of \code{clusterApply}.
  if the length \code{p} of \code{seq} is greater than the number of
  cluster nodes \code{n}, then the first \code{n} jobs are placed in
  order on the \code{n} nodes.  When the first job completes, the next
  job is placed on the available node; this continues until all jobs
  are complete.  Using \code{clusterApplyLB} can result in better
  cluster utilization than using \code{clusterApply}.  However,
  increased communication can reduce performance.  Furthermore, the
  node that executes a particular job is nondeterministic, which can
  complicate ensuring reproducibility in simulations.

  \code{clusterExport} assigns the global values on the master of the
  variables named in \code{list} to variables of the same names in the
  global environments of each node.

  \code{clusterSplit} splits \code{seq} into one consecutive piece for
  each cluster and returns the result as a list with length equal to the
  number of cluster nodes.  Currently the pieces are chosen to be close
  to equal in length.  Future releases will attempt to use relative
  performance information about nodes to choose split proportional to
  performance.

  For more details see
  \url{http://www.stat.uiowa.edu/~luke/R/cluster/cluster.html}.
}
\examples{
  \dontrun{
cl <- makeSOCKcluster(c("localhost","localhost"))

clusterApply(cl, 1:2, get("+"), 3)

clusterEvalQ(cl, library(boot))

x<-1
clusterExport(cl, "x")
clusterCall(cl, function(y) x + y, 2)

  }
}
\keyword{programming}
