\name{snow-internal}
\title{Internal SNOW Objects}
\alias{runMPIslave}
\alias{setMPIcluster}
\alias{stopCluster.default}
\alias{stopCluster.MPIcluster}
\alias{stopCluster.spawnedMPIcluster}
\alias{defaultClusterOptions}
\alias{enquote}
\alias{docall}
\alias{slaveLoop}
\alias{newSOCKnode}
\alias{makeSOCKmaster}
\alias{closeNode.SOCKnode}
\alias{sendData.SOCKnode}
\alias{recvData.SOCKnode}
\alias{newPVMnode}
\alias{makePVMmaster}
\alias{closeNode.PVMnode}
\alias{sendData.PVMnode}
\alias{recvData.PVMnode}
\alias{newMPInode}
\alias{makeMPImaster}
\alias{closeNode.MPInode}
\alias{sendData.MPInode}
\alias{recvData.MPInode}
\alias{closeNode}
\alias{closeNode.default}
\alias{sendData}
\alias{recvData}
\alias{sendNode}
\alias{postNode}
\alias{stopNode}
\alias{sendCall}
\alias{recvResult}
\alias{initSprngNode}
\alias{splitIndices}
\alias{splitList}
\alias{splitRows}
\alias{splitCols}
\alias{addClusterOptions}
\alias{initDefaultClusterOptions}
\alias{findRecvOneTag}
\alias{recvOneData}
\alias{recvOneData.MPIcluster}
\alias{recvOneData.PVMcluster}
\alias{recvOneResult}
\alias{getClusterOption}
\usage{
stopCluster.default(cl)
stopCluster.MPIcluster(cl)
stopCluster.spawnedMPIcluster(cl)
defaultClusterOptions
addClusterOptions(options, new)
initDefaultClusterOptions()

enquote(x)
docall(fun, args)
slaveLoop(master)

newSOCKnode(machine = "localhost", ..., options = defaultClusterOptions)
makeSOCKmaster()
closeNode.SOCKnode(node)
sendData.SOCKnode(node, data)
recvData.SOCKnode(node)

newPVMnode(where = "", options = defaultClusterOptions)
makePVMmaster()
sendData.PVMnode(node, data)
recvData.PVMnode(node)

setMPIcluster(new)
runMPIslave()
newMPInode(rank, comm)
makeMPImaster(comm)
sendData.MPInode(node, data)
recvData.MPInode(node)

closeNode(node)
closeNode.default(node)
sendData(node, data)
recvData(node)

postNode(con, type, value = NULL, tag = NULL)
stopNode(n)

sendCall(con, fun, args, return = TRUE)
recvResult(con)

initSprngNode(streamno, nstream, seed, kind, para) 

splitIndices(nx, ncl)
splitList(x, ncl)
splitRows(x, ncl)
splitCols(x, ncl)

findRecvOneTag(cl, anytag)
recvOneData(cl)
recvOneResult(cl)
recvOneData.MPIcluster(cl)
recvOneData.PVMcluster(cl)
getClusterOption(name, options = defaultClusterOptions)
}
\description{
  Internal functions for the snow package.
}
\details{
  These are not to be called by the user.
}
\keyword{internal}
