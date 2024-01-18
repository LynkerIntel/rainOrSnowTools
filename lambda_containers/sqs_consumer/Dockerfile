FROM rocker/geospatial:4.3

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
RUN install2.r digest terra remotes dplyr tidyr plyr readr lubridate codetools paws
# RUN install2.r digest terra remotes dplyr tidyr plyr readr lubridate codetools paws lambdr

# Add rust cargo 
# RUN apt-get install cargo
RUN curl -y https://sh.rustup.rs -sSf | sh

# try to install gifski
RUN installGithub.r r-rust/gifski

# install AOI, climateR, and rainOrSnowTools...
RUN installGithub.r mdneuzerling/lambdr@HEAD
RUN installGithub.r mikejohnson51/AOI@HEAD
RUN installGithub.r mikejohnson51/climateR@HEAD

ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

RUN installGithub.r SnowHydrology/rainOrSnowTools@cicd_pipeline

RUN mkdir /lambda
COPY sqs_consumer.R /lambda

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

# # (NEW GIVE Read/Write/Execute permissions to 'root/.netrc' )Create .netrc file in /lambda
# RUN Rscript -e 'climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"), netrcFile =  "/lambda/.netrc")' 

# # (NEW GIVE Read/Write/Execute permissions to 'root/.netrc' )Create .netrc file in /lambda
# RUN Rscript -e 'climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"), netrcFile =  "/lambda/.netrc")' && \
#     chmod 755 /lambda/.netrc

# # Create .urs_cookies file in /root
# RUN touch /lambda/.urs_cookies && \
#     chmod 755 /lambda/.urs_cookies

# # Create .dodsrc file
# RUN cd /lambda && Rscript -e 'climateR::writeDodsrc(netrcFile = "/lambda/.netrc", dodsrcFile = ".dodsrc")' && cd -

# # Create .dodsrc file
# # RUN cd /tmp && Rscript -e 'climateR::writeDodsrc(netrcFile = "/tmp/.netrc", dodsrcFile = ".dodsrc")' && cd -

# RUN cd /lambda && Rscript -e 'climateR::writeDodsrc(netrcFile = "/tmp/.netrc", dodsrcFile = ".dodsrc")' && cd -

# # (NEW GIVE Read/Write/Execute permissions to 'root/.netrc' )Create .netrc file in /lambda
# RUN Rscript -e 'climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"))' && \
#     chmod 755 /root/.netrc

# # Create .urs_cookies file in /root
# RUN touch /root/.urs_cookies && \
#     chmod 755 /root/.urs_cookies

# # Create .dodsrc file
# RUN cd /lambda && Rscript -e 'climateR::writeDodsrc()' && cd -

# Set ${LAMBDA_TASK_ROOT}/sqs_consumer.R as the designated script file
RUN chmod 755 -R /lambda \
    && printf "#!/bin/sh\ncd /lambda\nRscript sqs_consumer.R" > /var/runtime/bootstrap \
    && chmod +x /var/runtime/bootstrap

# Just the function name from the above script
CMD ["sqs_consumer"]
