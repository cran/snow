#
# MPI Implementation
#

newMPInode <- function(rank, comm)
    structure(list(rank = rank, RECVTAG = 33, SENDTAG = 22, comm = comm),
              class = "MPInode")

makeMPImaster <- function(comm = 0)
    structure(list(rank = 0, RECVTAG = 22, SENDTAG = 33, comm = comm),
              class = "MPInode")

sendData.MPInode <- function(node, data)
    mpi.send.Robj(data, node$rank, node$SENDTAG, node$comm)

recvData.MPInode <- function(node)
    mpi.recv.Robj(node$rank, node$RECVTAG, node$comm)

recvOneData.MPIcluster <- function(cl) {
    rtag <- findRecvOneTag(cl, mpi.any.tag())
    comm <- cl[[1]]$comm  # should all be the same
    status <- 0
    mpi.probe(mpi.any.source(), rtag, comm, status)
    srctag <- mpi.get.sourcetag(status)
    data <- mpi.recv.Robj(srctag[1], srctag[2], comm)
    list(node = srctag[1], value = data)
}

getMPIcluster <- NULL
setMPIcluster <- NULL
local({
    cl <- NULL
    getMPIcluster <<- function() cl
    setMPIcluster <<- function(new) cl <<- new
})

makeMPIcluster <- function(count, ..., options = defaultClusterOptions) {
    if (! is.null(getMPIcluster())) stop("MPI cluster already running")
    options <- addClusterOptions(options, list(...))
    if (missing(count)) {
        # assume something like mpirun -np count+1 has been used to start R
        count <- mpi.comm.size(0) - 1
        if (count <= 0)
            stop("no nodes available.")
        cl <- vector("list",count)
        for (i in seq(along=cl))
            cl[[i]] <- newMPInode(i, 0)
        class(cl) <- "MPIcluster"
        setMPIcluster(cl)
        cl
    }
    else {
	# use process spawning to create cluster
        if (! require(Rmpi))
            stop("the `Rmpi' package is needed for MPI clusters.")
        comm <- 1
        intercomm <- 2
        if (mpi.comm.size(comm) > 0)
            stop(paste("a cluster already exists", comm))
        scriptdir <- getClusterOption("scriptdir", options)
        outfile <- getClusterOption("outfile", options)
        if (getClusterOption("homogeneous")) {
            script <- file.path(scriptdir, "RMPInode.sh")
            rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
            rprog <- getClusterOption("rprog", options)
            args <- c(paste("RPROG=", rprog, sep=""),
                      paste("OUT=", outfile, sep=""),
                      paste("R_LIBS=", rlibs, sep=""),
                      script)
        }
        else {
            rlibs <- NULL
            rprog <- NULL
            args <- c(paste("RPROG=", rprog, sep=""),
                      paste("OUT=", outfile, sep=""),
                      paste("R_LIBS=", rlibs, sep=""),
                      "RunSnowNode", "RMPInode.sh")
        }
        count <- mpi.comm.spawn(slave = "/usr/bin/env", slavearg = args,
                                nslaves = count, intercomm = intercomm)
        if (mpi.intercomm.merge(intercomm, 0, comm)) {
            mpi.comm.set.errhandler(comm)
            mpi.comm.disconnect(intercomm)
        }
        else stop("Failed to merge the comm for master and slaves.")
        cl <- vector("list",count)
        for (i in seq(along=cl))
            cl[[i]] <- newMPInode(i, comm)
        class(cl) <- c("spawnedMPIcluster",  "MPIcluster")
        setMPIcluster(cl)
        cl
    }
}

runMPIslave <- function() {
    comm <- 1
    intercomm <- 2
    mpi.comm.get.parent(intercomm)
    mpi.intercomm.merge(intercomm,1,comm)
    mpi.comm.set.errhandler(comm)
    mpi.comm.disconnect(intercomm)

    slaveLoop(makeMPImaster(comm))

    mpi.comm.disconnect(comm)
    mpi.quit()
}

stopCluster.MPIcluster <- function(cl) {
    NextMethod()
    setMPIcluster(NULL)
}
    
stopCluster.spawnedMPIcluster <- function(cl) {
    comm <- 1
    NextMethod()
    mpi.comm.disconnect(comm)
}

#**** figure out how to get mpi.quit called (similar issue for pvm?)
#**** fix things so stopCluster works in both versions.
#**** need .Last to make sure cluster is shut down on exit of master
#**** figure out why the slaves busy wait under mpirun