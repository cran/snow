#
# PVM Implementation
#

newPVMnode <- function(where = "",
                       options = defaultClusterOptions) {
    # **** allow some form of spec here
    # **** make sure options are quoted
    scriptdir <- getClusterOption("scriptdir", options)
    outfile <- getClusterOption("outfile", options)
    if (getClusterOption("homogeneous")) {
        script <- file.path(scriptdir, "RPVMnode.sh")
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
                  "RunSnowNode", "RPVMnode.sh")
    }
    tid <- .PVM.spawn(task="/usr/bin/env", arglist = args, where = where)
    structure(list(tid = tid, RECVTAG = 33,SENDTAG = 22), class = "PVMnode")
}

makePVMmaster <- function()
    structure(list(tid = .PVM.parent (), RECVTAG = 22, SENDTAG = 33),
              class = "PVMnode")

sendData.PVMnode <- function(node, data) {
    .PVM.initsend ()
    .PVM.serialize(data, node$con)
    .PVM.send (node$tid, node$SENDTAG)
}

recvData.PVMnode <- function(node) {
    .PVM.recv (node$tid, node$RECVTAG)
    .PVM.unserialize(node$con)
}

recvOneData.PVMcluster <- function(cl) {
    rtag <- findRecvOneTag(cl, -1)
    binfo <- .PVM.bufinfo(.PVM.recv(-1, rtag))
    for (i in seq(along = cl)) {
        if (cl[[i]]$tid == binfo$tid) {
            n <- i
            break
        }
    }
    data <- .PVM.unserialize()
    list(node = n, value = data)
}

makePVMcluster <- function(count, ..., options = defaultClusterOptions) {
    if (! require(rpvm))
        stop("the `rpvm' package is needed for PVM clusters.")
    options <- addClusterOptions(options, list(...))
    cl <- vector("list",count)
    for (i in seq(along=cl))
        cl[[i]] <- newPVMnode(options = options)
    class(cl) <- c("PVMcluster")
    cl
}
