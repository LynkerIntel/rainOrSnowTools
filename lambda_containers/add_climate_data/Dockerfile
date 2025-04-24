FROM rocker/geospatial@sha256:d574731e9436748683f001fb40c391a9d3358135de1f4c8285ae99fb07b39c41
# FROM ghcr.io/rocker-org/geospatial@sha256:d574731e9436748683f001fb40c391a9d3358135de1f4c8285ae99fb07b39c41
# FROM rocker/geospatial:4.3

# # Specifiying x86_64
COPY --from=public.ecr.aws/lambda/provided:al2.2023.05.13.00-x86_64 /lambda-entrypoint.sh /lambda-entrypoint.sh
COPY --from=public.ecr.aws/lambda/provided:al2.2023.05.13.00-x86_64 /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie

ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime

RUN mkdir ${LAMBDA_RUNTIME_DIR}
RUN mkdir ${LAMBDA_TASK_ROOT}
WORKDIR ${LAMBDA_TASK_ROOT}
ENTRYPOINT ["/lambda-entrypoint.sh"]

# install R packages
RUN install2.r remotes dplyr plyr lubridate codetools paws
# RUN install2.r digest terra remotes dplyr tidyr plyr readr lubridate codetools paws

# Add rust cargo 
# RUN apt-get install cargo
RUN curl -y https://sh.rustup.rs -sSf | sh

# try to install gifski
RUN installGithub.r r-rust/gifski

# install lambdr R package
RUN installGithub.r mdneuzerling/lambdr@a3cece5b23f9f1b89e95972506f79f9a6eb2ee22
# RUN installGithub.r mdneuzerling/lambdr@HEAD

# Install AOI R package
RUN installGithub.r mikejohnson51/AOI@f821d499b80371c7c389937072ea041312a8efcd
# RUN installGithub.r mikejohnson51/AOI@HEAD

# Install climateR R package
RUN installGithub.r mikejohnson51/climateR@81a644319bf4566ac507e80f7aa8b1538c611deb
# RUN installGithub.r mikejohnson51/climateR@b73a3167a557840349c63ecc310afc182a1a3156

# this forces rainOrSnowTools to be installed from github on every build
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

RUN installGithub.r LynkerIntel/rainOrSnowTools@main

RUN mkdir /lambda
COPY add_climate_data.R /lambda

# Environment variable defaults
ENV NASA_DATA_USER=default_user
ENV NASA_DATA_PASSWORD=default_password
ENV SQS_QUEUE_NAME=default
ENV SQS_QUEUE_URL=default
ENV S3_BUCKET_NAME=default

# Create .dodsrc file
RUN cd /lambda && Rscript -e ' \
    dodsrcFile <- ".dodsrc"; \
    netrcFile <- "/tmp/.netrc"; \
    unlink(dodsrcFile); \
    dir <- dirname(dodsrcFile); \
    string <- paste0( \
        "USE_CACHE=0\n", \
        "MAX_CACHE_SIZE=20\n", \
        "MAX_CACHED_OBJ=5\n", \
        "IGNORE_EXPIRES=0\n", \
        "DEFAULT_EXPIRES=86400\n", \
        "ALWAYS_VALIDATE=0\n", \
        "DEFLATE=0\n", \
        "VALIDATE_SSL=1\n", \
        paste0("HTTP.COOKIEJAR=/tmp/.urs_cookies\n"), \
        paste0("HTTP.NETRC=", netrcFile)); \
    write(string, path.expand(dodsrcFile)); \
    Sys.chmod(dodsrcFile, mode = "755")' && cd -

# Set ${LAMBDA_TASK_ROOT}/add_climate_data.R as the designated script file
RUN chmod 755 -R /lambda \
    && printf "#!/bin/sh\ncd /lambda\nRscript add_climate_data.R" > /var/runtime/bootstrap \
    && chmod +x /var/runtime/bootstrap

# Just the function name from the above script
CMD ["add_climate_data"]
