FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y \
    && apt-get dist-upgrade -y \
    && apt-get install -y apache2 apache2-utils wget emacs-nox htop less dcmtk git libapache2-mod-php jq imagemagick libcurl4-openssl-dev \
    && apt-get clean

RUN apt-get install -y r-base \
    && Rscript -e "install.packages('rpart', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('RColorBrewer', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('htmlTable', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('rjson', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('dplyr', dependencies=TRUE, repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('rpart.plot', dependencies=TRUE, repos='http://cran.rstudio.com/')"

RUN cd /var/www/html && rm index.html && git clone https://github.com/mmiv-center/filter_dicom_by_tag.git . \
    && chmod 777 /var/www/html/php/data \
    && chmod 777 /var/www/html/php/project_cache \
    && chmod 777 /var/www/html/php/exports \
    && chown -R www-data:www-data /var/www/html/php/project_cache \
    && chown -R www-data:www-data /var/www/html/php/data \
    && chown -R www-data:www-data /var/www/html/php/exports \
    && sed -i 's/Listen 80/Listen 8888/g' /etc/apache2/ports.conf \
    && sed -i 's/128M/2048M/g' /etc/php/7.4/apache2/php.ini \
    && sed -i 's/max_execution_time = 30/max_execution_time = 240/' /etc/php/7.4/apache2/php.ini \
    && sed -i 's/16KP/32KP/g' /etc/ImageMagick-6/policy.xml

CMD ["apache2ctl", "-D", "FOREGROUND"]
EXPOSE 8888
