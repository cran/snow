#
# Socket Implementation
#

#**** allow user to be different on different machines
#**** allow machinse to be selected from a hosts list
newSOCKnode <- function(machine = "localhost", ...,
                        options = defaultClusterOptions) {
    # **** allow some form of spec here
    # **** make sure options are quoted
    options <- addClusterOptions(options, list(...))
    port <- getClusterOption("port", options)
    scriptdir <- getClusterOption("scriptdir", options)
    if (getClusterOption("homogeneous")) {
        script <- file.path(scriptdir, "RSOCKnode.sh")
        rlibs <- paste(getClusterOption("rlibs", options), collapse = ":")
        rprog <- getClusterOption("rprog", options)
    }   
    else {
        script <- "RunSnowNode RSOCKnode.sh"
        rlibs <- NULL
        rprog <- NULL
    }
    rshcmd <- getClusterOption("rshcmd", options)
    user <- getClusterOption("user", options)
    env <- paste("MASTER=", getClusterOption("master", options),
                 " PORT=", port,
                 " OUT=", getClusterOption("outfile", options),
                 sep="")
    if (! is.null(rprog))
        env <- paste(env, " RPROG=", rprog, sep="")
    if (! is.null(rlibs))
        env <- paste(env, " R_LIBS=", rlibs, sep="")

    system(paste(rshcmd, "-l", user, machine, "env", env, script))
    con <- socketConnection(port = port, server=TRUE, blocking=TRUE,
                            open="a+b")
    structure(list(con = con, host = machine), class = "SOCKnode")
}

makeSOCKmaster <- function() {
    master <- Sys.getenv("MASTER")
    port <- as.integer(Sys.getenv("PORT"))
    # maybe use `try' and slep/retry if first time fails?
    con <- socketConnection(master, port = port, blocking=TRUE, open="a+b")
    structure(list(con = con), class = "SOCKnode")
}

closeNode.SOCKnode <- function(node) close(node$con)

sendData.SOCKnode <- function(node, data) {
    timeout <- getClusterOption("timeout")
    old <- options(timeout = timeout);
    on.exit(options(old))
    serialize(data, node$con)
}

recvData.SOCKnode <- function(node) {
    timeout <- getClusterOption("timeout")
    old <- options(timeout = timeout);
    on.exit(options(old))
    unserialize(node$con)
}

recvOneData.SOCKcluster <- function(cl) {
    socklist <- lapply(cl, function(x) x$con)
    repeat {
        ready <- socketSelect(socklist)
        if (length(ready) > 0) break;
    }
    n <- which(ready)[1]  # may need rotation or some such for fairness
    list(node = n, value = unserialize(socklist[[n]]))
}

makeSOCKcluster <- function(names, ..., options = defaultClusterOptions) {
    if (! exists("serialize") && ! require(serialize))
        stop("the `serialize' package is needed for SOCK clusters.")
    options <- addClusterOptions(options, list(...))
    cl <- vector("list",length(names))
    for (i in seq(along=cl))
        cl[[i]] <- newSOCKnode(names[[i]], options = options)
    class(cl) <- c("SOCKcluster")
    cl
}
