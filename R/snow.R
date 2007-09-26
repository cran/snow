#
# Utilities
#

enquote <- function(x) as.call(list(as.name("quote"), x))

docall <- function(fun, args) {
    if ((is.character(fun) && length(fun) == 1) || is.name(fun))
        fun <- get(as.character(fun), env = .GlobalEnv, mode = "function")
    do.call("fun", lapply(args, enquote))
}

if (! exists("emptyenv"))
    emptyenv <- function() NULL


#
# Checking and subsetting
#

checkCluster <- function(cl) {
    if (! inherits(cl, "cluster"))
        stop("not a valid cluster");
}    
    
"[.cluster" <-function(cl,...) {
    v<-unclass(cl)[...]
    class(v)<-class(cl)
    v
}


#
# Slave Loop Function
#

slaveLoop <- function(master) {
    repeat {
        msg <- recvData(master)
	cat(paste("Type:", msg$type, "\n"))

        if (msg$type == "DONE") {
            closeNode(master)
            break;
        }
        else if (msg$type == "EXEC") {
            value <- try(docall(msg$data$fun, msg$data$args))
            #**** use exception= if failure?
            value <- list(type = "VALUE", value = value, tag = msg$data$tag)
            sendData(master, value)
        }
    }
}


#
# Higher-Level Node Functions
#

closeNode <- function(node) UseMethod("closeNode")
closeNode.default <- function(node) {}

sendData <- function(node, data) UseMethod("sendData")
recvData <- function(node) UseMethod("recvData")

postNode <- function(con, type, value = NULL, tag = NULL) {
    sendData(con, list(type = type, data = value, tag = NULL))
}

stopNode <- function(n) {
    postNode(n, "DONE")
    closeNode(n)
}


recvOneData <- function(cl) UseMethod("recvOneData")
    

#
#  Cluster Creation and Destruction
#

defaultClusterOptions <- NULL

#**** check valid cluster option

initDefaultClusterOptions <- function() {
    rhome <- Sys.getenv("R_HOME")
    if (Sys.getenv("R_SNOW_LIB") != "")
        homogeneous <- FALSE
    else homogeneous <- TRUE
    options <- list(port = 10187,
                    timeout = 60 * 60 * 24 * 14, # two weeks
                    master =  Sys.info()["nodename"],
                    homogeneous = homogeneous,
                    type = NULL,
                    outfile = "/dev/null",
                    rhome = rhome,
                    user = Sys.info()["user"],
                    rshcmd = "ssh",
                    rlibs = Sys.getenv("R_LIBS"),
                    scriptdir = .path.package("snow"),
                    rprog = file.path(rhome, "bin", "R"))
    defaultClusterOptions <<- addClusterOptions(emptyenv(), options)
}

addClusterOptions <- function(options, new) {
    if (! is.null(new)) {
        options <- new.env(parent = options)
        names <- names(new)
        for (i in seq(along = new))
            assign(names[i], new[[i]], env = options)
    }
    options
}

getClusterOption <- function(name, options = defaultClusterOptions)
    get(name, env = options)

setDefaultClusterOptions <- function(...) {
    list <- list(...)
    names <- names(list)
    for (i in seq(along = list))
        assign(names[i], list[[i]], env = defaultClusterOptions)
}

makeCluster <- function(spec, type = getClusterOption("type"), ...) {
    if (is.null(type))
        stop("need to specify a cluster type")
    switch(type,
        SOCK = makeSOCKcluster(spec, ...),
        PVM = makePVMcluster(spec, ...),
        MPI = makeMPIcluster(spec, ...),
        stop("unknown cluster type"))
}

stopCluster <- function(cl) UseMethod("stopCluster")

stopCluster.default <- function(cl)
    for (n in cl) stopNode(n)


#
# Cluster Functions
#

sendCall <- function(con, fun, args, return = TRUE)
    #**** mark node as in-call
    postNode(con, "EXEC", list(fun = fun, args = args, return = return))

recvResult <- function(con) recvData(con)$value

clusterCall  <- function(cl, fun, ...) {
    checkCluster(cl)
    for (i in seq(along = cl))
        sendCall(cl[[i]], fun, list(...))
    lapply(cl, recvResult)
}

