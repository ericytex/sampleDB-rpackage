FROM rocker/shiny:4.1.2
RUN apt-get update && apt-get install -y  libpng-dev make zlib1g-dev && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/lib/R/etc/ /usr/lib/R/etc/
RUN echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = 4)" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site
RUN R -e 'install.packages("remotes")'
RUN Rscript -e 'remotes::install_version("purrr",upgrade="never", version = "0.3.4")'
RUN Rscript -e 'remotes::install_version("rappdirs",upgrade="never", version = "0.3.3")'
RUN Rscript -e 'remotes::install_version("dplyr",upgrade="never", version = "1.0.10")'
RUN Rscript -e 'remotes::install_version("tidyr",upgrade="never", version = "1.2.1")'
RUN Rscript -e 'remotes::install_version("shinyWidgets",upgrade="never", version = "0.7.3")'
RUN Rscript -e 'remotes::install_version("shinyjs",upgrade="never", version = "2.1.0")'
RUN Rscript -e 'remotes::install_version("shinyFeedback",upgrade="never", version = "0.4.0")'
RUN Rscript -e 'remotes::install_version("RSQLite",upgrade="never", version = "2.2.17")'
RUN Rscript -e 'remotes::install_version("readr",upgrade="never", version = "2.1.2")'
RUN Rscript -e 'remotes::install_version("markdown",upgrade="never", version = "1.1")'
RUN Rscript -e 'remotes::install_version("lubridate",upgrade="never", version = "1.8.0")'
RUN Rscript -e 'remotes::install_version("emojifont",upgrade="never", version = "0.5.5")'
RUN Rscript -e 'remotes::install_version("DT",upgrade="never", version = "0.24")'

RUN mkdir /build_zone
ADD . /build_zone
WORKDIR /build_zone
RUN R -e 'remotes::install_local(upgrade="never")'
RUN rm -rf /build_zone
RUN R -e 'library(sampleDB); sampleDB::SampleDB_Setup();'
RUN << EOT bash
	export SDB_PATH=$(R --slave -e "Sys.getenv('SDB_PATH')" | cut -f 2 -d " ")
EOT
VOLUME "$SDB_PATH"
RUN unset SDB_PATH 

EXPOSE 3838

CMD ["/usr/bin/shiny-server sampleDB"]