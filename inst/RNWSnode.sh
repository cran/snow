#! /bin/sh

${RPROG:-R} --vanilla <<EOF > ${OUT:-/dev/null} 2>&1 &

library(nws)
library(snow)

slaveLoop(makeNWSmaster())
EOF
