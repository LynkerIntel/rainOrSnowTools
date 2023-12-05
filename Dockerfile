FROM rocker/geospatial:4.3

COPY --from=public.ecr.aws/lambda/provided:al2.2023.05.13.00 /lambda-entrypoint.sh /lambda-entrypoint.sh
COPY --from=public.ecr.aws/lambda/provided:al2.2023.05.13.00 /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie
ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime

RUN mkdir ${LAMBDA_RUNTIME_DIR}
RUN mkdir ${LAMBDA_TASK_ROOT}
WORKDIR ${LAMBDA_TASK_ROOT}
ENTRYPOINT ["/lambda-entrypoint.sh"]

# install R packages
RUN install2.r digest terra lambdr remotes dplyr tidyr plyr readr lubridate codetools

# Add rust cargo 
# RUN apt-get install cargo
RUN curl -y https://sh.rustup.rs -sSf | sh

# try to install gifski
RUN installGithub.r r-rust/gifski

# install AOI, climateR, and rainOrSnowTools...
RUN installGithub.r mikejohnson51/AOI@HEAD
RUN installGithub.r mikejohnson51/climateR@HEAD
RUN installGithub.r SnowHydrology/rainOrSnowTools@cicd_pipeline

RUN mkdir /lambda
COPY expose_rpkg.R /lambda

# Set ${LAMBDA_TASK_ROOT}/expose_rpkg.R as the designated script file
RUN chmod 755 -R /lambda \
    && printf "#!/bin/sh\ncd /lambda\nRscript expose_rpkg.R" > /var/runtime/bootstrap \
    && chmod +x /var/runtime/bootstrap

# Just the function name from the above script
CMD ["get_elev"]