clusterApply <- function(cl, x, fun, ...) {
    checkCluster(cl)
    if (length(cl) < length(x))
        stop("data length must be at most cluster size")
    for (i in seq(along = x))
        sendCall(cl[[i]], fun, c(list(x[[i]]), list(...)))
    lapply(cl[seq(along=x)], recvResult)
}

clusterEvalQ<-function(cl, expr)
    clusterCall(cl, eval, substitute(expr), env=.GlobalEnv)

clusterExport <- function(cl, list) {
    # do this with only one clusterCall--loop on slaves?
    gets <- function(n, v) { assign(n, v, env = .GlobalEnv); NULL }
    for (name in list) {
        clusterCall(cl, gets, name, get(name, env = .GlobalEnv))
    }
}

## A variant that does the exports one at at ime--this may be useful
## when large objects are being sent
# clusterExportSerial <- function(cl, list) {
#     gets <- function(n, v) { assign(n, v, env = .GlobalEnv); NULL }
#     for (name in list) {
#         v <- get(name, env = .GlobalEnv)
#         for (i in seq(along = cl)) {
#             sendCall(cl[[i]], gets, list(name, v))
#             recvResult(cl[[i]])
#         }
#     }
# }

recvOneResult <- function(cl) {
    v <- recvOneData(cl)
    list(value = v$value$value, node=v$node)
}

findRecvOneTag <- function(cl, anytag) {
    rtag <- NULL
    for (node in cl) {
        if (is.null(rtag))
            rtag <- node$RECVTAG
        else if (rtag != node$RECVTAG) {
            rtag <- anytag
            break;
        }
    }
    rtag
}

## this is separate to avoid capturing data in the closure
clusterLBwrap <- function(fun) {
    force(fun)
    function(x, i, ...) list(value = try(fun(x, ...)), index = i)
}

clusterApplyLB <- function(cl, x, fun, ...) {
    checkCluster(cl)
    n <- length(x)
    p <- length(cl)
    if (n > 0 && p > 0) {
        wrap <- clusterLBwrap(fun)
        submit <- function(node, job) {
            args <- c(list(x[[job]]), list(job), list(...))
            sendCall(cl[[node]], wrap, args)
        }
        for (i in 1 : min(n, p))
            submit(i, i)
        val <- vector("list", length(x))
        for (i in seq(along = x)) {
            d <- recvOneResult(cl)
            j <- i + min(n, p)
            if (j <= n)
                submit(d$node, j)
            val[d$value$index] <- list(d$value$value)
        }
        val
    }
}

## **** should this just be done in terms of clusterApply?
## **** should this allow load balancing?
## **** disallow recycling if one arg is length zero?
clusterMap <- function(cl, fun, ..., MoreArgs = NULL, RECYCLE = TRUE) {
    checkCluster(cl)
    args <- list(...)
    if (length(args) == 0)
        stop("need at least one argument")
    n <- sapply(args, length)
    if (any(length(cl) < n))
        stop("data lengths must be at most cluster size")
    if (RECYCLE) {
        vlen <- max(n)
        if (! all(n == vlen))
            ## expand all arguments -- inefficient but simple
            for (i in 1:length(args))
                args[[i]] <- rep(args[[i]], length = max(n))
    }
    else vlen = min(n)
    if (vlen == 0)
        NULL
    else {
        for (i in 1:vlen) {
            nodeargs <- c(lapply(args, function(x) x[[i]]), MoreArgs)
            sendCall(cl[[i]], fun, nodeargs)
        }
        lapply(cl[1:vlen], recvResult)
    }
}


#
# Cluster RNG Support
#

clusterSetupRNG <- function (cl, type="RNGstream", ...) {
    RNGnames <- c("RNGstream", "SPRNG")
    rng <- pmatch (type, RNGnames)
    if (is.na(rng))
        stop(paste("'", type,
                   "' is not a valid choice. Choose 'RNGstream' or 'SPRNG'.",
                   sep = ""))
    type <- RNGnames[rng]
    if (rng == 1)
        clusterSetupRNGstream(cl, ...)
    else clusterSetupSPRNG(cl, ...)
    type
}


#
# Cluster SPRNG Support 
#
# adapted from rpvm (Li & Rossini)

