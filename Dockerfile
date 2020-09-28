FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y \
    && apt-get dist-upgrade -y \
    && apt-get install -y apache2 apache2-utils wget emacs-nox htop less dcmtk git libapache2-mod-php jq imagemagick \
    && apt-get clean

RUN apt-get install -y r-base \
    && Rscript -e "install.packages('rpart', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('RColorBrewer', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('htmlTable', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('rjson', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('rpart.plot', dependencies=TRUE, repos='http://cran.rstudio.com/')"

RUN cd /var/www/html && rm index.html && git clone https://github.com/mmiv-center/filter_dicom_by_tag.git . \
    && chmod 777 /var/www/html/php/data \
    && chmod 777 /var/www/html/php/project_cache \
    && chown -R www-data:www-data /var/www/html/php/project_cache

CMD ["apache2ctl", "-D", "FOREGROUND"]
EXPOSE 80
