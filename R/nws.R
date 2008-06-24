#
# NWS Implementation
#

# driver side
newNWSnode <- function(machine = "localhost", tmpWsName, rank, ws,
                       wsServer, state, options) {
    port <- getClusterOption("port", options)
    scriptdir <- getClusterOption("scriptdir", options)
    if (getClusterOption("homogeneous")) {
        script <- file.path(scriptdir, "RNWSnode.sh")
        rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
        rprog <- getClusterOption("rprog", options)
    }   
    else {
        script <- "RunSnowNode RNWSnode.sh"
        rlibs <- NULL
        rprog <- NULL
    }
    rshcmd <- getClusterOption("rshcmd", options)
    user <- getClusterOption("user", options)
    env <- paste("MASTER=", getClusterOption("master", options),
                 " PORT=", port,
                 " OUT=", getClusterOption("outfile", options),
                 " RANK=", rank,
                 " TMPWS=", tmpWsName,
                 sep="")
    if (! is.null(rprog))
        env <- paste(env, " RPROG=", rprog, sep="")
    if (! is.null(rlibs))
        env <- paste(env, " R_LIBS=", rlibs, sep="")

    system(paste(rshcmd, "-l", user, machine, "env", env, script))

    structure(list(ws = ws,
                   wsServer = wsServer,
                   incomingVar = 'forDriver',
                   outgoingVar = sprintf('forNode%04d', rank),
                   rank = rank,
                   state = state,
                   mybuffer = sprintf('buffer%04d', rank),
                   host = machine),
              class = "NWSnode")
}

# compute engine side
makeNWSmaster <- function() {
    if (! require(nws))
        stop("the `nws' package is needed for NWS clusters.")

    ws <- netWorkSpace(tmpWs <- Sys.getenv("TMPWS"),
                       serverHost = Sys.getenv("MASTER"),
                       port = as.integer(Sys.getenv("PORT")))

    rank = as.integer(Sys.getenv("RANK"))
    structure(list(ws = ws,
                   outgoingVar = 'forDriver',
                   incomingVar = sprintf('forNode%04d', rank),
                   rank = rank),
              class = "NWSnode")
}

closeNode.NWSnode <- function(node) {}

# note that all messages to the driver include the rank of the sender.
# in a context where this information is not needed (and would be
# unexpected), we strip it out.  we can do this because the driver
# signals its interest in the node's identity implicitly via a call to
# recvOneData, rather than recvData.  if this ever changes, we will have
# to revisit this hack.
sendData.NWSnode <- function(node, data) {
  if (node$outgoingVar == 'forDriver')
    data <- list(node = node$rank, data = data)
  nwsStore(node$ws, node$outgoingVar, data)
}

recvData.NWSnode <- function(node) {
  if (node$incomingVar != 'forDriver') {
    data <- nwsFetch(node$ws, node$incomingVar)
  }
  else {
    # first check if we have already received a message for this node
    if (! is.null(node$state[[node$mybuffer]])) {
      # cat("debug: found a buffered message for", node$rank, "\n")
      data <- node$state[[node$mybuffer]]
      node$state[[node$mybuffer]] <- NULL
    }
    else {
      repeat {
        # get the next message
        d <- nwsFetch(node$ws, node$incomingVar)

        # find out who this data is from
        rank <- d$node
        data <- d$data

        # if it's from worker node$rank, we're done
        if (rank == node$rank) {
          # cat("debug: received the right message for", rank, "\n")
          break
        }

        # it's not, so stash this in node$state$buffer<rank>,
        # issuing a warning if node$state$buffer<rank> is not empty
        # cat("debug: received a message for", rank,
        #     "when I want one for", node$rank, "\n")
        k <- sprintf('buffer%04d', rank)
        if (! is.null(node$state[[k]]))
          warning("overwriting previous message")
        node$state[[k]] <- data
      }
    }
  }
  data
}

# only called from the driver and only when we care about
# the source of the data.
recvOneData.NWScluster <- function(cl) {
  # check if there is any previously received data
  # (I don't think there ever should be)
  for (i in seq(along=cl)) {
    bname <- sprintf('buffer%04d', i)
    if (! is.null(cl[[1]]$state[[bname]])) {
      # cat("debug: received a buffered message from node", i, "\n")
      warning("recvOneData called while there is buffered data",
         immediate.=TRUE)
      data <- cl[[1]]$state[[bname]]
      cl[[1]]$state[[bname]] <- NULL
      return(list(node = i, value = data))
    }
  }
  d <- nwsFetch(cl[[1]]$ws, 'forDriver')
  # cat("debug: received a message from node", d$node, "\n")
  list(node = d$node, value = d$data)
}

makeNWScluster <- function(names=rep('localhost', 3), ..., options = defaultClusterOptions) {
    if (! require(nws))
        stop("the `nws' package is needed for NWS clusters.")

    # this allows makeNWScluster to be called like makeMPIcluster and
    # makePVMcluster
    if (is.numeric(names))
        names <- rep('localhost', names[1])

    options <- addClusterOptions(options,
       list(port = 8765, scriptdir = .path.package("snow")))
    options <- addClusterOptions(options, list(...))

    wsServer <- nwsServer(serverHost = getClusterOption("master", options),
                           port = getClusterOption("port", options))

    state <- new.env()

    tmpWsName = nwsMktempWs(wsServer, 'snow_nws_%04d')
    ws = nwsOpenWs(wsServer, tmpWsName)
    cl <- vector("list", length(names))
    for (i in seq(along=cl)) 
        cl[[i]] <- newNWSnode(names[[i]], tmpWsName = tmpWsName, rank = i,
                              ws = ws, wsServer = wsServer, state = state, options = options)

    class(cl) <- c("NWScluster", "cluster")
    cl
}

stopCluster.NWScluster <- function(cl) {
  NextMethod()
  nwsDeleteWs(cl[[1]]$wsServer, nwsWsName(cl[[1]]$ws))
  close(cl[[1]]$wsServer)
}