clusterSetupSPRNG <- function (cl, seed = round(2^32 * runif(1)),
                            prngkind = "default", para = 0, ...) 
{
    if (!is.character(prngkind) || length(prngkind) > 1)
        stop("'rngkind' must be a character string of length 1.")
    if (!is.na(pmatch(prngkind, "default")))
        prngkind <- "LFG"
    prngnames <- c("LFG", "LCG", "LCG64", "CMRG", "MLFG", "PMLCG")
    kind <- pmatch(prngkind, prngnames) - 1
    if (is.na(kind))
        stop(paste("'", prngkind, "' is not a valid choice", sep = ""))
    nc <- length(cl)
    invisible(clusterApply(cl, 0:(nc-1), initSprngNode, nc, seed, kind, para))
}

initSprngNode <- function (streamno, nstream, seed, kind, para) 
{
    if (! require(rsprng))
        stop("the `rsprng' package is needed for SPRNG support.")
    .Call("r_init_sprng", as.integer(kind), as.integer(streamno), 
        as.integer(nstream), as.integer(seed), as.integer(para),
        PACKAGE = "rsprng")
    RNGkind("user")
}


#
# rlecuyer support
#

clusterSetupRNGstream <- function (cl, seed=rep(12345,6), ...) {
    if (! require(rlecuyer))
        stop("the `rlecuyer' package is needed for RNGstream support.")
    .lec.init()
    .lec.SetPackageSeed(seed)
    nc <- length(cl)
    names <- as.character(1:nc)
    .lec.CreateStream(names)
    states <- lapply(names, .lec.GetStateList)
    invisible(clusterApply(cl, states, initRNGstreamNode))
}

initRNGstreamNode <- function (stream) {
    if (! require(rlecuyer))
        stop("the `rlecuyer' package is needed for RNGstream support.") 

    if (length(.lec.Random.seed.table$name) > 0) {
	rm(".lec.Random.seed.table", envir=.GlobalEnv)
	assign(".lec.Random.seed.table", list(Cg=matrix(0,nrow=0,ncol=6),
                                              Bg=matrix(0,nrow=0,ncol=6),
                                              Ig=matrix(0,nrow=0,ncol=6),
                                              AIP=matrix(0,nrow=0,ncol=2),
                                              name=c()), envir=.GlobalEnv)
    }
    .lec.Random.seed.table$Cg <<- rbind(.lec.Random.seed.table$Cg,
                                        stream$Cg[1:6])
    .lec.Random.seed.table$Bg <<- rbind(.lec.Random.seed.table$Bg,stream$Bg)
    .lec.Random.seed.table$Ig <<- rbind(.lec.Random.seed.table$Ig,stream$Ig)
    .lec.Random.seed.table$AIP <<- rbind(.lec.Random.seed.table$AIP,
                                         c(stream$Anti, stream$IncPrec))
    .lec.Random.seed.table$name <<- c(.lec.Random.seed.table$name, stream$name)

    old.kind<-.lec.CurrentStream(stream$name)
    old.kind
}


#
# Parallel Functions
#

splitIndices <- function(nx, ncl) {
    batchsize <- if (nx %% ncl == 0) nx %/% ncl else 1 + nx %/% ncl
    batches <- (nx + batchsize - 1) %/% batchsize
    split(1:nx, rep(1:batches, each = batchsize)[1:nx])
}

splitIndices <- function(nx, ncl) {
    i <- 1:nx;
    if (ncl == 1) i
    else structure(split(i, cut(i, ncl)), names=NULL)
}

clusterSplit <- function(cl, seq)
    lapply(splitIndices(length(seq), length(cl)), function(i) seq[i])

splitList <- function(x, ncl)
    lapply(splitIndices(length(x), ncl), function(i) x[i])

splitRows <- function(x, ncl)
    lapply(splitIndices(nrow(x), ncl), function(i) x[i,, drop=F])

splitCols <- function(x, ncl)
    lapply(splitIndices(ncol(x), ncl), function(i) x[,i, drop=F])

parLapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitList(x, length(cl)), lapply, fun, ...))

parRapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitRows(x,length(cl)), apply, 1, fun, ...))

parCapply <- function(cl, x, fun, ...)
    docall(c, clusterApply(cl, splitCols(x,length(cl)), apply, 2, fun, ...))

parMM <- function(cl, A, B)
    docall(rbind,clusterApply(cl, splitRows(A, length(cl)), get("%*%"), B))

# adapted from sapply in the R sources
parSapply <- function (cl, X, FUN, ..., simplify = TRUE, USE.NAMES = TRUE) 
{
    FUN <- match.fun(FUN) # should this be done on slave?
    answer <- parLapply(cl,as.list(X), FUN, ...)
    if (USE.NAMES && is.character(X) && is.null(names(answer))) 
        names(answer) <- X
    if (simplify && length(answer) != 0) {
        common.len <- unique(unlist(lapply(answer, length)))
        if (common.len == 1) 
            unlist(answer, recursive = FALSE)
        else if (common.len > 1) 
            array(unlist(answer, recursive = FALSE),
                  dim = c(common.len, length(X)),
                  dimnames = list(names(answer[[1]]), names(answer)))
        else answer
    }
    else answer
}

# adapted from apply in the R sources
parApply <- function(cl, X, MARGIN, FUN, ...)
{
    FUN <- match.fun(FUN) # should this be done on slave?

    ## Ensure that X is an array object
    d <- dim(X)
    dl <- length(d)
    if(dl == 0)
	stop("dim(X) must have a positive length")
    ds <- 1:dl

    # for compatibility with R versions prior to 1.7.0
    if (! exists("oldClass"))
	oldClass <- class
    if(length(oldClass(X)) > 0)
	X <- if(dl == 2) as.matrix(X) else as.array(X)
    dn <- dimnames(X)

    ## Extract the margins and associated dimnames

    s.call <- ds[-MARGIN]
    s.ans  <- ds[MARGIN]
    d.call <- d[-MARGIN]
    d.ans  <- d[MARGIN]
    dn.call<- dn[-MARGIN]
    dn.ans <- dn[MARGIN]
    ## dimnames(X) <- NULL

    ## do the calls

    d2 <- prod(d.ans)
    if(d2 == 0) {
        ## arrays with some 0 extents: return ``empty result'' trying
        ## to use proper mode and dimension:
        ## The following is still a bit `hackish': use non-empty X
        newX <- array(vector(typeof(X), 1), dim = c(prod(d.call), 1))
        ans <- FUN(if(length(d.call) < 2) newX[,1] else
                   array(newX[,1], d.call, dn.call), ...)
        return(if(is.null(ans)) ans else if(length(d.call) < 2) ans[1][-1]
               else array(ans, d.ans, dn.ans))
    }
    ## else
    newX <- aperm(X, c(s.call, s.ans))
    dim(newX) <- c(prod(d.call), d2)
    if(length(d.call) < 2) {# vector
        if (length(dn.call)) dimnames(newX) <- c(dn.call, list(NULL))
        ans <- parLapply(cl, 1:d2, function(i) FUN(newX[,i], ...))
    } else
        ans <- parLapply(cl, 1:d2,
            function(i) FUN(array(newX[,i], d.call, dn.call), ...))

    ## answer dims and dimnames

    ans.list <- is.recursive(ans[[1]])
    l.ans <- length(ans[[1]])

    ans.names <- names(ans[[1]])
    if(!ans.list)
	ans.list <- any(unlist(lapply(ans, length)) != l.ans)
    if(!ans.list && length(ans.names)) {
        all.same <- sapply(ans, function(x) identical(names(x), ans.names))
        if (!all(all.same)) ans.names <- NULL
    }
    len.a <- if(ans.list) d2 else length(ans <- unlist(ans, recursive = FALSE))
    if(length(MARGIN) == 1 && len.a == d2) {
	names(ans) <- if(length(dn.ans[[1]])) dn.ans[[1]] # else NULL
	return(ans)
    }
    if(len.a == d2)
	return(array(ans, d.ans, dn.ans))
    if(len.a > 0 && len.a %% d2 == 0)
	return(array(ans, c(len.a %/% d2, d.ans),
                     if(is.null(dn.ans)) {
                         if(!is.null(ans.names)) list(ans.names,NULL)
                     } else c(list(ans.names), dn.ans)))
    return(ans)
}


#
#  Library Initialization
#

.First.lib <- function(libname, pkgname) {
    if (is.null(defaultClusterOptions)) {
	initDefaultClusterOptions()
        if (length(find("mpi.comm.size")) != 0)
            type <- "MPI"
        else if (length(.find.package("rpvm", quiet = TRUE)) != 0)
            type <- "PVM"
        else if (length(.find.package("Rmpi", quiet = TRUE)) != 0)
            type <- "MPI"
        else type <- "SOCK"
        setDefaultClusterOptions(type = type)
    }
}
